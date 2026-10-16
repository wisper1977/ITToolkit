# Static Windows PowerShell 5.1 regression for stale GUI diagnostic display.
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$path = Join-Path $root 'ITToolkit-GUI.ps1'
$tokens = $null
$errors = $null
$null = [System.Management.Automation.Language.Parser]::ParseFile($path,[ref]$tokens,[ref]$errors)
if (@($errors).Count -ne 0) { throw ('GUI parse failure: ' + ($errors -join '; ')) }
Write-Host 'PASS: GUI parses under Windows PowerShell 5.1.'
$source = [IO.File]::ReadAllText($path)
$start = $source.IndexOf('function Clear-GUIReportState {')
$end = $source.IndexOf("`n}",$start)
if ($start -lt 0 -or $end -lt $start) { throw 'Missing GUI report invalidation helper.' }
$body = $source.Substring($start,$end-$start)
foreach ($required in @('$script:LastGUIReport = $null','$ui.SaveDiagnosticReport.IsEnabled = $false','$ui.CopyDiagnosticReport.IsEnabled = $false','$ui.DiagnosticOutput.Clear()')) {
    if (-not $body.Contains($required)) { throw ('Report invalidation missing: ' + $required) }
}
Write-Host 'PASS: Report invalidation clears both captured data and visible diagnostic text.'
$resolve = $source.IndexOf('function Resolve-GUITarget {')
$next = $source.IndexOf("`nfunction ",$resolve+1)
if ($resolve -lt 0 -or $next -lt $resolve) { throw 'Cannot locate target selection function.' }
$targetBlock = $source.Substring($resolve,$next-$resolve)
if (-not $targetBlock.Contains('Clear-GUIReportState')) { throw 'Target selection fails to invalidate report.' }
foreach ($required in @('$ui.UseAlternate.Add_Checked({','$ui.UseAlternate.Add_Unchecked({','$ui.ClearTarget.Add_Click({')) {
    if (-not $source.Contains($required)) { throw ('Missing credential/target handler: ' + $required) }
}
Write-Host 'PASS: Target selection invalidates the captured report and visible output.'
Write-Host 'NOTE: Interactively confirm target switch, credential switch, and Save/Copy disablement in GUI.'
