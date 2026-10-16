# Static regression for GUI Open Folder using an actual Explorer directory.
# powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Tests\Test-ReportFolderShellExplore.ps1
$ErrorActionPreference = 'Stop'
$gui = Join-Path (Split-Path -Parent $PSScriptRoot) 'ITToolkit-GUI.ps1'
$tokens = $null; $errors = $null
$null = [System.Management.Automation.Language.Parser]::ParseFile($gui, [ref]$tokens, [ref]$errors)
if (@($errors).Count -gt 0) { throw ('GUI parser errors: ' + ($errors -join '; ')) }
Write-Host 'PASS: GUI parses under Windows PowerShell 5.1.'
$text = [IO.File]::ReadAllText($gui)
$checks = @(
    @('$ui.ArchiveFolder.Add_Click({','Open Folder action retained'),
    @('New-Object -ComObject Shell.Application -ErrorAction Stop','Native Shell automation'),
    @('$shell.Explore($fullFolder)','Open actual Explorer folder for drag-and-drop'),
    @('Get-GUIArchiveFolder','Configured reports path'),
    @('Test-Path -LiteralPath $folder -PathType Container','Existing directory validated'),
    @("if ($ExecutionMode -eq 'SeparateAccount' -and -not (Test-GUIProcessElevated))",'UAC only for non-elevated Separate Admin mode'),
    @('Start-Process -FilePath $powerShell -Verb RunAs','Scoped elevated PowerShell helper'),
    @("'WindowStyle','Hidden'","Hidden helper console"),
    @('NativeErrorCode -eq 1223','UAC cancellation is handled'),
    @("No elevation requested.","Technician decline is handled"),
    @("Replace(\"'\",\"''\")","Folder argument safely literal-quoted"),
    @('Copy Folder Path','Copy path fallback'),
    @('$ui.ArchiveCopyPath.Add_Click({','Copy path action retained')
)
foreach ($check in $checks) {
    if (-not $text.Contains([string]$check[0])) { throw ('Missing: ' + $check[1]) }
    Write-Host ('PASS: ' + $check[1])
}
if ($text.Contains("ArchiveFolder.Content = 'Browse Reports'")) { throw 'Rejected file picker action is still present.' }
Write-Host 'PASS: No rejected file-picker substitution.'
Write-Host 'NOTE: Windows interactive validation still required in all three launcher modes, especially Separate Admin.'
