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
    foreach ($extra in @('SystemUptime','FirewallProfiles','InstalledHotfixes')) {
        $match = @($Result.Data | Where-Object { $_ -and [string]$_.Check -eq $extra } | Select-Object -First 1)
        if (-not $match.Count -or [string]$match[0].QueryStatus -ne 'Available') {
            $unavailable++
            $reason = if ($match.Count -and $match[0].Error) { [string]$match[0].Error } else { 'No verified evidence returned.' }
            $findings.Add([pscustomobject]@{Check=$extra;Level='Unavailable';Evidence=$reason;NextStep='Review permissions and the corresponding diagnostic collector.'})
            continue
        }
        $record=$match[0]
        $available++
        switch ($extra) {
            'SystemUptime' {
                $findings.Add([pscustomobject]@{Check=$extra;Level='Observed';Evidence=("{0}; uptime {1} days." -f $record.Caption,$record.UptimeDays);NextStep='Review reboot requirements only alongside actual update or operational evidence.'})
            }
            'FirewallProfiles' {
                if ([int]$record.DisabledCount -gt 0) {
                    $review++
                    $findings.Add([pscustomobject]@{Check=$extra;Level='Review';Evidence=("Disabled Windows Firewall profiles: {0}." -f $record.DisabledProfiles);NextStep='Confirm effective policy and intended network security controls before changing settings.'})
                } else {
                    $findings.Add([pscustomobject]@{Check=$extra;Level='Observed';Evidence=("{0} queried Windows Firewall profiles are enabled." -f $record.ProfilesQueried);NextStep='Enabled profiles alone do not prove a secure firewall ruleset.'})
                }
            }
            'InstalledHotfixes' {
                $findings.Add([pscustomobject]@{Check=$extra;Level='Observed';Evidence=("{0} installed QFE entries returned; missing-update status not assessed." -f $record.HotfixCount);NextStep='Use an approved update compliance source to determine missing or overdue updates.'})
            }
        }
    }
    return [pscustomobject]@{
        Target = [string]$Result.Target
        Mode = 'Local'
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
    $lines.Add(("EVIDENCE-BASED HEALTH ANALYSIS ({0})" -f $Analysis.Mode))
    $lines.Add(("Review: {0} | Available: {1} | Unavailable: {2}" -f $Analysis.ReviewCount,$Analysis.AvailableCount,$Analysis.UnavailableCount))
    $lines.Add('Review findings are investigation prompts, not confirmed faults. No overall health score is assigned.')
    foreach ($finding in @($Analysis.Findings)) {
        $lines.Add(("[{0}] {1}: {2}" -f $finding.Level,$finding.Check,$finding.Evidence))
        $lines.Add(('  Next: ' + [string]$finding.NextStep))
    }
    return ($lines -join "`r`n")
}

