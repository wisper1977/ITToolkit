# IT Toolkit v1.26 Phase 6C - Classic Create Snapshot (read-only).
# The collector is shared with the GUI to preserve snapshot schema and credential isolation.
function New-ClassicComparisonSnapshot {
    $target = Get-Target
    if (-not $target) { return }
    $mode = if ($script:ToolkitAuthMode -eq 'Alternate') { 'Alternate' } else { 'Default' }
    $credential = $null
    if ($mode -eq 'Alternate') {
        try {
            $null = Test-ClassicAlternateReportContext
            $credential = $script:ToolkitAuthContext.Credential
            if ($null -eq $credential) { throw 'Alternate credential is missing.' }
        } catch {
            Write-Host "Snapshot blocked: $($_.Exception.Message)" -ForegroundColor Yellow
            Pause-Toolkit
            return
        }
    }
    Write-Host "`nCreate seven-category snapshot of $target ($mode authentication)?" -ForegroundColor Cyan
    $answer = (Read-Host 'Type YES to collect (anything else cancels)').Trim()
    if ($answer -cne 'YES') { return }
    try {
        $args = @{ Target=$target; Mode=$mode; ToolkitVersion=$script:ToolkitVersion }
        if ($mode -eq 'Alternate') { $args.Credential=$credential }
        Write-Host 'Collecting Services, Software, Updates, Users, Groups, Administrators, Shares ...' -ForegroundColor Cyan
        $snapshot = Get-ToolkitGUISnapshot @args
        if (-not $snapshot -or $snapshot.Target -ine $target -or $snapshot.AuthenticationMode -ne $mode) {
            throw 'Collector returned an invalid snapshot or an unexpected target/authentication mode.'
        }
        $expected = @('Services','Software','Updates','Users','Groups','Administrators','Shares')
        $errors = @($snapshot.Errors.PSObject.Properties)
        foreach ($category in $expected) {
            $property = $snapshot.Categories.PSObject.Properties[$category]
            $failure = $snapshot.Errors.PSObject.Properties[$category]
            if ($null -ne $failure) {
                Write-Host ("  {0}: UNAVAILABLE - {1}" -f $category, $failure.Value) -ForegroundColor Yellow
            } elseif ($null -ne $property) {
                Write-Host ("  {0}: {1} records" -f $category, @($property.Value).Count) -ForegroundColor Green
            } else {
                throw "Collector omitted category $category without an error. Snapshot was not saved."
            }
        }
        if ($errors.Count -eq $expected.Count) {
            throw 'All seven categories failed; no comparison baseline was saved.'
        }
        $folder = [string]$script:ReportFolder
        if ([string]::IsNullOrWhiteSpace($folder)) { throw 'Reports folder is not configured.' }
        if (-not (Test-Path -LiteralPath $folder -PathType Container)) {
            [void](New-Item -ItemType Directory -Path $folder -Force -ErrorAction Stop)
        }
        $safeTarget = $target -replace '[^a-zA-Z0-9_.-]','_'
        $file = '{0}_Complete_{1}.snapshot.json' -f $safeTarget,(Get-Date -Format 'yyyyMMdd_HHmmss_fff')
        $path = Join-Path $folder $file
        $json = ConvertTo-Json -InputObject $snapshot -Depth 8
        [System.IO.File]::WriteAllText($path,$json,(New-Object System.Text.UTF8Encoding($false)))
        Write-Host "`nSnapshot saved: $path" -ForegroundColor Green
        if ($errors.Count) { Write-Host 'Partial capture: categories marked UNAVAILABLE are not treated as removed during comparison.' -ForegroundColor Yellow }
        Write-Host 'Use main menu option 6 (Saved Report Comparison) to compare snapshots.' -ForegroundColor Cyan
    } catch {
        Write-Host "Snapshot creation failed: $($_.Exception.Message)" -ForegroundColor Yellow
    }
    Pause-Toolkit
}
