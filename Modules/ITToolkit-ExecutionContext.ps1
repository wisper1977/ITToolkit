# Shared IT Toolkit execution context (Windows PowerShell 5.1).
# Informational launch intent, never an authorization token. No credentials stored.
function Get-ToolkitExecutionContext {
    [CmdletBinding()]
    param(
        [ValidateSet('Current','SeparateAccount','OnDemand')]
        [string]$Mode = 'Current'
    )
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    if ($null -eq $identity -or $null -eq $identity.User) {
        throw 'Windows did not return a valid process identity.'
    }
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    $isElevated = [bool]$principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    return [pscustomobject]@{
        Mode = $Mode
        WindowsIdentity = $identity.Name
        WindowsSid = $identity.User.Value
        IsElevated = $isElevated
        SessionId = [System.Diagnostics.Process]::GetCurrentProcess().SessionId
        # Target authentication remains independently selected in GUI/Classic.
        RemoteAuthMode = 'Default'
    }
}
