# IT Toolkit v1.24 - dot-sourced component; loaded in parent script scope.
function Pause-Toolkit { [void](Read-Host 'Press Enter to return') }
function Get-Target {
    if (-not $script:TargetComputer) {
        Write-Host 'No target selected. Choose Change Target from the main menu.' -ForegroundColor Yellow
        Pause-Toolkit
        return $null
    }
    return $script:TargetComputer
}
function Resolve-TargetIPv4([string]$Computer) {
    if (-not $Computer) { return '(not selected)' }
    $ip = $null
    if ([System.Net.IPAddress]::TryParse($Computer, [ref]$ip) -and $ip.AddressFamily -eq [System.Net.Sockets.AddressFamily]::InterNetwork) { return $ip.ToString() }
    try {
        $ips = @([System.Net.Dns]::GetHostAddresses($Computer) | Where-Object { $_.AddressFamily -eq [System.Net.Sockets.AddressFamily]::InterNetwork } | ForEach-Object { $_.ToString() } | Select-Object -Unique)
        if ($ips.Count) { return ($ips -join ', ') }
        return '(no IPv4 DNS record)'
    } catch { return '(DNS lookup failed)' }
}
function Test-RemoteAdminAccess {
    if (-not $script:TargetComputer) {
        $script:AdminStatus = 'No target'
        $script:AdminDetail = 'Select a target first.'
        $script:AdminCheckedAt = $null
        return
    }
    $computer = $script:TargetComputer
    $script:AdminStatus = 'Unable to verify'
    $script:AdminDetail = 'Remote administration has not been confirmed.'
    $script:AdminCheckedAt = Get-Date
    Write-Host "Checking remote admin access to $computer..." -ForegroundColor Cyan

    # Only checks network admin-share access, not domain group membership or
    # actual remote elevation. A failed share check is not proof of no rights.
    $share = "\\$computer\ADMIN$"
    try {
        $null = Get-Item -LiteralPath $share -ErrorAction Stop
        $script:AdminStatus = 'Admin share accessible'
        $script:AdminDetail = 'ADMIN$ access succeeded; this strongly suggests remote administrative rights.'
    }
    catch [System.UnauthorizedAccessException] {
        $script:AdminStatus = 'Access denied'
        $script:AdminDetail = 'ADMIN$ explicitly denied access; other admin rights were not tested.'
    }
    catch {
        $message = $_.Exception.Message
        if ($message -match '(?i)access.*denied|unauthorized|0x80070005') {
            $script:AdminStatus = 'Access denied'
            $script:AdminDetail = 'ADMIN$ denied access; other admin rights were not tested.'
        } else {
            $script:AdminStatus = 'Unable to verify'
            $script:AdminDetail = "ADMIN$ could not be queried: $message"
        }
    }
    Write-Host "Result: $($script:AdminStatus)" -ForegroundColor $(if ($script:AdminStatus -eq 'Admin share accessible') {'Green'} elseif ($script:AdminStatus -eq 'Access denied') {'Yellow'} else {'DarkYellow'})
}

function Change-Target {
    $value = (Read-Host 'Enter target hostname or IPv4 (B/blank = cancel)').Trim()
    if (-not $value -or $value -ieq 'B') { return }
    if ($value -notmatch '^[a-zA-Z0-9_.-]+$') {
        Write-Host 'Invalid hostname or IP address.' -ForegroundColor Yellow
        Pause-Toolkit
        return
    }
    $script:LocalTargetMode = $false
    $script:TargetComputer = $value
    $script:TargetIPv4 = Resolve-TargetIPv4 $value
    Test-RemoteAdminAccess
}
function Show-Header([string]$Section) {
    Clear-Host
    Write-Host '============================================================' -ForegroundColor Cyan
    Write-Host "     $($script:ToolkitDisplayName.ToUpperInvariant()) v$ToolkitVersion - $Section" -ForegroundColor White
    Write-Host '============================================================' -ForegroundColor Cyan
    Write-Host "Current User:   $([Security.Principal.WindowsIdentity]::GetCurrent().Name)" -ForegroundColor Green
    Write-Host "Target Computer: $(if ($script:TargetComputer) {$script:TargetComputer} else {'(not selected)'})" -ForegroundColor Cyan
    Write-Host "Target IPv4:     $($script:TargetIPv4)" -ForegroundColor Cyan
    $statusColor = if ($script:AdminStatus -eq 'Admin share accessible') { 'Green' } elseif ($script:AdminStatus -eq 'Access denied') { 'Yellow' } else { 'DarkYellow' }
    Write-Host "Remote Admin:    $($script:AdminStatus)" -ForegroundColor $statusColor
    if ($script:AdminCheckedAt) { Write-Host "Last checked:    $($script:AdminCheckedAt.ToString('yyyy-MM-dd HH:mm:ss'))" -ForegroundColor DarkGray }
    Write-Host '------------------------------------------------------------'
    Show-DependencyWarnings
}
