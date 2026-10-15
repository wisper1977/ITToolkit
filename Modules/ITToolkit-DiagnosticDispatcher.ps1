# IT Toolkit v1.26 Phase 4A - shared diagnostic dispatcher (integration test only).
# Requires Phase 3A WMI, 3B WinRM, 3D Mixed and Phase 1 Authentication modules.
# Do not serialize the authentication context: it contains a live PSCredential.

# Classification supplements the original adapter status; it never replaces raw details.
# NO RESULTS is not success, and PARTIAL / UNAVAILABLE is not a complete failure.
function Get-ToolkitDiagnosticStatusCategory {
    [CmdletBinding()]
    param([AllowEmptyString()][string]$Status)
    switch ($Status.Trim().ToUpperInvariant()) {
        'SUCCESS'               { return 'Success' }
        'NO RESULTS'            { return 'NoData' }
        'REVIEW'                { return 'Review' }
        'PARTIAL'               { return 'Partial' }
        'PARTIAL / UNAVAILABLE' { return 'Partial' }
        'UNAVAILABLE'           { return 'Unavailable' }
        'NOT TESTED'            { return 'NotTested' }
        'NOT INTEGRATED'        { return 'NotTested' }
        default                 { return 'Unknown' }
    }
}

function Get-ToolkitDiagnosticMap {
    [CmdletBinding()]
    param()
    @(
        [pscustomobject]@{ Section='System'; Adapter='Mixed'; AdapterSection='SystemInfo'; Note='Remote systeminfo on target' }
        [pscustomobject]@{ Section='Network'; Adapter='Composite'; AdapterSection='Network'; Note='Original DNS, ping, trace route, remote IP config composite must be preserved' }
        [pscustomobject]@{ Section='Storage'; Adapter='WMI'; AdapterSection='Storage'; Note='' }
        [pscustomobject]@{ Section='Services'; Adapter='Detail'; AdapterSection='Services'; Note='Phase 3A returns non-running automatic services; original report may include counts' }
        [pscustomobject]@{ Section='Events'; Adapter='Detail'; AdapterSection='Events'; Note='Phase 3D covers System log errors; original may have broader scopes' }
        [pscustomobject]@{ Section='Users'; Adapter='WMI'; AdapterSection='Users'; Note='' }
        [pscustomobject]@{ Section='Groups'; Adapter='Detail'; AdapterSection='Groups'; Note='Original membership detail needs parity review' }
        [pscustomobject]@{ Section='Shares'; Adapter='WMI'; AdapterSection='Shares'; Note='WMI inventory is not an authenticated SMB share access test' }
        [pscustomobject]@{ Section='Health'; Adapter='Composite'; AdapterSection='Health'; Note='Composite diagnostic requires parity implementation' }
        [pscustomobject]@{ Section='Hardware'; Adapter='WMI'; AdapterSection='Hardware'; Note='' }
        [pscustomobject]@{ Section='Software'; Adapter='Mixed'; AdapterSection='RegistrySoftware'; Note='Installed software registry inventory' }
        [pscustomobject]@{ Section='Updates'; Adapter='WMI'; AdapterSection='Updates'; Note='' }
        [pscustomobject]@{ Section='Tasks'; Adapter='Detail'; AdapterSection='Tasks'; Note='Scheduled tasks basic inventory; original details require parity review' }
        [pscustomobject]@{ Section='Administrators'; Adapter='WinRM'; AdapterSection='Administrators'; Note='' }
        [pscustomobject]@{ Section='Sessions'; Adapter='Mixed'; AdapterSection='Sessions'; Note='' }
        [pscustomobject]@{ Section='SharePermissions'; Adapter='Composite'; AdapterSection='SharePermissions'; Note='Original permission enumeration requires explicit target identity handling' }
        [pscustomobject]@{ Section='Firewall'; Adapter='Detail'; AdapterSection='Firewall'; Note='' }
        [pscustomobject]@{ Section='BitLocker'; Adapter='Detail'; AdapterSection='BitLocker'; Note='Module unavailable on some targets; fallback not yet built' }
        [pscustomobject]@{ Section='Startup'; Adapter='WMI'; AdapterSection='Startup'; Note='' }
        [pscustomobject]@{ Section='Policy'; Adapter='Detail'; AdapterSection='Policy'; Note='Computer scope only' }
    )
}

function Invoke-ToolkitDiagnostic {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][ValidateNotNull()]$Context,
        [Parameter(Mandatory=$true)][ValidateNotNullOrEmpty()][string]$Section
    )
    if ($Context.PSTypeNames -notcontains 'ITToolkit.AuthenticationContext') { throw 'Invalid toolkit authentication context.' }
    if ($Context.Mode -notin @('Default','Alternate')) { throw 'Invalid toolkit authentication mode.' }
    if ($Context.Mode -eq 'Alternate' -and $null -eq $Context.Credential) { throw 'Alternate credential required; default fallback forbidden.' }
    $entry = @(Get-ToolkitDiagnosticMap | Where-Object { $_.Section -eq $Section })
    if ($entry.Count -ne 1) { throw "Unknown diagnostic section: $Section" }
    $m = $entry[0]
    if ($m.Adapter -eq 'Pending') {
        return [pscustomobject]@{ Target=[string]$Context.ComputerName; Mode=[string]$Context.Mode; UserName=[string]$Context.UserName; Section=$Section; CollectedAt=Get-Date; Status='NOT INTEGRATED'; StatusCategory='NotTested'; Data=@(); Error=$m.Note; Adapter=$m.Adapter; AdapterSection=$m.AdapterSection }
    }
    try {
        switch ($m.Adapter) {
            'WMI'   { $r = Get-ToolkitWmiDiagnostic -Context $Context -Section $m.AdapterSection }
            'WinRM' { $r = Get-ToolkitWinRMDiagnostic -Context $Context -Section $m.AdapterSection }
            'Mixed' { $r = Get-ToolkitMixedDiagnostic -Context $Context -Section $m.AdapterSection }
            'Composite' { $r = Get-ToolkitCompositeDiagnostic -Context $Context -Section $m.AdapterSection }
            'Detail' { $r = Get-ToolkitDetailDiagnostic -Context $Context -Section $m.AdapterSection }
            default { throw "Unknown adapter: $($m.Adapter)" }
        }
        # Return a sanitized, consistent result. Never return Credential or Context.
        [pscustomobject]@{
            Target=[string]$Context.ComputerName
            Mode=[string]$Context.Mode
            UserName=[string]$Context.UserName
            Section=$Section
            CollectedAt=$r.CollectedAt
            Status=[string]$r.Status
            StatusCategory=(Get-ToolkitDiagnosticStatusCategory -Status ([string]$r.Status))
            Data=@($r.Data)
            Error=[string]$r.Error
            Adapter=[string]$m.Adapter
            AdapterSection=[string]$m.AdapterSection
        }
    } catch {
        [pscustomobject]@{ Target=[string]$Context.ComputerName; Mode=[string]$Context.Mode; UserName=[string]$Context.UserName; Section=$Section; CollectedAt=Get-Date; Status='UNAVAILABLE'; StatusCategory='Unavailable'; Data=@(); Error=[string]$_.Exception.Message; Adapter=[string]$m.Adapter; AdapterSection=[string]$m.AdapterSection }
    }
}
