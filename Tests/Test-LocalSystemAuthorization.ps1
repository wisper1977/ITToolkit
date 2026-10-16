# Windows PowerShell 5.1: local authorization matrix; no collectors/UAC/network calls.
# Run: powershell.exe -NoProfile -File .\Tests\Test-LocalSystemAuthorization.ps1
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
. (Join-Path $root 'Modules\ITToolkit-ExecutionContext.ps1')
. (Join-Path $root 'Modules\ITToolkit-PrivilegeRequirements.ps1')
. (Join-Path $root 'Modules\ITToolkit-OperationAuthorization.ps1')

$guiSource = Get-Content -LiteralPath (Join-Path $root 'ITToolkit-GUI.ps1') -Raw
$classicSource = Get-Content -LiteralPath (Join-Path $root 'Modules\ITToolkit-ReportMenu.ps1') -Raw
foreach ($source in @($guiSource,$classicSource)) {
    if ($source -notmatch 'Assert-ToolkitLocalDiagnosticAuthorization -Sections') {
        throw 'GUI/Classic does not reference the shared all-local authorization guard.'
    }
}
Write-Host 'PASS: GUI and Classic use the shared local section/batch guard.'

$allSections = @((Get-ToolkitDiagnosticRequirements).Section)
if ($allSections.Count -ne 20 -or (@($allSections | Select-Object -Unique)).Count -ne 20) {
    throw 'Registry must contain 20 distinct sections.'
}
foreach ($section in $allSections) {
    $assessment = @(Assert-ToolkitLocalDiagnosticAuthorization -Sections @($section) -TargetComputer $env:COMPUTERNAME)
    if ($assessment.Count -ne 1 -or $assessment[0].Assessment -ne 'ReadyForAttempt') {
        throw ('Local current-token preflight failed: ' + $section)
    }
}
Write-Host 'PASS: All 20 local diagnostic sections accepted on current-token route.'

$batch = @(Assert-ToolkitLocalDiagnosticAuthorization -Sections $allSections -TargetComputer $env:COMPUTERNAME)
if ($batch.Count -ne 20) { throw 'Valid 20-section batch did not return 20 assessments.' }
Write-Host 'PASS: Complete 20-section local batch accepted before collection.'

$collectorCalls = 0
function Invoke-SimulatedCollection {
    param([string[]]$Sections,[string]$Target,[switch]$Elevated)
    $null = Assert-ToolkitLocalDiagnosticAuthorization -Sections $Sections -TargetComputer $Target -ElevatedLocal:$Elevated
    $script:collectorCalls++
}
function Assert-TestDenial {
    param([string[]]$Sections,[string]$Target,[switch]$Elevated,[string]$ExpectedText)
    $blocked = $false
    try {
        Invoke-SimulatedCollection -Sections $Sections -Target $Target -Elevated:$Elevated
    } catch {
        if ([string]$_.Exception.Message -notmatch $ExpectedText) { throw }
        $blocked = $true
    }
    if (-not $blocked) { throw ('Expected denial was not received: ' + $ExpectedText) }
}
Assert-TestDenial -Sections @('System') -Target 'OTHERCOMPUTER' -ExpectedText 'Local operation target must be this computer'
Assert-TestDenial -Sections @('System','Storage') -Target 'OTHERCOMPUTER' -ExpectedText 'Local operation target must be this computer'
Assert-TestDenial -Sections @('System','NotASection') -Target $env:COMPUTERNAME -ExpectedText 'Unknown toolkit diagnostic section'
Assert-TestDenial -Sections @('System') -Target $env:COMPUTERNAME -Elevated -ExpectedText 'Scoped UAC requires exactly one'
Assert-TestDenial -Sections @('BitLocker','Policy') -Target $env:COMPUTERNAME -Elevated -ExpectedText 'Scoped UAC requires exactly one'
if ($collectorCalls -ne 0) { throw 'Simulated collector ran after denied preflight.' }
Write-Host 'PASS: Mismatched target, unknown section, and invalid UAC batch denied before simulated collection.'

foreach ($section in @('BitLocker','Policy')) {
    $assessment = @(Assert-ToolkitLocalDiagnosticAuthorization -Sections @($section) -TargetComputer $env:COMPUTERNAME -ElevatedLocal)
    if ($assessment.Count -ne 1) { throw ('Missing UAC assessment: ' + $section) }
    if ($assessment[0].Assessment -notin @('ConsentRequired','ReadyForAttempt')) {
        throw ('Unexpected scoped UAC state: ' + $section)
    }
    if ($assessment[0].ProposedRoute -notin @('ElevatedLocalUac','CurrentToken')) {
        throw ('Unexpected scoped UAC route: ' + $section)
    }
}
Write-Host 'PASS: BitLocker and Policy only accept single-section scoped UAC assessment.'
Write-Host 'NOTE: No real collectors, interactive UI, remote authentication, or UAC were exercised.'
