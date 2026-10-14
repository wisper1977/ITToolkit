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
                $cs = @(Invoke-ToolkitWmiRead $Context 'Win32_ComputerSystem' | Select-Object Name,Manufacturer,Model,TotalPhysicalMemory)
                $bios = @(Invoke-ToolkitWmiRead $Context 'Win32_BIOS' | Select-Object Manufacturer,SMBIOSBIOSVersion,SerialNumber)
                $cpu = @(Invoke-ToolkitWmiRead $Context 'Win32_Processor' | Select-Object Name,NumberOfCores,NumberOfLogicalProcessors)
                $rows = @($cs + $bios + $cpu)
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
            Status = if ($rows.Count -gt 0) { 'SUCCESS' } else { 'NO RESULTS' }
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
