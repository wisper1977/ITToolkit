# IT Toolkit - organization branding is configured in Toolkit-config.json
# Windows PowerShell 5.1; run with your approved administrative credentials.
# Remote operations require appropriate rights and firewall/service configuration.
# No software is installed on remote hosts by this launcher.

$ErrorActionPreference = 'Stop'

# Components are dot-sourced in script scope to share configuration and target state.
$script:ToolkitRoot = $PSScriptRoot
$componentFolder = Join-Path $script:ToolkitRoot 'Modules'
$componentPath = Join-Path $componentFolder 'ITToolkit-Config.ps1'
if (-not (Test-Path -LiteralPath $componentPath -PathType Leaf)) { throw "Missing toolkit component: $componentPath" }
. $componentPath
# Check once at launch; settings changes can trigger a fresh check.
Test-ToolkitDependencies
if ($script:DependencyWarnings.Count -gt 0) {
    Write-Host ''
    Show-DependencyWarnings
    [void](Read-Host 'Press Enter to continue to the toolkit')
}
$script:TargetComputer = $null
$script:LocalTargetMode = $false
$script:TargetIPv4 = '(not selected)'
$script:AdminStatus = 'Not checked'
$script:AdminDetail = 'Select a target to run an access check.'
$script:AdminCheckedAt = $null


$componentPath = Join-Path $componentFolder 'ITToolkit-Core.ps1'
if (-not (Test-Path -LiteralPath $componentPath -PathType Leaf)) { throw "Missing toolkit component: $componentPath" }
. $componentPath
$componentPath = Join-Path $componentFolder 'ITToolkit-Tools.ps1'
if (-not (Test-Path -LiteralPath $componentPath -PathType Leaf)) { throw "Missing toolkit component: $componentPath" }
. $componentPath
$componentPath = Join-Path $componentFolder 'ITToolkit-Reports.ps1'
if (-not (Test-Path -LiteralPath $componentPath -PathType Leaf)) { throw "Missing toolkit component: $componentPath" }
. $componentPath
$componentPath = Join-Path $componentFolder 'ITToolkit-Snapshots.ps1'
if (-not (Test-Path -LiteralPath $componentPath -PathType Leaf)) { throw "Missing toolkit component: $componentPath" }
. $componentPath
# Phase 6C: shared, credential-aware seven-category snapshot collector.
$componentPath = Join-Path $componentFolder 'ITToolkit-GUISnapshotCollector.ps1'
if (-not (Test-Path -LiteralPath $componentPath -PathType Leaf)) { throw "Missing toolkit component: $componentPath" }
. $componentPath
$componentPath = Join-Path $componentFolder 'ITToolkit-ClassicSnapshot.ps1'
if (-not (Test-Path -LiteralPath $componentPath -PathType Leaf)) { throw "Missing toolkit component: $componentPath" }
. $componentPath
$componentPath = Join-Path $componentFolder 'ITToolkit-ReportMenu.ps1'
if (-not (Test-Path -LiteralPath $componentPath -PathType Leaf)) { throw "Missing toolkit component: $componentPath" }
. $componentPath
$componentPath = Join-Path $componentFolder 'ITToolkit-Settings.ps1'
if (-not (Test-Path -LiteralPath $componentPath -PathType Leaf)) { throw "Missing toolkit component: $componentPath" }
. $componentPath
$componentPath = Join-Path $componentFolder 'ITToolkit-ToolCatalog.ps1'
if (-not (Test-Path -LiteralPath $componentPath -PathType Leaf)) { throw "Missing toolkit component: $componentPath" }
. $componentPath
$componentPath = Join-Path $componentFolder 'ITToolkit-Authentication.ps1'
if (-not (Test-Path -LiteralPath $componentPath -PathType Leaf)) { throw "Missing toolkit component: $componentPath" }
. $componentPath
# Direct-local System and Firewall collector; no remote-management dependency.
$componentPath = Join-Path $componentFolder 'ITToolkit-LocalDiagnostics.ps1'
if (-not (Test-Path -LiteralPath $componentPath -PathType Leaf)) { throw "Missing toolkit component: $componentPath" }
. $componentPath
$componentPath = Join-Path $componentFolder 'ITToolkit-ClassicAuthentication.ps1'
if (-not (Test-Path -LiteralPath $componentPath -PathType Leaf)) { throw "Missing toolkit component: $componentPath" }
. $componentPath

