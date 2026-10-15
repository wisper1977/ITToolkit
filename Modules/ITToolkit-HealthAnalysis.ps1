# IT Toolkit v1.27 - shared evidence-based, read-only local health interpretation.
# No arbitrary health score; unavailable evidence is never treated as passing.
function Get-ToolkitLocalHealthAnalysis {
    [CmdletBinding()]
    param([Parameter(Mandatory=$true)][object]$Result)
    if ([string]$Result.Section -ne 'Health' -or [string]$Result.Mode -ne 'Local') {
        throw 'Health analysis requires a structured local Health diagnostic result.'
    }
    $findings = New-Object System.Collections.Generic.List[object]
    $available = 0
    $unavailable = 0
    $review = 0
    foreach ($name in @('SystemDrive','AutomaticServices','RecentSystemEvents')) {
        $item = @($Result.Data | Where-Object { $_ -and [string]$_.Check -eq $name } | Select-Object -First 1)
        if ($item.Count -eq 0 -or [string]$item[0].QueryStatus -notin @('Available','NoData')) {
            $unavailable++
            $detail = if ($item.Count -and $item[0].Error) { [string]$item[0].Error } else { 'No reliable evidence returned.' }
            $findings.Add([pscustomobject]@{ Check=$name; Level='Unavailable'; Evidence=$detail; NextStep='Review collector permissions and retry this check.' })
            continue
        }
        $record = $item[0]
        $available++
        switch ($name) {
            'SystemDrive' {
                if ($null -eq $record.FreePercent) {
                    $available--; $unavailable++
                    $findings.Add([pscustomobject]@{Check=$name;Level='Unavailable';Evidence='Drive free percentage is missing.';NextStep='Verify local disk size and free-space inventory.'})
                } elseif ([double]$record.FreePercent -lt 10) {
                    $review++
                    $findings.Add([pscustomobject]@{Check=$name;Level='Review';Evidence=("System drive {0} has {1}% free ({2} GB)." -f $record.Drive,$record.FreePercent,$record.FreeGB);NextStep='Review disk growth, retention, and capacity before taking any cleanup action.'})
                } else {
                    $findings.Add([pscustomobject]@{Check=$name;Level='Observed';Evidence=("System drive {0} has {1}% free ({2} GB)." -f $record.Drive,$record.FreePercent,$record.FreeGB);NextStep='No threshold finding from this check; monitor capacity trends.'})
                }
            }
            'AutomaticServices' {
                if ($null -eq $record.AutomaticNotRunning) {
                    $available--; $unavailable++
                    $findings.Add([pscustomobject]@{Check=$name;Level='Unavailable';Evidence='Service counts missing.';NextStep='Inspect the services collector.'})
                } elseif ([int]$record.AutomaticNotRunning -gt 0) {
                    $review++
                    $findings.Add([pscustomobject]@{Check=$name;Level='Review';Evidence=("{0} automatic-start services are not currently running, among {1} queried." -f $record.AutomaticNotRunning,$record.ServicesQueried);NextStep='Inspect individual services; trigger-start or intentional stops may be normal.'})
                } else {
                    $findings.Add([pscustomobject]@{Check=$name;Level='Observed';Evidence=("No non-running automatic-start services found in {0} queried." -f $record.ServicesQueried);NextStep='This does not establish service health.'})
                }
            }
            'RecentSystemEvents' {
                if ($null -eq $record.CriticalOrErrorCount) {
                    $available--; $unavailable++
                    $findings.Add([pscustomobject]@{Check=$name;Level='Unavailable';Evidence='Event count missing.';NextStep='Review System event-log access.'})
                } elseif ([int]$record.CriticalOrErrorCount -gt 0) {
                    $review++
                    $findings.Add([pscustomobject]@{Check=$name;Level='Review';Evidence=("{0} critical/error System events returned within 24 hours (maximum sample 100)." -f $record.CriticalOrErrorCount);NextStep='Review event IDs, sources and recurrence; event count alone does not establish severity.'})
                } else {
                    $findings.Add([pscustomobject]@{Check=$name;Level='Observed';Evidence='No matching System critical/error events returned for the last 24 hours.';NextStep='No matching events is not proof the system is healthy.'})
                }
            }
        }
    }
    return [pscustomobject]@{
        Target = [string]$Result.Target
        CollectionIdentity = [string]$Result.UserName
        CollectedAt = $Result.CollectedAt
        ReviewCount = $review
        AvailableCount = $available
        UnavailableCount = $unavailable
        Findings = @($findings.ToArray())
    }
}
function Format-ToolkitHealthAnalysis {
    [CmdletBinding()]
    param([Parameter(Mandatory=$true)][object]$Analysis)
    $lines = New-Object System.Collections.Generic.List[string]
    $lines.Add('EVIDENCE-BASED HEALTH ANALYSIS (LOCAL)')
    $lines.Add(("Review: {0} | Available: {1} | Unavailable: {2}" -f $Analysis.ReviewCount,$Analysis.AvailableCount,$Analysis.UnavailableCount))
    $lines.Add('Review findings are investigation prompts, not confirmed faults. No overall health score is assigned.')
    foreach ($finding in @($Analysis.Findings)) {
        $lines.Add(("[{0}] {1}: {2}" -f $finding.Level,$finding.Check,$finding.Evidence))
        $lines.Add(('  Next: ' + [string]$finding.NextStep))
    }
    return ($lines -join "`r`n")
}
