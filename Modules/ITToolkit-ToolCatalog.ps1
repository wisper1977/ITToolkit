# Classic Tools menu - built-in catalog shared with the GUI
# Reads the same built-in tool definitions, Favorites and custom-tool file as the GUI.
# Requires ITToolkit-BuiltInCatalog.ps1 in the Modules folder.
$script:ClassicPrefsRoot = Join-Path ([Environment]::GetFolderPath('LocalApplicationData')) 'CochiseCounty\ITToolkit'
$script:ClassicPrefsPath = Join-Path $script:ClassicPrefsRoot 'GUISettings.json'
$script:ClassicCustomPath = Join-Path $script:ClassicPrefsRoot 'CustomTools.json'

# Use exactly the same built-in tool definitions and publisher URLs as the GUI.
$catalogModule = Join-Path $script:ToolkitRoot 'Modules\ITToolkit-BuiltInCatalog.ps1'
if (-not (Test-Path -LiteralPath $catalogModule -PathType Leaf)) { throw "Missing shared Tools catalog: $catalogModule" }
. $catalogModule
$script:ClassicApps = @(Get-ToolkitBuiltInTools)
$script:ClassicDownloadUrls = Get-ToolkitToolDownloadUrls

function Get-ClassicTools {
    $tools = @($script:ClassicApps)
    if (Test-Path -LiteralPath $script:ClassicCustomPath -PathType Leaf) {
        try {
            $custom = Get-Content -LiteralPath $script:ClassicCustomPath -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
            foreach ($item in @($custom)) {
                if (-not $item -or [string]$item.Id -notmatch '^custom-[A-Za-z0-9-]+$' -or
                    [string]::IsNullOrWhiteSpace([string]$item.Name) -or
                    [string]::IsNullOrWhiteSpace([string]$item.Exe)) { continue }
                $tools += [pscustomobject]@{
                    Id=[string]$item.Id; Name=[string]$item.Name; Group=$(if ($item.Group) {[string]$item.Group} else {'Custom'});
                    Description=[string]$item.Description; Exe=[string]$item.Exe; Args=[string]$item.Args;
                    DownloadUrl=[string]$item.DownloadUrl
                }
            }
        } catch { Write-Host "Unable to read custom tools: $($_.Exception.Message)" -ForegroundColor Yellow }
    }
    return $tools
}
function Get-ClassicFavoriteIds {
    if (Test-Path -LiteralPath $script:ClassicPrefsPath -PathType Leaf) {
        try {
            $saved = Get-Content -LiteralPath $script:ClassicPrefsPath -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
            if ($null -ne $saved.Favorites) { return @($saved.Favorites | Where-Object { $_ -is [string] } | Select-Object -Unique | Select-Object -First 10) }
        } catch { Write-Host "Unable to read Favorites: $($_.Exception.Message)" -ForegroundColor Yellow }
    }
    return @('powershell','eventvwr','services')
}
# Keep tool-launch errors local to Tools; never let a helper failure close Classic.
function Wait-ClassicCatalog {
    try { [void](Read-Host 'Press Enter to return to Tools') }
    catch { Write-Host "Unable to pause Tools menu: $($_.Exception.Message)" -ForegroundColor Yellow }
}

