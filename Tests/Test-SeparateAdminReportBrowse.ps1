# Static Windows regression for Separate Administrative Account report browsing.
# powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Tests\Test-SeparateAdminReportBrowse.ps1
$ErrorActionPreference = 'Stop'
$gui = Join-Path (Split-Path -Parent $PSScriptRoot) 'ITToolkit-GUI.ps1'
$tokens = $null; $errors = $null
$null = [System.Management.Automation.Language.Parser]::ParseFile($gui,[ref]$tokens,[ref]$errors)
if (@($errors).Count -gt 0) { throw ('GUI parse error: ' + ($errors -join '; ')) }
Write-Host 'PASS: GUI parses under Windows PowerShell 5.1.'
$s = [IO.File]::ReadAllText($gui)
$checks = @(
    @('$ExecutionMode -eq ''SeparateAccount''','Separate-account-specific branch'),
    @("ArchiveFolder.Content = 'Browse Reports'",'Button accurately labels native browse action'),
    @('New-Object Microsoft.Win32.OpenFileDialog','Native Windows dialog'),
    @('$picker.InitialDirectory = $fullFolder','Uses configured reports folder'),
    @('$picker.ShowDialog($window)','Owned modal window in toolkit desktop session'),
    @('Open-GUISavedReport -Path $selected','Opens selected report using existing handler'),
    @('Selected report is outside the configured Reports folder.','Enforces configured archive boundary'),
    @('Choose an HTML, CSV or TXT report.','Restricts report type'),
    @('Use Copy Folder Path','Preserves fallback'),
    @('Explorer child completed','Unchanged Explorer path remains for other launch modes')
)
foreach ($check in $checks) {
    if (-not $s.Contains([string]$check[0])) { throw ('Missing: ' + $check[1]) }
    Write-Host ('PASS: ' + $check[1])
}
Write-Host 'NOTE: Interactive GUI test required for Separate Admin browse/open and Current/On-Demand Explorer.'
