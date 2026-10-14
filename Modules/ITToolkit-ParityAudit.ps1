# Non-mutating parity audit: flags known gaps against v1.25.7 report semantics.
function Test-ToolkitDiagnosticParity {
 [CmdletBinding()]
 param([Parameter(Mandatory=$true)]$Result)
 $findings=New-Object System.Collections.Generic.List[object]
 function Add-Finding([string]$level,[string]$msg){$findings.Add([pscustomobject]@{Level=$level;Message=$msg})}
 $rows=@($Result.Data)
 if($Result.Status -ne 'SUCCESS'){Add-Finding 'STATUS' "Dispatcher reports $($Result.Status); review before integration."}
 switch([string]$Result.Section){
  'Network' {
   foreach($row in $rows){if([string]::IsNullOrWhiteSpace([string]$row.Detail)){Add-Finding 'GAP' "Missing Detail for $($row.Check)"}}
   if(@($rows | Where-Object {$_.Check -match 'Remote ipconfig|Remote IP configuration'}).Count -ne 1){Add-Finding 'GAP' 'Remote IP configuration result absent or duplicated.'}
  }
  'Health' {Add-Finding 'EXPECTED' 'ADMIN$ is NOT TESTED by this dispatcher; a safe SMB lifecycle is still required.'}
  'SharePermissions' {
   foreach($row in $rows){if($row.Status -eq 'SUCCESS'){
    if(@($row.ShareACL).Count -eq 0){Add-Finding 'GAP' "No share ACL rows for $($row.Share)."}
    if(@($row.NTFSACL).Count -eq 0){Add-Finding 'GAP' "No NTFS ACL rows for $($row.Share)."}
   }else{Add-Finding 'GAP' "Share $($row.Share): $($row.Status): $($row.Error)"}}
  }
  'Services' {Add-Finding 'GAP' 'Original reports include total services queried; adapter currently returns only stopped automatic services.'}
  'Groups' {Add-Finding 'GAP' 'Original reports include direct Win32_GroupUser membership; adapter returns group inventory only.'}
  'Events' {Add-Finding 'GAP' 'Original reports query System AND Application logs over seven days (25 each); adapter currently differs.'}
  'Tasks' {Add-Finding 'REVIEW' 'Compare task state, last/next run, action, trigger and result details with original reporting.'}
  'Firewall' {Add-Finding 'GAP' 'Original report also lists up to 200 enabled firewall rules; current adapter returns profiles only.'}
  'BitLocker' {Add-Finding 'GAP' 'Original report has alternate read-only BitLocker probing; current adapter relies on Get-BitLockerVolume.'}
  'Policy' {Add-Finding 'REVIEW' 'Verify gpresult is collecting computer-scope RSoP, not only a user summary.'}
 }
 if($findings.Count -eq 0){Add-Finding 'CHECK' 'Data returned; inspect preview for content parity (not a certification).'}
 [pscustomobject]@{Section=$Result.Section;Findings=@($findings.ToArray())}
}
