# Static regression checks for the GUI one-time remote access-denied credential retry.
# Run on Windows PowerShell 5.1 from the repository root:
# powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Tests\Test-RemoteOnDemandRetry.ps1
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$path = Join-Path $root 'ITToolkit-GUI.ps1'
$tokens = $null; $errors = $null
$null = [System.Management.Automation.Language.Parser]::ParseFile($path,[ref]$tokens,[ref]$errors)
if (@($errors).Count -gt 0) { throw ('GUI PowerShell parser errors: ' + ($errors -join '; ')) }
Write-Host 'PASS: GUI source parses under Windows PowerShell 5.1.'
$s = [IO.File]::ReadAllText($path)
$checks = @(
    @('RetryRemoteWithAdmin','Retry action exists'),
    @('(?im)^STATUS:\s*ACCESS DENIED\b','Retry offered only after explicit denial'),
    @('Start-GUIDiagnostics @([string]$captured.Sections[0]) $false $false $credential','Retry only the selected check'),
    @('New-ToolkitAuthContext -ComputerName ([string]$script:TargetComputer) -Mode Alternate -Credential $onDemandCredential','Retry binds credential to selected target'),
    @('Assert-ToolkitRemoteDiagnosticAuthorization','Remote preflight is retained'),
    @('IsOnDemand = $onDemand','In-flight report records the on-demand credential path'),
    @('IsOnDemand = [bool]$script:PendingGUIReport.IsOnDemand','Completed report retains provenance'),
    @('Test-ToolkitRemoteExecutionIdentity -Context $context','Alternate worker verifies remote execution identity'),
    @('$ui.RetryRemoteWithAdmin.Visibility = [Windows.Visibility]::Collapsed','Target and report invalidation hides retry')
)
foreach ($check in $checks) {
    if (-not $s.Contains([string]$check[0])) { throw ('Missing: ' + $check[1]) }
    Write-Host ('PASS: ' + $check[1])
}
if ($s -notmatch '(?s)\$ui\.RetryRemoteWithAdmin\.Add_Click\(\{.*?\$captured\.Mode -ne ''Default''.*?\$dlg\.ShowDialog\(\).*?Start-GUIDiagnostics') {
    throw 'Retry handler lacks expected Default-only, manual prompt, and scoped dispatch sequence.'
}
Write-Host 'PASS: Retry requires a Default report and a user-visible credential prompt.'
Write-Host 'NOTE: Confirm in county GUI: denied remote check, explicit retry, correct admin identity, cancel path, unsuccessful credentials, no fallback, clear target, Save/Copy.'
