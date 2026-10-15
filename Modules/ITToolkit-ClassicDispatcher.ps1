# v1.26 Phase 5A - Classic reporting bridge. Windows PowerShell 5.1.
# No implicit identity fallback and no credentials in report objects.
function Test-ClassicAlternateReportContext {
    if ($script:ToolkitAuthMode -ne 'Alternate') { return $false }
    $ctx = $script:ToolkitAuthContext
    if ($null -eq $ctx -or $ctx.PSTypeNames -notcontains 'ITToolkit.AuthenticationContext' -or
        $ctx.Mode -ne 'Alternate' -or $null -eq $ctx.Credential -or
        [string]::IsNullOrWhiteSpace($script:TargetComputer) -or
        $ctx.ComputerName -ine $script:TargetComputer) {
        throw 'Alternate authentication context missing or target changed. Re-select Target Credentials (option 12).'
    }
    return $true
}
function Convert-ClassicDiagnosticValue {
    param($Value,[int]$Depth=0)
    if ($null -eq $Value) { return '' }
    if ($Depth -ge 4) { return '[nested value]' }
    if ($Value -is [string] -or $Value -is [ValueType]) { return [string]$Value }
    if ($Value -is [System.Collections.IDictionary]) {
        return (($Value.Keys | ForEach-Object { '{0}: {1}' -f $_,(Convert-ClassicDiagnosticValue $Value[$_] ($Depth+1)) }) -join '; ')
    }
    if ($Value -is [System.Collections.IEnumerable]) {
        return ((@($Value | ForEach-Object { Convert-ClassicDiagnosticValue $_ ($Depth+1) })) -join '; ')
    }
    return (($Value.PSObject.Properties | Where-Object { $_.Name -notin @('PSComputerName','RunspaceId','PSShowComputerName') } | ForEach-Object {
        '{0}: {1}' -f $_.Name,(Convert-ClassicDiagnosticValue $_.Value ($Depth+1))
    }) -join '; ')
}
function Convert-ClassicDispatcherResult {
    param([Parameter(Mandatory=$true)]$Result)
    $lines = New-Object System.Collections.Generic.List[string]
    $lines.Add(('Section: {0}' -f $Result.Section))
    $lines.Add(('Status: {0}' -f $Result.Status))
    if ($Result.PSObject.Properties['StatusCategory']) {
        $lines.Add(('Status category: {0}' -f $Result.StatusCategory))
    }
    $lines.Add(('Adapter: {0}' -f $Result.Adapter))
    $lines.Add(('Remote query identity: {0}' -f $Result.UserName))
    if (-not [string]::IsNullOrWhiteSpace([string]$Result.Error)) {
        $lines.Add(('Detail: {0}' -f $Result.Error))
    }
    $rows = @($Result.Data | Where-Object { $null -ne $_ })
    $lines.Add(('Records: {0}' -f $rows.Count))
    if ($rows.Count -eq 0) { $lines.Add('No records returned (not proof of a healthy state).') }
    $index = 0
    foreach ($item in $rows) {
        $index++
        $lines.Add('')
        # Prefer useful headings over a wall of anonymous Record N labels.
        $heading = ''
        switch ([string]$Result.Section) {
            'Services' {
                if ([string]$item.RecordType -eq 'Summary') { $heading='Service summary' }
                elseif ($item.Name) { $heading = 'Stopped automatic service: ' + [string]$item.Name }
            }
            'Tasks' { if ($item.TaskName) { $heading = 'Task: ' + [string]$item.TaskPath + [string]$item.TaskName } }
            'Events' { if ($item.LogName) { $heading = '{0} event {1}' -f $item.LogName,$item.Id } }
            'Groups' {
                if ([string]$item.RecordType -eq 'DirectMember') { $heading = 'Member: '+[string]$item.Member }
                elseif ($item.Group) { $heading='Group: '+[string]$item.Group }
            }
            'Firewall' { if ($item.DisplayName) { $heading='Rule: '+[string]$item.DisplayName } elseif($item.Name) {$heading='Firewall: '+[string]$item.Name} }
            'SharePermissions' { if ($item.Share) { $heading='Share: '+[string]$item.Share } }
            'Health' { if ($item.Check) { $heading='Check: '+[string]$item.Check } }
            'Network' { if ($item.Check) { $heading='Check: '+[string]$item.Check } }
        }
        if (-not $heading) { $heading = 'Record {0}' -f $index }
        $lines.Add($heading)
        foreach ($property in $item.PSObject.Properties) {
            if ($property.Name -in @('PSComputerName','RunspaceId','PSShowComputerName')) { continue }
            if ($property.Name -eq 'RecordType') { continue }
            if ($property.Name -eq 'Error' -and [string]::IsNullOrWhiteSpace([string]$property.Value)) { continue }
            if ($null -eq $property.Value) { continue }
            $value = Convert-ClassicDiagnosticValue $property.Value
            if ([string]::IsNullOrWhiteSpace([string]$value)) { continue }
            # Label-only headings are not repeated as a redundant property.
            if ($property.Name -eq 'Name' -and $heading -eq ('Stopped automatic service: '+$value)) { continue }
            if ($property.Name -eq 'Check' -and $heading -eq ('Check: '+$value)) { continue }
            $lines.Add(('{0}: {1}' -f $property.Name,$value))
        }
    }
    return ($lines -join "`r`n")
}
function Get-ClassicAlternateReportSection {
    param([Parameter(Mandatory=$true)][string]$Section)
    $null = Test-ClassicAlternateReportContext
    $result = Invoke-ToolkitDiagnostic -Context $script:ToolkitAuthContext -Section $Section
    $text = Convert-ClassicDispatcherResult $result
    if ($Section -eq 'Health') {
        $text += "`r`n`r`n" + (Format-ToolkitHealthAnalysis -Analysis (Get-ToolkitRemoteHealthAnalysis -Result $result))
    }
    return [pscustomobject]@{Section=$Section;Status=[string]$result.Status;StatusCategory=[string]$result.StatusCategory;Content=$text}
}
