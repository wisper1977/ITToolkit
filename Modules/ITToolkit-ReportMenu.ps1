# IT Toolkit v1.24 - dot-sourced component; loaded in parent script scope.
# Cache the last collected results for this Classic session only.
# Target changes invalidate the cache during Save-Last validation.
$script:ClassicLastReport = $null
function Save-ClassicCollectedReport {
    if ($null -eq $script:ClassicLastReport) {
        Write-Host 'No completed diagnostic report is available. Run a report first.' -ForegroundColor Yellow
        Pause-Toolkit; return
    }
    $cached = $script:ClassicLastReport
    if (-not $script:TargetComputer -or $script:TargetComputer -ine $cached.Target) {
        Write-Host 'The selected target has changed. Run the diagnostic again before saving.' -ForegroundColor Yellow
        Pause-Toolkit; return
    }
    $format = (Read-Host ('Report format [HTML / CSV / TXT] (Enter = {0}, B = cancel)' -f $script:ReportFormat)).Trim().ToUpperInvariant()
    if ($format -in @('B','0')) { return }
    if (-not $format) { $format = $script:ReportFormat }
    if ($format -notin @('HTML','CSV','TXT')) {
        Write-Host 'Invalid report format.' -ForegroundColor Yellow; Pause-Toolkit; return
    }
    $safeTarget = $cached.Target -replace '[^a-zA-Z0-9_.-]','_'
    $safeLabel = $cached.Label -replace '[^a-zA-Z0-9_.-]','_'
    $stamp = Get-Date -Format 'yyyyMMdd_HHmmss_fff'
    $path = Join-Path $script:ReportFolder ('{0}_{1}_{2}.{3}' -f $safeTarget,$safeLabel,$stamp,$format.ToLowerInvariant())
    try {
        if (-not (Test-Path -LiteralPath $script:ReportFolder -PathType Container)) {
            [void](New-Item -ItemType Directory -Path $script:ReportFolder -Force -ErrorAction Stop)
        }
        switch ($format) {
            'HTML' { $content = Convert-ReportHtml $cached.Text "$script:ToolkitDisplayName - $($cached.Label) - $($cached.Target)" }
            'CSV'  { $content = Convert-ReportCsv $cached.Lines }
            default { $content = $cached.Text }
        }
        [System.IO.File]::WriteAllText($path,$content,(New-Object System.Text.UTF8Encoding($false)))
        Write-Host "Report saved: $path" -ForegroundColor Green
        # Snapshot creation is separate from the cached report and can query the target.
        # Do not automatically rerun remote inventory when saving the displayed results.
        Write-Host 'The displayed report was saved without recollecting diagnostic data.' -ForegroundColor DarkGray
        $snapshotChoice = (Read-Host 'Also collect a JSON comparison snapshot? Requires fresh remote inventory (Y/N)').Trim()
        if ($snapshotChoice -ieq 'Y') {
            try {
                $snapshot = Get-ComparisonSnapshot $cached.Target $cached.Sections
                $snapshotPath = Join-Path $script:ReportFolder ('{0}_{1}_{2}.snapshot.json' -f $safeTarget,$safeLabel,(Get-Date -Format 'yyyyMMdd_HHmmss_fff'))
                [System.IO.File]::WriteAllText($snapshotPath,(ConvertTo-Json -InputObject $snapshot -Depth 8),(New-Object System.Text.UTF8Encoding($false)))
                Write-Host "Comparison snapshot saved: $snapshotPath" -ForegroundColor Green
            } catch { Write-Host "Could not collect comparison snapshot: $($_.Exception.Message)" -ForegroundColor Yellow }
        }
        Ask-OpenSavedReport $path
    } catch {
        Write-Host "Unable to save report: $($_.Exception.Message)" -ForegroundColor Yellow
    }
    Pause-Toolkit
}
function Save-DiagnosticReport([string[]]$Sections,[string]$Label) {
    $target = Get-Target
    if (-not $target) { return }
    $script:ClassicLastReport = $null
    $results = New-Object System.Collections.Generic.List[object]
    foreach ($section in $Sections) {
        Write-Host "Collecting $section ..." -ForegroundColor Cyan
        if ($script:LocalTargetMode) {
            if ($section -notin @('System','Firewall','Services','Storage','Network','Hardware','Users','Groups','Administrators','Shares','Software','Updates','Tasks','Events','Startup')) {
                $status = 'NOT TESTED'
                $content = 'Error details: Direct-local collection is not implemented for this section yet.'
            } else {
                $localResult = Get-ToolkitLocalDiagnostic -Section $section
                $status = [string]$localResult.Status
                $parts = New-Object System.Collections.Generic.List[string]
                $parts.Add("Status category: $($localResult.StatusCategory)")
                if ($localResult.Error) { $parts.Add("Error details: $($localResult.Error)") }
                foreach ($record in @($localResult.Data)) { $parts.Add(($record | Format-List * | Out-String -Width 200).TrimEnd()) }
                $content = $parts -join "`r`n"
            }
        } else {
            try { $content = [string](Get-ReportSection $section $target) }
            catch { $content = "Error details: $($_.Exception.Message)" }
            $status = Get-SectionStatus $section $content
        }
        $results.Add([pscustomobject]@{ Section=$section; Status=$status; Content=$content })
    }
    $lines = New-Object System.Collections.Generic.List[string]
    $lines.Add("$($script:ToolkitDisplayName.ToUpperInvariant()) v$script:ToolkitVersion - $(if ($script:LocalTargetMode) {'LOCAL'} else {'REMOTE'}) DIAGNOSTIC REPORT")
    $lines.Add("Report: $Label")
    $lines.Add("Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss zzz')")
    $lines.Add("Technician account: $([Security.Principal.WindowsIdentity]::GetCurrent().Name)")
    $lines.Add("Target hostname: $target")
    $lines.Add("Target IPv4: $(if ($script:LocalTargetMode) {'(not needed for local collection)'} else {Resolve-TargetIPv4 $target})")
    $lines.Add('Read-only queries. UNAVAILABLE does not establish that an issue does not exist.')
    $lines.Add('SUCCESS means a query returned successfully, not that configuration is healthy.')
    $lines.Add('')
    $lines.Add(('=' * 68))
    $lines.Add('DIAGNOSTIC STATUS SUMMARY')
    $lines.Add(('=' * 68))
    foreach ($item in $results) { $lines.Add(('{0,-22} {1}' -f $item.Section,$item.Status)) }
    $lines.Add('')
    foreach ($item in $results) {
        $lines.Add(('=' * 68))
        $lines.Add("$($item.Section) REPORT")
        $lines.Add("STATUS: $($item.Status)")
        if ($script:LocalTargetMode -and $item.Status -eq 'NOT TESTED') { $lines.Add('Status category: NotTested') }
        $lines.Add(('=' * 68))
        $lines.Add($item.Content)
        $lines.Add('')
    }
    $reportText = $lines -join "`r`n"
    $script:ClassicLastReport = [pscustomobject]@{
        Target=$target; Label=$Label; Sections=[string[]]$Sections; Lines=[string[]]$lines.ToArray(); Text=$reportText
    }
    Write-Host "`n$reportText"
    Write-Host "`nResults are retained in memory for this session. Nothing has been saved yet." -ForegroundColor Cyan
    $answer = (Read-Host 'Save these results now? (Y/N)').Trim().ToUpperInvariant()
    if ($answer -eq 'Y') { Save-ClassicCollectedReport }
    else { Pause-Toolkit }
}
function Menu-ReportArchive {
    $query = ''
    $filter = 'ALL'
    while ($true) {
        Show-Header 'Report Archive'
        Write-Host "Folder: $script:ReportFolder" -ForegroundColor DarkCyan
        Write-Host "Search: $(if ($query) {$query} else {'(none)'}) | Format: $filter" -ForegroundColor DarkGray
        $files = @()
        if (Test-Path -LiteralPath $script:ReportFolder -PathType Container) {
            $files = @(Get-ChildItem -LiteralPath $script:ReportFolder -File -ErrorAction SilentlyContinue |
                Where-Object { $_.Extension -in @('.html','.csv','.txt') -and ($filter -eq 'ALL' -or $_.Extension.TrimStart('.').ToUpperInvariant() -eq $filter) -and ($_.Name -like "*$query*") } |
                Sort-Object LastWriteTime -Descending)
        }
        if (-not $files.Count) { Write-Host 'No matching saved reports.' -ForegroundColor Yellow }
        else {
            $visible = @($files | Select-Object -First 40)
            for ($i=0; $i -lt $visible.Count; $i++) {
                Write-Host ('{0,3} {1,-19} {2}' -f ($i+1),$visible[$i].LastWriteTime.ToString('yyyy-MM-dd HH:mm'),$visible[$i].Name)
            }
            if ($files.Count -gt 40) { Write-Host 'Showing newest 40 results. Refine your search to find older reports.' -ForegroundColor DarkGray }
        }
        Write-Host ''
        Write-Host ' [number] Open report   S Search   F Format   R Reset   P Copy/view folder path   B Back' -ForegroundColor Cyan
        $choice = (Read-Host 'Choose').Trim()
        if ($choice -in @('B','b','0')) { return }
        switch ($choice.ToUpperInvariant()) {
            'S' { $query = (Read-Host 'Search filename (blank clears)').Trim(); continue }
            'F' {
                $selected = (Read-Host 'ALL, HTML, CSV, TXT').Trim().ToUpperInvariant()
                if ($selected -in @('ALL','HTML','CSV','TXT')) { $filter=$selected }
                else { Write-Host 'Invalid format.' -ForegroundColor Yellow; Pause-Toolkit }
                continue
            }
            'R' { $query=''; $filter='ALL'; continue }
            'P' { Write-Host "Report folder: $script:ReportFolder" -ForegroundColor Cyan; Pause-Toolkit; continue }
        }
        $index=0
        if ([int]::TryParse($choice,[ref]$index) -and $index -ge 1 -and $index -le [Math]::Min($files.Count,40)) {
            $chosen=$files[$index-1].FullName
            Write-Host "Opening: $chosen" -ForegroundColor Cyan
            try { Start-Process -FilePath $chosen -ErrorAction Stop }
            catch { Write-Host "Windows could not open this report: $($_.Exception.Message)" -ForegroundColor Yellow; Write-Host $chosen }
            Pause-Toolkit
        } else { Write-Host 'Invalid selection.' -ForegroundColor Yellow; Pause-Toolkit }
    }
}
function Menu-Reports {
    $all = @('Health','System','Hardware','Network','Storage','Services','Events','Policy','Users','Groups','Shares','Software','Updates','Tasks','Administrators','Sessions','SharePermissions','Firewall','BitLocker','Startup')
    $options = @{
        '2'=@('Health'); '3'=@('System'); '4'=@('Hardware'); '5'=@('Network'); '6'=@('Storage');
        '7'=@('Services'); '8'=@('Events'); '9'=@('Policy'); '10'=@('Software'); '11'=@('Updates');
        '12'=@('Tasks'); '13'=@('Users'); '14'=@('Groups'); '15'=@('Administrators');
        '16'=@('Sessions'); '17'=@('Shares'); '18'=@('SharePermissions'); '19'=@('Firewall');
        '20'=@('BitLocker'); '21'=@('Startup')
    }
    while ($true) {
        Show-Header 'System Information / Reporting'
        Write-Host ' COMPLETE REPORT' -ForegroundColor Yellow
        Write-Host ' 1 All-in-one report   - Run all twenty read-only diagnostic checks'
        Write-Host '------------------------------------------------------------' -ForegroundColor DarkGray
        Write-Host ' SYSTEM REPORTS' -ForegroundColor Yellow
        Write-Host ' 2 Quick health check  - Reachability, admin share, services, disk, events'
        Write-Host ' 3 System information  - OS, uptime, and general system details'
        Write-Host ' 4 Hardware inventory  - CPU, RAM, BIOS, serial, physical disks'
        Write-Host ' 5 Network diagnostics - DNS, ping, traceroute, remote IP config'
        Write-Host ' 6 Disk space          - Fixed drive capacity and free space'
        Write-Host ' 7 Windows services    - Nonrunning automatic services'
        Write-Host ' 8 Recent event errors - System/Application errors (last 7 days)'
        Write-Host ' 9 Group Policy        - Computer-scope GP Results'
        Write-Host '10 Installed software  - Registry uninstall entries'
        Write-Host '11 Windows updates     - Installed hotfixes and recent failures'
        Write-Host '12 Scheduled tasks     - Remote task inventory and last results'
        Write-Host '------------------------------------------------------------' -ForegroundColor DarkGray
        Write-Host ' USERS / SECURITY' -ForegroundColor Yellow
        Write-Host '13 Local users         - Local user accounts'
        Write-Host '14 Local groups        - Groups and direct membership'
        Write-Host '15 Local administrators - Direct Administrators group members'
        Write-Host '16 Active sessions     - Logged-on terminal sessions'
        Write-Host '17 Network shares      - SMB shares and paths'
        Write-Host '18 Share / NTFS ACLs   - Share and root-folder permissions (WinRM)'
        Write-Host '19 Windows firewall    - Profiles and selected enabled rules (WinRM)'
        Write-Host '20 BitLocker status    - Protection/encryption (no recovery keys)'
        Write-Host '21 Startup programs    - Windows startup entries'
        Write-Host '------------------------------------------------------------' -ForegroundColor DarkGray
        Write-Host '22 Save last collected results (no rerun)'
        Write-Host '23 Browse saved reports (archive)'
        Write-Host '24 Create snapshot       - Capture seven-category comparison baseline'
        Write-Host ' B Back to main menu'
        Write-Host '------------------------------------------------------------' -ForegroundColor DarkGray
        Write-Host ''
        $choice = (Read-Host 'Choose').Trim().ToUpperInvariant()
        if ($choice -eq 'B' -or $choice -eq '0') { return }
        if ($choice -eq '22') { Save-ClassicCollectedReport; continue }
        if ($choice -eq '23') { Menu-ReportArchive; continue }
        if ($choice -eq '24') { if ($script:LocalTargetMode) { Write-Host 'Local snapshots are not yet supported. Select a remote target.' -ForegroundColor Yellow; Pause-Toolkit } else { New-ClassicComparisonSnapshot }; continue }
        if ($choice -eq '1') { Save-DiagnosticReport $all 'Complete'; continue }
        if ($options.ContainsKey($choice)) {
            $sections = $options[$choice]
            Save-DiagnosticReport $sections $sections[0]
        }
    }
}

