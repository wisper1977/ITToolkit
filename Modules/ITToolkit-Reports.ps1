# IT Toolkit v1.24 - dot-sourced component; loaded in parent script scope.
# Reporting is read-only. Every section is independent, so access failures
# are included in the report and do not prevent the remaining checks.
$script:ReportFolder = $script:Config.ReportFolder
if (-not [System.IO.Path]::IsPathRooted($script:ReportFolder)) {
    $script:ReportFolder = Join-Path $script:ToolkitRoot $script:ReportFolder
}
function Set-ReportFolder {
    Write-Host "`nCurrent report folder: $script:ReportFolder" -ForegroundColor Cyan
    $entered = (Read-Host 'Enter an existing folder (B/blank = cancel)').Trim().Trim('"')
    if (-not $entered -or $entered -ieq 'B') { return }
    if (-not (Test-Path -LiteralPath $entered -PathType Container)) {
        Write-Host 'Folder not found. Create it first and try again.' -ForegroundColor Yellow
        Pause-Toolkit; return
    }
    $script:ReportFolder = (Resolve-Path -LiteralPath $entered).ProviderPath
    try {
        $relative = $script:ReportFolder
        $base = $script:ToolkitRoot.TrimEnd('\') + '\'
        if ($relative.StartsWith($base,[System.StringComparison]::OrdinalIgnoreCase)) { $relative = $relative.Substring($base.Length) }
        $script:Config.ReportFolder = $relative
        if (-not (Save-ToolkitConfig)) { throw 'Configuration could not be saved.' }
    }
    catch { Write-Host 'Setting applied for this session but could not be saved.' -ForegroundColor Yellow }
    Pause-Toolkit
}
# Inventory reports enumerate accounts local to the selected Windows computer.
# Domain account/group membership is only shown where returned as a member
# of a local group; this is not an enumeration of the entire AD domain.
function Format-WmiAccountReference([string]$Reference) {
    $domain = [regex]::Match($Reference, 'Domain="((?:\\.|[^"])*)"').Groups[1].Value
    $name = [regex]::Match($Reference, 'Name="((?:\\.|[^"])*)"').Groups[1].Value
    $domain = $domain.Replace('\\','\')
    $name = $name.Replace('\\','\')
    if ($domain -and $name) { return "$domain\$name" }
    if ($name) { return $name }
    return $Reference
}
# Report output format is stored independently of the tool paths.
function Set-ReportFormat {
    Write-Host "`nCurrent report format: $script:ReportFormat" -ForegroundColor Cyan
    $format = (Read-Host 'Choose TXT, CSV or HTML (B = cancel)').Trim().ToUpperInvariant()
    if (-not $format -or $format -eq 'B') { return }
    if ($format -notin @('TXT','CSV','HTML')) { Write-Host 'Invalid format.' -ForegroundColor Yellow; Pause-Toolkit; return }
    $script:ReportFormat = $format
    try { $script:Config.ReportFormat = $format; if (-not (Save-ToolkitConfig)) { throw 'Configuration could not be saved.' } }
    catch { Write-Host 'Saved for this session only (settings folder is not writable).' -ForegroundColor Yellow }
    Pause-Toolkit
}
function Invoke-TargetReadOnly([string]$Target,[scriptblock]$Block,[object[]]$ArgumentList = @()) {
    # Deliberately does not change configuration. Requires WinRM/PSRemoting access.
    return Invoke-Command -ComputerName $Target -ScriptBlock $Block -ArgumentList $ArgumentList -ErrorAction Stop
}
function Convert-ReportHtml([string]$Text,[string]$Title) {
    # Presentation-only transformation: do not alter raw TXT/CSV or snapshot data.
    # Encode every collected field before inserting it into HTML.
    $enc = { param([string]$value) [System.Net.WebUtility]::HtmlEncode($value) }
    $safeTitle = & $enc $Title
    $css = @'
body{font:14px Segoe UI,Arial,sans-serif;margin:24px auto;max-width:1500px;padding:0 22px;color:#17212b;background:#fff}
h1{font-size:23px;margin:0 0 8px}.note{color:#586779;font-size:12px;margin:0 0 14px}
nav{background:#edf3fa;padding:14px;border-radius:7px;margin:15px 0;display:grid;grid-template-columns:repeat(4,minmax(0,1fr));gap:6px 12px}
nav strong{grid-column:1/-1;margin-bottom:3px}
nav a{color:#184d88;text-decoration:none;display:block;padding:5px 8px;border-radius:4px;overflow-wrap:anywhere}
nav a:hover,nav a:focus{background:#dce9f8;text-decoration:underline}
@media(max-width:950px){nav{grid-template-columns:repeat(3,minmax(0,1fr))}}
@media(max-width:680px){nav{grid-template-columns:repeat(2,minmax(0,1fr))}}
@media(max-width:430px){nav{grid-template-columns:1fr}}
.back-to-top{display:block;width:max-content;margin:12px 0 0 auto;padding:5px 9px;color:#184d88;text-decoration:none;font:600 12px Segoe UI,Arial,sans-serif;border-radius:4px;background:#edf3fa}
.back-to-top:hover,.back-to-top:focus{background:#c9e0f8;text-decoration:underline}
details.report-section{border:1px solid #d8e1ec;border-radius:8px;margin:12px 0;overflow:hidden}
details.report-section>summary{cursor:pointer;background:#e7f0fc;color:#184d88;font-weight:700;padding:11px 15px;list-style-position:inside}
details.report-section>summary:hover{background:#dae9fc}.section-body{padding:14px 16px}
.report-line{display:block;min-height:1.5em;white-space:pre-wrap;overflow-wrap:anywhere;font:12.5px/1.5 Consolas,'Courier New',monospace;padding:2px 6px;border-radius:2px}
.report-line.stripe{background:#c9e0f8}
.report-line.good{background:#e9f8ed}.report-line.warn{background:#fff4d6}.report-line.bad{background:#fde9e9}
.report-line.added{background:#e9f8ed}.report-line.removed{background:#fde9e9}.report-line.changed{background:#fff4d6}
.good{color:#166534;background:#e9f8ed;font-weight:600}.warn{color:#92400e;background:#fff4d6;font-weight:600}.bad{color:#991b1b;background:#fde9e9;font-weight:600}.neutral{color:#475569;background:#e9edf2;font-weight:600}
.added{color:#166534;background:#e9f8ed}.removed{color:#991b1b;background:#fde9e9}.changed{color:#92400e;background:#fff4d6}
.task-table-wrap{overflow-x:auto;max-width:100%;margin:12px 0 18px}
table.task-table{width:100%;border-collapse:collapse;font-size:12.5px;line-height:1.4;table-layout:auto}
.task-table th{background:#e9f0f9;text-align:left;color:#24486e;position:sticky;top:0}
.task-table th,.task-table td{padding:7px 9px;border:1px solid #dce4ec;vertical-align:top;overflow-wrap:anywhere}
.task-table tbody tr:nth-child(even){background:#c9e0f8}.task-table tbody tr:hover{background:#b4d2f3}
.task-table td:nth-child(2){font-weight:600}.task-table td:nth-child(1){font-size:11px;color:#546477}
.task-table .task-state{white-space:nowrap}.task-table .task-code{font-family:Consolas,monospace;white-space:nowrap}
.task-table .task-review{background:#fff5de}.task-table .task-review:nth-child(even){background:#fff0ce}
@media print{nav,.back-to-top{display:none}details.report-section{break-inside:avoid}details.report-section>summary{background:#eee}.task-table th{position:static}}
'@
    $lines = @($Text -split '\r?\n')
    $html = New-Object System.Text.StringBuilder
    $sections = New-Object System.Collections.Generic.List[object]
    foreach ($line in $lines) {
        if ($line -match '^(DIAGNOSTIC STATUS SUMMARY|COMPARISON SUMMARY|[A-Za-z][A-Za-z ]+ REPORT|[A-Za-z][A-Za-z ]+ CHANGES)$') {
            $heading = $matches[1]
            $sectionId = 'section-' + (($heading.ToLowerInvariant() -replace '[^a-z0-9]+','-').Trim('-'))
            $sections.Add([pscustomobject]@{Label=$heading;Id=$sectionId})
        }
    }
    if ($sections.Count -gt 0) {
        [void]$html.Append('<nav aria-label="Report sections"><strong>Jump to:</strong> ')
        foreach ($section in $sections) {
            [void]$html.Append(('<a href="#{0}">{1}</a>' -f $section.Id,(& $enc $section.Label)))
        }
        [void]$html.Append('</nav>')
    }
    $inSection = $false
    $inTaskTable = $false
    $tableStarts = @('TASKS WITH RESULTS TO REVIEW:','ALL SCHEDULED TASKS:')
    $waitingForTable = $false
    $colPositions = @()
    $readableRowIndex = 0
    foreach ($line in $lines) {
        if ($line -match '^(DIAGNOSTIC STATUS SUMMARY|COMPARISON SUMMARY|[A-Za-z][A-Za-z ]+ REPORT|[A-Za-z][A-Za-z ]+ CHANGES)$') {
            if ($inTaskTable) { [void]$html.Append('</tbody></table></div>'); $inTaskTable=$false }
            if ($inSection) { [void]$html.Append('<a class="back-to-top" href="#report-top">&#8593; Back to Top</a></div></details>') }
            $heading = $matches[1]
            $sectionId = 'section-' + (($heading.ToLowerInvariant() -replace '[^a-z0-9]+','-').Trim('-'))
            [void]$html.Append(('<details class="report-section" id="{0}" open><summary>{1}</summary><div class="section-body">' -f $sectionId,(& $enc $heading)))
            $inSection = $true
            $readableRowIndex = 0
            $waitingForTable = $false
            continue
        }
        if ($inSection -and $line -in $tableStarts) {
            if ($inTaskTable) { [void]$html.Append('</tbody></table></div>'); $inTaskTable = $false }
            $waitingForTable = $true
            [void]$html.Append(('<h3>{0}</h3>' -f (& $enc $line.TrimEnd(':'))))
            continue
        }
        if ($waitingForTable -and $line -match '^TaskPath\s{2,}TaskName\s{2,}State\s+LastRunTime\s+LastResult\s+Meaning\s*$') {
            # Read column boundaries from the formatted header rather than
            # guessing widths, preserving spaces within task names and paths.
            $colPositions = @($line.IndexOf('TaskPath'),$line.IndexOf('TaskName'),$line.IndexOf('State'),$line.IndexOf('LastRunTime'),$line.IndexOf('LastResult'),$line.IndexOf('Meaning'))
            [void]$html.Append('<div class="task-table-wrap"><table class="task-table"><thead><tr>')
            foreach ($headingName in @('Path','Task','State','Last run','Result','Meaning')) { [void]$html.Append(('<th scope="col">{0}</th>' -f $headingName)) }
            [void]$html.Append('</tr></thead><tbody>')
            $inTaskTable = $true
            $waitingForTable = $false
            continue
        }
        if ($inTaskTable) {
            if ($line -match '^\s*$') { [void]$html.Append('</tbody></table></div>'); $inTaskTable=$false; continue }
            if ($line -match '^\s*-{2,}\s+') { continue }
            $cells = @()
            for ($i=0; $i -lt 6; $i++) {
                $start = $colPositions[$i]
                $stop = if ($i -lt 5) { $colPositions[$i+1] } else { $line.Length }
                if ($line.Length -le $start) { $value = '' }
                else { $value = $line.Substring($start,[Math]::Min($line.Length,$stop)-$start).Trim() }
                $cells += $value
            }
            $rowClass = if ($cells[4] -ne '0' -and $cells[3] -ne 'Never' -and $cells[4] -notmatch '^2670(08|09|10|11|12|13|14|15)$') { ' class="task-review"' } else { '' }
            [void]$html.Append("<tr$rowClass>")
            for ($i=0; $i -lt 6; $i++) {
                $cellClass = if ($i -eq 2) { ' class="task-state"' } elseif ($i -eq 4) { ' class="task-code"' } else { '' }
                [void]$html.Append(('<td{0}>{1}</td>' -f $cellClass,(& $enc $cells[$i])))
            }
            [void]$html.Append('</tr>')
            continue
        }
        if ($line -match '^\s*$' -and $waitingForTable) { continue }
        # These rulers belong to the plain-text report; HTML already has section borders.
        if ($line -match '^\s*={5,}\s*$') { continue }
        $class='report-line'
        if (-not [string]::IsNullOrWhiteSpace($line)) {
            $readableRowIndex++
            if (($readableRowIndex % 2) -eq 0) { $class += ' stripe' }
        }
        if ($line -match '^\s*ADDED:') { $class += ' added' }
        elseif ($line -match '^\s*REMOVED:') { $class += ' removed' }
        elseif ($line -match '^\s*CHANGED:') { $class += ' changed' }
        elseif ($line -match '(?i)^\s*(?:STATUS:\s*)?(?:[A-Za-z][A-Za-z ]{0,24}\s+)?(?:ACCESS DENIED|UNAVAILABLE|PARTIAL / UNAVAILABLE|ERROR)(?:\s|$|:)' -or $line -match '(?i)^NOT COMPARABLE: [1-9]') { $class += ' bad' }
        elseif ($line -match '(?i)^\s*(?:STATUS:\s*)?(?:[A-Za-z][A-Za-z ]{0,24}\s+)?(?:REVIEW|WARNING|NO RESULTS)(?:\s|$|:)' -or $line -match '^Results needing review: [1-9]' -or $line -match '^Total changes: [1-9]') { $class += ' warn' }
        elseif ($line -match '(?i)^\s*(?:STATUS:\s*)?(?:[A-Za-z][A-Za-z ]{0,24}\s+)?(?:SUCCESS|PASS)(?:\s|$|:)' -or $line -match '^No changes detected') { $class += ' good' }
        [void]$html.Append(('<span class="{0}">{1}</span>' -f $class,(& $enc $line)))
    }
    if ($inTaskTable) { [void]$html.Append('</tbody></table></div>') }
    if ($inSection) { [void]$html.Append('<a class="back-to-top" href="#report-top">&#8593; Back to Top</a></div></details>') }
    return "<!doctype html><html lang='en'><head><meta charset='utf-8'><meta name='viewport' content='width=device-width,initial-scale=1'><title>$safeTitle</title><style>$css</style></head><body><h1 id='report-top'>$safeTitle</h1><p class='note'>Read-only diagnostic report. Colors indicate query status or reported changes, not overall system health. Click any section heading to collapse or expand it.</p>$($html.ToString())</body></html>"
}
function Ask-OpenSavedReport([string]$Path) {
    if ([string]::IsNullOrWhiteSpace($Path) -or -not (Test-Path -LiteralPath $Path -PathType Leaf)) { return }
    $response = (Read-Host 'Open the saved report now? (Y/N)').Trim()
    if ($response -ine 'Y') { return }
    try { Start-Process -FilePath $Path -ErrorAction Stop }
    catch { Write-Host "Unable to open report: $($_.Exception.Message)" -ForegroundColor Yellow }
}
function Convert-ReportCsv([string[]]$Lines) {
    # CSV preserves every line/section for tickets; table-shaped inventory export
    # can be introduced separately if a structured schema is needed.
    $section = 'Header'
    $rows = foreach ($line in $Lines) {
        if ($line -match '^([\w ]+) REPORT$') { $section = $Matches[1] }
        [pscustomobject]@{ Section=$section; Detail=$line }
    }
    return (($rows | ConvertTo-Csv -NoTypeInformation) -join "`r`n")
}
function Get-RemoteEventEntries([string]$Target,[string]$LogName,[datetime]$Since,[int]$Limit = 25) {
    $failures = New-Object System.Collections.Generic.List[string]
    # First choice: modern Event Log RPC API; this does not require WinRM.
    try {
        $events = @(Get-WinEvent -ComputerName $Target -FilterHashtable @{LogName=$LogName;Level=1,2;StartTime=$Since} -MaxEvents $Limit -ErrorAction Stop)
        return [pscustomobject]@{ Status='SUCCESS'; Method='Get-WinEvent (RPC)'; Events=$events; Detail='' }
    } catch {
        if ($_.FullyQualifiedErrorId -match 'NoMatchingEventsFound') { return [pscustomobject]@{Status='NO RESULTS';Method='Get-WinEvent (RPC)';Events=@();Detail='No matching Critical/Error events.'} }
        $failures.Add("RPC: $($_.Exception.Message)")
    }
    # Second choice: PowerShell remoting, if separately enabled.
    try {
        $events = @(Invoke-TargetReadOnly $Target {
            param($Log,$SinceDate,$Count)
            Get-WinEvent -FilterHashtable @{LogName=$Log;Level=1,2;StartTime=$SinceDate} -MaxEvents $Count -ErrorAction Stop |
                Select-Object TimeCreated,Id,ProviderName,LevelDisplayName,Message
        } -ArgumentList $LogName,$Since,$Limit)
        return [pscustomobject]@{Status='SUCCESS';Method='PowerShell Remoting';Events=$events;Detail=''}
    } catch {
        if ($_.FullyQualifiedErrorId -match 'NoMatchingEventsFound') { return [pscustomobject]@{Status='NO RESULTS';Method='PowerShell Remoting';Events=@();Detail='No matching Critical/Error events.'} }
        $failures.Add("WinRM: $($_.Exception.Message)")
    }
    # Last resort: legacy DCOM/WMI event class, returning at most the desired number.
    try {
        $dmtf = [System.Management.ManagementDateTimeConverter]::ToDmtfDateTime($Since)
        $escaped = $LogName.Replace("'","''")
        $filter = "Logfile='$escaped' AND EventType=1 AND TimeGenerated >= '$dmtf'"
        $events = @(Get-WmiObject Win32_NTLogEvent -ComputerName $Target -Filter $filter -ErrorAction Stop |
            Select-Object -First $Limit @{N='TimeCreated';E={$_.ConvertToDateTime($_.TimeGenerated)}},@{N='Id';E={$_.EventCode}},@{N='ProviderName';E={$_.SourceName}},@{N='LevelDisplayName';E={'Error'}},@{N='Message';E={$_.Message}})
        if ($events.Count -eq 0) { return [pscustomobject]@{Status='NO RESULTS';Method='WMI Win32_NTLogEvent';Events=@();Detail='No matching events.'} }
        return [pscustomobject]@{Status='SUCCESS';Method='WMI Win32_NTLogEvent';Events=$events;Detail='Legacy event types may not distinguish Critical from Error precisely.'}
    } catch { $failures.Add("WMI: $($_.Exception.Message)") }
    $description = $failures -join '; '
    $status = if ($description -match '(?i)access is denied|access denied|0x80070005|unauthorized') { 'ACCESS DENIED' } else { 'UNAVAILABLE' }
    return [pscustomobject]@{Status=$status;Method='RPC / WinRM / WMI';Events=@();Detail=$description}
}
function Get-RemoteBitLocker([string]$Target) {
    # All queries are read-only. Never collect recovery keys or key protectors.
    $failures = New-Object System.Collections.Generic.List[string]
    $featureStatus = 'Unknown (could not determine installed management components)'
    try {
        $feature = Invoke-TargetReadOnly $Target {
            $cmd = Get-Command Get-WindowsFeature -ErrorAction SilentlyContinue
            if ($cmd) {
                $items = @(Get-WindowsFeature -Name BitLocker,BitLocker-Utilities,BitLocker-NetworkUnlock -ErrorAction SilentlyContinue |
                    Select-Object Name,InstallState)
                if ($items.Count) { return ($items | ForEach-Object { "$($_.Name)=$($_.InstallState)" }) -join '; ' }
            }
            'Feature inventory not available on this Windows edition'
        }
        if ($feature) { $featureStatus = [string]($feature -join '; ') }
    } catch { $failures.Add("Feature inventory: $($_.Exception.Message)") }
    try {
        $result = @(Invoke-TargetReadOnly $Target {
            if (-not (Get-Command Get-BitLockerVolume -ErrorAction SilentlyContinue)) {
                throw 'BitLocker PowerShell cmdlet is not installed on target'
            }
            @(Get-BitLockerVolume -ErrorAction Stop | Select-Object MountPoint,VolumeStatus,ProtectionStatus,EncryptionPercentage,EncryptionMethod)
        })
        if ($result.Count) {
            return "Method: Get-BitLockerVolume (WinRM)`r`nFeature inventory: $featureStatus`r`n" + ($result | Format-Table -AutoSize | Out-String -Width 180)
        }
        $failures.Add('Get-BitLockerVolume: query returned zero volumes')
    } catch { $failures.Add("Get-BitLockerVolume: $($_.Exception.Message)") }
    try {
        $volumes = @(Get-WmiObject -Namespace 'root\CIMV2\Security\MicrosoftVolumeEncryption' -Class Win32_EncryptableVolume -ComputerName $Target -ErrorAction Stop)
        if ($volumes.Count) {
            $rows = foreach ($vol in $volumes) {
                $prot = $vol.GetProtectionStatus()
                $conv = $vol.GetConversionStatus()
                [pscustomobject]@{
                    Drive = $vol.DriveLetter
                    Protection = if ($prot.ReturnValue -eq 0) {switch ($prot.ProtectionStatus) {0 {'Off'} 1 {'On'} 2 {'Unknown'} default {"Code $($prot.ProtectionStatus)"}}} else {"Unavailable (code $($prot.ReturnValue))"}
                    Conversion = if ($conv.ReturnValue -eq 0) {switch ($conv.ConversionStatus) {0 {'FullyDecrypted'} 1 {'FullyEncrypted'} 2 {'EncryptionInProgress'} 3 {'DecryptionInProgress'} 4 {'EncryptionPaused'} 5 {'DecryptionPaused'} default {"Code $($conv.ConversionStatus)"}}} else {"Unavailable (code $($conv.ReturnValue))"}
                    EncryptedPercent = if ($conv.ReturnValue -eq 0) { $conv.EncryptionPercentage } else { 'Unknown' }
                }
            }
            return "Method: Win32_EncryptableVolume (remote WMI)`r`nFeature inventory: $featureStatus`r`n" + ($rows | Format-Table -AutoSize | Out-String -Width 180)
        }
        $failures.Add('Encryption WMI provider: returned zero volumes')
    } catch { $failures.Add("Encryption WMI provider: $($_.Exception.Message)") }
    try {
        $text = @(Invoke-TargetReadOnly $Target {
            $command = Join-Path $env:windir 'System32\manage-bde.exe'
            if (-not (Test-Path -LiteralPath $command)) { throw 'manage-bde.exe not installed on target' }
            $output = @(& $command -status 2>&1)
            if ($LASTEXITCODE -ne 0) { throw "manage-bde -status returned exit code $LASTEXITCODE" }
            $output
        })
        if ($text.Count) {
            # manage-bde -status reports encryption state, not recovery credentials.
            return "Method: manage-bde -status (WinRM)`r`nFeature inventory: $featureStatus`r`n" + ($text -join "`r`n")
        }
        $failures.Add('manage-bde: empty response')
    } catch { $failures.Add("manage-bde: $($_.Exception.Message)") }
    $details = $failures -join "`r`n"
    $status = if ($details -match '(?i)access is denied|access denied|0x80070005|unauthorized') { 'ACCESS DENIED' } else { 'UNAVAILABLE' }
    return "STATUS: $status - BitLocker encryption/protection state could not be verified. An unavailable cmdlet/provider is NOT evidence that drives are unencrypted.`r`nFeature inventory: $featureStatus`r`n$details"
}
function Get-TaskResultExplanation([string]$Result, [bool]$NeverRun) {
    if ($NeverRun) { return 'Not run / no recorded execution' }
    $number = [long]0
    if (-not [long]::TryParse($Result, [ref]$number)) { return 'Result unavailable or unrecognized' }
    if ($number -eq 0) { return 'Completed successfully' }
    # Windows Task Scheduler HRESULT status values (SCHED_S_*).
    switch ($number) {
        267008 { return 'Task is ready to run' }               # 0x41300
        267009 { return 'Task is currently running' }         # 0x41301
        267010 { return 'Task is disabled' }                  # 0x41302
        267011 { return 'Task has not run yet' }              # 0x41303
        267012 { return 'No additional scheduled runs' }     # 0x41304
        267013 { return 'Task properties are unavailable' }  # 0x41305
        267014 { return 'Last run was terminated by user' }  # 0x41306
        267015 { return 'No triggers or triggers disabled' } # 0x41307
        2147746132 { return 'Class not registered (0x80040154)' }
        1056 { return 'An instance is already running (1056)' }
        1 { return 'Operation returned error 1 (task-specific)' }
    }
    # An arbitrary task action may return a custom application code. Never
    # treat an unknown nonzero value as a confirmed Windows/Task Scheduler error.
    $hex = '0x{0:X8}' -f ($number -band [long]0xFFFFFFFF)
    return "Task-specific/unmapped result ($hex)"
}
function Format-TaskInventory([object[]]$Items,[string]$Method) {
    # Normalize information collected through any of the supported methods.
    $rows = @($Items | ForEach-Object {
        $task = $_
        $last = [string]$task.LastRunTime
        $result = [string]$task.LastResult
        $never = $false
        if ([string]::IsNullOrWhiteSpace($last) -or $last -match '^(Unavailable|N/A|Never|11/30/1999|1/1/2000|01/01/2000|12/30/1899)') { $never = $true }
        if (-not $never) {
            $parsed = [datetime]::MinValue
            if ([datetime]::TryParse($last, [ref]$parsed) -and $parsed.Year -lt 2001) { $never = $true }
        }
        $decimalResult = [long]0
        $validResult = [long]::TryParse($result, [ref]$decimalResult)
        $infoCode = $validResult -and $decimalResult -ge 267008 -and $decimalResult -le 267015
        [pscustomobject]@{
            TaskPath = [string]$task.TaskPath
            TaskName = [string]$task.TaskName
            State = [string]$task.State
            LastRunTime = if ($never) { 'Never' } else { $last }
            LastResult = $result
            Meaning = Get-TaskResultExplanation $result $never
            NeverRun = $never
            ReviewResult = (-not $never -and $validResult -and $decimalResult -ne 0 -and -not $infoCode)
        }
    })
    $neverCount = @($rows | Where-Object { $_.NeverRun }).Count
    $reviewItems = @($rows | Where-Object { $_.ReviewResult } | Sort-Object TaskPath,TaskName)
    $nonzero = @($rows | Where-Object { -not $_.NeverRun -and $_.LastResult -ne '0' -and $_.LastResult -ne 'Unavailable' }).Count
    $lines = New-Object System.Collections.Generic.List[string]
    $lines.Add("Method: $Method")
    $lines.Add("Tasks found: $($rows.Count)")
    $lines.Add("Never run / no recorded run: $neverCount (placeholder dates normalized to Never)")
    $lines.Add("Nonzero results on previously run tasks: $nonzero (not all indicate failure)")
    $lines.Add("Results needing review: $($reviewItems.Count) (excludes Windows task scheduler informational 0x413xx codes)")
    if ($reviewItems.Count) {
        $lines.Add('')
        $lines.Add('TASKS WITH RESULTS TO REVIEW:')
        $lines.Add('Explanations describe known codes only; unmapped values require task-specific investigation.')
        $lines.Add((($reviewItems | Select-Object TaskPath,TaskName,State,LastRunTime,LastResult,Meaning | Format-Table -AutoSize -Wrap | Out-String -Width 260).TrimEnd()))
    } else {
        $lines.Add('No previously run tasks with reviewable nonzero results detected.')
    }
    $lines.Add('')
    $lines.Add('ALL SCHEDULED TASKS:')
    $lines.Add('Meaning is descriptive only; successful collection does not guarantee task health.')
    $lines.Add((($rows | Sort-Object TaskPath,TaskName | Select-Object TaskPath,TaskName,State,LastRunTime,LastResult,Meaning | Format-Table -AutoSize -Wrap | Out-String -Width 260).TrimEnd()))
    return ($lines -join "`r`n")
}
function Get-RemoteScheduledTasks([string]$Target) {
    $failures = New-Object System.Collections.Generic.List[string]
    try {
        $rows = @(Invoke-TargetReadOnly $Target {
            if (-not (Get-Command Get-ScheduledTask -ErrorAction SilentlyContinue)) {
                throw 'ScheduledTasks module not available'
            }
            foreach ($task in @(Get-ScheduledTask -ErrorAction Stop)) {
                $info = $null
                try { $info = Get-ScheduledTaskInfo -InputObject $task -ErrorAction Stop } catch { }
                [pscustomobject]@{
                    TaskPath = [string]$task.TaskPath
                    TaskName = [string]$task.TaskName
                    State = [string]$task.State
                    LastRunTime = if ($info) { [string]$info.LastRunTime } else { 'Unavailable' }
                    LastResult = if ($info) { [string]$info.LastTaskResult } else { 'Unavailable' }
                }
            }
        })
        if ($rows.Count) { return (Format-TaskInventory $rows 'Get-ScheduledTask / Get-ScheduledTaskInfo (WinRM)') }
        $failures.Add('PowerShell scheduled task query returned zero rows')
    } catch { $failures.Add("WinRM ScheduledTasks: $($_.Exception.Message)") }
    try {
        $result = Invoke-TargetReadOnly $Target {
            $lines = @(& "$env:windir\System32\schtasks.exe" /Query /FO CSV /V 2>&1)
            [pscustomobject]@{ ExitCode = $LASTEXITCODE; Output = @($lines | ForEach-Object { [string]$_ }) }
        }
        if ($result.ExitCode -eq 0 -and @($result.Output).Count -gt 1) {
            $items = @((@($result.Output) -join "`n") | ConvertFrom-Csv)
            if ($items.Count) {
                $rows = @($items | ForEach-Object {
                    [pscustomobject]@{TaskPath=''; TaskName=[string]$_['TaskName']; State=[string]$_['Status']; LastRunTime=[string]$_['Last Run Time']; LastResult=[string]$_['Last Result']}
                })
                return (Format-TaskInventory $rows 'schtasks (executed remotely through WinRM)')
            }
        }
        $failures.Add("Remote schtasks returned no task records or failed (exit code $($result.ExitCode))")
    } catch { $failures.Add("Remote schtasks (WinRM): $($_.Exception.Message)") }
    try {
        $result = @(& "$env:windir\System32\schtasks.exe" /Query /S $Target /FO CSV /V 2>&1)
        $exit = $LASTEXITCODE
        if ($exit -eq 0 -and $result.Count -gt 1) {
            $items = @(($result -join "`n") | ConvertFrom-Csv)
            if ($items.Count) {
                $rows = @($items | ForEach-Object {
                    [pscustomobject]@{TaskPath=''; TaskName=[string]$_['TaskName']; State=[string]$_['Status']; LastRunTime=[string]$_['Last Run Time']; LastResult=[string]$_['Last Result']}
                })
                return (Format-TaskInventory $rows 'schtasks /S (remote RPC)')
            }
        }
        $failures.Add("Direct schtasks returned no task records or failed (exit code $exit)")
    } catch { $failures.Add("Direct schtasks /S: $($_.Exception.Message)") }
    $details = $failures -join "`r`n"
    $status = if ($details -match '(?i)access is denied|access denied|0x80070005|unauthorized') { 'ACCESS DENIED' } else { 'UNAVAILABLE' }
    return "STATUS: $status - Could not verify scheduled-task inventory. Zero returned rows are not proof that no tasks exist.`r`n$details"
}
function Get-SectionStatus([string]$Section,[string]$Content) {
    if ([string]::IsNullOrWhiteSpace($Content)) { return 'NO RESULTS' }
    # Both the new neutral error heading and older report content indicate
    # collection failure; classify ONLY the actual error message, not the label.
    if ($Content -match '(?i)^(?:Error details:|UNAVAILABLE / ACCESS DENIED / ERROR:)') {
        $actualError = $Content -replace '(?i)^(?:Error details:|UNAVAILABLE / ACCESS DENIED / ERROR:)\s*', ''
        if ($actualError -match '(?i)access is denied|access denied|0x80070005|unauthorized') { return 'ACCESS DENIED' }
        return 'UNAVAILABLE'
    }
    if ($Content -match '(?im)^STATUS:\s*(UNAVAILABLE|ACCESS DENIED|NO RESULTS)') { return $Matches[1].ToUpperInvariant() }
    if ($Section -eq 'Events') {
        if ($Content -match '(?m)^\w+: (UNAVAILABLE|ACCESS DENIED)') { return 'PARTIAL / UNAVAILABLE' }
        if ($Content -match '(?m)^\w+: NO RESULTS' -and $Content -notmatch '(?m)^\w+: SUCCESS') { return 'NO RESULTS' }
    }
    if ($Section -eq 'Health') {
        if ($Content -match '(?i)UNAVAILABLE|UNABLE TO VERIFY|ACCESS DENIED') { return 'PARTIAL / UNAVAILABLE' }
        if ($Content -match '(?i)\(LOW\)|NO PING RESPONSE') { return 'REVIEW' }
    }
    if ($Content -match '(?im)^No (?:fixed disks|local user accounts|local groups|SMB shares|ordinary disk shares|nonrunning automatic-start services)') { return 'NO RESULTS' }
    if ($Section -eq 'Tasks' -and [string]::IsNullOrWhiteSpace($Content.Trim())) { return 'NO RESULTS' }
    if ($Section -eq 'BitLocker' -and $Content -match 'STATUS: NO RESULTS') { return 'NO RESULTS' }
    if ($Section -eq 'Network' -and $Content -match 'IPCONFIG /ALL: UNAVAILABLE') { return 'PARTIAL / UNAVAILABLE' }
    if ($Section -eq 'Updates' -and $Content -match 'Recent update failure events unavailable') { return 'PARTIAL / UNAVAILABLE' }
    if ($Section -eq 'SharePermissions' -and $Content -match 'ACL unavailable') { return 'PARTIAL / UNAVAILABLE' }
    return 'SUCCESS'
}
function Get-ReportHealth([string]$Target) {
    $parts = New-Object System.Collections.Generic.List[string]
    try {
        $ping = Test-Connection -ComputerName $Target -Count 1 -Quiet -ErrorAction Stop
        $parts.Add("Reachability (ICMP): $(if ($ping) {'PASS'} else {'NO PING RESPONSE (not necessarily offline)'})")
    } catch { $parts.Add("Reachability: UNABLE TO VERIFY - $($_.Exception.Message)") }
    # Reevaluate ADMIN$ for the report; cached header status may be stale.
    try { $null = Get-Item -LiteralPath "\\$Target\ADMIN$" -ErrorAction Stop; $parts.Add('ADMIN$ administrative share: ACCESSIBLE') }
    catch { $parts.Add("ADMIN$ administrative share: UNAVAILABLE / DENIED - $($_.Exception.Message)") }
    try {
        $drive = Get-WmiObject Win32_LogicalDisk -ComputerName $Target -Filter "DeviceID='C:'" -ErrorAction Stop
        if ($drive -and $drive.Size) {
            $percent = [math]::Round(100 * $drive.FreeSpace / $drive.Size,1)
            $parts.Add("System drive free space: $percent% $(if ($percent -lt 15) {'(LOW)'} else {'(OK)'})")
        } else { $parts.Add('System drive free space: UNAVAILABLE') }
    } catch { $parts.Add("System drive free space: UNAVAILABLE - $($_.Exception.Message)") }
    try {
        $services = @(Get-WmiObject Win32_Service -ComputerName $Target -ErrorAction Stop | Where-Object { $_.StartMode -eq 'Auto' -and $_.State -ne 'Running' })
        $parts.Add("Automatic services not running: $($services.Count) (review service triggers/intent before treating as failures)")
    } catch { $parts.Add("Services: UNAVAILABLE - $($_.Exception.Message)") }
    $recent = Get-RemoteEventEntries $Target 'System' ((Get-Date).AddDays(-1)) 100
    if ($recent.Status -in @('SUCCESS','NO RESULTS')) { $parts.Add("Recent System critical/errors (24h, up to 100): $(@($recent.Events).Count) [$($recent.Method)]") }
    else { $parts.Add("Event check: $($recent.Status) - $($recent.Detail)") }
    return ($parts -join "`r`n")
}
function Get-RemoteIpConfig([string]$Target) {
    # ipconfig /all must run on the selected remote host, never on the technician workstation.
    try {
        $lines = @(Invoke-TargetReadOnly $Target {
            $output = @(& "$env:windir\System32\ipconfig.exe" /all 2>&1)
            if ($LASTEXITCODE -ne 0) { throw "ipconfig exited with code $LASTEXITCODE" }
            $output | ForEach-Object { [string]$_ }
        })
        if ($lines.Count -gt 0) {
            return "Method: ipconfig /all (remote WinRM)`r`n" + ($lines -join "`r`n")
        }
        throw 'Remote ipconfig returned no output'
    } catch {
        $winrmError = $_.Exception.Message
    }
    # WMI fallback provides a subset of ipconfig /all fields when WinRM is blocked.
    try {
        $adapters = @(Get-WmiObject -Class Win32_NetworkAdapterConfiguration -ComputerName $Target -Filter 'IPEnabled=True' -ErrorAction Stop)
        if ($adapters.Count -gt 0) {
            $formatted = $adapters | Select-Object Description,MACAddress,DHCPEnabled,DHCPServer,IPAddress,IPSubnet,DefaultIPGateway,DNSServerSearchOrder,DNSDomain,DNSHostName | Format-List | Out-String -Width 220
            return "Method: WMI fallback (partial ipconfig /all equivalent)`r`n" + $formatted
        }
        throw 'WMI returned no IP-enabled adapters'
    } catch {
        return "IPCONFIG /ALL: UNAVAILABLE - Remote WinRM failed: $winrmError; WMI fallback failed: $($_.Exception.Message)"
    }
}
function Get-ReportSection([string]$Section,[string]$Target) {
    try {
        switch ($Section) {
            'System' {
                $result = & systeminfo.exe /s $Target 2>&1 | Out-String
                if ($LASTEXITCODE -ne 0) { throw "systeminfo exit code $LASTEXITCODE : $result" }
                return $result
            }
            'Network' {
                $out = New-Object System.Collections.Generic.List[string]
                $out.Add('DNS resolution:')
                $out.Add((Resolve-TargetIPv4 $Target))
                $out.Add("`nPing (4 packets):")
                $out.Add((& ping.exe -n 4 $Target 2>&1 | Out-String))
                $out.Add("`nRoute (no reverse DNS):")
                $out.Add((& tracert.exe -d -w 500 -h 15 $Target 2>&1 | Out-String))
                $out.Add("`nRemote IP configuration (ipconfig /all):")
                $out.Add((Get-RemoteIpConfig $Target))
                return ($out -join "`r`n")
            }
            'Storage' {
                $items = @(Get-WmiObject Win32_LogicalDisk -ComputerName $Target -Filter 'DriveType=3' -ErrorAction Stop |
                    Select-Object DeviceID,VolumeName,@{N='SizeGB';E={[math]::Round($_.Size / 1GB,2)}},@{N='FreeGB';E={[math]::Round($_.FreeSpace / 1GB,2)}},@{N='FreePercent';E={if ($_.Size) {[math]::Round($_.FreeSpace * 100 / $_.Size,1)} else {0}}})
                if ($items.Count -eq 0) { return 'No fixed disks returned.' }
                return ($items | Format-Table -AutoSize | Out-String -Width 180)
            }
            'Services' {
                $all = @(Get-WmiObject Win32_Service -ComputerName $Target -ErrorAction Stop)
                $stopped = @($all | Where-Object { $_.StartMode -eq 'Auto' -and $_.State -ne 'Running' })
                $header = "Services queried: $($all.Count)`r`nAutomatic services not running: $($stopped.Count)`r`n"
                if ($stopped.Count -eq 0) { return ($header + 'No nonrunning automatic-start services found.') }
                return ($header + ($stopped | Select-Object Name,DisplayName,State,StartMode | Format-Table -AutoSize | Out-String -Width 180))
            }
            'Events' {
                $since = (Get-Date).AddDays(-7)
                $parts = @()
                foreach ($logName in @('System','Application')) {
                    $response = Get-RemoteEventEntries $Target $logName $since 25
                    $parts += "${logName}: $($response.Status) - Method: $($response.Method)"
                    if ($response.Detail) { $parts += $response.Detail }
                    if ($response.Status -eq 'SUCCESS') {
                        $parts += (@($response.Events) | Select-Object TimeCreated,Id,ProviderName,LevelDisplayName,@{N='Message';E={ $m = [string]$_.Message -replace '\s+',' '; $m.Substring(0,[Math]::Min(240,$m.Length)) }} | Format-List | Out-String -Width 180)
                    }
                    $parts += ''
                }
                return ($parts -join "`r`n")
            }
            'Users' {
                $accounts = @(Get-WmiObject -Class Win32_UserAccount -ComputerName $Target -Filter 'LocalAccount=True' -ErrorAction Stop | Sort-Object Name)
                if (-not $accounts.Count) { return 'No local user accounts returned. On domain controllers, domain accounts are not enumerated here.' }
                $header = "Local user accounts found: $($accounts.Count)`r`nScope: Local accounts on $Target (not all Active Directory users).`r`n"
                return ($header + ($accounts | Select-Object Name,Domain,Disabled,Lockout,PasswordRequired,SID | Format-Table -AutoSize | Out-String -Width 220))
            }
            'Groups' {
                $groups = @(Get-WmiObject -Class Win32_Group -ComputerName $Target -Filter 'LocalAccount=True' -ErrorAction Stop | Sort-Object Name)
                $memberships = @(Get-WmiObject -Class Win32_GroupUser -ComputerName $Target -ErrorAction Stop)
                $byGroup = @{}
                foreach ($link in $memberships) {
                    $groupName = Format-WmiAccountReference ([string]$link.GroupComponent)
                    $memberName = Format-WmiAccountReference ([string]$link.PartComponent)
                    if (-not $byGroup.ContainsKey($groupName)) { $byGroup[$groupName] = New-Object System.Collections.Generic.List[string] }
                    $byGroup[$groupName].Add($memberName)
                }
                $result = New-Object System.Collections.Generic.List[string]
                $result.Add("Local groups found: $($groups.Count)")
                $result.Add('Memberships are direct members only; nested domain groups are not expanded.')
                $result.Add('')
                foreach ($group in $groups) {
                    $key = "$($group.Domain)\$($group.Name)"
                    $result.Add("GROUP: $key")
                    if ($group.Description) { $result.Add("Description: $($group.Description)") }
                    if ($byGroup.ContainsKey($key)) {
                        foreach ($member in @($byGroup[$key] | Sort-Object -Unique)) { $result.Add("  - $member") }
                    } else { $result.Add('  (no direct members returned)') }
                    $result.Add('')
                }
                if (-not $groups.Count) { $result.Add('No local groups returned. Domain controllers do not have ordinary local groups.') }
                return ($result -join "`r`n")
            }
            'Shares' {
                $shares = @(Get-WmiObject -Class Win32_Share -ComputerName $Target -ErrorAction Stop | Sort-Object Name)
                if (-not $shares.Count) { return 'No SMB shares returned.' }
                $header = "Shares found: $($shares.Count)`r`nIncludes hidden/administrative shares where visible. This report does not audit share or NTFS permissions.`r`n"
                return ($header + ($shares | Select-Object Name,Path,Description,Type,Status | Format-Table -AutoSize | Out-String -Width 220))
            }
            'Health' { return (Get-ReportHealth $Target) }
            'Hardware' {
                $cs = Get-WmiObject Win32_ComputerSystem -ComputerName $Target -ErrorAction Stop
                $bios = Get-WmiObject Win32_BIOS -ComputerName $Target -ErrorAction Stop
                $cpu = @(Get-WmiObject Win32_Processor -ComputerName $Target -ErrorAction Stop)
                $disks = @(Get-WmiObject Win32_DiskDrive -ComputerName $Target -ErrorAction Stop)
                $obj = [pscustomobject]@{ Manufacturer=$cs.Manufacturer; Model=$cs.Model; RAM_GB=[math]::Round($cs.TotalPhysicalMemory/1GB,2); BIOSSerial=$bios.SerialNumber; BIOSVersion=($bios.SMBIOSBIOSVersion -join ', '); CPU=($cpu.Name -join ' / ') }
                return (($obj | Format-List | Out-String) + "`r`nDISKS:`r`n" + ($disks | Select-Object Model,SerialNumber,@{N='SizeGB';E={[math]::Round($_.Size/1GB,2)}} | Format-Table -AutoSize | Out-String -Width 180))
            }
            'Software' {
                $paths = @('SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall','SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall')
                $hive = [uint32]2147483650 # HKLM
                $reg = [WMIClass]"\\$Target\root\default:StdRegProv"
                $items = New-Object System.Collections.Generic.List[object]
                foreach ($path in $paths) {
                    $keys = $reg.EnumKey($hive,$path)
                    foreach ($sub in @($keys.sNames)) {
                        if (-not $sub) { continue }
                        $key = "$path\$sub"
                        $name = $reg.GetStringValue($hive,$key,'DisplayName').sValue
                        if (-not $name) { continue }
                        $version = $reg.GetStringValue($hive,$key,'DisplayVersion').sValue
                        $publisher = $reg.GetStringValue($hive,$key,'Publisher').sValue
                        $items.Add([pscustomobject]@{Name=$name;Version=$version;Publisher=$publisher})
                    }
                }
                return ("Registry uninstall entries: $($items.Count) (does not enumerate every portable/Store app)`r`n" + ($items | Sort-Object Name,Version -Unique | Format-Table -AutoSize | Out-String -Width 220))
            }
            'Updates' {
                $items = @(Get-WmiObject Win32_QuickFixEngineering -ComputerName $Target -ErrorAction Stop | Sort-Object InstalledOn -Descending)
                $detail = ($items | Select-Object HotFixID,Description,InstalledOn,InstalledBy | Format-Table -AutoSize | Out-String -Width 200)
                try {
                    $failure = Invoke-TargetReadOnly $Target { Get-WinEvent -FilterHashtable @{LogName='System';ProviderName='Microsoft-Windows-WindowsUpdateClient';Id=20;StartTime=(Get-Date).AddDays(-30)} -MaxEvents 20 -ErrorAction SilentlyContinue | Select-Object TimeCreated,Id,Message | Format-List | Out-String }
                } catch { $failure = "Recent update failure events unavailable (WinRM may be disabled): $($_.Exception.Message)" }
                return "Installed hotfix records: $($items.Count)`r`n$detail`r`nRecent Windows Update error events (30 days):`r`n$failure"
            }
            'Tasks' { return (Get-RemoteScheduledTasks $Target) }
            'Administrators' {
                $links = @(Get-WmiObject Win32_GroupUser -ComputerName $Target -ErrorAction Stop)
                $localGroup = @(Get-WmiObject Win32_Group -ComputerName $Target -Filter 'LocalAccount=True' -ErrorAction Stop | Where-Object { $_.SID -eq 'S-1-5-32-544' } | Select-Object -First 1)
                if (-not $localGroup.Count) { return 'No local Administrators group found (domain controller or unavailable).' }
                $groupKey = "$($localGroup[0].Domain)\$($localGroup[0].Name)"
                $members = @($links | Where-Object { (Format-WmiAccountReference ([string]$_.GroupComponent)) -eq $groupKey } | ForEach-Object { Format-WmiAccountReference ([string]$_.PartComponent) } | Sort-Object -Unique)
                return ("Direct members of ${groupKey} (nested domain groups not expanded):`r`n" + ($members -join "`r`n"))
            }
            'Sessions' {
                $output = & quser.exe /server:$Target 2>&1
                if ($LASTEXITCODE -ne 0) { throw "quser exit code $LASTEXITCODE : $($output -join ' ')" }
                return ($output -join "`r`n")
            }
            'SharePermissions' {
                $shares = @(Get-WmiObject Win32_Share -ComputerName $Target -ErrorAction Stop | Where-Object { $_.Type -eq 0 })
                if (-not $shares.Count) { return 'No ordinary disk shares returned.' }
                $out = New-Object System.Collections.Generic.List[string]
                foreach ($sh in $shares) {
                    $out.Add("SHARE: $($sh.Name) => $($sh.Path)")
                    try {
                        $acl = Invoke-TargetReadOnly $Target { param($shareName,$folder) $share = Get-SmbShareAccess -Name $shareName -ErrorAction Stop | Select-Object AccountName,AccessControlType,AccessRight; $ntfs = Get-Acl -LiteralPath $folder -ErrorAction Stop; [pscustomobject]@{Share=($share | Format-Table -AutoSize | Out-String);NTFS=($ntfs.Access | Select-Object IdentityReference,FileSystemRights,AccessControlType,IsInherited | Format-Table -AutoSize | Out-String)} } -ArgumentList $sh.Name,$sh.Path
                        $out.Add("SHARE ACL:`r`n$($acl.Share)")
                        $out.Add("NTFS ACL (share root only):`r`n$($acl.NTFS)")
                    } catch { $out.Add("ACL unavailable (WinRM/permissions required): $($_.Exception.Message)") }
                }
                return ($out -join "`r`n")
            }
            'Firewall' {
                return (Invoke-TargetReadOnly $Target { "FIREWALL PROFILES:"; Get-NetFirewallProfile | Select-Object Name,Enabled,DefaultInboundAction,DefaultOutboundAction | Format-Table -AutoSize | Out-String; "ENABLED RULES (first 200):"; Get-NetFirewallRule -Enabled True | Select-Object -First 200 DisplayName,Direction,Action,Profile | Format-Table -AutoSize | Out-String } | Out-String -Width 200)
            }
            'BitLocker' { return (Get-RemoteBitLocker $Target) }
            'Startup' {
                $items = @(Get-WmiObject Win32_StartupCommand -ComputerName $Target -ErrorAction Stop)
                return ("Startup entries: $($items.Count)`r`n" + ($items | Select-Object Name,Location,User,Command | Format-List | Out-String -Width 220))
            }
            'Policy' {
                $result = & gpresult.exe /S $Target /SCOPE COMPUTER /R 2>&1 | Out-String
                if ($LASTEXITCODE -ne 0) { throw "gpresult exit code $LASTEXITCODE : $result" }
                return $result
            }
        }
    } catch { return "Error details: $($_.Exception.Message)" }
}
