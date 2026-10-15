# IT Toolkit v1.27C - direct local diagnostic collector foundation.
# Windows PowerShell 5.1; dot-source when local collection is explicitly selected.
# Used by explicit local mode in both GUI and Classic.
# Local collection runs with the current process token. It does not elevate,
# accept alternate credentials, open WinRM, or establish SMB sessions.

function Get-ToolkitLocalDiagnostic {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [ValidateSet('System','Firewall','Services','Storage','Network','Hardware','Users','Groups','Administrators','Shares','Software')]
        [string]$Section
    )

    $target = [string]$env:COMPUTERNAME
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $result = [ordered]@{
        Target = $target
        Mode = 'Local'
        UserName = [string]$identity.Name
        Section = $Section
        CollectedAt = Get-Date
        Status = 'UNAVAILABLE'
        StatusCategory = 'Unavailable'
        Data = @()
        Error = ''
        Adapter = 'Local'
        AdapterSection = $Section
    }

    try {
        switch ($Section) {
            'System' {
                # No -ComputerName or -CimSession: the local CIM service is used.
                $os = Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction Stop
                if ($null -ne $os) {
                    $result.Data = @([pscustomobject]@{
                        ComputerName = $target
                        Caption = [string]$os.Caption
                        Version = [string]$os.Version
                        BuildNumber = [string]$os.BuildNumber
                        LastBootUpTime = $os.LastBootUpTime
                        OSArchitecture = [string]$os.OSArchitecture
                    })
                }
            }
            'Software' {
                # Read-only machine-wide uninstall registry entries in both registry
                # views. Explicit views avoid 32-bit PowerShell missing 64-bit apps.
                # Scope intentionally mirrors remote HKLM uninstall inventory; Store
                # and portable apps are not comprehensively enumerated.
                $subPath = 'SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall'
                $views = if ([Environment]::Is64BitOperatingSystem) {
                    @([Microsoft.Win32.RegistryView]::Registry64, [Microsoft.Win32.RegistryView]::Registry32)
                } else {
                    @([Microsoft.Win32.RegistryView]::Registry32)
                }
                $entries = New-Object System.Collections.Generic.List[object]
                foreach ($view in $views) {
                    $base = [Microsoft.Win32.RegistryKey]::OpenBaseKey(
                        [Microsoft.Win32.RegistryHive]::LocalMachine, $view)
                    try {
                        $root = $base.OpenSubKey($subPath, $false)
                        if ($null -eq $root) { continue }
                        try {
                            foreach ($keyName in $root.GetSubKeyNames()) {
                                $entry = $root.OpenSubKey($keyName, $false)
                                if ($null -eq $entry) { continue }
                                try {
                                    $name = [string]$entry.GetValue('DisplayName', '')
                                    if ([string]::IsNullOrWhiteSpace($name)) { continue }
                                    $entries.Add([pscustomobject]@{
                                        Name = $name
                                        Version = [string]$entry.GetValue('DisplayVersion', '')
                                        Publisher = [string]$entry.GetValue('Publisher', '')
                                    })
                                } finally {
                                    $entry.Dispose()
                                }
                            }
                        } finally {
                            $root.Dispose()
                        }
                    } finally {
                        $base.Dispose()
                    }
                }
                $result.Data = @($entries | Sort-Object Name,Version,Publisher -Unique)
                # No uninstall entries -> NoData, not proof that nothing is installed.
            }
            'Shares' {
                # Read-only SMB share inventory (including built-in administrative shares).
                # Share permissions and backing-path ACLs are separate diagnostics.
                $shares = @(Get-CimInstance -ClassName Win32_Share -ErrorAction Stop)
                $result.Data = @($shares | Sort-Object Name | ForEach-Object {
                    [pscustomobject]@{
                        Name = [string]$_.Name
                        Path = [string]$_.Path
                        Description = [string]$_.Description
                        Type = [uint32]$_.Type
                    }
                })
                # No shares is a NoData result; it is not evidence of missing access.
            }
            'Administrators' {
                # SID identifies the built-in group independently of OS display language.
                # Direct members only: domain group nesting is deliberately not expanded.
                $adminSid = New-Object System.Security.Principal.SecurityIdentifier('S-1-5-32-544')
                $members = @(Get-LocalGroupMember -SID $adminSid -ErrorAction Stop)
                $records = New-Object System.Collections.Generic.List[object]
                $records.Add([pscustomobject]@{
                    RecordType = 'Summary'
                    GroupSID = 'S-1-5-32-544'
                    DirectMemberCount = $members.Count
                    Note = 'Direct members only; nested domain group membership is not expanded.'
                })
                foreach ($member in @($members | Sort-Object Name)) {
                    $records.Add([pscustomobject]@{
                        RecordType = 'Member'
                        Name = [string]$member.Name
                        ObjectClass = [string]$member.ObjectClass
                        PrincipalSource = [string]$member.PrincipalSource
                        SID = if ($null -ne $member.SID) { [string]$member.SID.Value } else { '' }
                    })
                }
                $result.Data = @($records.ToArray())
                # An empty membership list still yields SUCCESS if the group was queried.
            }
            'Groups' {
                # Read-only local SAM group inventory. Membership enumeration is a
                # separate follow-up; do not infer membership from group existence.
                $groups = @(Get-CimInstance -ClassName Win32_Group -Filter 'LocalAccount=True' -ErrorAction Stop)
                $result.Data = @($groups | Sort-Object Name | ForEach-Object {
                    [pscustomobject]@{
                        Domain = [string]$_.Domain
                        Name = [string]$_.Name
                        SID = [string]$_.SID
                        Description = [string]$_.Description
                    }
                })
            }
            'Users' {
                # Read-only local SAM account inventory, matching the remote Users scope.
                # Do not expose password material or attempt local/domain account changes.
                $accounts = @(Get-CimInstance -ClassName Win32_UserAccount -Filter 'LocalAccount=True' -ErrorAction Stop)
                $result.Data = @($accounts | Sort-Object Name | ForEach-Object {
                    [pscustomobject]@{
                        Domain = [string]$_.Domain
                        Name = [string]$_.Name
                        Disabled = [bool]$_.Disabled
                        Lockout = [bool]$_.Lockout
                        SID = [string]$_.SID
                    }
                })
                # Zero local accounts returned is NoData; query success alone is not account-health assessment.
            }
            'Hardware' {
                # Read-only direct CIM inventory. Preserve type per record for report clarity.
                $computer = Get-CimInstance -ClassName Win32_ComputerSystem -ErrorAction Stop
                $bios = Get-CimInstance -ClassName Win32_BIOS -ErrorAction Stop
                $processors = @(Get-CimInstance -ClassName Win32_Processor -ErrorAction Stop)
                $drives = @(Get-CimInstance -ClassName Win32_DiskDrive -ErrorAction Stop)
                if ($null -eq $computer -or $null -eq $bios -or $processors.Count -eq 0) {
                    throw 'Essential local hardware inventory was missing; collection cannot be verified.'
                }
                $records = New-Object System.Collections.Generic.List[object]
                $records.Add([pscustomobject]@{
                    RecordType = 'Computer'
                    Manufacturer = [string]$computer.Manufacturer
                    Model = [string]$computer.Model
                    TotalPhysicalMemoryGB = if ($null -ne $computer.TotalPhysicalMemory) {
                        [math]::Round([double]$computer.TotalPhysicalMemory / 1GB, 2)
                    } else { $null }
                })
                $records.Add([pscustomobject]@{
                    RecordType = 'BIOS'
                    Manufacturer = [string]$bios.Manufacturer
                    SMBIOSBIOSVersion = [string]$bios.SMBIOSBIOSVersion
                    SerialNumber = [string]$bios.SerialNumber
                })
                foreach ($cpu in $processors) {
                    $records.Add([pscustomobject]@{
                        RecordType = 'Processor'
                        Name = [string]$cpu.Name
                        NumberOfCores = $cpu.NumberOfCores
                        NumberOfLogicalProcessors = $cpu.NumberOfLogicalProcessors
                    })
                }
                foreach ($disk in $drives) {
                    $records.Add([pscustomobject]@{
                        RecordType = 'PhysicalDisk'
                        Model = [string]$disk.Model
                        InterfaceType = [string]$disk.InterfaceType
                        SizeGB = if ($null -ne $disk.Size) {
                            [math]::Round([double]$disk.Size / 1GB, 2)
                        } else { $null }
                    })
                }
                $result.Data = @($records.ToArray())
            }
            'Network' {
                # Read-only local adapter configuration; no remote ping, traceroute or WinRM.
                # Preserve each address/gateway as a distinct list in a single string field
                # so GUI, Classic, and saved text reports remain readable.
                $adapters = @(Get-CimInstance -ClassName Win32_NetworkAdapterConfiguration -Filter 'IPEnabled=True' -ErrorAction Stop)
                $result.Data = @($adapters | Sort-Object Index | ForEach-Object {
                    [pscustomobject]@{
                        Description = [string]$_.Description
                        InterfaceIndex = [int]$_.Index
                        MACAddress = [string]$_.MACAddress
                        DHCPEnabled = [bool]$_.DHCPEnabled
                        IPAddresses = (@($_.IPAddress | Where-Object { $_ }) -join ', ')
                        SubnetMasks = (@($_.IPSubnet | Where-Object { $_ }) -join ', ')
                        DefaultGateways = (@($_.DefaultIPGateway | Where-Object { $_ }) -join ', ')
                        DNSServers = (@($_.DNSServerSearchOrder | Where-Object { $_ }) -join ', ')
                        DNSDomain = [string]$_.DNSDomain
                    }
                })
                # A valid query with no enabled IP adapters yields NoData, not Success.
            }
            'Storage' {
                # Match the existing remote disk-space report: fixed logical disks only.
                # Local CIM does not require remote WinRM, ADMIN$, or alternate credentials.
                $disks = @(Get-CimInstance -ClassName Win32_LogicalDisk -Filter 'DriveType=3' -ErrorAction Stop)
                $result.Data = @($disks | Sort-Object DeviceID | ForEach-Object {
                    $capacity = if ($null -ne $_.Size) { [double]$_.Size } else { $null }
                    $free = if ($null -ne $_.FreeSpace) { [double]$_.FreeSpace } else { $null }
                    [pscustomobject]@{
                        DeviceID = [string]$_.DeviceID
                        VolumeName = [string]$_.VolumeName
                        SizeGB = if ($null -ne $capacity) { [math]::Round($capacity / 1GB, 2) } else { $null }
                        FreeGB = if ($null -ne $free) { [math]::Round($free / 1GB, 2) } else { $null }
                        FreePercent = if ($null -ne $capacity -and $capacity -gt 0 -and $null -ne $free) {
                            [math]::Round(100 * $free / $capacity, 1)
                        } else { $null }
                    }
                })
                # An empty fixed-drive query is NoData; it is not evidence of zero free space.
            }
            'Services' {
                # Match the existing remote Services report: automatic-start
                # services whose current state is not Running. Read only.
                # An empty finding list is still a successful query, not NoData.
                $services = @(Get-CimInstance -ClassName Win32_Service -ErrorAction Stop)
                if ($services.Count -eq 0) {
                    throw 'The local service query returned no service records; collection cannot be verified.'
                }
                $stopped = @($services | Where-Object {
                    $_.StartMode -eq 'Auto' -and $_.State -ne 'Running'
                } | Sort-Object Name)
                $records = New-Object System.Collections.Generic.List[object]
                $records.Add([pscustomobject]@{
                    RecordType = 'Summary'
                    ServicesQueried = $services.Count
                    AutomaticNotRunning = $stopped.Count
                    Note = if ($stopped.Count -eq 0) {
                        'No nonrunning automatic-start services found. Collection success does not establish overall health.'
                    } else {
                        'Automatic-start services not currently running; some may be trigger-start or intentionally stopped.'
                    }
                })
                foreach ($svc in $stopped) {
                    $records.Add([pscustomobject]@{
                        RecordType = 'Service'
                        Name = [string]$svc.Name
                        DisplayName = [string]$svc.DisplayName
                        State = [string]$svc.State
                        StartMode = [string]$svc.StartMode
                    })
                }
                $result.Data = @($records.ToArray())
            }
            'Firewall' {
                # A disabled firewall profile is observable configuration data,
                # not a failed collection and not automatically a health verdict.
                $profiles = @(Get-NetFirewallProfile -ErrorAction Stop)
                $result.Data = @($profiles | ForEach-Object {
                    [pscustomobject]@{
                        Name = [string]$_.Name
                        Enabled = [bool]$_.Enabled
                        DefaultInboundAction = [string]$_.DefaultInboundAction
                        DefaultOutboundAction = [string]$_.DefaultOutboundAction
                    }
                })
            }
        }
        if (@($result.Data).Count -gt 0) {
            $result.Status = 'SUCCESS'
            $result.StatusCategory = 'Success'
        } else {
            $result.Status = 'NO RESULTS'
            $result.StatusCategory = 'NoData'
        }
    } catch {
        $message = [string]$_.Exception.Message
        $denied = $_.Exception -is [System.UnauthorizedAccessException] -or
            $message -match '(?i)access is denied|access denied|0x80070005|unauthorized'
        $result.Status = if ($denied) { 'ACCESS DENIED' } else { 'UNAVAILABLE' }
        $result.StatusCategory = if ($denied) { 'AccessDenied' } else { 'Unavailable' }
        $result.Error = $message
    }

    # Return a new result with no credential or process-token object embedded.
    return [pscustomobject]$result
}
