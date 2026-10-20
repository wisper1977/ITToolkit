# v1.26 Phase 3D: isolated mixed-method diagnostic probes.
# Remote commands execute inside one authenticated WinRM operation.
# No credential fallback, remote mutations, or secret collection.
function Get-ToolkitMixedDiagnostic {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]$Context,
        [Parameter(Mandatory=$true)]
        [ValidateSet('SystemInfo','GroupPolicy','Sessions','Events','RegistrySoftware')]
        [string]$Section
    )
    if ($null -eq $Context -or $Context.PSTypeNames -notcontains 'ITToolkit.AuthenticationContext') {
        throw 'Expected an authentication context from New-ToolkitAuthContext.'
    }
    if ($Context.Mode -notin @('Default','Alternate')) { throw 'Unknown authentication mode.' }
    if ($Context.Mode -eq 'Alternate' -and $null -eq $Context.Credential) {
        throw 'Alternate credentials missing: refusing to use current Windows identity.'
    }
    $started = Get-Date
    $status = 'UNAVAILABLE'
    $details = ''
    $results = @()
    try {
        $scriptBlock = {
            param([string]$Kind)
            $ErrorActionPreference = 'Stop'
            switch ($Kind) {
                'SystemInfo' {
                    # Run CIM queries on the selected target under the verified WinRM identity.
                    $records = New-Object System.Collections.Generic.List[object]
                    $failures = New-Object System.Collections.Generic.List[string]
                    foreach ($check in @('OperatingSystem','ComputerSystem','Processor','BIOS','PendingRestart','SecureBoot','TPM')) {
                        try {
                            switch ($check) {
                                'OperatingSystem' {
                                    $os = Get-CimInstance Win32_OperatingSystem -ErrorAction Stop
                                    if (-not $os) { throw 'No operating system data returned.' }
                                    $total = [double]$os.TotalVisibleMemorySize
                                    $free = [double]$os.FreePhysicalMemory
                                    $records.Add([pscustomobject]@{
                                        Check=$check; QueryStatus='Available'
                                        ComputerName=[string]$env:COMPUTERNAME
                                        Caption=[string]$os.Caption; Version=[string]$os.Version
                                        BuildNumber=[string]$os.BuildNumber; OSArchitecture=[string]$os.OSArchitecture
                                        InstallDate=$os.InstallDate; LastBootUpTime=$os.LastBootUpTime
                                        UptimeDays=if($os.LastBootUpTime){[math]::Round(((Get-Date)-[datetime]$os.LastBootUpTime).TotalDays,1)}else{$null}
                                        TotalMemoryGB=if($total -gt 0){[math]::Round($total/1MB,2)}else{$null}
                                        AvailableMemoryGB=if($total -gt 0){[math]::Round($free/1MB,2)}else{$null}
                                        MemoryUsedPercent=if($total -gt 0){[math]::Round(100*($total-$free)/$total,1)}else{$null}
                                        WindowsDirectory=[string]$os.WindowsDirectory
                                    })
                                }
                                'ComputerSystem' {
                                    $cs = Get-CimInstance Win32_ComputerSystem -ErrorAction Stop
                                    if (-not $cs) { throw 'No computer system data returned.' }
                                    $records.Add([pscustomobject]@{
                                        Check=$check;QueryStatus='Available'
                                        Manufacturer=[string]$cs.Manufacturer; Model=[string]$cs.Model
                                        Domain=[string]$cs.Domain; PartOfDomain=[bool]$cs.PartOfDomain
                                        SystemType=[string]$cs.SystemType
                                        LogicalProcessors=$cs.NumberOfLogicalProcessors
                                        PhysicalProcessors=$cs.NumberOfProcessors
                                        HypervisorPresent=$cs.HypervisorPresent
                                    })
                                }
                                'Processor' {
                                    $cpu = @(Get-CimInstance Win32_Processor -ErrorAction Stop)
                                    if (-not $cpu.Count) { throw 'No processor data returned.' }
                                    foreach($p in $cpu) {
                                        $records.Add([pscustomobject]@{
                                            Check=$check;QueryStatus='Available'
                                            Name=[string]$p.Name; Cores=$p.NumberOfCores
                                            LogicalProcessors=$p.NumberOfLogicalProcessors
                                            MaxClockSpeedMHz=$p.MaxClockSpeed
                                        })
                                    }
                                }
                                'BIOS' {
                                    $bios = Get-CimInstance Win32_BIOS -ErrorAction Stop
                                    if (-not $bios) { throw 'No BIOS data returned.' }
                                    $records.Add([pscustomobject]@{
                                        Check=$check;QueryStatus='Available'
                                        Manufacturer=[string]$bios.Manufacturer
                                        SMBIOSBIOSVersion=[string]$bios.SMBIOSBIOSVersion
                                        ReleaseDate=$bios.ReleaseDate
                                    })
                                }
                                'PendingRestart' {
                                    $found = New-Object System.Collections.Generic.List[string]
                                    foreach($key in @(
                                        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending',
                                        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired'
                                    )) { if(Test-Path -LiteralPath $key -ErrorAction Stop) { $found.Add($key.Split('\')[-1]) } }
                                    $session = Get-ItemProperty -LiteralPath 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager' -Name PendingFileRenameOperations -ErrorAction SilentlyContinue
                                    if ($null -ne $session -and @($session.PendingFileRenameOperations).Count -gt 0) { $found.Add('PendingFileRenameOperations') }
                                    $records.Add([pscustomobject]@{
                                        Check=$check;QueryStatus='Available'
                                        IndicatorsPresent=($found.Count -gt 0);Indicators=($found -join ', ')
                                        Note='Selected indicators only; no indicator does not establish that a reboot is unnecessary.'
                                    })
                                }
                                'SecureBoot' {
                                    if (-not (Get-Command Confirm-SecureBootUEFI -ErrorAction SilentlyContinue)) { throw 'Secure Boot query command unavailable.' }
                                    $enabled = Confirm-SecureBootUEFI -ErrorAction Stop
                                    $records.Add([pscustomobject]@{Check=$check;QueryStatus='Available';Enabled=[bool]$enabled})
                                }
                                'TPM' {
                                    if (-not (Get-Command Get-Tpm -ErrorAction SilentlyContinue)) { throw 'TPM query command unavailable.' }
                                    $tpm = Get-Tpm -ErrorAction Stop
                                    if ($null -eq $tpm -or $null -eq $tpm.TpmPresent -or
                                        $null -eq $tpm.TpmReady -or $null -eq $tpm.TpmEnabled) {
                                        throw 'TPM query returned incomplete status values.'
                                    }
                                    $records.Add([pscustomobject]@{
                                        Check=$check;QueryStatus='Available'
                                        TpmPresent=$tpm.TpmPresent;TpmReady=$tpm.TpmReady
                                        TpmEnabled=$tpm.TpmEnabled
                                    })
                                }
                            }
                        } catch {
                            $failures.Add($check)
                            $records.Add([pscustomobject]@{Check=$check;QueryStatus='Unavailable';Error=[string]$_.Exception.Message})
                        }
                    }
                    $records
                }
                'GroupPolicy' {
                    # Computer RSOP; reports may be unavailable for some system configurations.
                    $output = @(& "$env:SystemRoot\System32\gpresult.exe" /SCOPE COMPUTER /R 2>&1)
                    $exitCode = $LASTEXITCODE
                    if ($exitCode -ne 0) { throw "gpresult failed (exit $exitCode): $($output -join ' ')" }
                    foreach ($line in $output) { if ($null -ne $line) { [pscustomobject]@{ Line = [string]$line } } }
                }
                'Sessions' {
                    $exe = "$env:SystemRoot\System32\quser.exe"
                    if (-not (Test-Path -LiteralPath $exe -PathType Leaf)) { throw 'quser.exe unavailable on the target.' }
                    $output = @(& $exe 2>&1)
                    $exitCode = $LASTEXITCODE
                    if ($exitCode -ne 0) { throw "quser failed (exit $exitCode): $($output -join ' ')" }
                    foreach ($line in $output) { if ($null -ne $line) { [pscustomobject]@{ Line = [string]$line } } }
                }
                'Events' {
                    # Critical/Error events, System log, last seven days, max 20.
                    try {
                        Get-WinEvent -FilterHashtable @{
                            LogName='System'; Level=@(1,2); StartTime=(Get-Date).AddDays(-7)
                        } -MaxEvents 20 -ErrorAction Stop | ForEach-Object {
                            [pscustomobject]@{
                                TimeCreated = $_.TimeCreated
                                Id = $_.Id
                                LevelDisplayName = [string]$_.LevelDisplayName
                                ProviderName = [string]$_.ProviderName
                                Message = [string]$_.Message
                            }
                        }
                    } catch {
                        if ($_.FullyQualifiedErrorId -match 'NoMatchingEventsFound') { return }
                        throw
                    }
                }
                'RegistrySoftware' {
                    # HKLM-only uninstall entries (both views). Do NOT enumerate credentials or keys.
                    $locations = @(
                        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*',
                        'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*'
                    )
                    foreach ($loc in $locations) {
                        Get-ItemProperty -Path $loc -ErrorAction SilentlyContinue |
                            Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_.DisplayName) } |
                            ForEach-Object {
                                [pscustomobject]@{
                                    Name = [string]$_.DisplayName
                                    Version = [string]$_.DisplayVersion
                                    Publisher = [string]$_.Publisher
                                    InstallDate = [string]$_.InstallDate
                                }
                            }
                    }
                }
                default { throw 'Unsupported mixed diagnostic section.' }
            }
        }
        $parameters = @{
            ComputerName = [string]$Context.ComputerName
            ScriptBlock = $scriptBlock
            ArgumentList = @($Section)
            ErrorAction = 'Stop'
        }
        if ($Context.Mode -eq 'Alternate') {
            $parameters.Credential = $Context.Credential
            $parameters.Authentication = 'Negotiate'
        }
        $results = @(Invoke-Command @parameters)
        $status = if ($Section -eq 'SystemInfo' -and $results.Count -gt 0) {
            $available = @($results | Where-Object { $_.QueryStatus -eq 'Available' }).Count
            if ($available -eq 0) { 'UNAVAILABLE' }
            elseif ($available -lt $results.Count) { 'PARTIAL / UNAVAILABLE' }
            else { 'SUCCESS' }
        } elseif ($results.Count -gt 0) { 'SUCCESS' } else { 'NO RESULTS' }
    } catch {
        $details = [string]$_.Exception.Message
        $results = @()
    }
    [pscustomobject]@{
        Target = [string]$Context.ComputerName
        Mode = [string]$Context.Mode
        UserName = [string]$Context.UserName
        Section = $Section
        CollectedAt = $started
        Status = $status
        Count = @($results).Count
        Data = @($results)
        Error = $details
    }
}
