# IT Toolkit v1.24 - dot-sourced component; loaded in parent script scope.
function Run-External([string]$Exe, [string[]]$Arguments = @()) {
    Write-Host "`nRunning: $Exe $($Arguments -join ' ')" -ForegroundColor Cyan
    try { & $Exe @Arguments; if ($LASTEXITCODE -and $LASTEXITCODE -ne 0) { Write-Host "Exit code: $LASTEXITCODE" -ForegroundColor Yellow } }
    catch { Write-Host $_.Exception.Message -ForegroundColor Red }
    Write-Host ''
    Pause-Toolkit
}
function Start-Gui([string]$File, [string[]]$Arguments = @()) {
    try {
        if ($Arguments.Count -gt 0) { Start-Process -FilePath $File -ArgumentList $Arguments -ErrorAction Stop }
        else { Start-Process -FilePath $File -ErrorAction Stop }
        Write-Host 'Opened in a separate window.' -ForegroundColor Green
    } catch { Write-Host "Could not launch $File : $($_.Exception.Message)" -ForegroundColor Red }
    Pause-Toolkit
}
function Get-SysTool([string[]]$Candidates) {
    if (-not $script:SysinternalsFolder) {
        Write-Host 'Sysinternals Store installation not found. Enter its Tools folder from the main menu.' -ForegroundColor Yellow
        Pause-Toolkit
        return $null
    }
    foreach ($name in $Candidates) {
        $path = Join-Path $script:SysinternalsFolder $name
        if (Test-Path -LiteralPath $path -PathType Leaf) { return $path }
    }
    Write-Host "Utility not found in: $script:SysinternalsFolder" -ForegroundColor Yellow
    Pause-Toolkit
    return $null
}
function Run-Sys([string[]]$Names,[string[]]$Args = @()) {
    $exe = Get-SysTool $Names
    if ($exe) { Run-External $exe $Args }
}
function Run-RemoteSys([string[]]$Names,[string[]]$Extra = @()) {
    $target = Get-Target
    if ($target) { Run-Sys $Names (@("\\$target") + $Extra) }
}
function Ask-Port {
    $port = (Read-Host 'TCP port (1-65535; B/blank = cancel)').Trim()
    if (-not $port -or $port -ieq 'B') { return $null }
    if ($port -notmatch '^\d{1,5}$' -or [int]$port -lt 1 -or [int]$port -gt 65535) {
        Write-Host 'Invalid port.' -ForegroundColor Yellow; Pause-Toolkit; return $null
    }
    return [int]$port
}
function Menu-Sysinternals {
    while ($true) {
        Show-Header 'Sysinternals'
        Write-Host ' 1 PsInfo       - Remote OS, uptime, and hardware details'
        Write-Host ' 2 PsList       - View remote running processes'
        Write-Host ' 3 PsService    - View remote Windows services'
        Write-Host ' 4 PsLoggedOn   - Find users logged on to the target'
        Write-Host ' 5 PsLogList    - Read the remote System event log'
        Write-Host ' 6 PsFile       - Show files opened remotely via file shares'
        Write-Host ' 7 PsPing       - Check a remote TCP port'
        Write-Host ' 8 PsExec       - Open a remote command prompt'
        Write-Host ' 9 PsKill       - Terminate a remote process (confirmation)'
        Write-Host '10 PsShutdown   - Restart the remote computer (confirmation)'
        Write-Host '11 ShareEnum    - Browse network shares (GUI)'
        Write-Host '------------------------------------------------------------' -ForegroundColor DarkGray
        Write-Host ' B Back to main menu'
        Write-Host '------------------------------------------------------------' -ForegroundColor DarkGray
        Write-Host ''
        $choice = (Read-Host 'Choose').Trim()
        switch ($choice.ToUpperInvariant()) {
            '1' { Run-RemoteSys @('PsInfo64.exe','PsInfo.exe') }
            '2' { Run-RemoteSys @('PsList64.exe','PsList.exe') }
            '3' { Run-RemoteSys @('PsService64.exe','PsService.exe') @('query') }
            '4' { Run-RemoteSys @('PsLoggedon64.exe','PsLoggedon.exe') }
            '5' { Run-RemoteSys @('PsLogList64.exe','PsLogList.exe') @('-s','System') }
            '6' { Run-RemoteSys @('PsFile64.exe','PsFile.exe') }
            '7' { $t=Get-Target; if ($t) { $p=Ask-Port; if ($p) { Run-Sys @('PsPing64.exe','PsPing.exe') @("${t}:$p") } } }
            '8' { $t=Get-Target; if ($t) { Write-Host 'Remote command prompt: type exit to return.' -ForegroundColor Yellow; Run-Sys @('PsExec64.exe','PsExec.exe') @("\\$t",'cmd.exe') } }
            '9' { $t=Get-Target; if ($t) { $pidText=(Read-Host 'PID to terminate (B to cancel)').Trim(); if ($pidText -match '^\d+$' -and (Read-Host "Type KILL to end PID $pidText on $t") -ceq 'KILL') { Run-Sys @('PsKill64.exe','PsKill.exe') @("\\$t",$pidText) } } }
            '10' { $t=Get-Target; if ($t -and (Read-Host "Type RESTART to reboot $t immediately") -ceq 'RESTART') { Run-Sys @('PsShutdown64.exe','PsShutdown.exe') @("\\$t",'-r','-t','0') } }
            '11' { $exe=Get-SysTool @('ShareEnum64.exe','ShareEnum.exe'); if ($exe) { Start-Gui $exe } }
            'B' { return }
            '0' { return }
        }
    }
}
function Set-PortQryPath {
    Write-Host "`nCurrent PortQry executable: $PortQryExecutable" -ForegroundColor Cyan
    $entered = (Read-Host 'Enter PortQry executable or folder (B/blank = cancel)').Trim().Trim('"')
    if (-not $entered -or $entered -ieq 'B') { return }
    $candidate = $entered
    if (Test-Path -LiteralPath $candidate -PathType Container) {
        $candidate = Join-Path $candidate 'portqry.exe'
    }
    if (-not (Test-Path -LiteralPath $candidate -PathType Leaf) -or
        [System.IO.Path]::GetFileName($candidate) -ine 'portqry.exe') {
        Write-Host 'Could not find portqry.exe at that location. No changes made.' -ForegroundColor Yellow
        Pause-Toolkit
        return
    }
    $script:PortQryExecutable = (Resolve-Path -LiteralPath $candidate).ProviderPath
    Write-Host "PortQry path set to: $script:PortQryExecutable" -ForegroundColor Green
    try {
        $script:Config.PortQryPath = $script:PortQryExecutable
        if (-not (Save-ToolkitConfig)) { throw 'Configuration could not be saved.' }
        Write-Host 'Path saved for future launches.' -ForegroundColor Green
    } catch {
        Write-Host 'Path works for this session, but could not save the setting.' -ForegroundColor Yellow
        Write-Host $_.Exception.Message -ForegroundColor Yellow
    }
    Pause-Toolkit
}
function Run-PortQry {
    $target = Get-Target
    if (-not $target) { return }
    if (-not (Test-Path -LiteralPath $PortQryExecutable -PathType Leaf)) {
        Write-Host "PortQry was not found at: $PortQryExecutable" -ForegroundColor Yellow
        Write-Host 'Check that the extracted folder contains portqry.exe.' -ForegroundColor Yellow
        Pause-Toolkit
        return
    }
    $portText = (Read-Host 'Port to query (1-65535; B/blank = cancel)').Trim()
    if (-not $portText -or $portText -ieq 'B') { return }
    if ($portText -notmatch '^\d{1,5}$' -or [int]$portText -lt 1 -or [int]$portText -gt 65535) {
        Write-Host 'Invalid port.' -ForegroundColor Yellow
        Pause-Toolkit
        return
    }
    $protocol = (Read-Host 'Protocol: T = TCP, U = UDP, B = back [T]').Trim().ToUpperInvariant()
    if ($protocol -eq 'B') { return }
    if (-not $protocol -or $protocol -eq 'T') { $protocol = 'TCP' }
    elseif ($protocol -eq 'U') { $protocol = 'UDP' }
    else { Write-Host 'Invalid protocol.' -ForegroundColor Yellow; Pause-Toolkit; return }
    Run-External $PortQryExecutable @('-n', $target, '-e', $portText, '-p', $protocol)
}
function Menu-Network {
    while ($true) {
        Show-Header 'Network Diagnostics'
        Write-Host ' 1 Ping target          - Test basic network reachability'
        Write-Host ' 2 Trace route          - Show network hops to target'
        Write-Host ' 3 DNS lookup           - Resolve hostname and address via DNS'
        Write-Host ' 4 Test TCP port        - Check a specific TCP service port'
        Write-Host ' 5 List network shares  - Show shares published by the target'
        Write-Host ' 6 PortQry              - Query target TCP or UDP port'
        Write-Host '------------------------------------------------------------' -ForegroundColor DarkGray
        Write-Host ' B Back to main menu'
        Write-Host '------------------------------------------------------------' -ForegroundColor DarkGray
        Write-Host ''
        $choice=(Read-Host 'Choose').Trim().ToUpperInvariant()
        switch ($choice) {
            '1' { $t=Get-Target; if ($t) { Run-External 'ping.exe' @('-n','4',$t) } }
            '2' { $t=Get-Target; if ($t) { Run-External 'tracert.exe' @('-d',$t) } }
            '3' { $t=Get-Target; if ($t) { Run-External 'nslookup.exe' @($t) } }
            '4' { $t=Get-Target; if ($t) { $p=Ask-Port; if ($p) { try { Test-NetConnection -ComputerName $t -Port $p -InformationLevel Detailed | Format-List * | Out-Host } catch { Write-Host $_.Exception.Message -ForegroundColor Red }; Pause-Toolkit } } }
            '5' { $t=Get-Target; if ($t) { Run-External 'net.exe' @('view',"\\$t") } }
            '6' { Run-PortQry }
            'B' { return }
            '0' { return }
        }
    }
}
function Menu-Windows {
    while ($true) {
        Show-Header 'Windows Administration'
        Write-Host ' 1 Remote Event Viewer  - Inspect remote Windows event logs'
        Write-Host ' 2 Computer Management  - Manage remote shares, services, etc.'
        Write-Host ' 3 Query services       - List remote Windows services'
        Write-Host ' 4 System information   - Display remote systeminfo details'
        Write-Host ' 5 Performance Monitor  - Open GUI; select remote counters'
        Write-Host '------------------------------------------------------------' -ForegroundColor DarkGray
        Write-Host ' B Back to main menu'
        Write-Host '------------------------------------------------------------' -ForegroundColor DarkGray
        Write-Host ''
        $choice=(Read-Host 'Choose').Trim().ToUpperInvariant()
        switch ($choice) {
            '1' { $t=Get-Target; if ($t) { Start-Gui 'eventvwr.exe' @("/computer:$t") } }
            '2' { $t=Get-Target; if ($t) { Start-Gui 'compmgmt.msc' @("/computer:$t") } }
            '3' { $t=Get-Target; if ($t) { Run-External 'sc.exe' @("\\$t",'query') } }
            '4' { $t=Get-Target; if ($t) { Run-External 'systeminfo.exe' @('/s',$t) } }
            '5' { Start-Gui 'perfmon.exe' }
            'B' { return }
            '0' { return }
        }
    }
}
function Menu-AD {
    while ($true) {
        Show-Header 'Active Directory / Group Policy'
        Write-Host ' 1 AD Users and Computers - Manage domain users, PCs, and OUs'
        Write-Host ' 2 DNS Manager           - Inspect and manage DNS records'
        Write-Host ' 3 Group Policy Mgmt     - View and administer domain GPOs'
        Write-Host ' 4 Group Policy Results  - Show target computer GPO results'
        Write-Host ' 5 AD Explorer (ADViewer) - Browse AD objects and attributes'
        Write-Host '------------------------------------------------------------' -ForegroundColor DarkGray
        Write-Host ' B Back to main menu'
        Write-Host '------------------------------------------------------------' -ForegroundColor DarkGray
        Write-Host ''
        $choice=(Read-Host 'Choose').Trim().ToUpperInvariant()
        switch ($choice) {
            '1' { Start-Gui 'dsa.msc' }
            '2' { Start-Gui 'dnsmgmt.msc' }
            '3' { Start-Gui 'gpmc.msc' }
            '4' { $t=Get-Target; if ($t) { Run-External 'gpresult.exe' @('/S',$t,'/SCOPE','COMPUTER','/R') } }
            '5' { $exe=Get-SysTool @('ADExplorer.exe','ADExplorer64.exe'); if ($exe) { Start-Gui $exe } }
            'B' { return }
            '0' { return }
        }
    }
}
