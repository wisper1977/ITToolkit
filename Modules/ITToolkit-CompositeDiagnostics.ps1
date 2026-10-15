# Phase 4B standalone composite diagnostics. Windows PowerShell 5.1.
# Remote data collection uses explicit WinRM credential whenever Mode = Alternate.
# No SMB connections are created, no changes are made, no authentication fallback.
function Invoke-ToolkitCompositeRemote {
    [CmdletBinding()]
    param([Parameter(Mandatory=$true)]$Context,[Parameter(Mandatory=$true)][scriptblock]$ScriptBlock,[object[]]$ArgumentList=@())
    if ($Context.PSTypeNames -notcontains 'ITToolkit.AuthenticationContext') { throw 'Invalid authentication context.' }
    if ($Context.Mode -notin @('Default','Alternate')) { throw 'Invalid authentication mode.' }
    if ($Context.Mode -eq 'Alternate' -and $null -eq $Context.Credential) { throw 'Alternate credential required; no fallback permitted.' }
    $arg = @{ ComputerName=[string]$Context.ComputerName; ScriptBlock=$ScriptBlock; ArgumentList=$ArgumentList; ErrorAction='Stop' }
    if ($Context.Mode -eq 'Alternate') { $arg.Credential=$Context.Credential; $arg.Authentication='Negotiate' }
    @(Invoke-Command @arg)
}
function Get-ToolkitCompositeDiagnostic {
    [CmdletBinding()]
    param([Parameter(Mandatory=$true)]$Context,[Parameter(Mandatory=$true)][ValidateSet('Network','Health','SharePermissions')][string]$Section)
    $rows=@(); $errors=New-Object System.Collections.Generic.List[string]
    $stamp=Get-Date
    try {
        switch ($Section) {
            'Network' {
                # DNS, ping and route are client-side connectivity checks; no credential applies.
                try {
                    $ips=@([System.Net.Dns]::GetHostAddresses([string]$Context.ComputerName) | Where-Object { $_.AddressFamily -eq [System.Net.Sockets.AddressFamily]::InterNetwork } | ForEach-Object { $_.IPAddressToString })
                    $rows+= [pscustomobject]@{Check='DNS IPv4';Source='Client';Status=if($ips.Count){'SUCCESS'}else{'NO RESULTS'};Detail=($ips -join ', ')}
                } catch { $errors.Add('DNS: '+$_.Exception.Message); $rows += [pscustomobject]@{Check='DNS IPv4';Source='Client';Status='UNAVAILABLE';Detail=$_.Exception.Message} }
                try {
                    $pingOut=@(& ping.exe -n 4 $Context.ComputerName 2>&1) -join "`n"
                    $pingCode=$LASTEXITCODE
                    $rows += [pscustomobject]@{Check='Ping (4 packets)';Source='Client';Status=if($pingCode -eq 0){'SUCCESS'}else{'REVIEW'};Detail=$pingOut}
                } catch { $errors.Add('Ping: '+$_.Exception.Message); $rows += [pscustomobject]@{Check='Ping (4 packets)';Source='Client';Status='UNAVAILABLE';Detail=$_.Exception.Message} }
                try {
                    $routeOut=@(& tracert.exe -d -w 500 -h 15 $Context.ComputerName 2>&1) -join "`n"
                    $routeCode=$LASTEXITCODE
                    $rows += [pscustomobject]@{Check='Traceroute (15 hops)';Source='Client';Status=if($routeCode -eq 0){'SUCCESS'}else{'REVIEW'};Detail=$routeOut}
                } catch { $errors.Add('Traceroute: '+$_.Exception.Message); $rows += [pscustomobject]@{Check='Traceroute (15 hops)';Source='Client';Status='UNAVAILABLE';Detail=$_.Exception.Message} }
                try {
                    $remote=@(Invoke-ToolkitCompositeRemote $Context {
                        $lines=@(& "$env:windir\System32\ipconfig.exe" /all 2>&1)
                        if($LASTEXITCODE -ne 0){throw "ipconfig /all failed (exit $LASTEXITCODE): $($lines -join ' ')"}
                        [pscustomobject]@{ Check='Remote ipconfig /all';Source='WinRM';Status='SUCCESS';Detail=($lines -join "`n") }
                    })
                    $rows+=@($remote)
                } catch {
                    # Credential-aware WMI fallback; never queries using caller identity in alternate mode.
                    $winrmError=$_.Exception.Message
                    try {
                        $adapters=@(Invoke-ToolkitWmiRead -Context $Context -Class 'Win32_NetworkAdapterConfiguration' -Filter 'IPEnabled=True')
                        if(-not $adapters.Count){throw 'No IP-enabled adapters returned.'}
                        $details=$adapters | Select-Object Description,MACAddress,DHCPEnabled,DHCPServer,IPAddress,IPSubnet,DefaultIPGateway,DNSServerSearchOrder,DNSDomain,DNSHostName | Format-List | Out-String -Width 220
                        $rows += [pscustomobject]@{Check='Remote IP configuration';Source='WMI fallback';Status='PARTIAL';Detail="WinRM unavailable: $winrmError`n$details"}
                    } catch { $errors.Add('Remote IP: '+$_.Exception.Message);$rows += [pscustomobject]@{Check='Remote IP configuration';Source='WinRM/WMI';Status='UNAVAILABLE';Detail="WinRM: $winrmError; WMI: $($_.Exception.Message)"} }
                }
            }
            'Health' {
                try {
                    $ping=Test-Connection -ComputerName $Context.ComputerName -Count 1 -Quiet -ErrorAction Stop
                    $rows += [pscustomobject]@{Check='Reachability (ICMP)';Value=if($ping){'PASS'}else{'NO PING RESPONSE (not necessarily offline)'};Status=if($ping){'SUCCESS'}else{'REVIEW'}}
                } catch { $rows += [pscustomobject]@{Check='Reachability (ICMP)';Value=$_.Exception.Message;Status='UNAVAILABLE'};$errors.Add('Ping: '+$_.Exception.Message) }
                $rows += [pscustomobject]@{Check='ADMIN$';Value='NOT TESTED - independent SMB adapter required; no SMB session opened';Status='NOT TESTED'}
                try {
                    $remote=@(Invoke-ToolkitCompositeRemote $Context {
                        $drive=Get-WmiObject Win32_LogicalDisk -Filter "DeviceID='C:'" -ErrorAction Stop
                        if($drive -and $drive.Size){$percent=[math]::Round(100*[double]$drive.FreeSpace/[double]$drive.Size,1);[pscustomobject]@{Check='System drive free space';Value="$percent%";Status=if($percent -lt 15){'REVIEW'}else{'SUCCESS'}}}
                        else {[pscustomobject]@{Check='System drive free space';Value='No drive data';Status='UNAVAILABLE'}}
                        try {$auto=@(Get-WmiObject Win32_Service -ErrorAction Stop | Where-Object {$_.StartMode -eq 'Auto' -and $_.State -ne 'Running'});[pscustomobject]@{Check='Automatic services not running';Value=[string]$auto.Count;Status='SUCCESS'}}
                        catch {[pscustomobject]@{Check='Automatic services not running';Value=$_.Exception.Message;Status='UNAVAILABLE'}}
                        try {$ev=@(Get-WinEvent -FilterHashtable @{LogName='System';Level=1,2;StartTime=(Get-Date).AddDays(-1)} -MaxEvents 100 -ErrorAction Stop);[pscustomobject]@{Check='System critical/error events (24h, max 100)';Value=[string]$ev.Count;Status='SUCCESS'}}
                        catch {if($_.FullyQualifiedErrorId -match 'NoMatchingEventsFound'){[pscustomobject]@{Check='System critical/error events (24h, max 100)';Value='0';Status='NO RESULTS'}}else{[pscustomobject]@{Check='System critical/error events (24h, max 100)';Value=$_.Exception.Message;Status='UNAVAILABLE'}}}
                    })
                    $rows+=@($remote)
                } catch {$errors.Add('Remote Health: '+$_.Exception.Message);$rows += [pscustomobject]@{Check='Remote health metrics';Value=$_.Exception.Message;Status='UNAVAILABLE'}}
                # Keep new observations on the same selected WinRM identity.
                # Independent errors cannot invalidate other successful checks.
                try {
                    $extra=@(Invoke-ToolkitCompositeRemote $Context {
                        try {
                            $os=Get-WmiObject Win32_OperatingSystem -ErrorAction Stop
                            if (-not $os -or -not $os.ConvertToDateTime($os.LastBootUpTime)) { throw 'Boot time unavailable.' }
                            $boot=$os.ConvertToDateTime($os.LastBootUpTime)
                            [pscustomobject]@{Check='System uptime (days)';Value=[string]([math]::Round(((Get-Date)-$boot).TotalDays,1));Status='SUCCESS'}
                        } catch {[pscustomobject]@{Check='System uptime (days)';Value=$_.Exception.Message;Status='UNAVAILABLE'}}
                        try {
                            $profiles=@(Get-NetFirewallProfile -ErrorAction Stop)
                            if (-not $profiles.Count) { throw 'No Windows Firewall profiles returned.' }
                            $disabled=@($profiles | Where-Object { -not [bool]$_.Enabled } | ForEach-Object { [string]$_.Name })
                            [pscustomobject]@{Check='Disabled firewall profiles';Value=($disabled -join ', ');Status='SUCCESS';DisabledCount=$disabled.Count;ProfilesQueried=$profiles.Count}
                        } catch {[pscustomobject]@{Check='Disabled firewall profiles';Value=$_.Exception.Message;Status='UNAVAILABLE'}}
                        try {
                            $patches=@(Get-WmiObject Win32_QuickFixEngineering -ErrorAction Stop)
                            [pscustomobject]@{Check='Installed QFE count';Value=[string]$patches.Count;Status='SUCCESS'}
                        } catch {[pscustomobject]@{Check='Installed QFE count';Value=$_.Exception.Message;Status='UNAVAILABLE'}}
                    })
                    $rows+=@($extra)
                } catch {
                    $errors.Add('Extended remote Health: '+$_.Exception.Message)
                    foreach ($name in @('System uptime (days)','Disabled firewall profiles','Installed QFE count')) {
                        $rows += [pscustomobject]@{Check=$name;Value=$_.Exception.Message;Status='UNAVAILABLE'}
                    }
                }
            }
            'SharePermissions' {
                $rows=@(Invoke-ToolkitCompositeRemote $Context {
                    $shares=@(Get-WmiObject Win32_Share -Filter 'Type=0' -ErrorAction Stop)
                    foreach($s in $shares){
                        $name=[string]$s.Name;$path=[string]$s.Path
                        try {
                            $shareAcl=@(Get-SmbShareAccess -Name $name -ErrorAction Stop | Select-Object AccountName,AccessControlType,AccessRight)
                            $ntfsAcl=@((Get-Acl -LiteralPath $path -ErrorAction Stop).Access | Select-Object IdentityReference,FileSystemRights,AccessControlType,IsInherited)
                            [pscustomobject]@{Share=$name;Path=$path;Status='SUCCESS';ShareACL=$shareAcl;NTFSACL=$ntfsAcl;Error=''}
                        } catch {[pscustomobject]@{Share=$name;Path=$path;Status='UNAVAILABLE';ShareACL=@();NTFSACL=@();Error=$_.Exception.Message}}
                    }
                })
            }
        }
        $statuses=@($rows | ForEach-Object {$_.Status})
        $status=if($errors.Count -gt 0 -or $statuses -contains 'UNAVAILABLE' -or $statuses -contains 'NOT TESTED' -or $statuses -contains 'PARTIAL'){'PARTIAL / UNAVAILABLE'}elseif($statuses -contains 'REVIEW'){'REVIEW'}elseif($rows.Count -eq 0){'NO RESULTS'}else{'SUCCESS'}
        [pscustomobject]@{Target=[string]$Context.ComputerName;Mode=[string]$Context.Mode;UserName=[string]$Context.UserName;Section=$Section;CollectedAt=$stamp;Status=$status;Data=@($rows);Error=($errors -join ' | ')}
    } catch {
        [pscustomobject]@{Target=[string]$Context.ComputerName;Mode=[string]$Context.Mode;UserName=[string]$Context.UserName;Section=$Section;CollectedAt=$stamp;Status='UNAVAILABLE';Data=@();Error=$_.Exception.Message}
    }
}
