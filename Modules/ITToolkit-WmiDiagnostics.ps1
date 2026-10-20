# IT Toolkit v1.26 Phase 3A - Credential-aware, read-only WMI diagnostic adapter.
# Safe for independent testing. No SMB connections, file changes, or fallback identities.
# Load ITToolkit-Authentication.ps1 before dot-sourcing this module.

function Assert-ToolkitWmiContext {
    param([Parameter(Mandatory=$true)]$Context)
    if ($null -eq $Context -or $Context.PSTypeNames -notcontains 'ITToolkit.AuthenticationContext') {
        throw 'Expected an authentication context from New-ToolkitAuthContext.'
    }
    if ([string]::IsNullOrWhiteSpace([string]$Context.ComputerName)) { throw 'No target computer was selected.' }
    if ($Context.Mode -eq 'Alternate' -and $null -eq $Context.Credential) {
        throw 'Alternate credentials are missing. Refusing to query with the default Windows account.'
    }
    if ($Context.Mode -notin @('Default','Alternate')) { throw 'Unknown authentication mode.' }
}

function Invoke-ToolkitWmiRead {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]$Context,
        [Parameter(Mandatory=$true)][ValidateNotNullOrEmpty()][string]$Class,
        [string]$Filter,
        [string]$Namespace='root\cimv2'
    )
    Assert-ToolkitWmiContext $Context
    $params = @{
        ComputerName = [string]$Context.ComputerName
        Class = $Class
        Namespace = $Namespace
        ErrorAction = 'Stop'
    }
    if (-not [string]::IsNullOrWhiteSpace($Filter)) { $params.Filter = $Filter }
    if ($Context.Mode -eq 'Alternate') { $params.Credential = $Context.Credential }
    # Do not retry without -Credential if access is denied or authentication fails.
    @(Get-WmiObject @params)
}

