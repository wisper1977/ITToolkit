# Windows PowerShell 5.1: controlled negative-path test, no diagnostic or UAC launched.
# Run from repository root: powershell.exe -NoProfile -File .\Tests\Test-LocalSystemAuthorization.ps1
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
. (Join-Path $root 'Modules\ITToolkit-ExecutionContext.ps1')
. (Join-Path $root 'Modules\ITToolkit-PrivilegeRequirements.ps1')
. (Join-Path $root 'Modules\ITToolkit-OperationAuthorization.ps1')

# Ensure both real entry points call the shared guard before their collection blocks.
$guiSource = Get-Content -LiteralPath (Join-Path $root 'ITToolkit-GUI.ps1') -Raw
$classicSource = Get-Content -LiteralPath (Join-Path $root 'Modules\ITToolkit-ReportMenu.ps1') -Raw
foreach ($source in @($guiSource,$classicSource)) {
    if ($source -notmatch 'Assert-ToolkitLocalSystemAuthorization -TargetComputer') {
        throw 'A GUI/Classic local System entry point does not use the shared authorization guard.'
    }
}

$authorized = Assert-ToolkitLocalSystemAuthorization -TargetComputer $env:COMPUTERNAME
if ($authorized.Assessment -ne 'ReadyForAttempt') { throw 'Valid local System preflight failed.' }
Write-Host 'PASS: Current computer accepted for local System diagnostic.'

# A simulated collection callback must never be reached after a failed guard.
$collectorCalls = 0
function Invoke-SimulatedSystemCollection {
    param([string]$TargetComputer)
    $null = Assert-ToolkitLocalSystemAuthorization -TargetComputer $TargetComputer
    $script:collectorCalls++
}
$denied = $false
try {
    Invoke-SimulatedSystemCollection -TargetComputer 'OTHERCOMPUTER'
} catch {
    if ([string]$_.Exception.Message -notmatch 'Local operation target must be this computer') { throw }
    $denied = $true
}
if (-not $denied) { throw 'Mismatched local target was not denied.' }
if ($collectorCalls -ne 0) { throw 'Simulated collector ran after a denied request.' }
Write-Host 'PASS: Mismatched local target blocked before simulated collection.'
Write-Host 'PASS: GUI and Classic entry points reference the shared guard.'
Write-Host 'NOTE: This does not exercise WPF event handling or Classic interactive screens.'
