# IT Toolkit v1.27C - direct local diagnostic collector foundation.
# Windows PowerShell 5.1; dot-source when local collection is explicitly selected.
# Used by explicit local mode in both GUI and Classic.
# Local collection runs with the current process token. It does not elevate,
# accept alternate credentials, open WinRM, or establish SMB sessions.

function Get-ToolkitLocalDiagnostic {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [ValidateSet('System','Firewall','Services')]
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