function Get-ToolkitWmiDiagnostic {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]$Context,
        [Parameter(Mandatory=$true)]
        [ValidateSet('Storage','Services','Hardware','Users','Groups','Shares','Startup','Updates')]
        [string]$Section
    )
    Assert-ToolkitWmiContext $Context
    $collected = Get-Date
    $rows = @()
    $statusOverride = $null
    try {
        switch ($Section) {
            'Storage' {
                $rows = @(Invoke-ToolkitWmiRead $Context 'Win32_LogicalDisk' 'DriveType=3' | ForEach-Object {
                    [pscustomobject]@{ DeviceID=$_.DeviceID; VolumeName=$_.VolumeName;
                        SizeGB=if ($_.Size) {[math]::Round([double]$_.Size/1GB,2)} else {$null};
                        FreeGB=if ($null -ne $_.FreeSpace) {[math]::Round([double]$_.FreeSpace/1GB,2)} else {$null};
                        FreePercent=if ($_.Size) {[math]::Round(100*[double]$_.FreeSpace/[double]$_.Size,1)} else {$null} }
                })
            }
            'Services' {
                $rows = @(Invoke-ToolkitWmiRead $Context 'Win32_Service' | Where-Object { $_.StartMode -eq 'Auto' -and $_.State -ne 'Running' } | Select-Object Name,DisplayName,State,StartMode)
            }
            'Hardware' {
                # Independent, read-only component inventory. Missing optional evidence
                # is reported explicitly instead of discarding successful checks.
                $records = New-Object System.Collections.Generic.List[object]
                foreach ($entry in @(
                    @('Computer','Win32_ComputerSystem'),
                    @('BIOS','Win32_BIOS'),
                    @('Processor','Win32_Processor'),
                    @('MemoryModule','Win32_PhysicalMemory'),
                    @('PhysicalDisk','Win32_DiskDrive'),
                    @('Enclosure','Win32_SystemEnclosure')
                )) {
                    $kind = [string]$entry[0]
                    try {
                        $items = @(Invoke-ToolkitWmiRead $Context ([string]$entry[1]))
                        if (-not $items.Count) { throw ('No ' + $kind + ' records returned.') }
                        foreach ($item in $items) {
                            switch ($kind) {
                                'Computer' {
                                    $records.Add([pscustomobject]@{
                                        RecordType=$kind; QueryStatus='Available'
                                        Name=[string]$item.Name;Manufacturer=[string]$item.Manufacturer;Model=[string]$item.Model
                                        TotalPhysicalMemoryGB=if($null -ne $item.TotalPhysicalMemory){[math]::Round([double]$item.TotalPhysicalMemory/1GB,2)}else{$null}
                                        PhysicalProcessors=$item.NumberOfProcessors;LogicalProcessors=$item.NumberOfLogicalProcessors
                                        HypervisorPresent=$item.HypervisorPresent
                                        Note='Hypervisor presence alone does not establish that this system is a virtual machine.'
                                    })
                                }
                                'BIOS' {
                                    $records.Add([pscustomobject]@{
                                        RecordType=$kind;QueryStatus='Available'
                                        Manufacturer=[string]$item.Manufacturer;SMBIOSBIOSVersion=[string]$item.SMBIOSBIOSVersion
                                        SerialNumber=[string]$item.SerialNumber;ReleaseDate=$item.ReleaseDate
                                    })
                                }
                                'Processor' {
                                    $records.Add([pscustomobject]@{
                                        RecordType=$kind;QueryStatus='Available';Name=[string]$item.Name
                                        NumberOfCores=$item.NumberOfCores;NumberOfLogicalProcessors=$item.NumberOfLogicalProcessors
                                        MaxClockSpeedMHz=$item.MaxClockSpeed
                                    })
                                }
                                'MemoryModule' {
                                    $records.Add([pscustomobject]@{
                                        RecordType=$kind;QueryStatus='Available';BankLabel=[string]$item.BankLabel
                                        DeviceLocator=[string]$item.DeviceLocator;Manufacturer=[string]$item.Manufacturer
                                        CapacityGB=if($null -ne $item.Capacity){[math]::Round([double]$item.Capacity/1GB,2)}else{$null}
                                        SpeedMHz=$item.Speed;ConfiguredClockSpeedMHz=$item.ConfiguredClockSpeed
                                        PartNumber=[string]$item.PartNumber
                                    })
                                }
                                'PhysicalDisk' {
                                    $records.Add([pscustomobject]@{
                                        RecordType=$kind;QueryStatus='Available';Model=[string]$item.Model
                                        InterfaceType=[string]$item.InterfaceType;MediaType=[string]$item.MediaType
                                        SizeGB=if($null -ne $item.Size){[math]::Round([double]$item.Size/1GB,2)}else{$null}
                                        Index=$item.Index
                                        Note='Windows-reported physical disk properties; interface and media classifications may be virtualized.'
                                    })
                                }
                                'Enclosure' {
                                    $records.Add([pscustomobject]@{
                                        RecordType=$kind;QueryStatus='Available';Manufacturer=[string]$item.Manufacturer
                                        Model=[string]$item.Model;ChassisTypes=(@($item.ChassisTypes) -join ', ')
                                        SerialNumber=[string]$item.SerialNumber
                                        Note='Chassis information is reported by firmware or hypervisor.'
                                    })
                                }
                            }
                        }
                    } catch {
                        $records.Add([pscustomobject]@{
                            RecordType=$kind;QueryStatus='Unavailable';Error=[string]$_.Exception.Message
                        })
                    }
                }
                $rows = @($records.ToArray())
                $available = @($rows | Where-Object { $_.QueryStatus -eq 'Available' }).Count
                $statusOverride = if ($available -eq 0) { 'UNAVAILABLE' } elseif ($available -lt $rows.Count) { 'PARTIAL / UNAVAILABLE' } else { 'SUCCESS' }
            }
            'Users' { $rows = @(Invoke-ToolkitWmiRead $Context 'Win32_UserAccount' 'LocalAccount=True' | Select-Object Domain,Name,Disabled,Lockout,SID) }
            'Groups' { $rows = @(Invoke-ToolkitWmiRead $Context 'Win32_Group' 'LocalAccount=True' | Select-Object Domain,Name,SID,Description) }
            'Shares' { $rows = @(Invoke-ToolkitWmiRead $Context 'Win32_Share' | Select-Object Name,Path,Description,Type) }
            'Startup' { $rows = @(Invoke-ToolkitWmiRead $Context 'Win32_StartupCommand' | Select-Object Name,Location,User,Command) }
            'Updates' { $rows = @(Invoke-ToolkitWmiRead $Context 'Win32_QuickFixEngineering' | Select-Object HotFixID,Description,InstalledOn,InstalledBy) }
        }
        return [pscustomobject]@{
            Target = [string]$Context.ComputerName
            Mode = [string]$Context.Mode
            UserName = [string]$Context.UserName
            Section = $Section
            CollectedAt = $collected
            Status = if ($null -ne $statusOverride) { $statusOverride } elseif ($rows.Count -gt 0) { 'SUCCESS' } else { 'NO RESULTS' }
            Data = @($rows)
            Error = ''
        }
    } catch {
        # A failed query is never retried under the caller identity.
        return [pscustomobject]@{
            Target = [string]$Context.ComputerName
            Mode = [string]$Context.Mode
            UserName = [string]$Context.UserName
            Section = $Section
            CollectedAt = $collected
            Status = 'UNAVAILABLE'
            Data = @()
            Error = [string]$_.Exception.Message
        }
    }
}
