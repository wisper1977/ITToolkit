# IT Toolkit configuration - dot-sourced component; loaded in parent script scope.
# Single portable configuration file. All persistent settings live here.
# Always use the root path initialized by ITToolkit.ps1, never the Modules directory.
if (-not $script:ToolkitRoot) { throw 'ToolkitRoot was not initialized by ITToolkit.ps1.' }
$script:ConfigPath = Join-Path $script:ToolkitRoot 'Toolkit-config.json'

$script:Config = [ordered]@{
    Version          = 'Unknown'
    SysinternalsPath = 'Auto'
    PortQryPath = 'C:\PortQryV2\portqry.exe'
    ReportFolder = 'Reports'
    ReportFormat = 'HTML'
}

function Save-ToolkitConfig {
    try {
        $json = ConvertTo-Json -InputObject $script:Config -Depth 4
        [System.IO.File]::WriteAllText($script:ConfigPath, $json + [Environment]::NewLine, (New-Object System.Text.UTF8Encoding($false)))
        return $true
    } catch {
        Write-Host "Could not save toolkit configuration: $($_.Exception.Message)" -ForegroundColor Yellow
        return $false
    }
}
# The root configuration is required. Never silently create a second settings file.
if (-not (Test-Path -LiteralPath $script:ConfigPath -PathType Leaf)) {
    throw "Missing toolkit configuration file: $script:ConfigPath"
}
try {
    $loaded = Get-Content -LiteralPath $script:ConfigPath -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
    if ($null -eq $loaded -or $loaded -isnot [pscustomobject]) {
        throw 'Configuration JSON must contain an object.'
    }
    foreach ($key in @('Version','SysinternalsPath','PortQryPath','ReportFolder','ReportFormat')) {
        if ($null -ne $loaded.$key -and $loaded.$key -is [string] -and $loaded.$key.Trim()) {
            $script:Config[$key] = $loaded.$key.Trim()
        }
    }
    if ($null -eq $loaded.Version -or $loaded.Version -isnot [string] -or -not $loaded.Version.Trim()) {
        throw 'The Version setting is missing or empty.'
    }
    # Preserve additional configuration properties, including Branding and
    # AuthenticationDomain, when Classic Settings saves the configuration.
    foreach ($property in $loaded.PSObject.Properties) {
        if (-not $script:Config.Contains($property.Name)) {
            $script:Config[$property.Name] = $property.Value
        }
    }
} catch {
    throw "Cannot load toolkit configuration '$script:ConfigPath': $($_.Exception.Message)"
}
if ($script:Config.ReportFormat.ToUpperInvariant() -notin @('TXT','CSV','HTML')) { $script:Config.ReportFormat = 'HTML' }
$script:ReportFormat = $script:Config.ReportFormat.ToUpperInvariant()
$script:PortQryExecutable = $script:Config.PortQryPath
$PreferredToolsFolder = 'C:\Program Files\WindowsApps\Microsoft.SysinternalsSuite_2026.9.0.0_x64__8wekyb3d8bbwe\Tools'
function Find-SysinternalsFolder {
    $saved = $script:Config.SysinternalsPath
    if ($saved -and $saved -ne 'Auto' -and (Test-Path -LiteralPath $saved -PathType Container)) { return $saved }
    # Automatic fallback if manually configured directory no longer exists.
    foreach ($candidate in @((Join-Path $script:ToolkitRoot 'Sysinternals'), 'C:\Sysinternals', $PreferredToolsFolder)) {
        if (Test-Path -LiteralPath $candidate -PathType Container) { return $candidate }
    }
    try {
        $packages = @(Get-ChildItem 'C:\Program Files\WindowsApps' -Directory -Filter 'Microsoft.SysinternalsSuite_*_x64__8wekyb3d8bbwe' -ErrorAction Stop | Sort-Object Name -Descending)
        foreach ($package in $packages) {
            $candidate = Join-Path $package.FullName 'Tools'
            if (Test-Path -LiteralPath $candidate -PathType Container) { return $candidate }
        }
    } catch { }
    return $null
}

$script:ToolkitVersion = [string]$script:Config.Version
# Shared display branding for Classic menus, diagnostic reports and comparisons.
# These are display labels only; the Windows authentication domain is independent.
$script:OrganizationName = 'Your Organization'
$script:ApplicationName = 'IT Toolkit'
if ($script:Config.Contains('Branding') -and $null -ne $script:Config.Branding) {
    if (-not [string]::IsNullOrWhiteSpace([string]$script:Config.Branding.OrganizationName)) {
        $script:OrganizationName = ([string]$script:Config.Branding.OrganizationName).Trim()
    }
    if (-not [string]::IsNullOrWhiteSpace([string]$script:Config.Branding.ApplicationName)) {
        $script:ApplicationName = ([string]$script:Config.Branding.ApplicationName).Trim()
    }
}
$script:ToolkitDisplayName = ($script:OrganizationName + ' ' + $script:ApplicationName).Trim()

$script:SysinternalsFolder = Find-SysinternalsFolder
$script:DependencyWarnings = @()

# Verify optional external utilities at startup. This does not test remote hosts.
function Test-ToolkitDependencies {
    $warnings = New-Object System.Collections.Generic.List[string]

    $script:SysinternalsFolder = Find-SysinternalsFolder
    $hasSysinternals = $false
    if ($script:SysinternalsFolder -and (Test-Path -LiteralPath $script:SysinternalsFolder -PathType Container)) {
        foreach ($exeName in @('PsInfo64.exe', 'PsInfo.exe', 'PsExec64.exe', 'PsExec.exe')) {
            if (Test-Path -LiteralPath (Join-Path $script:SysinternalsFolder $exeName) -PathType Leaf) {
                $hasSysinternals = $true
                break
            }
        }
    }
    if (-not $hasSysinternals) {
        $warnings.Add('MICROSOFT SYSINTERNALS NOT FOUND - Check Toolkit Settings > Sysinternals folder.')
    }

    $hasPortQry = $false
    if ($script:PortQryExecutable -and (Test-Path -LiteralPath $script:PortQryExecutable -PathType Leaf)) {
        $hasPortQry = ([System.IO.Path]::GetFileName($script:PortQryExecutable) -ieq 'portqry.exe')
    }
    if (-not $hasPortQry) {
        $warnings.Add("PORTQRY NOT FOUND - Check Toolkit Settings > PortQry executable: $($script:PortQryExecutable)")
    }

    $script:DependencyWarnings = @($warnings.ToArray())
}

function Show-DependencyWarnings {
    if ($script:DependencyWarnings.Count -eq 0) { return }
    Write-Host '!!!!!!!!!!!!!!!!!!!! MISSING TOOL WARNING !!!!!!!!!!!!!!!!!!!!' -ForegroundColor Red
    foreach ($warning in $script:DependencyWarnings) {
        Write-Host "  WARNING: $warning" -ForegroundColor Red
    }
    Write-Host 'Other toolkit features remain available.' -ForegroundColor Red
    Write-Host '------------------------------------------------------------' -ForegroundColor Red
}

