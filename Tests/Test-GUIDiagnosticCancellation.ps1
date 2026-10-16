# Windows PowerShell 5.1; no target connection or application launch required.
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$source = Join-Path $root 'ITToolkit-GUI.ps1'
$errors = $null
$tokens = $null
$ast = [System.Management.Automation.Language.Parser]::ParseFile($source,[ref]$tokens,[ref]$errors)
if (@($errors).Count -gt 0) { throw ('GUI syntax errors: ' + ($errors -join '; ')) }
Write-Host 'PASS: GUI script parses in Windows PowerShell.'

$text = Get-Content -LiteralPath $source -Raw
foreach ($required in @('Name="CancelDiagnostic"','Request-GUIDiagnosticCancellation','BeginStop($null,$null)','DiagnosticRemoteSingleTimeoutSeconds','DiagnosticRemoteBatchTimeoutSeconds','if ($script:DiagnosticCancelRequested)','Clear-GUIReportState')) {
    if (-not $text.Contains($required)) { throw ('Cancellation integration missing: ' + $required) }
}
Write-Host 'PASS: Cancel button, async stop, time budgets, and stale-report protection are present.'

# Exercise the identical asynchronous stop API against a harmless in-process delay.
$ps = [PowerShell]::Create()
try {
    $null = $ps.AddScript('Start-Sleep -Seconds 20; "UNEXPECTED FINISH"')
    $invocation = $ps.BeginInvoke()
    Start-Sleep -Milliseconds 200
    $stop = $ps.BeginStop($null,$null)
    if (-not $stop.AsyncWaitHandle.WaitOne(5000)) { throw 'Async stop did not finish within five seconds for a local sleep test.' }
    $ps.EndStop($stop)
    if (-not $invocation.IsCompleted) { throw 'Cancelled invocation did not reach a terminal state.' }
    try { $null = $ps.EndInvoke($invocation) } catch [System.Management.Automation.PipelineStoppedException] { }
    Write-Host 'PASS: PowerShell 5.1 BeginStop cancels a cooperative background worker.'
} finally {
    $ps.Dispose()
}
Write-Host 'NOTE: Remote WMI/WinRM and the live WPF cancel button require county-network testing.'
