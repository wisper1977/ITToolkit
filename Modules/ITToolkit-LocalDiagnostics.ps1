# IT Toolkit v1.27C - direct local diagnostic collector foundation.
# Windows PowerShell 5.1; dot-source when local collection is explicitly selected.
# Used by explicit local mode in both GUI and Classic.
# Default local collection uses the current process token. Only explicitly
# authorized BitLocker/Policy UAC handoffs use a separate elevated process.
# It does not use WinRM or open SMB sessions.

function Get-ToolkitLocalDiagnostic {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [ValidateSet('System','Firewall','Services','Storage','Network','Hardware','Users','Groups','Administrators','Shares','Software','Updates','Tasks','Events','Startup','BitLocker','Sessions','Policy','SharePermissions','Health')]
        [string]$Section
    )

    $target = [string]$env:COMPUTERNAME
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $result = [ordered]@{
        Target = $target
        Mode = 'Local'
        UserName = [string]$identity.Name
        Section = $Section
        CollectedAt = Get-Date
        Status = 'UNAVAILABLE'
        StatusCategory = 'Unavailable'
        Data = @()
        Error = ''
        Adapter = 'Local'
        AdapterSection = $Section
    }

    try {
        switch ($Section) {
            'System' {
                # Direct local CIM; no remote sessions or privilege escalation.
                $result.Data = @($records = New-Object System.Collections.Generic.List[object]
                    $failures = New-Object System.Collections.Generic.List[string]
                    foreach ($check in @('OperatingSystem','ComputerSystem','Processor','BIOS','PendingRestart','SecureBoot','TPM')) {
                        try {
                            switch ($check) {
                                'OperatingSystem' {
                                    $os = Get-CimInstance Win32_OperatingSystem -ErrorAction Stop
                                    if (-not $os) { throw 'No operating system data returned.' }
                                    $total = [double]$os.TotalVisibleMemorySize
                                    $free = [double]$os.FreePhysicalMemory
                                    $records.Add([pscustomobject]@{
                                        Check=$check; QueryStatus='Available'
                                        ComputerName=[string]$env:COMPUTERNAME
                                        Caption=[string]$os.Caption; Version=[string]$os.Version
                                        BuildNumber=[string]$os.BuildNumber; OSArchitecture=[string]$os.OSArchitecture
                                        InstallDate=$os.InstallDate; LastBootUpTime=$os.LastBootUpTime
                                        UptimeDays=if($os.LastBootUpTime){[math]::Round(((Get-Date)-[datetime]$os.LastBootUpTime).TotalDays,1)}else{$null}
                                        TotalMemoryGB=if($total -gt 0){[math]::Round($total/1MB,2)}else{$null}
                                        AvailableMemoryGB=if($total -gt 0){[math]::Round($free/1MB,2)}else{$null}
                                        MemoryUsedPercent=if($total -gt 0){[math]::Round(100*($total-$free)/$total,1)}else{$null}
                                        WindowsDirectory=[string]$os.WindowsDirectory
                                    })
                                }
                                'ComputerSystem' {
                                    $cs = Get-CimInstance Win32_ComputerSystem -ErrorAction Stop
                                    if (-not $cs) { throw 'No computer system data returned.' }
                                    $records.Add([pscustomobject]@{
                                        Check=$check;QueryStatus='Available'
                                        Manufacturer=[string]$cs.Manufacturer; Model=[string]$cs.Model
                                        Domain=[string]$cs.Domain; PartOfDomain=[bool]$cs.PartOfDomain
                                        SystemType=[string]$cs.SystemType
                                        LogicalProcessors=$cs.NumberOfLogicalProcessors
                                        PhysicalProcessors=$cs.NumberOfProcessors
                                        HypervisorPresent=$cs.HypervisorPresent
                                    })
                                }
                                'Processor' {
                                    $cpu = @(Get-CimInstance Win32_Processor -ErrorAction Stop)
                                    if (-not $cpu.Count) { throw 'No processor data returned.' }
                                    foreach($p in $cpu) {
                                        $records.Add([pscustomobject]@{
                                            Check=$check;QueryStatus='Available'
                                            Name=[string]$p.Name; Cores=$p.NumberOfCores
                                            LogicalProcessors=$p.NumberOfLogicalProcessors
                                            MaxClockSpeedMHz=$p.MaxClockSpeed
                                        })
                                    }
                                }
                                'BIOS' {
                                    $bios = Get-CimInstance Win32_BIOS -ErrorAction Stop
                                    if (-not $bios) { throw 'No BIOS data returned.' }
                                    $records.Add([pscustomobject]@{
                                        Check=$check;QueryStatus='Available'
                                        Manufacturer=[string]$bios.Manufacturer
                                        SMBIOSBIOSVersion=[string]$bios.SMBIOSBIOSVersion
                                        ReleaseDate=$bios.ReleaseDate
                                    })
                                }
                                'PendingRestart' {
                                    $found = New-Object System.Collections.Generic.List[string]
                                    foreach($key in @(
                                        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending',
                                        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired'
                                    )) { if(Test-Path -LiteralPath $key -ErrorAction Stop) { $found.Add($key.Split('\')[-1]) } }
                                    $session = Get-ItemProperty -LiteralPath 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager' -Name PendingFileRenameOperations -ErrorAction SilentlyContinue
                                    if ($null -ne $session -and @($session.PendingFileRenameOperations).Count -gt 0) { $found.Add('PendingFileRenameOperations') }
                                    $records.Add([pscustomobject]@{
                                        Check=$check;QueryStatus='Available'
                                        IndicatorsPresent=($found.Count -gt 0);Indicators=($found -join ', ')
                                        Note='Selected indicators only; no indicator does not establish that a reboot is unnecessary.'
                                    })
                                }
                                'SecureBoot' {
                                    if (-not (Get-Command Confirm-SecureBootUEFI -ErrorAction SilentlyContinue)) { throw 'Secure Boot query command unavailable.' }
                                    $enabled = Confirm-SecureBootUEFI -ErrorAction Stop
                                    $records.Add([pscustomobject]@{Check=$check;QueryStatus='Available';Enabled=[bool]$enabled})
                                }
                                'TPM' {
                                    if (-not (Get-Command Get-Tpm -ErrorAction SilentlyContinue)) { throw 'TPM query command unavailable.' }
                                    $tpm = Get-Tpm -ErrorAction Stop
                                    if ($null -eq $tpm -or $null -eq $tpm.TpmPresent -or
                                        $null -eq $tpm.TpmReady -or $null -eq $tpm.TpmEnabled) {
                                        throw 'TPM query returned incomplete status values.'
                                    }
                                    $records.Add([pscustomobject]@{
                                        Check=$check;QueryStatus='Available'
                                        TpmPresent=$tpm.TpmPresent;TpmReady=$tpm.TpmReady
                                        TpmEnabled=$tpm.TpmEnabled
                                    })
                                }
                            }
                        } catch {
                            $failures.Add($check)
                            $records.Add([pscustomobject]@{Check=$check;QueryStatus='Unavailable';Error=[string]$_.Exception.Message})
                        }
                    }
                    $records)
                $available = @($result.Data | Where-Object { $_.QueryStatus -eq 'Available' }).Count
                if ($available -eq 0) { $result.Status = 'UNAVAILABLE'; $result.StatusCategory = 'Unavailable' }
                elseif ($available -lt @($result.Data).Count) { $result.Status = 'PARTIAL / UNAVAILABLE'; $result.StatusCategory = 'Partial' }
            }
            'Health' {
                # Evidence-only local summary, not a system health grade.
                # Remote ping/ADMIN$ checks are intentionally inapplicable locally.
                $records = New-Object System.Collections.Generic.List[object]
                $failures = New-Object System.Collections.Generic.List[string]
                try {
                    $systemDrive = [string]$env:SystemDrive
                    $drive = Get-CimInstance -ClassName Win32_LogicalDisk -Filter (
                        "DeviceID='" + $systemDrive + "'") -ErrorAction Stop
                    if ($null -eq $drive -or [double]$drive.Size -le 0) {
                        throw 'System volume size is unavailable.'
                    }
                    $records.Add([pscustomobject]@{
                        Check = 'SystemDrive'
                        QueryStatus = 'Available'
                        Drive = $systemDrive
                        FreePercent = [math]::Round(
                            100 * [double]$drive.FreeSpace / [double]$drive.Size, 1)
                        FreeGB = [math]::Round([double]$drive.FreeSpace / 1GB, 2)
                        Note = 'Observed capacity only; no health rating assigned.'
                    })
                } catch {
                    $failures.Add('SystemDrive')
                    $records.Add([pscustomobject]@{
                        Check = 'SystemDrive'
                        QueryStatus = 'Unavailable'
                        Error = [string]$_.Exception.Message
                    })
                }
                try {
                    $services = @(Get-CimInstance -ClassName Win32_Service -ErrorAction Stop)
                    if ($services.Count -eq 0) {
                        throw 'Service query returned no records.'
                    }
                    $notRunning = @($services | Where-Object {
                        $_.StartMode -eq 'Auto' -and $_.State -ne 'Running'
                    })
                    $records.Add([pscustomobject]@{
                        Check = 'AutomaticServices'
                        QueryStatus = 'Available'
                        ServicesQueried = $services.Count
                        AutomaticNotRunning = $notRunning.Count
                        Note = 'Trigger-start or intentionally stopped services need individual review.'
                    })
                } catch {
                    $failures.Add('AutomaticServices')
                    $records.Add([pscustomobject]@{
                        Check = 'AutomaticServices'
                        QueryStatus = 'Unavailable'
                        Error = [string]$_.Exception.Message
                    })
                }
                try {
                    $events = @(Get-WinEvent -FilterHashtable @{
                        LogName = 'System'
                        Level = @(1,2)
                        StartTime = (Get-Date).AddDays(-1)
                    } -MaxEvents 100 -ErrorAction Stop)
                    $records.Add([pscustomobject]@{
                        Check = 'RecentSystemEvents'
                        QueryStatus = 'Available'
                        CriticalOrErrorCount = $events.Count
                        WindowHours = 24
                        MaxEvents = 100
                        Note = 'Bounded count, not a complete error history.'
                    })
                } catch {
                    $message = [string]$_.Exception.Message
                    if ($_.FullyQualifiedErrorId -match 'NoMatchingEventsFound' -or
                        $message -match '(?i)^No events were found') {
                        $records.Add([pscustomobject]@{
                            Check = 'RecentSystemEvents'
                            QueryStatus = 'NoData'
                            CriticalOrErrorCount = 0
                            WindowHours = 24
                            MaxEvents = 100
                            Note = 'No matching events found; this does not establish health.'
                        })
                    } else {
                        $failures.Add('RecentSystemEvents')
                        $records.Add([pscustomobject]@{
                            Check = 'RecentSystemEvents'
                            QueryStatus = 'Unavailable'
                            Error = $message
                        })
                    }
                }
                # System, security and update observations use independent read-only
                # checks. No installed-hotfix list can establish missing-update compliance.
                try {
                    $os = Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction Stop
                    if (-not $os -or -not $os.LastBootUpTime) { throw 'Last boot time was unavailable.' }
                    $records.Add([pscustomobject]@{
                        Check='SystemUptime'; QueryStatus='Available'
                        Caption=[string]$os.Caption
                        LastBootUpTime=$os.LastBootUpTime
                        UptimeDays=[math]::Round(((Get-Date)-[datetime]$os.LastBootUpTime).TotalDays,1)
                        Note='Boot age is informational and does not establish system health.'
                    })
                } catch {
                    $failures.Add('SystemUptime')
                    $records.Add([pscustomobject]@{Check='SystemUptime';QueryStatus='Unavailable';Error=[string]$_.Exception.Message})
                }
                try {
                    $profiles = @(Get-NetFirewallProfile -ErrorAction Stop)
                    if ($profiles.Count -lt 1) { throw 'No Windows Firewall profiles returned.' }
                    $disabled = @($profiles | Where-Object { -not [bool]$_.Enabled } | ForEach-Object { [string]$_.Name })
                    $records.Add([pscustomobject]@{
                        Check='FirewallProfiles'; QueryStatus='Available'
                        ProfilesQueried=$profiles.Count
                        DisabledProfiles=($disabled -join ', ')
                        DisabledCount=$disabled.Count
                        Note='Profile state is configuration evidence, not a security compliance verdict.'
                    })
                } catch {
                    $failures.Add('FirewallProfiles')
                    $records.Add([pscustomobject]@{Check='FirewallProfiles';QueryStatus='Unavailable';Error=[string]$_.Exception.Message})
                }
                try {
                    $hotfixes = @(Get-CimInstance -ClassName Win32_QuickFixEngineering -ErrorAction Stop)
                    $records.Add([pscustomobject]@{
                        Check='InstalledHotfixes';QueryStatus='Available'
                        HotfixCount=$hotfixes.Count
                        Note='Installed QFE inventory only; does not detect missing updates or establish patch compliance.'
                    })
                } catch {
                    $failures.Add('InstalledHotfixes')
                    $records.Add([pscustomobject]@{Check='InstalledHotfixes';QueryStatus='Unavailable';Error=[string]$_.Exception.Message})
                }
                try {
                    # Narrow read-only reboot indicators. This is not a Windows
                    # Update scan and absence does not prove the host is current.
                    $reasons = New-Object System.Collections.Generic.List[string]
                    $cbs = 'SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending'
                    $wua = 'SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired'
                    $registry = [Microsoft.Win32.RegistryKey]::OpenBaseKey(
                        [Microsoft.Win32.RegistryHive]::LocalMachine,
                        [Microsoft.Win32.RegistryView]::Default)
                    try {
                        foreach ($check in @(@('Component servicing',$cbs),@('Windows Update',$wua))) {
                            $key = $registry.OpenSubKey([string]$check[1],$false)
                            if ($null -ne $key) {
                                $reasons.Add([string]$check[0])
                                $key.Dispose()
                            }
                        }
                        $sm = $registry.OpenSubKey('SYSTEM\CurrentControlSet\Control\Session Manager',$false)
                        if ($null -eq $sm) { throw 'Session Manager registry key unavailable.' }
                        try {
                            $pending = @($sm.GetValue('PendingFileRenameOperations',$null) | Where-Object { $null -ne $_ })
                            if ($pending.Count -gt 0 -and @($pending[0]).Count -gt 0) {
                                $reasons.Add('Pending file rename operations')
                            }
                        } finally { $sm.Dispose() }
                    } finally { $registry.Dispose() }
                    $records.Add([pscustomobject]@{
                        Check='PendingRestart';QueryStatus='Available'
                        IndicatorCount=$reasons.Count
                        Indicators=($reasons -join ', ')
                        Note='Selected registry indicators only; absence is not a comprehensive reboot assessment.'
                    })
                } catch {
                    $failures.Add('PendingRestart')
                    $records.Add([pscustomobject]@{Check='PendingRestart';QueryStatus='Unavailable';Error=[string]$_.Exception.Message})
                }
                $result.Data = @($records.ToArray())
                if ($failures.Count -gt 0) {
                    $result.Status = 'PARTIAL'
                    $result.StatusCategory = 'Partial'
                    $result.Error = 'Unavailable checks: ' + ($failures -join ', ')
                }
            }
            'SharePermissions' {
                # Read-only ordinary filesystem share ACL inspection, scoped to
                # the local computer. Administrative and IPC shares are excluded.
                $shares = @(Get-SmbShare -ErrorAction Stop | Where-Object {
                    -not $_.Special -and [string]$_.Path -ne ''
                } | Sort-Object Name)
                $records = New-Object System.Collections.Generic.List[object]
                $failed = New-Object System.Collections.Generic.List[string]
                $records.Add([pscustomobject]@{
                    RecordType = 'Summary'
                    OrdinarySharesFound = $shares.Count
                    Note = if ($shares.Count -eq 0) {
                        'No ordinary disk shares were found. Administrative shares are excluded.'
                    } else {
                        'Read-only share permissions and root NTFS access entries; effective access is not calculated.'
                    }
                })
                foreach ($share in $shares) {
                    $records.Add([pscustomobject]@{
                        RecordType = 'Share'
                        ShareName = [string]$share.Name
                        Path = [string]$share.Path
                    })
                    try {
                        $shareEntries = @(Get-SmbShareAccess -Name $share.Name -ErrorAction Stop)
                        foreach ($entry in $shareEntries) {
                            $records.Add([pscustomobject]@{
                                RecordType = 'ShareAccess'
                                ShareName = [string]$share.Name
                                Account = [string]$entry.AccountName
                                AccessControlType = [string]$entry.AccessControlType
                                AccessRight = [string]$entry.AccessRight
                            })
                        }
                    } catch {
                        $failed.Add([string]$share.Name + ' share ACL')
                        $records.Add([pscustomobject]@{
                            RecordType = 'QueryError'
                            ShareName = [string]$share.Name
                            Scope = 'Share'
                            Error = [string]$_.Exception.Message
                        })
                    }
                    try {
                        $acl = Get-Acl -LiteralPath ([string]$share.Path) -ErrorAction Stop
                        foreach ($entry in @($acl.Access)) {
                            $records.Add([pscustomobject]@{
                                RecordType = 'NTFSAccess'
                                ShareName = [string]$share.Name
                                Account = [string]$entry.IdentityReference
                                FileSystemRights = [string]$entry.FileSystemRights
                                AccessControlType = [string]$entry.AccessControlType
                                IsInherited = [bool]$entry.IsInherited
                            })
                        }
                    } catch {
                        $failed.Add([string]$share.Name + ' NTFS ACL')
                        $records.Add([pscustomobject]@{
                            RecordType = 'QueryError'
                            ShareName = [string]$share.Name
                            Scope = 'NTFS'
                            Error = [string]$_.Exception.Message
                        })
                    }
                }
                $result.Data = @($records.ToArray())
                if ($failed.Count -gt 0) {
                    $result.Status = 'PARTIAL'
                    $result.StatusCategory = 'Partial'
                    $result.Error = 'Could not read: ' + ($failed -join ', ')
                }
            }
            'Policy' {
                # Read-only effective COMPUTER policy summary, consistent with
                # remote Policy's computer scope. No gpupdate or policy mutation.
                $gpresultPath = Join-Path $env:SystemRoot 'System32\gpresult.exe'
                if (-not (Test-Path -LiteralPath $gpresultPath -PathType Leaf)) {
                    throw 'The local gpresult.exe utility is unavailable.'
                }
                $policyLines = @(& $gpresultPath /SCOPE COMPUTER /R 2>&1 | ForEach-Object { [string]$_ })
                $exitCode = $LASTEXITCODE
                if ($exitCode -ne 0) {
                    throw ("Local computer policy query failed (exit code {0}): {1}" -f
                        $exitCode, ($policyLines -join ' '))
                }
                $content = @($policyLines | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
                $result.Data = @($content | ForEach-Object {
                    [pscustomobject]@{ RecordType = 'PolicyLine'; Text = $_ }
                })
                # Successful process with no text is NoData; not a valid GPO verdict.
            }
            'Sessions' {
                # Query local interactive/terminal sessions only, under the current
                # identity. Preserve quser text rather than guessing column breaks.
                $quserPath = Join-Path $env:SystemRoot 'System32\quser.exe'
                if (-not (Test-Path -LiteralPath $quserPath -PathType Leaf)) {
                    throw 'The local quser.exe utility is unavailable.'
                }
                $sessionLines = @(& $quserPath 2>&1 | ForEach-Object { [string]$_ })
                $exitCode = $LASTEXITCODE
                if ($exitCode -ne 0) {
                    throw ("Local session query failed (exit code {0}): {1}" -f
                        $exitCode, ($sessionLines -join ' '))
                }
                $content = @($sessionLines | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
                if ($content.Count -gt 0) {
                    $result.Data = @($content | ForEach-Object {
                        [pscustomobject]@{ RecordType = 'SessionLine'; Text = $_ }
                    })
                }
                # A successful but empty response remains NoData.
            }
            'BitLocker' {
                # Read-only BitLocker volume states. Never read, expand, or return
                # KeyProtector/RecoveryPassword/RecoveryKey data.
                $volumes = @(Get-BitLockerVolume -ErrorAction Stop)
                $result.Data = @($volumes | Sort-Object MountPoint | ForEach-Object {
                    [pscustomobject]@{
                        MountPoint = [string]$_.MountPoint
                        VolumeType = [string]$_.VolumeType
                        VolumeStatus = [string]$_.VolumeStatus
                        ProtectionStatus = [string]$_.ProtectionStatus
                        EncryptionPercentage = if ($null -ne $_.EncryptionPercentage) {
                            [double]$_.EncryptionPercentage
                        } else { $null }
                        EncryptionMethod = [string]$_.EncryptionMethod
                        LockStatus = [string]$_.LockStatus
                    }
                })
                # Query success reports observed volume status, not security compliance.
            }
            'Startup' {
                # Direct-local read-only startup command inventory. Mirrors the
                # existing remote Win32_StartupCommand scope, not all startup mechanisms.
                $entries = @(Get-CimInstance -ClassName Win32_StartupCommand -ErrorAction Stop)
                $result.Data = @($entries | Sort-Object Name,Location | ForEach-Object {
                    [pscustomobject]@{
                        Name = [string]$_.Name
                        Location = [string]$_.Location
                        User = [string]$_.User
                        Command = [string]$_.Command
                    }
                })
                # A valid query with zero entries is NoData, not a health assessment.
            }
            'Events' {
                # Bounded local System/Application error log inspection (past 7 days,
                # latest 25 per log). A lack of error events is not a health verdict.
                $since = (Get-Date).AddDays(-7)
                $records = New-Object System.Collections.Generic.List[object]
                $failedLogs = New-Object System.Collections.Generic.List[string]
                foreach ($logName in @('System','Application')) {
                    $events = @()
                    $queryStatus = 'Available'
                    $queryError = ''
                    try {
                        $events = @(Get-WinEvent -FilterHashtable @{
                            LogName = $logName
                            Level = 2
                            StartTime = $since
                        } -MaxEvents 25 -ErrorAction Stop)
                    } catch {
                        $queryError = [string]$_.Exception.Message
                        if ($_.FullyQualifiedErrorId -match 'NoMatchingEventsFound' -or
                            $queryError -match '(?i)^No events were found') {
                            $queryStatus = 'NoData'
                            $queryError = ''
                        } else {
                            $queryStatus = 'Unavailable'
                            $failedLogs.Add($logName)
                        }
                    }
                    $records.Add([pscustomobject]@{
                        RecordType = 'LogSummary'
                        LogName = $logName
                        QueryStatus = $queryStatus
                        ErrorEventsReturned = $events.Count
                        WindowDays = 7
                        MaxEvents = 25
                        Error = $queryError
                    })
                    foreach ($event in $events) {
                        $message = ([string]$event.Message -replace '\s+', ' ').Trim()
                        if ($message.Length -gt 300) { $message = $message.Substring(0, 300) }
                        $records.Add([pscustomobject]@{
                            RecordType = 'ErrorEvent'
                            LogName = $logName
                            TimeCreated = $event.TimeCreated
                            Id = $event.Id
                            ProviderName = [string]$event.ProviderName
                            LevelDisplayName = [string]$event.LevelDisplayName
                            Message = $message
                        })
                    }
                }
                $result.Data = @($records.ToArray())
                if ($failedLogs.Count -gt 0) {
                    $result.Status = 'PARTIAL'
                    $result.StatusCategory = 'Partial'
                    $result.Error = 'One or more event logs could not be queried: ' + ($failedLogs -join ', ')
                }
            }
            'Tasks' {
                # Read-only local Task Scheduler inventory. Failed task-info reads are
                # surfaced per task instead of replacing values with a success claim.
                $tasks = @(Get-ScheduledTask -ErrorAction Stop)
                $records = New-Object System.Collections.Generic.List[object]
                foreach ($task in @($tasks | Sort-Object TaskPath,TaskName)) {
                    $info = $null
                    $infoError = ''
                    try {
                        $info = $task | Get-ScheduledTaskInfo -ErrorAction Stop
                    } catch {
                        $infoError = [string]$_.Exception.Message
                    }
                    $records.Add([pscustomobject]@{
                        TaskPath = [string]$task.TaskPath
                        TaskName = [string]$task.TaskName
                        State = [string]$task.State
                        LastRunTime = if ($null -ne $info) { $info.LastRunTime } else { $null }
                        LastTaskResult = if ($null -ne $info) { $info.LastTaskResult } else { $null }
                        NextRunTime = if ($null -ne $info) { $info.NextRunTime } else { $null }
                        DetailStatus = if ($null -ne $info) { 'Available' } else { 'Unavailable' }
                        DetailError = $infoError
                    })
                }
                $result.Data = @($records.ToArray())
                # A task's nonzero LastTaskResult is evidence for review, not proof
                # that local task inventory failed.
            }
            'Updates' {
                # Read-only installed hotfix inventory. This does not scan Windows
                # Update, install patches, or assess missing security updates.
                $fixes = @(Get-CimInstance -ClassName Win32_QuickFixEngineering -ErrorAction Stop)
                $result.Data = @($fixes | Sort-Object HotFixID | ForEach-Object {
                    [pscustomobject]@{
                        RecordType = 'InstalledHotfix'
                        HotFixID = [string]$_.HotFixID
                        Description = [string]$_.Description
                        InstalledOn = [string]$_.InstalledOn
                        InstalledBy = [string]$_.InstalledBy
                    }
                })
                # No QFE records is NoData, never evidence of patch compliance.
            }
            'Software' {
                # Read-only machine-wide uninstall registry entries in both registry
                # views. Explicit views avoid 32-bit PowerShell missing 64-bit apps.
                # Scope intentionally mirrors remote HKLM uninstall inventory; Store
                # and portable apps are not comprehensively enumerated.
                $subPath = 'SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall'
                $views = if ([Environment]::Is64BitOperatingSystem) {
                    @([Microsoft.Win32.RegistryView]::Registry64, [Microsoft.Win32.RegistryView]::Registry32)
                } else {
                    @([Microsoft.Win32.RegistryView]::Registry32)
                }
                $entries = New-Object System.Collections.Generic.List[object]
                foreach ($view in $views) {
                    $base = [Microsoft.Win32.RegistryKey]::OpenBaseKey(
                        [Microsoft.Win32.RegistryHive]::LocalMachine, $view)
                    try {
                        $root = $base.OpenSubKey($subPath, $false)
                        if ($null -eq $root) { continue }
                        try {
                            foreach ($keyName in $root.GetSubKeyNames()) {
                                $entry = $root.OpenSubKey($keyName, $false)
                                if ($null -eq $entry) { continue }
                                try {
                                    $name = [string]$entry.GetValue('DisplayName', '')
                                    if ([string]::IsNullOrWhiteSpace($name)) { continue }
                                    $entries.Add([pscustomobject]@{
                                        Name = $name
                                        Version = [string]$entry.GetValue('DisplayVersion', '')
                                        Publisher = [string]$entry.GetValue('Publisher', '')
                                    })
                                } finally {
                                    $entry.Dispose()
                                }
                            }
                        } finally {
                            $root.Dispose()
                        }
                    } finally {
                        $base.Dispose()
                    }
                }
                $result.Data = @($entries | Sort-Object Name,Version,Publisher -Unique)
                # No uninstall entries -> NoData, not proof that nothing is installed.
            }
            'Shares' {
                # Read-only SMB share inventory (including built-in administrative shares).
                # Share permissions and backing-path ACLs are separate diagnostics.
                $shares = @(Get-CimInstance -ClassName Win32_Share -ErrorAction Stop)
                $result.Data = @($shares | Sort-Object Name | ForEach-Object {
                    [pscustomobject]@{
                        Name = [string]$_.Name
                        Path = [string]$_.Path
                        Description = [string]$_.Description
                        Type = [uint32]$_.Type
                    }
                })
                # No shares is a NoData result; it is not evidence of missing access.
            }
            'Administrators' {
                # SID identifies the built-in group independently of OS display language.
                # Direct members only: domain group nesting is deliberately not expanded.
                $adminSid = New-Object System.Security.Principal.SecurityIdentifier('S-1-5-32-544')
                $members = @(Get-LocalGroupMember -SID $adminSid -ErrorAction Stop)
                $records = New-Object System.Collections.Generic.List[object]
                $records.Add([pscustomobject]@{
                    RecordType = 'Summary'
                    GroupSID = 'S-1-5-32-544'
                    DirectMemberCount = $members.Count
                    Note = 'Direct members only; nested domain group membership is not expanded.'
                })
                foreach ($member in @($members | Sort-Object Name)) {
                    $records.Add([pscustomobject]@{
                        RecordType = 'Member'
                        Name = [string]$member.Name
                        ObjectClass = [string]$member.ObjectClass
                        PrincipalSource = [string]$member.PrincipalSource
                        SID = if ($null -ne $member.SID) { [string]$member.SID.Value } else { '' }
                    })
                }
                $result.Data = @($records.ToArray())
                # An empty membership list still yields SUCCESS if the group was queried.
            }
            'Groups' {
                # Read-only local SAM group inventory. Membership enumeration is a
                # separate follow-up; do not infer membership from group existence.
                $groups = @(Get-CimInstance -ClassName Win32_Group -Filter 'LocalAccount=True' -ErrorAction Stop)
                $result.Data = @($groups | Sort-Object Name | ForEach-Object {
                    [pscustomobject]@{
                        Domain = [string]$_.Domain
                        Name = [string]$_.Name
                        SID = [string]$_.SID
                        Description = [string]$_.Description
                    }
                })
            }
            'Users' {
                # Read-only local SAM account inventory, matching the remote Users scope.
                # Do not expose password material or attempt local/domain account changes.
                $accounts = @(Get-CimInstance -ClassName Win32_UserAccount -Filter 'LocalAccount=True' -ErrorAction Stop)
                $result.Data = @($accounts | Sort-Object Name | ForEach-Object {
                    [pscustomobject]@{
                        Domain = [string]$_.Domain
                        Name = [string]$_.Name
                        Disabled = [bool]$_.Disabled
                        Lockout = [bool]$_.Lockout
                        SID = [string]$_.SID
                    }
                })
                # Zero local accounts returned is NoData; query success alone is not account-health assessment.
            }
            'Hardware' {
                # Read-only direct CIM inventory. Preserve type per record for report clarity.
                $computer = Get-CimInstance -ClassName Win32_ComputerSystem -ErrorAction Stop
                $bios = Get-CimInstance -ClassName Win32_BIOS -ErrorAction Stop
                $processors = @(Get-CimInstance -ClassName Win32_Processor -ErrorAction Stop)
                $drives = @(Get-CimInstance -ClassName Win32_DiskDrive -ErrorAction Stop)
                if ($null -eq $computer -or $null -eq $bios -or $processors.Count -eq 0) {
                    throw 'Essential local hardware inventory was missing; collection cannot be verified.'
                }
                $records = New-Object System.Collections.Generic.List[object]
                $records.Add([pscustomobject]@{
                    RecordType = 'Computer'
                    Manufacturer = [string]$computer.Manufacturer
                    Model = [string]$computer.Model
                    TotalPhysicalMemoryGB = if ($null -ne $computer.TotalPhysicalMemory) {
                        [math]::Round([double]$computer.TotalPhysicalMemory / 1GB, 2)
                    } else { $null }
                })
                $records.Add([pscustomobject]@{
                    RecordType = 'BIOS'
                    Manufacturer = [string]$bios.Manufacturer
                    SMBIOSBIOSVersion = [string]$bios.SMBIOSBIOSVersion
                    SerialNumber = [string]$bios.SerialNumber
                })
                foreach ($cpu in $processors) {
                    $records.Add([pscustomobject]@{
                        RecordType = 'Processor'
                        Name = [string]$cpu.Name
                        NumberOfCores = $cpu.NumberOfCores
                        NumberOfLogicalProcessors = $cpu.NumberOfLogicalProcessors
                    })
                }
                foreach ($disk in $drives) {
                    $records.Add([pscustomobject]@{
                        RecordType = 'PhysicalDisk'
                        Model = [string]$disk.Model
                        InterfaceType = [string]$disk.InterfaceType
                        SizeGB = if ($null -ne $disk.Size) {
                            [math]::Round([double]$disk.Size / 1GB, 2)
                        } else { $null }
                    })
                }
                $result.Data = @($records.ToArray())
            }
            'Network' {
                # Keep the v1.27 IP-enabled fields for report compatibility; add
                # connection-aware adapter inventory without network probes or elevation.
                # Include Windows-named disconnected/disabled adapters where available.
                $configs = @(Get-CimInstance -ClassName Win32_NetworkAdapterConfiguration -ErrorAction Stop)
                $configByIndex = @{}
                foreach ($config in $configs) {
                    $configByIndex[[int]$config.Index] = $config
                }
                $adapters = @(Get-CimInstance -ClassName Win32_NetworkAdapter -ErrorAction Stop |
                    Where-Object {
                        (-not [string]::IsNullOrWhiteSpace([string]$_.NetConnectionID)) -or
                        ($configByIndex.ContainsKey([int]$_.Index) -and [bool]$configByIndex[[int]$_.Index].IPEnabled)
                    } | Sort-Object Index)
                $result.Data = @($adapters | ForEach-Object {
                    $adapter = $_
                    $config = $configByIndex[[int]$adapter.Index]
                    # Win32_NetworkAdapter.NetConnectionStatus: 2 = Connected;
                    # null means Windows did not report a connection state.
                    $connectionCode = $adapter.NetConnectionStatus
                    $connectionState = if ($null -eq $connectionCode) { 'UNKNOWN' }
                        elseif ([int]$connectionCode -eq 2) { 'Connected' }
                        elseif ([int]$connectionCode -eq 7) { 'Media disconnected' }
                        elseif ([int]$connectionCode -eq 0) { 'Disconnected' }
                        elseif ([int]$connectionCode -eq 4) { 'Hardware not present' }
                        elseif ([int]$connectionCode -eq 5) { 'Hardware disabled' }
                        else { 'State code ' + [string]$connectionCode }
                    [pscustomobject]@{
                        RecordType = 'NetworkAdapter'
                        Name = [string]$adapter.NetConnectionID
                        Description = [string]$adapter.Description
                        InterfaceIndex = if ($null -ne $adapter.InterfaceIndex) { [int]$adapter.InterfaceIndex } else { $null }
                        WmiAdapterIndex = [int]$adapter.Index
                        MACAddress = [string]$adapter.MACAddress
                        ConnectionStatus = $connectionState
                        NetEnabled = if ($null -ne $adapter.NetEnabled) { [bool]$adapter.NetEnabled } else { $null }
                        PhysicalAdapter = if ($null -ne $adapter.PhysicalAdapter) { [bool]$adapter.PhysicalAdapter } else { $null }
                        SpeedMbps = if ($connectionState -eq 'Connected' -and $null -ne $adapter.Speed -and
                            [decimal]$adapter.Speed -gt 0 -and
                            [decimal]$adapter.Speed -ne [decimal][long]::MaxValue -and
                            [decimal]$adapter.Speed -ne [decimal][uint64]::MaxValue) {
                            [math]::Round([double]$adapter.Speed / 1000000, 1)
                        } else { $null }
                        IPEnabled = if ($null -ne $config) { [bool]$config.IPEnabled } else { $false }
                        DHCPEnabled = if ($null -ne $config) { [bool]$config.DHCPEnabled } else { $false }
                        DHCPServer = if ($null -ne $config) { [string]$config.DHCPServer } else { '' }
                        DHCPLeaseObtained = if ($null -ne $config -and $config.DHCPEnabled) { [string]$config.DHCPLeaseObtained } else { '' }
                        DHCPLeaseExpires = if ($null -ne $config -and $config.DHCPEnabled) { [string]$config.DHCPLeaseExpires } else { '' }
                        IPAddresses = if ($null -ne $config) { (@($config.IPAddress | Where-Object { $_ }) -join ', ') } else { '' }
                        SubnetMasks = if ($null -ne $config) { (@($config.IPSubnet | Where-Object { $_ }) -join ', ') } else { '' }
                        DefaultGateways = if ($null -ne $config) { (@($config.DefaultIPGateway | Where-Object { $_ }) -join ', ') } else { '' }
                        DNSServers = if ($null -ne $config) { (@($config.DNSServerSearchOrder | Where-Object { $_ }) -join ', ') } else { '' }
                        DNSDomain = if ($null -ne $config) { [string]$config.DNSDomain } else { '' }
                        DNSHostName = if ($null -ne $config) { [string]$config.DNSHostName } else { '' }
                        DNSDomainSuffixSearchOrder = if ($null -ne $config) {
                            (@($config.DNSDomainSuffixSearchOrder | Where-Object { $_ }) -join ', ')
                        } else { '' }
                    }
                })
                # Route evidence uses the Windows active route table; no route is changed.
                # Preserve adapter results if the NetTCPIP route provider is unavailable.
                $networkRecords = New-Object System.Collections.Generic.List[object]
                foreach ($adapterRow in @($result.Data)) { $networkRecords.Add($adapterRow) }
                try {
                    $routes = @(Get-NetRoute -PolicyStore ActiveStore -ErrorAction Stop |
                        Sort-Object AddressFamily,DestinationPrefix,InterfaceIndex,RouteMetric,NextHop)
                    $interfacesByKey = @{}
                    foreach ($netInterface in @(Get-NetIPInterface -ErrorAction Stop)) {
                        $key = ([string]$netInterface.InterfaceIndex + '|' + [string]$netInterface.AddressFamily)
                        $interfacesByKey[$key] = $netInterface
                    }
                    # Default-route summary comes first, with connection state.
                    # Metrics describe route preference, not verified path selection.
                    foreach ($route in @($routes | Where-Object {
                        $_.DestinationPrefix -eq '0.0.0.0/0' -or $_.DestinationPrefix -eq '::/0'
                    } | Sort-Object AddressFamily,InterfaceAlias,NextHop)) {
                        $key = ([string]$route.InterfaceIndex + '|' + [string]$route.AddressFamily)
                        $netInterface = $interfacesByKey[$key]
                        $interfaceMetric = if ($null -ne $netInterface) { $netInterface.InterfaceMetric } else { $null }
                        $networkRecords.Add([pscustomobject]@{
                            RecordType = 'DefaultRoute'
                            AddressFamily = [string]$route.AddressFamily
                            DestinationPrefix = [string]$route.DestinationPrefix
                            NextHop = [string]$route.NextHop
                            InterfaceIndex = [int]$route.InterfaceIndex
                            InterfaceAlias = [string]$route.InterfaceAlias
                            ConnectionState = if ($null -ne $netInterface) { [string]$netInterface.ConnectionState } else { 'Unknown' }
                            RouteMetric = $route.RouteMetric
                            InterfaceMetric = $interfaceMetric
                            CombinedMetric = if ($null -ne $interfaceMetric -and $null -ne $route.RouteMetric) {
                                [long]$route.RouteMetric + [long]$interfaceMetric
                            } else { $null }
                            Note = 'Listed default route; not proof that Windows selected or can reach this gateway.'
                        })
                    }
                    $networkRecords.Add([pscustomobject]@{
                        RecordType = 'RouteSummary'
                        Table = 'ActiveStore'
                        RouteCount = $routes.Count
                        Note = 'Active Windows routes only; listed routes are not evidence of reachability or a persistent route.'
                    })
                    foreach ($route in $routes) {
                        $key = ([string]$route.InterfaceIndex + '|' + [string]$route.AddressFamily)
                        $netInterface = $interfacesByKey[$key]
                        $interfaceMetric = if ($null -ne $netInterface) { $netInterface.InterfaceMetric } else { $null }
                        $networkRecords.Add([pscustomobject]@{
                            RecordType = 'ActiveRoute'
                            AddressFamily = [string]$route.AddressFamily
                            DestinationPrefix = [string]$route.DestinationPrefix
                            NextHop = [string]$route.NextHop
                            InterfaceIndex = [int]$route.InterfaceIndex
                            InterfaceAlias = [string]$route.InterfaceAlias
                            RouteMetric = $route.RouteMetric
                            InterfaceMetric = $interfaceMetric
                            CombinedMetric = if ($null -ne $interfaceMetric -and $null -ne $route.RouteMetric) {
                                [long]$route.RouteMetric + [long]$interfaceMetric
                            } else { $null }
                            State = [string]$route.State
                            PolicyStore = 'ActiveStore'
                        })
                    }
                } catch {
                    $networkRecords.Add([pscustomobject]@{
                        RecordType = 'RouteCollection'
                        Status = 'UNAVAILABLE'
                        Detail = [string]$_.Exception.Message
                    })
                    $result.Status = 'PARTIAL / UNAVAILABLE'
                    $result.StatusCategory = 'Partial'
                }
                $result.Data = @($networkRecords.ToArray())
            }
            'Storage' {
                # Match the existing remote disk-space report: fixed logical disks only.
                # Local CIM does not require remote WinRM, ADMIN$, or alternate credentials.
                $disks = @(Get-CimInstance -ClassName Win32_LogicalDisk -Filter 'DriveType=3' -ErrorAction Stop)
                $result.Data = @($disks | Sort-Object DeviceID | ForEach-Object {
                    $capacity = if ($null -ne $_.Size) { [double]$_.Size } else { $null }
                    $free = if ($null -ne $_.FreeSpace) { [double]$_.FreeSpace } else { $null }
                    [pscustomobject]@{
                        DeviceID = [string]$_.DeviceID
                        VolumeName = [string]$_.VolumeName
                        SizeGB = if ($null -ne $capacity) { [math]::Round($capacity / 1GB, 2) } else { $null }
                        FreeGB = if ($null -ne $free) { [math]::Round($free / 1GB, 2) } else { $null }
                        FreePercent = if ($null -ne $capacity -and $capacity -gt 0 -and $null -ne $free) {
                            [math]::Round(100 * $free / $capacity, 1)
                        } else { $null }
                    }
                })
                # An empty fixed-drive query is NoData; it is not evidence of zero free space.
            }
            'Services' {
                # Match the existing remote Services report: automatic-start
                # services whose current state is not Running. Read only.
                # An empty finding list is still a successful query, not NoData.
                $services = @(Get-CimInstance -ClassName Win32_Service -ErrorAction Stop)
                if ($services.Count -eq 0) {
                    throw 'The local service query returned no service records; collection cannot be verified.'
                }
                $stopped = @($services | Where-Object {
                    $_.StartMode -eq 'Auto' -and $_.State -ne 'Running'
                } | Sort-Object Name)
                $records = New-Object System.Collections.Generic.List[object]
                $records.Add([pscustomobject]@{
                    RecordType = 'Summary'
                    ServicesQueried = $services.Count
                    AutomaticNotRunning = $stopped.Count
                    Note = if ($stopped.Count -eq 0) {
                        'No nonrunning automatic-start services found. Collection success does not establish overall health.'
                    } else {
                        'Automatic-start services not currently running; some may be trigger-start or intentionally stopped.'
                    }
                })
                foreach ($svc in $stopped) {
                    $records.Add([pscustomobject]@{
                        RecordType = 'Service'
                        Name = [string]$svc.Name
                        DisplayName = [string]$svc.DisplayName
                        State = [string]$svc.State
                        StartMode = [string]$svc.StartMode
                    })
                }
                $result.Data = @($records.ToArray())
            }
            'Firewall' {
                # A disabled firewall profile is observable configuration data,
                # not a failed collection and not automatically a health verdict.
                $profiles = @(Get-NetFirewallProfile -ErrorAction Stop)
                $result.Data = @($profiles | ForEach-Object {
                    [pscustomobject]@{
                        Name = [string]$_.Name
                        Enabled = [bool]$_.Enabled
                        DefaultInboundAction = [string]$_.DefaultInboundAction
                        DefaultOutboundAction = [string]$_.DefaultOutboundAction
                    }
                })
            }
        }
        if ($result.StatusCategory -eq 'Partial' -or
            ($Section -eq 'System' -and $result.StatusCategory -eq 'Unavailable' -and @($result.Data).Count -gt 0)) {
            # Preserve explicitly calculated partial or all-unavailable System evidence.
        } elseif (@($result.Data).Count -gt 0) {
            $result.Status = 'SUCCESS'
            $result.StatusCategory = 'Success'
        } else {
            $result.Status = 'NO RESULTS'
            $result.StatusCategory = 'NoData'
        }
    } catch {
        $message = [string]$_.Exception.Message
        $denied = $_.Exception -is [System.UnauthorizedAccessException] -or
            $message -match '(?i)access is denied|access denied|0x80070005|unauthorized'
        $result.Status = if ($denied) { 'ACCESS DENIED' } else { 'UNAVAILABLE' }
        $result.StatusCategory = if ($denied) { 'AccessDenied' } else { 'Unavailable' }
        $result.Error = $message
    }

    # Return a new result with no credential or process-token object embedded.
    return [pscustomobject]$result
}


# Explicit UAC handoff supports consent elevation and a separate administrator
# account supplied to Windows. The initiating process never handles credentials.
function Invoke-ToolkitElevatedLocalDiagnostic {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [ValidateSet('BitLocker','Policy')]
        [string]$Section,
        [switch]$AllowCurrentUserRemoteSigned
    )
    $initiator = [Security.Principal.WindowsIdentity]::GetCurrent()
    $modulePath = Join-Path $PSScriptRoot 'ITToolkit-LocalDiagnostics.ps1'
    $exe = Join-Path $PSHOME 'powershell.exe'
    $directory = Join-Path $env:TEMP ('ITToolkit-Elevated-' + [guid]::NewGuid().ToString('N'))
    [void](New-Item -ItemType Directory -Path $directory -ErrorAction Stop)
    try {
        # Separate UAC administrator identities need access to the transfer folder.
        # Never grant Everyone, Users, or Authenticated Users access. Windows UAC
        # must approve the administrator process; the initiating account only
        # reads the result after the child exits.
        $acl = New-Object System.Security.AccessControl.DirectorySecurity
        $acl.SetAccessRuleProtection($true,$false)
        foreach ($account in @($initiator.User,
            (New-Object System.Security.Principal.SecurityIdentifier('S-1-5-32-544')),
            (New-Object System.Security.Principal.SecurityIdentifier('S-1-5-18')))) {
            $rule = New-Object System.Security.AccessControl.FileSystemAccessRule(
                $account,'FullControl','ContainerInherit,ObjectInherit','None','Allow')
            $acl.AddAccessRule($rule)
        }
        (Get-Item -LiteralPath $directory).SetAccessControl($acl)
        $outputFile = Join-Path $directory 'report.clixml'
        $errorFile = Join-Path $directory 'error.clixml'
        $statusFile = Join-Path $directory 'child-stage.txt'
        $nonce = [guid]::NewGuid().ToString('N')
        $safeModule = "'" + $modulePath.Replace("'","''") + "'"
        $safeOutput = "'" + $outputFile.Replace("'","''") + "'"
        $safeError = "'" + $errorFile.Replace("'","''") + "'"
        $safeStatus = "'" + $statusFile.Replace("'","''") + "'"
        $safeSection = "'" + $Section + "'"
        $safeNonce = "'" + $nonce + "'"
        $allowPolicy = if ($AllowCurrentUserRemoteSigned.IsPresent) { '$true' } else { '$false' }
        # All generated parameters are escaped literals or validated choices.
        # Errors are returned as data, not hidden by a detached child process.
        $child = @'
$ErrorActionPreference = 'Stop'
try {
    # Non-secret diagnostic checkpoint; restricted by the handoff folder ACL.
    [IO.File]::WriteAllText(__STATUS__, 'child-started')
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object System.Security.Principal.WindowsPrincipal -ArgumentList $identity
    if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        throw 'The Windows UAC process does not have an elevated administrator token.'
    }
    # Persistently changing CurrentUser execution policy is allowed only after
    # the initiating technician explicitly approved that separate action.
    $previousPolicy = [string](Get-ExecutionPolicy)
    $policyChanged = $false
    if ($previousPolicy -eq 'Restricted' -and __ALLOW_POLICY__) {
        $scopes = @(Get-ExecutionPolicy -List)
        $machinePolicy = @($scopes | Where-Object { $_.Scope -eq 'MachinePolicy' } |
            Select-Object -First 1 -ExpandProperty ExecutionPolicy)
        $userPolicy = @($scopes | Where-Object { $_.Scope -eq 'UserPolicy' } |
            Select-Object -First 1 -ExpandProperty ExecutionPolicy)
        if ($machinePolicy.Count -ne 1 -or $userPolicy.Count -ne 1 -or
            [string]$machinePolicy[0] -ne 'Undefined' -or
            [string]$userPolicy[0] -ne 'Undefined') {
            throw 'PowerShell execution policy is managed by Group Policy or could not be verified. IT Toolkit will not change it.'
        }
        Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned -Force -ErrorAction Stop
        if ([string](Get-ExecutionPolicy) -ne 'RemoteSigned') {
            throw 'RemoteSigned did not become the effective PowerShell policy. The module was not loaded.'
        }
        $policyChanged = $true
    }
    . __MODULE__
    $diagnosticResult = Get-ToolkitLocalDiagnostic -Section __SECTION__
    [pscustomobject]@{
        Nonce = __NONCE__
        CollectionIdentity = $identity.Name
        CollectionSid = $identity.User.Value
        IsElevated = $true
        PolicyChanged = $policyChanged
        PreviousExecutionPolicy = $previousPolicy
        EffectiveExecutionPolicy = [string](Get-ExecutionPolicy)
        Result = $diagnosticResult
    } | Export-Clixml -LiteralPath __OUTPUT__ -ErrorAction Stop
    [IO.File]::WriteAllText(__STATUS__, 'result-written')
} catch {
    try {
        [pscustomobject]@{
            Nonce = __NONCE__
            CollectionIdentity = [Security.Principal.WindowsIdentity]::GetCurrent().Name
            PolicyChanged = $policyChanged
            PreviousExecutionPolicy = $previousPolicy
            EffectiveExecutionPolicy = [string](Get-ExecutionPolicy)
            Error = [string]$_.Exception.Message
        } | Export-Clixml -LiteralPath __ERROR__ -ErrorAction Stop
    } catch { }
    exit 1
}
'@
        $child = $child.Replace('__MODULE__',$safeModule)
        $child = $child.Replace('__SECTION__',$safeSection)
        $child = $child.Replace('__OUTPUT__',$safeOutput)
        $child = $child.Replace('__ERROR__',$safeError)
        $child = $child.Replace('__STATUS__',$safeStatus)
        $child = $child.Replace('__NONCE__',$safeNonce)
        $child = $child.Replace('__ALLOW_POLICY__',$allowPolicy)
        $encoded = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($child))
        try {
            $process = Start-Process -FilePath $exe -ArgumentList @(
                '-NoProfile','-NonInteractive','-EncodedCommand',$encoded
            ) -Verb RunAs -Wait -PassThru -ErrorAction Stop
        } catch {
            if ($_.Exception -is [System.ComponentModel.Win32Exception] -and
                $_.Exception.NativeErrorCode -eq 1223) {
                throw 'Windows UAC approval was cancelled. No elevated diagnostic was collected.'
            }
            throw ('Windows could not start the elevated diagnostic: ' + [string]$_.Exception.Message)
        }
        if (Test-Path -LiteralPath $errorFile -PathType Leaf) {
            $childError = Import-Clixml -LiteralPath $errorFile -ErrorAction Stop
            if ([string]$childError.Nonce -eq $nonce) {
                $childMessage = [string]$childError.Error
                $childAccount = [string]$childError.CollectionIdentity
                if ([bool]$childError.PolicyChanged) {
                    $childMessage = ("CurrentUser policy for {0} was changed from {1} to {2}, but the diagnostic failed: {3}" -f
                        $childAccount, [string]$childError.PreviousExecutionPolicy,
                        [string]$childError.EffectiveExecutionPolicy, $childMessage)
                }
                if ($childMessage -match '(?i)running scripts is disabled|cannot be loaded because|execution.polic|PSSecurityException|UnauthorizedAccess.*script') {
                    $detail = ("Windows PowerShell execution policy blocked the local diagnostic module under {0}. " +
                        "The administrator UAC sign-in succeeded, but the collector was NOT run. " +
                        "Review the effective policy for that administrative account with Get-ExecutionPolicy -List " +
                        "and consult your organization's approved signed-script or execution-policy deployment process. " +
                        "IT Toolkit will not override execution policy. Original error: {1}")
                    throw ($detail -f $childAccount, $childMessage)
                }
                throw ("Elevated diagnostic under {0} failed: {1}" -f $childAccount, $childMessage)
            }
        }
        if (-not (Test-Path -LiteralPath $outputFile -PathType Leaf)) {
            $stage = 'no child checkpoint found'
            if (Test-Path -LiteralPath $statusFile -PathType Leaf) {
                try { $stage = [IO.File]::ReadAllText($statusFile).Trim() }
                catch { $stage = 'child checkpoint exists but cannot be read' }
            }
            $message = ("Elevated diagnostic returned no accessible result (exit code {0}; stage: {1}). " +
                "No report was collected. 'no child checkpoint found' suggests the child command did not reach " +
                "its first file write or lacked access to the protected folder. 'child-started' means " +
                "the child began execution but did not complete the report handoff. " +
                "Check UAC identity, toolkit file access, temporary-folder permissions, and endpoint security.")
            throw ($message -f $process.ExitCode,$stage)
        }
        if ($process.ExitCode -ne 0) {
            throw ("Elevated process exited with code {0}; its output was discarded." -f $process.ExitCode)
        }
        $payload = Import-Clixml -LiteralPath $outputFile -ErrorAction Stop
        if ([string]$payload.Nonce -cne $nonce -or
            -not [bool]$payload.IsElevated -or
            [string]::IsNullOrWhiteSpace([string]$payload.CollectionIdentity) -or
            [string]::IsNullOrWhiteSpace([string]$payload.CollectionSid)) {
            throw 'Elevated diagnostic result failed identity or request validation.'
        }
        if ($null -eq $payload.Result -or [string]$payload.Result.Section -ne $Section -or
            [string]$payload.Result.Target -ine $env:COMPUTERNAME -or
            [string]$payload.Result.Mode -ne 'Local') {
            throw 'Elevated diagnostic returned data for an unexpected section, target, or mode.'
        }
        # Do not relabel an administrator account as the initiating technician.
        $result = $payload.Result
        $result | Add-Member -NotePropertyName InitiatingIdentity -NotePropertyValue $initiator.Name -Force
        $result | Add-Member -NotePropertyName CollectionIdentity -NotePropertyValue ([string]$payload.CollectionIdentity) -Force
        $result | Add-Member -NotePropertyName CollectionSid -NotePropertyValue ([string]$payload.CollectionSid) -Force
        $result | Add-Member -NotePropertyName Authorization -NotePropertyValue 'Windows UAC' -Force
        $result | Add-Member -NotePropertyName ExecutionPolicyChanged -NotePropertyValue ([bool]$payload.PolicyChanged) -Force
        $result | Add-Member -NotePropertyName ExecutionPolicyBefore -NotePropertyValue ([string]$payload.PreviousExecutionPolicy) -Force
        $result | Add-Member -NotePropertyName ExecutionPolicyAfter -NotePropertyValue ([string]$payload.EffectiveExecutionPolicy) -Force
        return $result
    } finally {
        Remove-Item -LiteralPath $directory -Recurse -Force -ErrorAction SilentlyContinue
    }
}
