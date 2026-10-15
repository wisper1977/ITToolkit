# IT Toolkit v1.27C - direct local diagnostic collector foundation.
# Windows PowerShell 5.1; dot-source when local collection is explicitly selected.
# This module is not yet wired into GUI or Classic target selection.
# Local collection runs with the current process token. It does not elevate,
# accept alternate credentials, open WinRM, or establish SMB sessions.

function Get-ToolkitLocalDiagnostic {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [ValidateSet('System','Firewall')]
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
