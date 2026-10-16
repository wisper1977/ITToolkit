# IT Toolkit v1.27 - read-only operation authorization assessment.
# Windows PowerShell 5.1. Dot-source ExecutionContext and PrivilegeRequirements first.
# Advisory/preflight only: does not grant privileges, start a process, prompt, or change identity.
# The caller must still enforce Windows UAC and the transport's actual permissions.
function Get-ToolkitOperationAuthorization {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][ValidateNotNullOrEmpty()][string]$Section,
        [Parameter(Mandatory=$true)][ValidateSet('Local','Default','Alternate')][string]$TargetMode,
        [Parameter(Mandatory=$true)][ValidateNotNullOrEmpty()][string]$TargetComputer,
        [ValidateSet('Auto','CurrentToken','ElevatedLocal')][string]$RequestedRoute = 'Auto',
        [AllowNull()][object]$AuthenticationContext
    )
    if (-not (Get-Command Get-ToolkitExecutionContext -CommandType Function -ErrorAction SilentlyContinue)) {
        throw 'Load ITToolkit-ExecutionContext.ps1 before authorization assessment.'
    }
    if (-not (Get-Command Get-ToolkitDiagnosticExecutionChoice -CommandType Function -ErrorAction SilentlyContinue)) {
        throw 'Load ITToolkit-PrivilegeRequirements.ps1 before authorization assessment.'
    }
    # Fail closed for unknown sections, even if the caller proposes CurrentToken.
    $requirement = Get-ToolkitDiagnosticRequirement -Section $Section
    $actual = Get-ToolkitExecutionContext
    $target = $TargetComputer.Trim()
    $blocked = ''
    $state = 'ReadyForAttempt'
    $route = 'CurrentToken'
    $authMode = if ($TargetMode -eq 'Local') { 'CurrentWindowsToken' } else { $TargetMode }
    # No alternate identity is selected until its typed, target-bound context validates.
    # Do not present the initiating Windows identity as a fallback on a blocked request.
    $requestedIdentity = if ($TargetMode -eq 'Alternate') { '' } else { [string]$actual.WindowsIdentity }

    if ([string]::IsNullOrWhiteSpace($target)) {
        throw 'TargetComputer must not be empty.'
    }
    if ($TargetMode -eq 'Local') {
        if ($target -ine [Environment]::MachineName -and $target -notin @('.','localhost')) {
            $blocked = 'Local operation target must be this computer.'
        }
        if ($null -ne $AuthenticationContext) {
            $blocked = 'Local operation cannot accept a remote authentication context.'
        }
        $choice = Get-ToolkitDiagnosticExecutionChoice -Section $Section -TargetMode Local -IsElevated ([bool]$actual.IsElevated)
        if ($RequestedRoute -eq 'ElevatedLocal' -and -not [bool]$requirement.LocalUacAvailable) {
            $blocked = 'No scoped elevated-local route is registered for this diagnostic.'
        } elseif ($RequestedRoute -eq 'ElevatedLocal' -and [bool]$actual.IsElevated) {
            # An elevated token already exists; no new UAC authorization is needed.
            $route = 'CurrentToken'
        } elseif ($RequestedRoute -eq 'ElevatedLocal' -or
            ($RequestedRoute -eq 'Auto' -and $choice.RunAction -eq 'RunElevatedUac')) {
            $route = 'ElevatedLocalUac'
            $state = 'ConsentRequired'
        }
    } else {
        if ($RequestedRoute -eq 'ElevatedLocal') {
            $blocked = 'Windows local UAC cannot authorize a remote diagnostic.'
        }
        if ($TargetMode -eq 'Default') {
            if ($null -ne $AuthenticationContext) {
                $blocked = 'Default remote mode must not accept an alternate authentication context.'
            }
        } else {
            $authMode = 'Alternate'
            # Validate the existing typed context, its chosen target, and live PSCredential;
            # never copy the credential to the returned preflight result.
            if ($null -eq $AuthenticationContext -or
                $AuthenticationContext.PSTypeNames -notcontains 'ITToolkit.AuthenticationContext' -or
                [string]$AuthenticationContext.Mode -ne 'Alternate' -or
                [string]$AuthenticationContext.ComputerName -ine $target -or
                $AuthenticationContext.Credential -isnot [System.Management.Automation.PSCredential] -or
                [string]::IsNullOrWhiteSpace([string]$AuthenticationContext.UserName) -or
                [string]$AuthenticationContext.UserName -ine [string]$AuthenticationContext.Credential.UserName) {
                $blocked = 'Missing, invalid, or target-mismatched explicit alternate authentication context. No fallback allowed.'
            } else {
                $requestedIdentity = [string]$AuthenticationContext.UserName
            }
        }
    }
    if ($blocked) { $state = 'Blocked' }
    # ReadyForAttempt is NOT authenticated/authorized. Windows and remote transports
    # enforce actual access; post-execution collector identity must be recorded separately.
    [pscustomobject]@{
        Operation = 'ReadOnlyDiagnostic'
        Section = [string]$requirement.Section
        TargetComputer = $target
        TargetMode = $TargetMode
        RequestedRoute = $RequestedRoute
        ProposedRoute = if ($state -eq 'Blocked') { 'None' } else { $route }
        Assessment = $state
        Reason = if ($blocked) { $blocked } elseif ($state -eq 'ConsentRequired') {
            'Explicit Windows UAC approval is required; no elevated process has been started.'
        } else {
            'Preflight requirements satisfied; actual Windows or remote authorization is not verified.'
        }
        InitiatingIdentity = [string]$actual.WindowsIdentity
        InitiatingSid = [string]$actual.WindowsSid
        InitiatingSessionId = [int]$actual.SessionId
        ProcessIsElevated = [bool]$actual.IsElevated
        RequestedAuthenticationMode = $authMode
        RequestedIdentity = $requestedIdentity
        ExecutionIdentityVerified = $false
    }
}

