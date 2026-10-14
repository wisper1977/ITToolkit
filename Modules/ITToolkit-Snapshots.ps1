# IT Toolkit v1.24 - dot-sourced component; loaded in parent script scope.
# Comparison snapshots are machine-readable sidecars generated from remote, read-only queries.
# Existing HTML/TXT/CSV reports remain readable; legacy reports without snapshots cannot
# reliably represent all services or structured membership changes.
function Get-ComparisonSnapshot([string]$Target,[string[]]$Sections) {
    $categories = [ordered]@{}
    $failures = [ordered]@{}
    $needed = @($Sections | Where-Object { $_ -in @('Services','Software','Updates','Users','Groups','Administrators','Shares') })
    foreach ($section in $needed) {
        Write-Host "Collecting comparison inventory: $section ..." -ForegroundColor DarkCyan
        try {
            $entries = @()
            switch ($section) {
                'Services' {
                    $entries = @(Get-WmiObject Win32_Service -ComputerName $Target -ErrorAction Stop | ForEach-Object {
                        [pscustomobject]@{ Key=[string]$_.Name; DisplayName=[string]$_.DisplayName; State=[string]$_.State; StartMode=[string]$_.StartMode; StartName=[string]$_.StartName }
                    })
                }
                'Software' {
                    $reg = [WMIClass]"\\$Target\root\default:StdRegProv"
                    $hive = [uint32]2147483650
                    $entries = @(foreach ($base in @('SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall','SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall')) {
                        $found = $reg.EnumKey($hive,$base)
                        if ($found.ReturnValue -ne 0) { throw "Cannot enumerate software registry $base (code $($found.ReturnValue))." }
                        foreach ($sub in @($found.sNames)) {
                            if (-not $sub) { continue }
                            $key = "$base\$sub"
                            $name = [string]$reg.GetStringValue($hive,$key,'DisplayName').sValue
                            if (-not $name) { continue }
                            [pscustomobject]@{ Key="$base\$sub"; Name=$name; Version=[string]$reg.GetStringValue($hive,$key,'DisplayVersion').sValue; Publisher=[string]$reg.GetStringValue($hive,$key,'Publisher').sValue }
                        }
                    })
                }
                'Updates' {
                    $entries = @(Get-WmiObject Win32_QuickFixEngineering -ComputerName $Target -ErrorAction Stop | ForEach-Object {
                        [pscustomobject]@{ Key=[string]$_.HotFixID; Description=[string]$_.Description; InstalledOn=[string]$_.InstalledOn }
                    })
                }
                'Users' {
                    $entries = @(Get-WmiObject Win32_UserAccount -ComputerName $Target -Filter 'LocalAccount=True' -ErrorAction Stop | ForEach-Object {
                        [pscustomobject]@{ Key=[string]$_.SID; Name=[string]$_.Name; Disabled=[string]$_.Disabled; Lockout=[string]$_.Lockout }
                    })
                }
                'Groups' {
                    $entries = @(Get-WmiObject Win32_GroupUser -ComputerName $Target -ErrorAction Stop | ForEach-Object {
                        $group = Format-WmiAccountReference ([string]$_.GroupComponent)
                        $member = Format-WmiAccountReference ([string]$_.PartComponent)
                        [pscustomobject]@{ Key="$group -> $member"; Group=$group; Member=$member }
                    })
                }
                'Administrators' {
                    $groups = @(Get-WmiObject Win32_Group -ComputerName $Target -Filter 'LocalAccount=True' -ErrorAction Stop | Where-Object { $_.SID -eq 'S-1-5-32-544' })
                    if ($groups.Count -eq 0) { throw 'Local Administrators group not available.' }
                    $groupName = "$($groups[0].Domain)\$($groups[0].Name)"
                    $entries = @(Get-WmiObject Win32_GroupUser -ComputerName $Target -ErrorAction Stop | ForEach-Object {
                        if ((Format-WmiAccountReference ([string]$_.GroupComponent)) -eq $groupName) {
                            $member = Format-WmiAccountReference ([string]$_.PartComponent)
                            [pscustomobject]@{ Key=$member; Member=$member }
                        }
                    })
                }
                'Shares' {
                    $entries = @(Get-WmiObject Win32_Share -ComputerName $Target -ErrorAction Stop | ForEach-Object {
                        [pscustomobject]@{ Key=[string]$_.Name; Path=[string]$_.Path; Description=[string]$_.Description; Type=[string]$_.Type }
                    })
                }
            }
            $categories[$section] = @($entries)
        } catch {
            $failures[$section] = $_.Exception.Message
        }
    }
    return [pscustomobject]@{
        SchemaVersion = 1
        ToolkitVersion = $script:ToolkitVersion
        Target = $Target
        CapturedAt = (Get-Date).ToString('o')
        Technician = [Security.Principal.WindowsIdentity]::GetCurrent().Name
        Categories = [pscustomobject]$categories
        Errors = [pscustomobject]$failures
    }
}
function Get-SnapshotFiles {
    if (-not (Test-Path -LiteralPath $script:ReportFolder -PathType Container)) { return @() }
    return @(Get-ChildItem -LiteralPath $script:ReportFolder -Filter '*.snapshot.json' -File -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending)
}
function Read-ComparisonSnapshot([string]$Path) {
    $data = Get-Content -LiteralPath $Path -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
    if ($data.SchemaVersion -ne 1 -or -not $data.Target -or -not $data.Categories) { throw 'Not a compatible toolkit snapshot.' }
    return $data
}
function Choose-Snapshot([string]$Prompt,[string]$TargetFilter = '') {
    $files = @(Get-SnapshotFiles | Where-Object { -not $TargetFilter -or $_.Name -like "$(($TargetFilter -replace '[^a-zA-Z0-9_.-]','_'))_*" })
    if ($files.Count -eq 0) { Write-Host 'No saved structured snapshots found.' -ForegroundColor Yellow; return $null }
    Write-Host "`n$Prompt" -ForegroundColor Cyan
    for ($i=0; $i -lt $files.Count; $i++) { Write-Host ('{0,3} {1}   {2}' -f ($i+1),$files[$i].Name,$files[$i].LastWriteTime.ToString('yyyy-MM-dd HH:mm')) }
    Write-Host ' B  Cancel' -ForegroundColor Yellow
    $answer = (Read-Host 'Choose number').Trim()
    if ($answer -ieq 'B') { return $null }
    $index = 0
    if (-not [int]::TryParse($answer,[ref]$index) -or $index -lt 1 -or $index -gt $files.Count) {
        Write-Host 'Invalid selection.' -ForegroundColor Yellow
        return $null
    }
    return $files[$index-1].FullName
}
function Compare-Snapshots([string]$OlderPath,[string]$NewerPath,[string]$OnlyCategory = '') {
    try {
        $old = Read-ComparisonSnapshot $OlderPath
        $new = Read-ComparisonSnapshot $NewerPath
    } catch { Write-Host "Unable to load snapshot: $($_.Exception.Message)" -ForegroundColor Yellow; Pause-Toolkit; return }
    if ($old.Target -ine $new.Target) {
        Write-Host "Different targets: $($old.Target) and $($new.Target)." -ForegroundColor Yellow
        $answer=(Read-Host 'Type YES to compare anyway').Trim()
        if ($answer -cne 'YES') { return }
    }
    $categories = @('Services','Software','Updates','Users','Groups','Administrators','Shares')
    if ($OnlyCategory) { $categories = @($OnlyCategory) }
    $lines = New-Object System.Collections.Generic.List[string]
    $lines.Add("$($script:ToolkitDisplayName.ToUpperInvariant()) v$script:ToolkitVersion - SAVED REPORT COMPARISON")
    $lines.Add("Baseline: $($old.Target), $($old.CapturedAt)")
    $lines.Add("Current:  $($new.Target), $($new.CapturedAt)")
    $lines.Add("Source baseline: $OlderPath")
    $lines.Add("Source current:  $NewerPath")
    $lines.Add('Differences only. These snapshots contain direct membership and available inventories; collection errors are not interpreted as removals.')
    $lines.Add('')
    $categoryDetails = New-Object System.Collections.Generic.List[string]
    $totalAdded = 0; $totalRemoved = 0; $totalChanged = 0; $notComparable = 0
    foreach ($category in $categories) {
        $categoryDetails.Add(('=' * 64))
        $categoryDetails.Add("$category CHANGES")
        $categoryDetails.Add(('=' * 64))
        $oldProperty = $old.Categories.PSObject.Properties[$category]
        $newProperty = $new.Categories.PSObject.Properties[$category]
        if (-not $oldProperty -or -not $newProperty) {
            $oldError = $old.Errors.PSObject.Properties[$category]
            $newError = $new.Errors.PSObject.Properties[$category]
            $notComparable++
            $categoryDetails.Add("NOT COMPARABLE: missing inventory. Baseline error: $($oldError.Value); Current error: $($newError.Value)")
            $categoryDetails.Add('')
            continue
        }
        $before = @($oldProperty.Value)
        $after = @($newProperty.Value)
        $oldMap = @{}
        $newMap = @{}
        foreach ($item in $before) { if ($null -ne $item -and $item.Key) { $oldMap[[string]$item.Key] = $item } }
        foreach ($item in $after)  { if ($null -ne $item -and $item.Key) { $newMap[[string]$item.Key] = $item } }
        $added = 0; $removed = 0; $changed = 0
        foreach ($key in @($newMap.Keys | Sort-Object)) {
            if (-not $oldMap.ContainsKey($key)) { $categoryDetails.Add("ADDED: $key | $((($newMap[$key].PSObject.Properties | Where-Object {$_.Name -ne 'Key'} | ForEach-Object { "$($_.Name)=$($_.Value)" }) -join '; '))"); $added++; continue }
            $differences = @()
            foreach ($property in $newMap[$key].PSObject.Properties) {
                if ($property.Name -eq 'Key') { continue }
                $prior = [string]$oldMap[$key].($property.Name)
                $latest = [string]$property.Value
                if ($prior -cne $latest) { $differences += "$($property.Name): '$prior' => '$latest'" }
            }
            if ($differences.Count -gt 0) { $categoryDetails.Add("CHANGED: $key | $($differences -join '; ')"); $changed++ }
        }
        foreach ($key in @($oldMap.Keys | Sort-Object)) {
            if (-not $newMap.ContainsKey($key)) { $categoryDetails.Add("REMOVED: $key"); $removed++ }
        }
        $totalAdded += $added; $totalRemoved += $removed; $totalChanged += $changed
        $categoryDetails.Add("Summary: $added added, $removed removed, $changed changed")
        if (($added + $removed + $changed) -eq 0) { $categoryDetails.Add('No changes detected.') }
        $categoryDetails.Add('')
    }
    $lines.Add(('=' * 64))
    $lines.Add('COMPARISON SUMMARY')
    $lines.Add(('=' * 64))
    $lines.Add("Total changes: $($totalAdded + $totalRemoved + $totalChanged)")
    $lines.Add("ADDED: $totalAdded")
    $lines.Add("REMOVED: $totalRemoved")
    $lines.Add("CHANGED: $totalChanged")
    $lines.Add("NOT COMPARABLE: $notComparable categories")
    if (($totalAdded + $totalRemoved + $totalChanged) -eq 0 -and $notComparable -eq 0) {
        $lines.Add('No changes detected across all comparable categories.')
    }
    $lines.Add('')
    foreach ($detail in $categoryDetails) { $lines.Add($detail) }
    $output = ($lines -join "`r`n")
    Write-Host $output
    $save = (Read-Host 'Save comparison report? (Y/N)').Trim()
    if ($save -ine 'Y') { Pause-Toolkit; return }
    try {
        if (-not (Test-Path -LiteralPath $script:ReportFolder)) { [void](New-Item -ItemType Directory -Path $script:ReportFolder -Force -ErrorAction Stop) }
        $safeTarget = ([string]$new.Target -replace '[^a-zA-Z0-9_.-]','_')
        $format = (Read-Host ('Comparison format [HTML / CSV / TXT] (Enter = {0}, B = cancel)' -f $script:ReportFormat)).Trim().ToUpperInvariant()
        if ($format -in @('B','0')) { return }
        if (-not $format) { $format = $script:ReportFormat }
        if ($format -notin @('HTML','CSV','TXT')) { Write-Host 'Invalid format.' -ForegroundColor Yellow; Pause-Toolkit; return }
        $extension = $format.ToLowerInvariant()
        $filename = '{0}_Comparison_{1}.{2}' -f $safeTarget,(Get-Date -Format 'yyyyMMdd_HHmmss_fff'),$extension
        $path = Join-Path $script:ReportFolder $filename
        switch ($format) {
            'HTML' { $contents = Convert-ReportHtml $output "$script:ToolkitDisplayName - Comparison - $($new.Target)" }
            'CSV' {
                $rows = New-Object System.Collections.Generic.List[object]
                $category = 'Summary'
                foreach ($line in $lines) {
                    if ($line -match '^([A-Za-z][A-Za-z ]+) CHANGES$') { $category=$Matches[1] }
                    $kind='INFO'; $detail=[string]$line
                    if ($line -match '^(ADDED|REMOVED|CHANGED|NOT COMPARABLE):\s*(.*)$') { $kind=$Matches[1]; $detail=$Matches[2] }
                    $rows.Add([pscustomobject]@{Category=$category;ChangeType=$kind;Detail=$detail})
                }
                $contents = ($rows | ConvertTo-Csv -NoTypeInformation) -join "`r`n"
            }
            default { $contents = $output }
        }
        [System.IO.File]::WriteAllText($path,$contents,[System.Text.Encoding]::UTF8)
        Write-Host "Saved: $path" -ForegroundColor Green
        Ask-OpenSavedReport $path
    } catch { Write-Host "Could not save comparison: $($_.Exception.Message)" -ForegroundColor Yellow }
    Pause-Toolkit
}
function Menu-Comparison {
    while ($true) {
        Show-Header 'Saved Report Comparison'
        Write-Host ' 1 Compare two newest snapshots for selected target'
        Write-Host ' 2 Choose any two saved snapshots'
        Write-Host ' 3 Compare services only (choose two snapshots)'
        Write-Host '------------------------------------------------------------' -ForegroundColor DarkGray
        Write-Host ' B Back to main menu'
        Write-Host '------------------------------------------------------------' -ForegroundColor DarkGray
        Write-Host ''
        $choice=(Read-Host 'Choose').Trim().ToUpperInvariant()
        if ($choice -in @('B','0')) { return }
        if ($choice -eq '1') {
            if (-not $script:TargetComputer) { Write-Host 'Select a target first.' -ForegroundColor Yellow; Pause-Toolkit; continue }
            $safe = $script:TargetComputer -replace '[^a-zA-Z0-9_.-]','_'
            $found = @(Get-SnapshotFiles | Where-Object { $_.Name -like "${safe}_Complete_*.snapshot.json" } | Select-Object -First 2)
            if ($found.Count -lt 2) { Write-Host 'At least two complete-report snapshots are needed for the selected target.' -ForegroundColor Yellow; Pause-Toolkit; continue }
            Compare-Snapshots $found[1].FullName $found[0].FullName
        } elseif ($choice -in @('2','3')) {
            $older=Choose-Snapshot 'Select baseline (older) snapshot'
            if (-not $older) { continue }
            $newer=Choose-Snapshot 'Select comparison (newer) snapshot'
            if (-not $newer) { continue }
            if ($older -eq $newer) { Write-Host 'Choose two different snapshots.' -ForegroundColor Yellow; Pause-Toolkit; continue }
            Compare-Snapshots $older $newer $(if ($choice -eq '3') {'Services'} else {''})
        }
    }
}
