# IT Toolkit v1.26 Phase 4D - read-only detailed parity adapter (Windows PowerShell 5.1).
# Requires ITToolkit-Authentication, WmiDiagnostics, CompositeDiagnostics.
# Always uses explicitly selected context; no implicit credential fallback.
function Get-ToolkitDetailDiagnostic {
 [CmdletBinding()]
 param([Parameter(Mandatory=$true)]$Context,[Parameter(Mandatory=$true)][ValidateSet('Services','Groups','Events','Tasks','Firewall','BitLocker','Policy')][string]$Section)
 if ($null -eq $Context -or $Context.PSTypeNames -notcontains 'ITToolkit.AuthenticationContext') {throw 'Invalid authentication context.'}
 if ($Context.Mode -eq 'Alternate' -and $null -eq $Context.Credential) {throw 'Alternate credentials required; no identity fallback.'}
 $start=Get-Date; $rows=@(); $problems=New-Object System.Collections.Generic.List[string]; $status='SUCCESS'
 try {
  switch ($Section) {
   'Services' {
    $all=@(Invoke-ToolkitWmiRead -Context $Context -Class 'Win32_Service')
    $stopped=@($all | Where-Object {$_.StartMode -eq 'Auto' -and $_.State -ne 'Running'})
    $rows+= [pscustomobject]@{RecordType='Summary';TotalServices=$all.Count;StoppedAutomatic=$stopped.Count;Name='';DisplayName='';State='';StartMode=''}
    $rows+=@($stopped | ForEach-Object {[pscustomobject]@{RecordType='StoppedAutomatic';TotalServices=$null;StoppedAutomatic=$null;Name=$_.Name;DisplayName=$_.DisplayName;State=$_.State;StartMode=$_.StartMode}})
   }
   'Groups' {
    $groups=@(Invoke-ToolkitWmiRead -Context $Context -Class 'Win32_Group' -Filter 'LocalAccount=True')
    $links=@(Invoke-ToolkitWmiRead -Context $Context -Class 'Win32_GroupUser')
    $rows+=@($groups | ForEach-Object {[pscustomobject]@{RecordType='Group';Group=($_.Domain+'\'+$_.Name);Member='';SID=$_.SID;Description=$_.Description;GroupComponent='';PartComponent=''}})
    $rows+=@($links | ForEach-Object {
      $gc=[string]$_.GroupComponent; $pc=[string]$_.PartComponent
      $g=$gc; $m=$pc
      if($gc -match 'Domain="([^"]+)",Name="([^"]+)"'){$g=$matches[1]+'\'+$matches[2]}
      if($pc -match 'Domain="([^"]+)",Name="([^"]+)"'){$m=$matches[1]+'\'+$matches[2]}
      [pscustomobject]@{RecordType='DirectMember';Group=$g;Member=$m;SID='';Description='';GroupComponent=$gc;PartComponent=$pc}
    })
   }
   'Events' {
    $rows=@(Invoke-ToolkitCompositeRemote -Context $Context -ScriptBlock {
      foreach($log in @('System','Application')) {
       try {
        $entries=@(Get-WinEvent -FilterHashtable @{LogName=$log;Level=1,2;StartTime=(Get-Date).AddDays(-7)} -MaxEvents 25 -ErrorAction Stop)
        foreach($e in $entries){[pscustomobject]@{RecordType='Event';LogName=$log;Status='SUCCESS';TimeCreated=$e.TimeCreated;Id=$e.Id;ProviderName=$e.ProviderName;LevelDisplayName=$e.LevelDisplayName;Message=[string]$e.Message;Error=''}}
       } catch {
        if($_.FullyQualifiedErrorId -match 'NoMatchingEventsFound') {[pscustomobject]@{RecordType='LogStatus';LogName=$log;Status='NO RESULTS';TimeCreated=$null;Id=$null;ProviderName='';LevelDisplayName='';Message='';Error='No critical/error events during the last seven days.'}}
        else {[pscustomobject]@{RecordType='LogStatus';LogName=$log;Status='UNAVAILABLE';TimeCreated=$null;Id=$null;ProviderName='';LevelDisplayName='';Message='';Error=$_.Exception.Message}}
       }
      }
    })
    if(@($rows | Where-Object {$_.Status -eq 'UNAVAILABLE'}).Count){$problems.Add('One or more event logs unavailable.')}
   }
   'Tasks' {
    $rows=@(Invoke-ToolkitCompositeRemote -Context $Context -ScriptBlock {
      if(-not (Get-Command Get-ScheduledTask -ErrorAction SilentlyContinue)){throw 'ScheduledTasks module unavailable.'}
      foreach($t in @(Get-ScheduledTask -ErrorAction Stop)) {
       $info=$null; $err=''
       try {$info=Get-ScheduledTaskInfo -InputObject $t -ErrorAction Stop} catch {$err=$_.Exception.Message}
       $actions=@($t.Actions | ForEach-Object {([string]$_.Execute+' '+[string]$_.Arguments).Trim()}) -join '; '
       $triggers=@($t.Triggers | ForEach-Object {([string]$_.CimClass.CimClassName+' '+[string]$_.StartBoundary).Trim()}) -join '; '
       [pscustomobject]@{TaskPath=$t.TaskPath;TaskName=$t.TaskName;State=[string]$t.State;Author=[string]$t.Author;LastRunTime=if($info){$info.LastRunTime}else{$null};NextRunTime=if($info){$info.NextRunTime}else{$null};LastTaskResult=if($info){$info.LastTaskResult}else{$null};NumberOfMissedRuns=if($info){$info.NumberOfMissedRuns}else{$null};Actions=$actions;Triggers=$triggers;DetailStatus=if($info){'SUCCESS'}else{'PARTIAL'};Error=$err}
      }
    })
    if(@($rows | Where-Object {$_.DetailStatus -eq 'PARTIAL'}).Count){$problems.Add('Some scheduled tasks do not expose execution history.')}
   }
   'Firewall' {
    $rows=@(Invoke-ToolkitCompositeRemote -Context $Context -ScriptBlock {
     if(-not (Get-Command Get-NetFirewallProfile -ErrorAction SilentlyContinue)){throw 'NetSecurity module unavailable.'}
     foreach($p in @(Get-NetFirewallProfile -ErrorAction Stop)) {[pscustomobject]@{RecordType='Profile';Name=$p.Name;Enabled=$p.Enabled;DefaultInboundAction=[string]$p.DefaultInboundAction;DefaultOutboundAction=[string]$p.DefaultOutboundAction;Direction='';Action='';Profile='';DisplayName=''}}
     foreach($r in @(Get-NetFirewallRule -Enabled True -ErrorAction Stop | Select-Object -First 200)) {[pscustomobject]@{RecordType='EnabledRule';Name=$r.Name;Enabled=$true;DefaultInboundAction='';DefaultOutboundAction='';Direction=[string]$r.Direction;Action=[string]$r.Action;Profile=[string]$r.Profile;DisplayName=$r.DisplayName}}
    })
   }
   'BitLocker' {
    # All fallbacks run ON the target through WinRM; never retrieve protector IDs or recovery secrets.
    $rows=@(Invoke-ToolkitCompositeRemote -Context $Context -ScriptBlock {
      $failure=New-Object System.Collections.Generic.List[string]
      if(Get-Command Get-BitLockerVolume -ErrorAction SilentlyContinue){
       try {
        $volumes=@(Get-BitLockerVolume -ErrorAction Stop)
        if($volumes.Count){foreach($v in $volumes){[pscustomobject]@{Method='Get-BitLockerVolume';MountPoint=[string]$v.MountPoint;VolumeStatus=[string]$v.VolumeStatus;ProtectionStatus=[string]$v.ProtectionStatus;EncryptionPercentage=$v.EncryptionPercentage;EncryptionMethod=[string]$v.EncryptionMethod;Status='SUCCESS';Detail=''}};return}
        $failure.Add('BitLocker cmdlet returned no volumes.')
       } catch {$failure.Add('BitLocker cmdlet: '+$_.Exception.Message)}
      } else {$failure.Add('BitLocker module unavailable.')}
      try {
       $volumes=@(Get-WmiObject -Namespace 'root\CIMV2\Security\MicrosoftVolumeEncryption' -Class Win32_EncryptableVolume -ErrorAction Stop)
       if($volumes.Count){
        foreach($v in $volumes){
         $pro=$v.GetProtectionStatus();$conv=$v.GetConversionStatus()
         [pscustomobject]@{Method='Win32_EncryptableVolume';MountPoint=[string]$v.DriveLetter;VolumeStatus=if($conv.ReturnValue -eq 0){[string]$conv.ConversionStatus}else{'Unknown'};ProtectionStatus=if($pro.ReturnValue -eq 0){[string]$pro.ProtectionStatus}else{'Unknown'};EncryptionPercentage=if($conv.ReturnValue -eq 0){$conv.EncryptionPercentage}else{$null};EncryptionMethod='';Status=if($pro.ReturnValue -eq 0 -and $conv.ReturnValue -eq 0){'SUCCESS'}else{'PARTIAL'};Detail="Protection code $($pro.ReturnValue); conversion code $($conv.ReturnValue)"}
        };return
       };$failure.Add('Encryption WMI provider returned no volumes.')
      } catch {$failure.Add('Encryption WMI provider: '+$_.Exception.Message)}
      try {
       $exe=Join-Path $env:windir 'System32\manage-bde.exe'
       if(-not (Test-Path -LiteralPath $exe)){throw 'manage-bde unavailable.'}
       $lines=@(& $exe -status 2>&1);$exit=$LASTEXITCODE
       if($exit -ne 0){throw "manage-bde -status exited $exit"}
       if($lines.Count){[pscustomobject]@{Method='manage-bde -status';MountPoint='';VolumeStatus='See detail';ProtectionStatus='See detail';EncryptionPercentage=$null;EncryptionMethod='';Status='SUCCESS';Detail=($lines -join "`n")};return}
       $failure.Add('manage-bde returned no output.')
      } catch {$failure.Add('manage-bde: '+$_.Exception.Message)}
      [pscustomobject]@{Method='None';MountPoint='';VolumeStatus='Unknown';ProtectionStatus='Unknown';EncryptionPercentage=$null;EncryptionMethod='';Status='UNAVAILABLE';Detail=('Encryption status unverified; missing tools do not imply unencrypted drives. '+($failure -join ' | '))}
    })
    if(@($rows | Where-Object {$_.Status -eq 'UNAVAILABLE' -or $_.Status -eq 'PARTIAL'}).Count){$problems.Add('Encryption status could not be fully verified for every returned volume.')}
   }
   'Policy' {
    $rows=@(Invoke-ToolkitCompositeRemote -Context $Context -ScriptBlock {
      $lines=@(& gpresult.exe /SCOPE COMPUTER /R 2>&1);$exit=$LASTEXITCODE
      if($exit -ne 0){throw "gpresult /SCOPE COMPUTER /R failed ($exit): $($lines -join ' ')"}
      foreach($line in $lines){[pscustomobject]@{Scope='COMPUTER';Line=[string]$line}}
    })
    if(-not (@($rows | Where-Object {$_.Line -match 'COMPUTER SETTINGS|Computer Configuration|Applied Group Policy Objects'}).Count)){$problems.Add('Computer policy content was not recognized in gpresult output; verify scope manually.')}
   }
  }
  if($rows.Count -eq 0){$status='NO RESULTS'}
  elseif($problems.Count){$status='PARTIAL / UNAVAILABLE'}
  if($Section -eq 'BitLocker' -and $rows.Count -and @($rows | Where-Object {$_.Status -eq 'UNAVAILABLE'}).Count){$status='UNAVAILABLE'}
 } catch {$status='UNAVAILABLE';$problems.Add($_.Exception.Message)}
 [pscustomobject]@{Target=[string]$Context.ComputerName;Mode=[string]$Context.Mode;UserName=[string]$Context.UserName;Section=$Section;CollectedAt=$start;Status=$status;Data=@($rows);Error=($problems -join ' | ')}
}