# Remote Health adapter has different evidence names and explicit source/credential scope.
# This formatter reuses the same review/available/unavailable presentation while
# refusing to interpret transport errors, NOT TESTED checks, or missing rows as normal.
function Get-ToolkitRemoteHealthAnalysis {
    [CmdletBinding()]
    param([Parameter(Mandatory=$true)][object]$Result)
    if ([string]$Result.Section -ne 'Health' -or [string]$Result.Mode -notin @('Default','Alternate')) {
        throw 'Remote Health analysis requires a structured remote Health result.'
    }
    $findings = New-Object System.Collections.Generic.List[object]
    $review = 0; $available = 0; $unavailable = 0
    $mapping = @(
        @{Check='SystemDrive';Source='System drive free space';Label='Storage'},
        @{Check='AutomaticServices';Source='Automatic services not running';Label='Services'},
        @{Check='RecentSystemEvents';Source='System critical/error events (24h, max 100)';Label='Events'}
    )
    foreach ($check in $mapping) {
        $row = @($Result.Data | Where-Object { $_ -and [string]$_.Check -eq $check.Source } | Select-Object -First 1)
        if ($row.Count -eq 0 -or [string]$row[0].Status -notin @('SUCCESS','REVIEW','NO RESULTS')) {
            $unavailable++
            $reason = if ($row.Count -gt 0) { [string]$row[0].Value } elseif ($Result.Error) { [string]$Result.Error } else { 'No verified remote data returned.' }
            $findings.Add([pscustomobject]@{Check=$check.Check;Level='Unavailable';Evidence=$reason;NextStep='Verify authorized remote WinRM access and collector permissions.'})
            continue
        }
        $value = [string]$row[0].Value
        switch ($check.Check) {
            'SystemDrive' {
                $percent = 0.0
                if ($value -notmatch '^([0-9]+(?:\.[0-9]+)?)%$' -or
                    -not [double]::TryParse($Matches[1],[Globalization.NumberStyles]::Float,
                        [Globalization.CultureInfo]::InvariantCulture,[ref]$percent) -or
                    $percent -gt 100) {
                    $unavailable++
                    $findings.Add([pscustomobject]@{Check=$check.Check;Level='Unavailable';Evidence='Remote system-drive percentage could not be verified.';NextStep='Inspect remote drive capacity query.'})
                    continue
                }
                $available++
                $level = if ($percent -lt 15) { 'Review' } else { 'Observed' }
                if ($level -eq 'Review') { $review++ }
                $findings.Add([pscustomobject]@{Check=$check.Check;Level=$level;Evidence=("Remote C: has {0}% free (review threshold: below 15%)." -f $percent);NextStep='Check available capacity and growth; no cleanup is performed.'})
            }
            'AutomaticServices' {
                $count = 0
                if (-not [int]::TryParse($value,[ref]$count) -or $count -lt 0) {
                    $unavailable++
                    $findings.Add([pscustomobject]@{Check=$check.Check;Level='Unavailable';Evidence='Remote automatic-service count is not numeric.';NextStep='Inspect service inventory.'})
                    continue
                }
                $available++
                $level = if ($count -gt 0) { 'Review' } else { 'Observed' }
                if ($level -eq 'Review') { $review++ }
                $findings.Add([pscustomobject]@{Check=$check.Check;Level=$level;Evidence=("$count remote automatic-start services not running.");NextStep='Inspect service details before determining whether stops are expected.'})
            }
            'RecentSystemEvents' {
                $count = 0
                if (-not [int]::TryParse($value,[ref]$count) -or $count -lt 0 -or $count -gt 100) {
                    $unavailable++
                    $findings.Add([pscustomobject]@{Check=$check.Check;Level='Unavailable';Evidence='Remote event count is not a valid bounded value.';NextStep='Inspect remote event collection.'})
                    continue
                }
                $available++
                $level = if ($count -gt 0) { 'Review' } else { 'Observed' }
                if ($level -eq 'Review') { $review++ }
                $findings.Add([pscustomobject]@{Check=$check.Check;Level=$level;Evidence=("$count remote critical/error System events within 24h (max 100 sampled).");NextStep='Review event sources, IDs and recurrence before assigning severity.'})
            }
        }
    }
    foreach ($extra in @(
        @{Check='SystemUptime';Source='System uptime (days)'},
        @{Check='FirewallProfiles';Source='Disabled firewall profiles'},
        @{Check='InstalledHotfixes';Source='Installed QFE count'}
    )) {
        $match=@($Result.Data | Where-Object { $_ -and [string]$_.Check -eq $extra.Source } | Select-Object -First 1)
        if (-not $match.Count -or [string]$match[0].Status -ne 'SUCCESS') {
            $unavailable++
            $reason=if ($match.Count) {[string]$match[0].Value} else {'No verified remote evidence returned.'}
            $findings.Add([pscustomobject]@{Check=$extra.Check;Level='Unavailable';Evidence=$reason;NextStep='Inspect remote WinRM access and collector permissions.'})
            continue
        }
        $value=[string]$match[0].Value
        switch ($extra.Check) {
            'SystemUptime' {
                $days=0.0
                if (-not [double]::TryParse($value,[Globalization.NumberStyles]::Float,[Globalization.CultureInfo]::InvariantCulture,[ref]$days) -or $days -lt 0) {
                    $unavailable++
                    $findings.Add([pscustomobject]@{Check=$extra.Check;Level='Unavailable';Evidence='Uptime value could not be validated.';NextStep='Inspect remote operating system evidence.'})
                    continue
                }
                $available++
                $findings.Add([pscustomobject]@{Check=$extra.Check;Level='Observed';Evidence=("Remote uptime: {0} days." -f $days);NextStep='Evaluate reboot needs alongside patch and operational policies.'})
            }
            'FirewallProfiles' {
                if (-not $match[0].PSObject.Properties['DisabledCount'] -or
                    -not $match[0].PSObject.Properties['ProfilesQueried']) {
                    $unavailable++
                    $findings.Add([pscustomobject]@{Check=$extra.Check;Level='Unavailable';Evidence='Firewall profile counts are missing.';NextStep='Inspect remote firewall profile data.'})
                    continue
                }
                $available++
                if ([int]$match[0].DisabledCount -gt 0) {
                    $review++
                    $findings.Add([pscustomobject]@{Check=$extra.Check;Level='Review';Evidence=("Disabled Windows Firewall profiles: {0}." -f $value);NextStep='Confirm effective policy and approved security configuration.'})
                } else {
                    $findings.Add([pscustomobject]@{Check=$extra.Check;Level='Observed';Evidence=("{0} queried remote firewall profiles enabled." -f $match[0].ProfilesQueried);NextStep='Firewall profile state does not establish security compliance.'})
                }
            }
            'InstalledHotfixes' {
                $count=0
                if (-not [int]::TryParse($value,[ref]$count) -or $count -lt 0) {
                    $unavailable++
                    $findings.Add([pscustomobject]@{Check=$extra.Check;Level='Unavailable';Evidence='Installed QFE count is invalid.';NextStep='Inspect remote hotfix query.'})
                    continue
                }
                $available++
                $findings.Add([pscustomobject]@{Check=$extra.Check;Level='Observed';Evidence=("$count installed QFE entries returned; missing updates not assessed.");NextStep='Use an approved patch compliance source for missing updates.'})
            }
        }
    }
    return [pscustomobject]@{
        Target=[string]$Result.Target
        Mode=[string]$Result.Mode
        CollectionIdentity=[string]$Result.UserName
        CollectedAt=$Result.CollectedAt
        ReviewCount=$review
        AvailableCount=$available
        UnavailableCount=$unavailable
        Findings=@($findings.ToArray())
    }
}
