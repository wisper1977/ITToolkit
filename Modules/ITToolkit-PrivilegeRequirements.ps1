# IT Toolkit v1.27 - shared diagnostic operation requirements.
# Descriptive policy metadata only. Never grants permission or selects credentials.
# The actual Windows token, UAC consent and authenticated remote transport remain authoritative.
function Get-ToolkitDiagnosticRequirements {
    [CmdletBinding()]
    param()
    $sections = @(
        'System','Network','Storage','Services','Events','Users','Groups',
        'Shares','Health','Hardware','Software','Updates','Tasks',
        'Administrators','Sessions','SharePermissions','Firewall',
        'BitLocker','Startup','Policy'
    )
    foreach ($section in $sections) {
        $supportsLocalUac = $section -in @('BitLocker','Policy')
        [pscustomobject]@{
            Section = $section
            Operation = 'ReadOnlyDiagnostic'
            LocalExecution = 'CurrentToken'
            LocalUacAvailable = [bool]$supportsLocalUac
            RemoteAuthentication = 'ExistingDefaultOrExplicitAlternate'
            InteractiveDesktopRequired = $false
            Notes = if ($supportsLocalUac) {
                'Scoped UAC is available in local mode when the process is not elevated. It is not mandatory for all queries.'
            } else {
                'No scoped local UAC handoff is registered for this diagnostic.'
            }
        }
    }
}

function Get-ToolkitDiagnosticRequirement {
    [CmdletBinding()]
    param([Parameter(Mandatory=$true)][ValidateNotNullOrEmpty()][string]$Section)
    $match = @(Get-ToolkitDiagnosticRequirements | Where-Object { $_.Section -eq $Section })
    if ($match.Count -ne 1) { throw "Unknown toolkit diagnostic section: $Section" }
    return $match[0]
}

function Get-ToolkitDiagnosticExecutionChoice {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][ValidateNotNullOrEmpty()][string]$Section,
        [Parameter(Mandatory=$true)][ValidateSet('Local','Default','Alternate')][string]$TargetMode,
        [Parameter(Mandatory=$true)][bool]$IsElevated
    )
    $requirement = Get-ToolkitDiagnosticRequirement -Section $Section
    $offerUac = $TargetMode -eq 'Local' -and
        [bool]$requirement.LocalUacAvailable -and -not $IsElevated
    [pscustomobject]@{
        Section = $requirement.Section
        TargetMode = $TargetMode
        RunAction = if ($offerUac) { 'RunElevatedUac' } else { 'RunSelected' }
        LocalUacAvailable = [bool]$requirement.LocalUacAvailable
        # This metadata cannot authorize any operation or infer the remote identity.
        RequiresAuthorizationCheck = $true
    }
}
