# Windows PowerShell 5.1. No remote connections are made.
$ErrorActionPreference='Stop'
$root=Split-Path -Parent $PSScriptRoot
foreach($relative in @('ITToolkit-GUI.ps1','Modules\ITToolkit-Reports.ps1')){
    $parseErrors=$null; $tokens=$null
    $null=[System.Management.Automation.Language.Parser]::ParseFile((Join-Path $root $relative),[ref]$tokens,[ref]$parseErrors)
    if(@($parseErrors).Count){throw ($relative+': '+($parseErrors -join '; '))}
}
Write-Host 'PASS: GUI and remote report module parse on Windows PowerShell 5.1.'
$reports=Get-Content -LiteralPath (Join-Path $root 'Modules\ITToolkit-Reports.ps1') -Raw
$gui=Get-Content -LiteralPath (Join-Path $root 'ITToolkit-GUI.ps1') -Raw
foreach($required in @('function Invoke-ToolkitBoundedRemoteSystemInfo','WaitForExit($TimeoutSeconds*1000)','-RedirectStandardOutput $stdout','-RedirectStandardError $stderr','try { $process.Kill() } catch { }','Invoke-ToolkitBoundedRemoteSystemInfo -Target $Target -TimeoutSeconds 30')){
    if(-not $reports.Contains($required)){throw ('Remote process deadline missing: '+$required)}
}
if(-not $gui.Contains('$script:DiagnosticRemoteSingleTimeoutSeconds = 60')){throw 'Expected 60-second GUI remote cancellation budget.'}
if(-not $gui.Contains('Request-GUIDiagnosticCancellation')){throw 'Existing GUI cancellation mechanism missing.'}
Write-Host 'PASS: Remote System Information has a bounded child process and cleanup.'
Write-Host 'PASS: GUI remote single-check cancellation remains enabled at 60 seconds.'
Write-Host 'NOTE: Access-denied status and real timeout require authorized county-network regression.'