# Narrow enforcement guard shared by GUI and Classic for a single local System
# report. Throws before the caller starts any collector on a denied preflight.
function Assert-ToolkitLocalSystemAuthorization {
    [CmdletBinding()]
    param([Parameter(Mandatory=$true)][ValidateNotNullOrEmpty()][string]$TargetComputer)
    $assessment = Get-ToolkitOperationAuthorization -Section System -TargetMode Local -TargetComputer $TargetComputer -RequestedRoute CurrentToken
    if ($assessment.Assessment -ne 'ReadyForAttempt' -or $assessment.ProposedRoute -ne 'CurrentToken') {
        throw ('Local System diagnostic blocked by preflight: ' + [string]$assessment.Reason)
    }
    return $assessment
}

# Shared, batch-aware local preflight. Validate every section before any collector starts.
# CurrentToken permits an ordinary read-only attempt, including initial Classic
# BitLocker/Policy probes. ElevatedLocal is only allowed for one scoped UAC section.
function Assert-ToolkitLocalDiagnosticAuthorization {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][ValidateNotNullOrEmpty()][string[]]$Sections,
        [Parameter(Mandatory=$true)][ValidateNotNullOrEmpty()][string]$TargetComputer,
        [switch]$ElevatedLocal
    )
    if ($ElevatedLocal -and ($Sections.Count -ne 1 -or $Sections[0] -notin @('BitLocker','Policy'))) {
        throw 'Scoped UAC requires exactly one local BitLocker or Policy section.'
    }
    $accepted = New-Object 'System.Collections.Generic.List[object]'
    foreach ($section in $Sections) {
        $route = if ($ElevatedLocal) { 'ElevatedLocal' } else { 'CurrentToken' }
        $assessment = Get-ToolkitOperationAuthorization -Section $section -TargetMode Local -TargetComputer $TargetComputer -RequestedRoute $route
        if ($assessment.Assessment -eq 'Blocked' -or $assessment.ProposedRoute -eq 'None') {
            throw ('Local ' + $section + ' diagnostic blocked by preflight: ' + [string]$assessment.Reason)
        }
        if ($ElevatedLocal) {
            if ($assessment.Assessment -notin @('ConsentRequired','ReadyForAttempt') -or
                $assessment.ProposedRoute -notin @('ElevatedLocalUac','CurrentToken')) {
                throw ('Local ' + $section + ' diagnostic has an invalid UAC preflight route.')
            }
        } elseif ($assessment.Assessment -ne 'ReadyForAttempt' -or $assessment.ProposedRoute -ne 'CurrentToken') {
            throw ('Local ' + $section + ' diagnostic requires another execution route.')
        }
        [void]$accepted.Add($assessment)
    }
    return $accepted.ToArray()
}