# Phase 5A: load validated credential-aware diagnostic adapters for Classic reporting.
# Existing default-credential diagnostics retain their original code paths.
foreach ($adapterName in @('ITToolkit-WmiDiagnostics.ps1','ITToolkit-WinRMDiagnostics.ps1',
                           'ITToolkit-MixedDiagnostics.ps1','ITToolkit-CompositeDiagnostics.ps1',
                           'ITToolkit-DetailDiagnostics.ps1','ITToolkit-DiagnosticDispatcher.ps1',
                           'ITToolkit-ClassicDispatcher.ps1')) {
    $adapterPath = Join-Path $componentFolder $adapterName
    if (-not (Test-Path -LiteralPath $adapterPath -PathType Leaf)) {
        throw "Missing Phase 5A component: $adapterPath. Install the Phase 3/4 diagnostic modules first."
    }
    . $adapterPath
}

while ($true) {
    Show-Header 'Main Menu'
    Write-Host ' TOOL CATEGORIES' -ForegroundColor Yellow
    Write-Host ' 1 Sysinternals Remote Tools'
    Write-Host ' 2 Network Diagnostics'
    Write-Host ' 3 Windows Administration'
    Write-Host ' 4 Active Directory and Group Policy'
    Write-Host ' 5 System Information and Reporting'
    Write-Host ' 6 Saved Report Comparison - Show changes between reports'
    Write-Host '------------------------------------------------------------' -ForegroundColor DarkGray
    Write-Host ' TARGET COMPUTER' -ForegroundColor Yellow
    Write-Host ' 7 Change Target Computer - Select a new remote computer'
    Write-Host ' 8 Clear Target Computer  - Remove selected computer'
    Write-Host ' 9 Recheck Admin Access    - Rerun admin share permission test'
    Write-Host '10 Use Local Computer    - Direct System, Firewall and Services reports'
    Write-Host '------------------------------------------------------------' -ForegroundColor DarkGray
    Write-Host ' SETTINGS' -ForegroundColor Yellow
    Write-Host '11 Toolkit Settings       - Manage all application settings'
    Write-Host '12 Tools                  - Shared catalog, Favorites and downloads'
    Write-Host '13 Target Credentials     - Select and test remote identity'
    Write-Host " Authentication: $script:ToolkitAuthMode $script:ToolkitAuthUserName" -ForegroundColor Cyan
    Write-Host " Collection mode: $(if ($script:LocalTargetMode) {'Local (current identity)'} else {'Remote'})" -ForegroundColor Cyan
    Write-Host '------------------------------------------------------------' -ForegroundColor DarkGray
    Write-Host ' INTERFACE' -ForegroundColor Yellow
    Write-Host '14 Switch to GUI         - Open graphical interface as current user'
    Write-Host ' B Refresh main menu'
    Write-Host '------------------------------------------------------------' -ForegroundColor DarkGray
    Write-Host ' 0 Exit'
    Write-Host ''
    $choice=(Read-Host 'Choose').Trim().ToUpperInvariant()
    switch ($choice) {
        '1' { if ($script:LocalTargetMode) { Write-Host 'This menu currently uses remote-management methods. Switch to a remote target, or use option 5 for local System/Firewall/Services reports.' -ForegroundColor Yellow; Pause-Toolkit; continue }; if (Assert-ClassicDefaultAuthentication) { Menu-Sysinternals } }
        '2' { if ($script:LocalTargetMode) { Write-Host 'This menu currently uses remote-management methods. Switch to a remote target, or use option 5 for local System/Firewall/Services reports.' -ForegroundColor Yellow; Pause-Toolkit; continue }; if (Assert-ClassicDefaultAuthentication) { Menu-Network } }
        '3' { if ($script:LocalTargetMode) { Write-Host 'This menu currently uses remote-management methods. Switch to a remote target, or use option 5 for local System/Firewall/Services reports.' -ForegroundColor Yellow; Pause-Toolkit; continue }; if (Assert-ClassicDefaultAuthentication) { Menu-Windows } }
        '4' { if ($script:LocalTargetMode) { Write-Host 'This menu currently uses remote-management methods. Switch to a remote target, or use option 5 for local System/Firewall/Services reports.' -ForegroundColor Yellow; Pause-Toolkit; continue }; if (Assert-ClassicDefaultAuthentication) { Menu-AD } }
        '5' { Menu-Reports }
        '6' { Menu-Comparison } # offline file comparison; no remote identity required
        '7' { Reset-ClassicAlternateCredential; Change-Target }
        '8' { Reset-ClassicAlternateCredential; $script:LocalTargetMode=$false; $script:TargetComputer=$null; $script:TargetIPv4='(not selected)'; $script:AdminStatus='Not checked'; $script:AdminDetail='Select a target to run an access check.'; $script:AdminCheckedAt=$null }
        '9' { if ($script:LocalTargetMode) { Write-Host 'ADMIN$ check does not apply to direct-local collection.' -ForegroundColor Yellow; Pause-Toolkit; continue }; if (-not (Assert-ClassicDefaultAuthentication)) { continue }; if ($script:TargetComputer) { Test-RemoteAdminAccess; Write-Host $script:AdminDetail; Pause-Toolkit } else { Write-Host 'Select a target first.' -ForegroundColor Yellow; Pause-Toolkit } }
        '11' { Menu-Settings }
        '12' { Menu-ClassicCatalog }
        '13' { if ($script:LocalTargetMode) { Write-Host 'Alternate-admin local collection is not yet implemented. Switch to remote target mode first.' -ForegroundColor Yellow; Pause-Toolkit } else { Set-ClassicTargetCredential } }
        '10' { Reset-ClassicAlternateCredential; $script:LocalTargetMode=$true; $script:TargetComputer=[string]$env:COMPUTERNAME; $script:TargetIPv4='(local collection)'; $script:AdminStatus='Local mode'; $script:AdminDetail='All 20 local diagnostic sections and snapshots collect directly on this computer; BitLocker and Policy may require separate UAC approval.'; $script:AdminCheckedAt=$null }
        '14' {
            $guiScript = Join-Path $script:ToolkitRoot 'ITToolkit-GUI.ps1'
            if (-not (Test-Path -LiteralPath $guiScript -PathType Leaf)) {
                Write-Host 'GUI script was not found; staying in Classic.' -ForegroundColor Yellow
                Pause-Toolkit
                continue
            }
            # This starts the GUI with the current Windows process identity, never a stored or alternate credential.
            # Do not pass selected targets, credentials, or transient session state.
            try {
                $psExe = Join-Path $PSHOME 'powershell.exe'
                $arguments = '-NoLogo -NoProfile -STA -File "' + $guiScript + '"'
                $newProcess = Start-Process -FilePath $psExe -ArgumentList $arguments -WorkingDirectory $script:ToolkitRoot -PassThru -ErrorAction Stop
                if ($null -eq $newProcess) { throw 'Windows did not return a process.' }
                Reset-ClassicAlternateCredential
                return
            } catch {
                Write-Host "Could not open GUI; staying in Classic: $($_.Exception.Message)" -ForegroundColor Yellow
                Pause-Toolkit
            }
        }
        '0' { return }
    }
}
