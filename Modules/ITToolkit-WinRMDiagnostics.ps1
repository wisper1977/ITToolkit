# IT Toolkit v1.26 Phase 3B: Read-only WinRM diagnostics under selected credentials.
# Requires ITToolkit-Authentication.ps1. Does not create persistent sessions or fall back.

function Get-ToolkitWinRMDiagnostic {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]$Context,
        [Parameter(Mandatory=$true)]
        [ValidateSet('Identity','Tasks','Firewall','BitLocker','Administrators')]
        [string]$Section
    )
    if ($null -eq $Context -or $Context.PSTypeNames -notcontains 'ITToolkit.AuthenticationContext') {
        throw 'Expected an authentication context from New-ToolkitAuthContext.'
    }
    if ($Context.Mode -notin @('Default','Alternate')) { throw 'Invalid authentication mode.' }
    if ([string]::IsNullOrWhiteSpace([string]$Context.ComputerName)) { throw 'No target computer selected.' }
    if ($Context.Mode -eq 'Alternate' -and $null -eq $Context.Credential) {
        throw 'Alternate credentials are missing; refusing fallback to the current identity.'
    }

    $collected = Get-Date
    $rows = @()
    $status = 'UNAVAILABLE'
    $errorText = ''
    try {
        # This script block runs on the target, not locally. All commands below are read-only.
        $remote = {
            param([string]$RequestedSection)
            $ErrorActionPreference = 'Stop'
            switch ($RequestedSection) {
                'Identity' {
                    [pscustomobject]@{
                        Computer = $env:COMPUTERNAME
                        Identity = [Security.Principal.WindowsIdentity]::GetCurrent().Name
                    }
                }
                'Tasks' {
                    if (-not (Get-Command Get-ScheduledTask -ErrorAction SilentlyContinue)) {
                        throw 'ScheduledTasks module is not available on this target.'
                    }
                    Get-ScheduledTask -ErrorAction Stop | ForEach-Object {
                        [pscustomobject]@{
                            TaskPath = [string]$_.TaskPath
                            TaskName = [string]$_.TaskName
                            State = [string]$_.State
                            Author = [string]$_.Author
                        }
                    }
                }
                'Firewall' {
                    if (-not (Get-Command Get-NetFirewallProfile -ErrorAction SilentlyContinue)) {
                        throw 'NetSecurity module is not available on this target.'
                    }
                    Get-NetFirewallProfile -ErrorAction Stop | ForEach-Object {
                        [pscustomobject]@{
                            Name = [string]$_.Name
                            Enabled = [bool]$_.Enabled
                            DefaultInboundAction = [string]$_.DefaultInboundAction
                            DefaultOutboundAction = [string]$_.DefaultOutboundAction
                        }
                    }
                }
                'BitLocker' {
                    if (-not (Get-Command Get-BitLockerVolume -ErrorAction SilentlyContinue)) {
                        throw 'BitLocker module is not available on this target.'
                    }
                    Get-BitLockerVolume -ErrorAction Stop | ForEach-Object {
                        # Do not query or serialize any key protector secrets/recovery passwords.
                        [pscustomobject]@{
                            MountPoint = [string]$_.MountPoint
                            VolumeStatus = [string]$_.VolumeStatus
                            ProtectionStatus = [string]$_.ProtectionStatus
                            EncryptionPercentage = $_.EncryptionPercentage
                            EncryptionMethod = [string]$_.EncryptionMethod
                        }
                    }
                }
                'Administrators' {
                    if (-not (Get-Command Get-LocalGroup -ErrorAction SilentlyContinue) -or
                        -not (Get-Command Get-LocalGroupMember -ErrorAction SilentlyContinue)) {
                        throw 'Microsoft.PowerShell.LocalAccounts commands are not available on this target.'
                    }
                    $adminSid = New-Object System.Security.Principal.SecurityIdentifier('S-1-5-32-544')
                    $adminGroup = Get-LocalGroup -SID $adminSid -ErrorAction Stop
                    Get-LocalGroupMember -Group $adminGroup.Name -ErrorAction Stop | ForEach-Object {
                        [pscustomobject]@{
                            Name = [string]$_.Name
                            ObjectClass = [string]$_.ObjectClass
                            PrincipalSource = [string]$_.PrincipalSource
                            SID = [string]$_.SID
                        }
                    }
                }
                default { throw 'Unsupported diagnostic section.' }
            }
        }
        $invokeArgs = @{
            ComputerName = [string]$Context.ComputerName
            ScriptBlock = $remote
            ArgumentList = @($Section)
            ErrorAction = 'Stop'
        }
        if ($Context.Mode -eq 'Alternate') {
            $invokeArgs.Credential = $Context.Credential
            $invokeArgs.Authentication = 'Negotiate'
        }
        $rows = @(Invoke-Command @invokeArgs)
        $status = if ($rows.Count -gt 0) { 'SUCCESS' } else { 'NO RESULTS' }
    } catch {
        $errorText = [string]$_.Exception.Message
        $rows = @()
    }
    [pscustomobject]@{
        Target = [string]$Context.ComputerName
        Mode = [string]$Context.Mode
        UserName = [string]$Context.UserName
        Section = $Section
        CollectedAt = $collected
        Status = $status
        Data = @($rows)
        Error = $errorText
    }
}