function Set-ClassicFavorite([string]$Id) {
    $favorites = @(Get-ClassicFavoriteIds | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) } | Select-Object -Unique)
    $wasFavorite = ($Id -in $favorites)
    if ($wasFavorite) {
        $favorites = @($favorites | Where-Object { $_ -ne $Id })
    } else {
        if ($favorites.Count -ge 10) {
            Write-Host "Favorites are full ($($favorites.Count)/10). Use F<number> on an existing favorite (marked *) to remove it, then add another." -ForegroundColor Yellow
            Wait-ClassicCatalog
            return
        }
        $favorites = @($favorites + $Id | Select-Object -Unique)
    }
    try {
        if (-not (Test-Path -LiteralPath $script:ClassicPrefsRoot -PathType Container)) {
            [void](New-Item -ItemType Directory -Path $script:ClassicPrefsRoot -Force -ErrorAction Stop)
        }
        $settings = if (Test-Path -LiteralPath $script:ClassicPrefsPath -PathType Leaf) {
            Get-Content -LiteralPath $script:ClassicPrefsPath -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
        } else { [pscustomobject]@{} }
        if ($settings.PSObject.Properties['Favorites']) { $settings.Favorites = @($favorites) }
        else { $settings | Add-Member -MemberType NoteProperty -Name Favorites -Value @($favorites) }
        $json = ConvertTo-Json -InputObject $settings -Depth 10 -ErrorAction Stop
        $tmp = Join-Path $script:ClassicPrefsRoot ('GUISettings-' + [guid]::NewGuid().ToString('N') + '.tmp')
        try {
            [IO.File]::WriteAllText($tmp,$json + [Environment]::NewLine,(New-Object Text.UTF8Encoding($false)))
            Move-Item -LiteralPath $tmp -Destination $script:ClassicPrefsPath -Force -ErrorAction Stop
        } finally { if (Test-Path -LiteralPath $tmp) { Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue } }
        if ($wasFavorite) { Write-Host "Removed from Favorites: $Id ($($favorites.Count)/10)" -ForegroundColor Green }
        else { Write-Host "Added to Favorites: $Id ($($favorites.Count)/10)" -ForegroundColor Green }
    } catch { Write-Host "Could not save Favorites: $($_.Exception.Message)" -ForegroundColor Yellow }
    Wait-ClassicCatalog
}
function Resolve-ClassicToolPath([object]$Tool) {
    $exe = [string]$Tool.Exe
    if ([string]::IsNullOrWhiteSpace($exe)) { return $null }
    if ($Tool.Id -eq 'portqry') {
        $port = [string]$script:Config.PortQryPath
        if ($port -and (Test-Path -LiteralPath $port -PathType Leaf)) { return $port }
    }
    if ([IO.Path]::IsPathRooted($exe)) { if (Test-Path -LiteralPath $exe -PathType Leaf) { return $exe }; return $null }
    $names = @($exe)
    switch ([string]$Tool.Id) {
        'procmon' { $names = @('Procmon.exe','Procmon64.exe','Procmon64a.exe') }
        'tcpview' { $names = @('tcpview.exe','Tcpview64.exe','Tcpview64a.exe') }
        'psexec'  { $names = @('PsExec.exe','PsExec64.exe') }
        'adexplorer' { $names = @('ADExplorer.exe','ADExplorer64.exe') }
    }
    foreach ($name in $names) {
        $command = Get-Command $name -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($command -and $command.Source) { return [string]$command.Source }
    }
    if ($exe -like '*.msc') {
        foreach ($folder in @((Join-Path $env:WINDIR 'System32'),(Join-Path $env:WINDIR 'SysWOW64'))) {
            $path = Join-Path $folder $exe
            if (Test-Path -LiteralPath $path -PathType Leaf) { return $path }
        }
        return $null
    }
    $folders = @($script:SysinternalsFolder,(Join-Path $script:ToolkitRoot 'Tools'),$env:ProgramFiles,
        (Join-Path $env:ProgramFiles 'Wireshark'),(Join-Path $env:ProgramFiles 'PuTTY'))
    if (${env:ProgramFiles(x86)}) { $folders += (Join-Path ${env:ProgramFiles(x86)} 'PuTTY') }
    foreach ($folder in $folders) {
        if (-not $folder) { continue }
        foreach ($name in $names) {
            $path = Join-Path $folder $name
            if (Test-Path -LiteralPath $path -PathType Leaf) { return $path }
        }
    }
    return $null
}
function Invoke-ClassicCatalogTool([object]$Tool) {
    $path = Resolve-ClassicToolPath $Tool
    if (-not $path) { Write-Host "Tool not detected: $($Tool.Name)" -ForegroundColor Yellow; Wait-ClassicCatalog; return }
    try {
        if ($Tool.Id -eq 'powershell-admin') {
            Write-Host 'Windows UAC will request administrator credentials or consent. IT Toolkit stays under the current identity.' -ForegroundColor Yellow
            $approval = (Read-Host 'Open a separate elevated Windows PowerShell console? (Y/N)').Trim().ToUpperInvariant()
            if ($approval -ne 'Y') { return }
            Start-Process -FilePath $path -ArgumentList '-NoLogo' -Verb RunAs -ErrorAction Stop | Out-Null
        } elseif ($Tool.Id -in @('portqry','psexec')) {
            # Open only catalog-defined command-line utilities in a persistent cmd console.
            $args = '/k ""' + $path + '" -?"'
            Start-Process -FilePath $env:ComSpec -ArgumentList $args -ErrorAction Stop | Out-Null
        } elseif ($path -like '*.msc') {
            $mmc = Join-Path $env:WINDIR 'System32\mmc.exe'
            if (-not (Test-Path -LiteralPath $mmc -PathType Leaf)) { $mmc = 'mmc.exe' }
            Start-Process -FilePath $mmc -ArgumentList ('"' + $path + '"') -ErrorAction Stop | Out-Null
        } else {
            $args = [string]$Tool.Args
            if ($args) { Start-Process -FilePath $path -ArgumentList $args -ErrorAction Stop | Out-Null }
            else { Start-Process -FilePath $path -ErrorAction Stop | Out-Null }
        }
        Write-Host "Launched $($Tool.Name)" -ForegroundColor Green
    } catch {
        Write-Host "Could not start $($Tool.Name): $($_.Exception.Message)" -ForegroundColor Yellow
        if ($_.Exception.InnerException) { Write-Host $_.Exception.InnerException.Message -ForegroundColor DarkYellow }
    }
    Wait-ClassicCatalog
}
function Open-ClassicToolDownload([object]$Tool) {
    $url = if ($Tool.Id -like 'custom-*') { [string]$Tool.DownloadUrl } else { [string]$script:ClassicDownloadUrls[[string]$Tool.Id] }
    if ($url -notmatch '^https://[^\s]+$') {
        Write-Host "No download page is configured for $($Tool.Name)." -ForegroundColor Yellow
        Wait-ClassicCatalog
        return
    }
    Write-Host "Download page for $($Tool.Name):" -ForegroundColor Cyan
    Write-Host $url -ForegroundColor White
    # Browser launch is best-effort: the toolkit may run under a separate admin
    # account whose desktop/browser session cannot be opened from this process.
    try {
        Start-Process -FilePath $url -ErrorAction Stop | Out-Null
        Write-Host 'Browser launch requested. If no window appears, use the link shown above.' -ForegroundColor Green
    } catch {
        Write-Host "Browser could not be launched under this account: $($_.Exception.Message)" -ForegroundColor Yellow
        try {
            Set-Clipboard -Value $url -ErrorAction Stop
            Write-Host 'Download URL copied to clipboard. Paste it into your browser.' -ForegroundColor Cyan
        } catch {
            Write-Host 'Copy the URL above into your browser.' -ForegroundColor Yellow
        }
    }
    Wait-ClassicCatalog
}
function Menu-ClassicCatalog {
    $filter = ''
    while ($true) {
        $all = @(Get-ClassicTools)
        $favorites = @(Get-ClassicFavoriteIds)
        $items = @($all | Where-Object { -not $filter -or $_.Name -like "*$filter*" -or $_.Group -like "*$filter*" -or $_.Description -like "*$filter*" })
        Show-Header 'Tools'
        Write-Host " TOOL CATALOG - $($items.Count) displayed / $($all.Count) total | $($favorites.Count)/10 Favorites" -ForegroundColor Yellow
        Write-Host ' Number = Launch | F<number> = Favorite | D<number> = Download URL' -ForegroundColor Gray
        Write-Host '------------------------------------------------------------' -ForegroundColor DarkGray
        for ($i=0; $i -lt $items.Count; $i++) {
            $tool = $items[$i]; $path = Resolve-ClassicToolPath $tool
            $state = if ($path) {'Installed'} else {'Unavailable'}
            $mark = if ($tool.Id -in $favorites) {'*'} else {' '}
            $color = if ($path) {'Green'} else {'DarkYellow'}
            Write-Host (' {0,2} [{1}] {2,-34} {3,-12} {4}' -f ($i+1),$mark,$tool.Name,$tool.Group,$state) -ForegroundColor $color
        }
        Write-Host '------------------------------------------------------------' -ForegroundColor DarkGray
        Write-Host ' S Search by name/category     R Reset search       B Back' -ForegroundColor Cyan
        Write-Host ' * = Favorite (shared with GUI) | Custom Tools are managed in GUI.' -ForegroundColor DarkGray
        $choice = (Read-Host 'Choose').Trim()
        if ($choice -ieq 'B' -or $choice -eq '0') { return }
        if ($choice -ieq 'S') { $filter = (Read-Host 'Search').Trim(); continue }
        if ($choice -ieq 'R') { $filter = ''; continue }
        # Use a dedicated Match object: -notmatch can clear PowerShell's automatic $Matches variable.
        $choiceMatch = [regex]::Match($choice, '^(F|D)?(\d+)$', [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
        if (-not $choiceMatch.Success) { continue }
        $action = $choiceMatch.Groups[1].Value.ToUpperInvariant()
        $n = [int]$choiceMatch.Groups[2].Value
        if ($n -lt 1 -or $n -gt $items.Count) { continue }
        $selected = $items[$n-1]
        try {
            if ($action -eq 'F') { Set-ClassicFavorite ([string]$selected.Id) }
            elseif ($action -eq 'D') { Open-ClassicToolDownload $selected }
            else { Invoke-ClassicCatalogTool $selected }
        } catch {
            Write-Host "Tools menu error: $($_.Exception.Message)" -ForegroundColor Red
            Write-Host "At: $($_.InvocationInfo.PositionMessage)" -ForegroundColor DarkYellow
            Wait-ClassicCatalog
        }
    }
}
