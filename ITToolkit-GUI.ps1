# IT Toolkit graphical interface - current build version is read from Toolkit-config.json
# Windows PowerShell 5.1 / WPF / STA. Works from the toolkit root folder.
# Shared built-in Tools catalog is loaded from Modules\ITToolkit-BuiltInCatalog.ps1.
$ErrorActionPreference = 'Stop'
if ([Threading.Thread]::CurrentThread.GetApartmentState() -ne [Threading.ApartmentState]::STA) {
    throw 'GUI requires an STA thread. Start through the Toolkit launcher or powershell.exe -STA -File ITToolkit-GUI.ps1.'
}
$script:ToolkitRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$configPath = Join-Path $script:ToolkitRoot 'Toolkit-config.json'
if (-not (Test-Path -LiteralPath $configPath -PathType Leaf)) { throw "Missing configuration: $configPath" }
$cfg = Get-Content -LiteralPath $configPath -Raw | ConvertFrom-Json
$version = if ($cfg.Version) { [string]$cfg.Version } else { 'Unknown' }
$organization = if ($cfg.Branding -and $cfg.Branding.OrganizationName) { [string]$cfg.Branding.OrganizationName } else { 'Your Organization' }
$appName = if ($cfg.Branding -and $cfg.Branding.ApplicationName) { [string]$cfg.Branding.ApplicationName } else { 'IT Toolkit' }
$displayName = ($organization + ' ' + $appName).Trim()
$authModule = Join-Path $script:ToolkitRoot 'Modules\ITToolkit-Authentication.ps1'
if (-not (Test-Path -LiteralPath $authModule -PathType Leaf)) { throw "Missing authentication module: $authModule" }
. $authModule
# Credential-aware SMB ADMIN$ adapter (separate from WMI / WinRM).
$smbModule = Join-Path $script:ToolkitRoot 'Modules\ITToolkit-SmbDiagnostics.ps1'
if (-not (Test-Path -LiteralPath $smbModule -PathType Leaf)) { throw "Missing SMB diagnostic module: $smbModule" }
. $smbModule

# The GUI has its own per-user preferences so Classic and launcher settings remain untouched.
$prefsRoot = Join-Path ([Environment]::GetFolderPath('LocalApplicationData')) 'CochiseCounty\ITToolkit'
$prefsPath = Join-Path $prefsRoot 'GUISettings.json'
$script:FavoriteIds = @('powershell','eventvwr','services')
$script:RecentTargets = @()
$script:LastGUIPage = 'Dashboard'
$script:GUIWindowPlacement = $null
if (Test-Path -LiteralPath $prefsPath -PathType Leaf) {
    try {
        $saved = Get-Content -LiteralPath $prefsPath -Raw | ConvertFrom-Json
        if ($null -ne $saved.Favorites) { $script:FavoriteIds = @($saved.Favorites | Where-Object { $_ -is [string] } | Select-Object -Unique) }
        # Migrate older dashboard pins first; support up to ten Favorites.
        if ($null -ne $saved.DashboardPins) {
            $script:FavoriteIds = @(@($saved.DashboardPins) + @($script:FavoriteIds) | Where-Object { $_ -is [string] } | Select-Object -Unique | Select-Object -First 10)
        } else { $script:FavoriteIds = @($script:FavoriteIds | Select-Object -First 10) }
        if ([string]$saved.LastPage -in @('Dashboard','Diagnostics','Tools','Reports','Settings')) {
            $script:LastGUIPage = [string]$saved.LastPage
        }
        if ($saved.WindowPlacement) { $script:GUIWindowPlacement = $saved.WindowPlacement }
        if ($null -ne $saved.RecentTargets) {
            $script:RecentTargets = @($saved.RecentTargets | Where-Object { $_ -and $_.Name -and $_.Name -match '^[a-zA-Z0-9_.-]+$' } | Select-Object -First 8)
        }
    } catch { }
}
function Save-GUIPreferences {
    try {
        if (-not (Test-Path -LiteralPath $prefsRoot -PathType Container)) { New-Item -ItemType Directory -Path $prefsRoot -Force | Out-Null }
        $preferences = [ordered]@{
            Favorites = @($script:FavoriteIds)
            RecentTargets = @($script:RecentTargets)
            LastPage = $script:LastGUIPage
            WindowPlacement = $script:GUIWindowPlacement
        }
        $json = ConvertTo-Json -InputObject $preferences -Depth 4
        [IO.File]::WriteAllText($prefsPath, $json + [Environment]::NewLine, (New-Object Text.UTF8Encoding($false)))
    } catch { [System.Windows.MessageBox]::Show("Could not save GUI preferences: $($_.Exception.Message)", 'IT Toolkit') | Out-Null }
}

# Built-in applications and download links are shared with Classic.
$catalogModule = Join-Path $script:ToolkitRoot 'Modules\ITToolkit-BuiltInCatalog.ps1'
if (-not (Test-Path -LiteralPath $catalogModule -PathType Leaf)) { throw "Missing shared Tools catalog: $catalogModule" }
. $catalogModule
$script:Apps = @(Get-ToolkitBuiltInTools)
# Custom applications are per-technician, separate from organization configuration.
$script:CustomToolsPath = Join-Path $prefsRoot 'CustomTools.json'
$script:CustomApps = @()
$script:DownloadUrls = Get-ToolkitToolDownloadUrls
function Test-GUICustomTool([object]$item) {
    if (-not $item -or [string]::IsNullOrWhiteSpace([string]$item.Id) -or [string]$item.Id -notmatch '^custom-[a-f0-9]{32}$') { return $false }
    if ([string]::IsNullOrWhiteSpace([string]$item.Name) -or [string]::IsNullOrWhiteSpace([string]$item.Exe)) { return $false }
    if ([string]$item.Exe -notmatch '(?i)\.(exe|msc)$') { return $false }
    if (-not [IO.Path]::IsPathRooted([string]$item.Exe)) { return $false }
    return $true
}
function Read-GUICustomTools {
    $script:CustomApps = @()
    if (Test-Path -LiteralPath $script:CustomToolsPath -PathType Leaf) {
        try {
            $items = @(Get-Content -LiteralPath $script:CustomToolsPath -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop)
            foreach ($item in $items) {
                if (-not (Test-GUICustomTool $item)) { continue }
                $tool = [pscustomobject]@{ Id=[string]$item.Id; Name=[string]$item.Name; Group=[string]$item.Group; Description=[string]$item.Description; Exe=[string]$item.Exe; Args=[string]$item.Args; DownloadUrl=[string]$item.DownloadUrl }
                $script:CustomApps += $tool
            }
        } catch { [Windows.MessageBox]::Show("Unable to load custom tools: $($_.Exception.Message)", 'Custom Tools') | Out-Null }
    }
}
function Save-GUICustomTools {
    if (-not (Test-Path -LiteralPath $prefsRoot -PathType Container)) { [void](New-Item -ItemType Directory -Path $prefsRoot -Force) }
    $json = ConvertTo-Json -InputObject @($script:CustomApps) -Depth 5
    # Write a temporary file and replace the user catalog only when serialization succeeds.
    $tmp = Join-Path $prefsRoot ('CustomTools-' + [guid]::NewGuid().ToString('N') + '.tmp')
    try {
        [IO.File]::WriteAllText($tmp, $json + [Environment]::NewLine, (New-Object Text.UTF8Encoding($false)))
        Move-Item -LiteralPath $tmp -Destination $script:CustomToolsPath -Force -ErrorAction Stop
    } finally { if (Test-Path -LiteralPath $tmp) { Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue } }
}
function Sync-GUICustomCatalog {
    $script:Apps = @($script:BuiltInApps) + @($script:CustomApps)
    foreach ($app in $script:Apps) { $script:ResolvedApps[$app.Id] = Resolve-ApplicationPath $app.Exe }
}

$script:BuiltInApps = @($script:Apps)
Read-GUICustomTools
$script:Apps = @($script:BuiltInApps) + @($script:CustomApps)

# Discover the same Sysinternals locations used by the Classic toolkit.
# No pinned Microsoft Store package version: the package folder changes after updates.
function Find-GUISysinternalsFolder {
    $configured = [string]$script:cfg.SysinternalsPath
    if ($configured -and $configured -ine 'Auto' -and (Test-Path -LiteralPath $configured -PathType Container)) {
        return $configured
    }
    foreach ($candidate in @((Join-Path $script:ToolkitRoot 'Sysinternals'), 'C:\Sysinternals', (Join-Path $script:ToolkitRoot 'Tools'))) {
        if (Test-Path -LiteralPath $candidate -PathType Container) { return $candidate }
    }
    $windowsApps = Join-Path $env:ProgramFiles 'WindowsApps'
    try {
        $packages = @(Get-ChildItem -LiteralPath $windowsApps -Directory -Filter 'Microsoft.SysinternalsSuite_*' -ErrorAction Stop |
                      Sort-Object Name -Descending)
        foreach ($package in $packages) {
            $tools = Join-Path $package.FullName 'Tools'
            if (Test-Path -LiteralPath $tools -PathType Container) { return $tools }
        }
    } catch { }
    return $null
}
function Resolve-ApplicationPath([string]$exe) {
    # PortQry is configured separately from Sysinternals. Respect the same setting as Classic.
    if ($exe -ieq 'portqry.exe') {
        $configuredPortQry = [string]$script:cfg.PortQryPath
        if (-not [string]::IsNullOrWhiteSpace($configuredPortQry)) {
            if (-not [IO.Path]::IsPathRooted($configuredPortQry)) {
                $configuredPortQry = Join-Path $script:ToolkitRoot $configuredPortQry
            }
            if (Test-Path -LiteralPath $configuredPortQry -PathType Leaf) { return $configuredPortQry }
        }
        foreach ($candidate in @((Join-Path $script:ToolkitRoot 'Tools\portqry.exe'), 'C:\PortQryV2\portqry.exe')) {
            if (Test-Path -LiteralPath $candidate -PathType Leaf) { return $candidate }
        }
    }
    if ([IO.Path]::IsPathRooted($exe)) { if (Test-Path -LiteralPath $exe -PathType Leaf) { return $exe }; return $null }
    # Sysinternals releases may ship the unsuffixed, x64 or ARM64 executable.
    $candidates = @($exe)
    switch -Regex ($exe) {
        '^(?i:procmon)(?:64|64a)?\.exe$' { $candidates = @('Procmon.exe','Procmon64.exe','Procmon64a.exe'); break }
        '^(?i:tcpview)(?:64|64a)?\.exe$' { $candidates = @('tcpview.exe','Tcpview64.exe','Tcpview64a.exe'); break }
        '^(?i:psexec)(?:64)?\.exe$' { $candidates = @('PsExec.exe','PsExec64.exe'); break }
        '^(?i:adexplorer)(?:64)?\.exe$' { $candidates = @('ADExplorer.exe','ADExplorer64.exe'); break }
    }
    foreach ($name in $candidates) {
        $command = Get-Command $name -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($command -and $command.Source) { return [string]$command.Source }
    }
    if ($exe -like '*.msc') {
        $mscPaths = @((Join-Path $env:WINDIR "System32\$exe"), (Join-Path $env:WINDIR "SysWOW64\$exe"))
        foreach ($mscPath in $mscPaths) { if (Test-Path -LiteralPath $mscPath -PathType Leaf) { return $mscPath } }
        return $null
    }
    $folders = @($env:ProgramFiles, (Join-Path $env:ProgramFiles 'Wireshark'), (Join-Path $env:ProgramFiles 'PuTTY'), (Join-Path $script:ToolkitRoot 'Tools'))
    if (${env:ProgramFiles(x86)}) { $folders += (Join-Path ${env:ProgramFiles(x86)} 'PuTTY') }
    if ($script:SysinternalsFolder) { $folders += $script:SysinternalsFolder }
    foreach ($folder in $folders) {
        if (-not $folder) { continue }
        foreach ($name in $candidates) {
            $candidate = Join-Path $folder $name
            if (Test-Path -LiteralPath $candidate -PathType Leaf) { return $candidate }
        }
    }
    return $null
}
$script:SysinternalsFolder = Find-GUISysinternalsFolder
$script:ResolvedApps = @{}
foreach ($app in $script:Apps) { $script:ResolvedApps[$app.Id] = Resolve-ApplicationPath $app.Exe }

Add-Type -AssemblyName PresentationFramework,PresentationCore,WindowsBase
[xml]$xaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" Title="IT Toolkit" Width="1090" Height="730" MinWidth="900" MinHeight="620" WindowStartupLocation="CenterScreen" Background="#F4F7FB" FontFamily="Segoe UI">
 <Window.Resources>
  <Style TargetType="Button"><Setter Property="Padding" Value="13,8"/><Setter Property="Margin" Value="0,0,8,8"/><Setter Property="Background" Value="#E3EBF4"/><Setter Property="BorderBrush" Value="#C2D0E0"/><Setter Property="Foreground" Value="#183452"/><Setter Property="Cursor" Value="Hand"/></Style>
  <Style TargetType="TextBlock"><Setter Property="Foreground" Value="#24384B"/></Style>
 </Window.Resources>
 <Grid>
  <Grid.RowDefinitions><RowDefinition Height="78"/><RowDefinition Height="*"/><RowDefinition Height="35"/></Grid.RowDefinitions>
  <Border Grid.Row="0" Background="#17365D" Padding="22,10">
   <DockPanel>
    <Image Name="HeaderLogo" Width="58" Height="58" DockPanel.Dock="Right" Stretch="Uniform" Visibility="Collapsed"/>
    <StackPanel VerticalAlignment="Center"><TextBlock Name="Heading" Foreground="White" FontSize="24" FontWeight="SemiBold"/><TextBlock Name="Subtitle" Foreground="#CBDBEE" Margin="0,5,0,0" FontSize="12"/></StackPanel>
   </DockPanel>
  </Border>
  <Grid Grid.Row="1"><Grid.ColumnDefinitions><ColumnDefinition Width="255"/><ColumnDefinition Width="*"/></Grid.ColumnDefinitions>
   <Border Background="#E6EDF5" BorderBrush="#CED9E6" BorderThickness="0,0,1,0" Padding="12,18">
    <Grid>
     <Grid.RowDefinitions><RowDefinition Height="Auto"/><RowDefinition Height="Auto"/><RowDefinition Height="*" MinHeight="0"/><RowDefinition Height="Auto"/></Grid.RowDefinitions>
     <StackPanel Grid.Row="0">
     <Button Name="NavDashboard" Content="Dashboard" Height="41"/>
     <Button Name="NavDiagnostics" Content="Diagnostics" Height="41"/>
     <Button Name="NavTools" Content="Tools" Height="41"/>
     <Button Name="NavReports" Content="Reports" Height="41"/>
     <Button Name="NavSettings" Content="Settings" Height="41"/>

     </StackPanel>
     <StackPanel Grid.Row="1">
     <Border Height="1" Background="#CAD5E1" Margin="0,12"/>
     <TextBlock Text="TARGET COMPUTER" FontWeight="SemiBold" FontSize="11" Foreground="#61748B" Margin="4,0,0,9"/>
     <Border Name="SideStatusCard" Background="#F1F5FA" BorderBrush="#CBD7E5" BorderThickness="1,1,1,1" CornerRadius="5" Padding="10,10,8,10">
      <StackPanel>
       <TextBlock Name="SideTarget" Text="Not selected" TextWrapping="Wrap" FontSize="13" FontWeight="Bold" Foreground="#17365D" Margin="0,0,0,5"/>
       <TextBlock Name="SideIPv4" Text="" TextWrapping="Wrap" FontSize="11" Foreground="#536D8B" Margin="0,0,0,8" Visibility="Collapsed"/>
       <Border Name="SideAccessBadge" Background="#E5EAF0" BorderBrush="#BBC8D5" BorderThickness="1" CornerRadius="4" Padding="6,5">
        <TextBlock Name="SideAccess" Text="Not checked" FontSize="11" FontWeight="SemiBold" TextWrapping="Wrap" Foreground="#51667B"/>
       </Border>
      </StackPanel>
     </Border>
     </StackPanel>
     <ScrollViewer Grid.Row="2" VerticalScrollBarVisibility="Auto" HorizontalScrollBarVisibility="Disabled" Margin="0,10,0,8">
     <Border Background="#F4F8FD" BorderBrush="#C7D7E8" BorderThickness="1" CornerRadius="5" Padding="9" Margin="0">
      <StackPanel>
       <TextBlock Text="COMPUTER HEALTH" FontWeight="SemiBold" FontSize="11" Foreground="#17365D" Margin="0,0,0,5"/>
       <TextBlock Name="DashboardHealthSummary" Text="Run Health Check for the selected computer." FontSize="11" TextWrapping="Wrap" Foreground="#53677E" Margin="0,0,0,9"/>
       <UniformGrid Columns="3" Margin="0,0,0,10">
        <Border Background="#FFF2DD" CornerRadius="4" Padding="5" Margin="0,0,4,0"><StackPanel><TextBlock Text="REVIEW" FontSize="9" FontWeight="SemiBold" Foreground="#785018" TextAlignment="Center"/><TextBlock Name="HealthReviewCount" Text="—" FontSize="19" FontWeight="SemiBold" Foreground="#785018" TextAlignment="Center"/></StackPanel></Border>
        <Border Background="#E6F0FD" CornerRadius="4" Padding="5" Margin="0,0,4,0"><StackPanel><TextBlock Text="CHECKED" FontSize="9" FontWeight="SemiBold" Foreground="#274C79" TextAlignment="Center"/><TextBlock Name="HealthAvailableCount" Text="—" FontSize="19" FontWeight="SemiBold" Foreground="#274C79" TextAlignment="Center"/></StackPanel></Border>
        <Border Background="#E7EAF0" CornerRadius="4" Padding="5"><StackPanel><TextBlock Text="UNKNOWN" FontSize="9" FontWeight="SemiBold" Foreground="#4B5563" TextAlignment="Center"/><TextBlock Name="HealthUnavailableCount" Text="—" FontSize="19" FontWeight="SemiBold" Foreground="#4B5563" TextAlignment="Center"/></StackPanel></Border>
       </UniformGrid>
       <TextBlock Text="EVIDENCE BY CATEGORY" FontWeight="SemiBold" FontSize="10" Foreground="#17365D" Margin="0,0,0,7"/>
       <TextBlock Name="HealthStorageDetail" Text="Storage: Not assessed" TextWrapping="Wrap" FontSize="11" Margin="0,0,0,8"/>
       <TextBlock Name="HealthServicesDetail" Text="Services: Not assessed" TextWrapping="Wrap" FontSize="11" Margin="0,0,0,8"/>
       <TextBlock Name="HealthEventsDetail" Text="Events: Not assessed" TextWrapping="Wrap" FontSize="11" Margin="0,0,0,8"/>
       <TextBlock Name="HealthSystemDetail" Text="System: Not assessed" TextWrapping="Wrap" FontSize="11" Margin="0,0,0,8"/>
       <TextBlock Name="HealthSecurityDetail" Text="Security: Not assessed" TextWrapping="Wrap" FontSize="11" Margin="0,0,0,8"/>
       <TextBlock Name="HealthUpdatesDetail" Text="Updates: Not assessed" TextWrapping="Wrap" FontSize="11" Margin="0,0,0,8"/>
       <TextBlock Name="HealthRestartDetail" Text="Restart: Not assessed" TextWrapping="Wrap" FontSize="11" Margin="0,0,0,8"/>
       <TextBlock Text="Review is not a confirmed fault. Installed QFEs do not establish patch compliance. Full findings: Diagnostics." TextWrapping="Wrap" FontSize="10" Foreground="#60738A"/>
      </StackPanel>
     </Border>
     </ScrollViewer>
     <Button Grid.Row="3" Name="SwitchClassic" Content="Switch to Classic" Height="41" Margin="0" ToolTip="Start Classic with this Windows identity; targets and alternate credentials do not transfer."/>
    </Grid>
   </Border>
   <ScrollViewer Grid.Column="1" VerticalScrollBarVisibility="Auto" HorizontalScrollBarVisibility="Disabled">
    <StackPanel Margin="26,22,26,22">
     <StackPanel Name="PageDashboard">
      <TextBlock Text="Dashboard" FontSize="24" FontWeight="SemiBold"/>
      <TextBlock Text="Select a target computer, then open a diagnostic tool or your favorite shortcuts." TextWrapping="Wrap" Margin="0,6,0,17" Foreground="#60738A"/>
      <Border Background="White" BorderBrush="#D7E0EB" BorderThickness="1" Padding="19" CornerRadius="5" Margin="0,0,0,15">
       <StackPanel><TextBlock Text="TARGET COMPUTER" FontWeight="SemiBold" Foreground="#17365D" Margin="0,0,0,9"/>
        <WrapPanel><TextBox Name="TargetInput" Width="270" Height="34" Padding="9,5" Margin="0,0,9,8" ToolTip="Computer hostname or IPv4 address"/><Button Name="SetTarget" Content="Set target / Check access" Height="34"/><Button Name="UseLocalTarget" Content="Use Local Computer" Height="34"/><Button Name="ClearTarget" Content="Clear" Height="34"/></WrapPanel>
        <WrapPanel Margin="0,0,0,7" VerticalAlignment="Center">
          <CheckBox Name="UseAlternate" Content="Use alternate credentials" Margin="0,5,14,4" VerticalAlignment="Center"/>
          <TextBlock Name="AlternateUserLabel" Text="" Foreground="#42678E" VerticalAlignment="Center" Margin="0,4,12,4"/>
          <Button Name="ChangeAlternate" Content="Enter credentials / Test" Height="31"/>
        </WrapPanel>
        <TextBlock Name="AlternateProbeSummary" Text="Default toolkit identity. Alternate mode uses selected credentials for WMI, WinRM and ADMIN$ checks." FontSize="11" Foreground="#60738A" TextWrapping="Wrap" Margin="0,0,0,8"/>
        <Border Name="TargetStatusCard" Background="#F6F9FD" BorderBrush="#D7E4F0" BorderThickness="1" CornerRadius="5" Padding="13,12" Margin="0,4,0,0">
         <Grid>
          <Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="20"/><ColumnDefinition Width="*"/></Grid.ColumnDefinitions>
          <StackPanel Grid.Column="0">
          <TextBlock Text="SELECTED TARGET" Foreground="#60738A" FontSize="10" FontWeight="SemiBold"/>
          <TextBlock Name="TargetNameText" Text="Not selected" TextWrapping="Wrap" FontSize="17" FontWeight="Bold" Foreground="#17365D" Margin="0,3,0,11"/>
          <WrapPanel Margin="0,0,0,10">
           <StackPanel Margin="0,0,18,6">
            <TextBlock Text="IPv4 ADDRESS" Foreground="#60738A" FontSize="10" FontWeight="SemiBold" Margin="0,0,0,4"/>
            <Border Background="#DDEDFE" BorderBrush="#ADCFEF" BorderThickness="1" CornerRadius="5" Padding="10,5">
             <TextBlock Name="TargetIpText" Text="(not selected)" TextWrapping="Wrap" FontWeight="SemiBold" Foreground="#194F85"/>
            </Border>
           </StackPanel>
           <StackPanel Margin="0,0,0,6">
            <TextBlock Text="ADMIN$ STATUS" Foreground="#60738A" FontSize="10" FontWeight="SemiBold" Margin="0,0,0,4"/>
            <Border Name="AdminBadge" Background="#E5EAF0" BorderBrush="#BBC8D5" BorderThickness="1" CornerRadius="5" Padding="10,5">
             <TextBlock Name="AdminStatusText" Text="Not checked" TextWrapping="Wrap" FontWeight="SemiBold" Foreground="#51667B"/>
            </Border>
           </StackPanel>
          </WrapPanel>
          <Border Name="AdminDetailBox" Background="#EEF3F8" BorderBrush="#D4DEE9" BorderThickness="1" CornerRadius="4" Padding="10,8">
           <TextBlock Name="AdminDetailText" Text="Select a target first." TextWrapping="Wrap" Foreground="#53677E"/>
          </Border>
          </StackPanel>
          <Border Grid.Column="2" BorderBrush="#D7E4F0" BorderThickness="1,0,0,0" Padding="14,0,0,0">
           <StackPanel>
            <TextBlock Text="TARGET INFORMATION" FontWeight="SemiBold" Foreground="#17365D" Margin="0,0,0,9"/>
            <Grid Margin="0,0,0,5"><Grid.ColumnDefinitions><ColumnDefinition Width="130"/><ColumnDefinition Width="*"/></Grid.ColumnDefinitions><TextBlock Text="DNS resolution" Foreground="#60738A"/><TextBlock Name="TargetDnsSummary" Grid.Column="1" Text="Not checked" TextWrapping="Wrap" FontWeight="SemiBold"/></Grid>
            <Grid Margin="0,0,0,5"><Grid.ColumnDefinitions><ColumnDefinition Width="130"/><ColumnDefinition Width="*"/></Grid.ColumnDefinitions><TextBlock Text="Reachability" Foreground="#60738A"/><TextBlock Name="TargetPingSummary" Grid.Column="1" Text="Not checked" TextWrapping="Wrap"/></Grid>
            <Grid Margin="0,0,0,5"><Grid.ColumnDefinitions><ColumnDefinition Width="130"/><ColumnDefinition Width="*"/></Grid.ColumnDefinitions><TextBlock Text="ADMIN$ checked" Foreground="#60738A"/><TextBlock Name="TargetCheckTime" Grid.Column="1" Text="Not checked"/></Grid>
            <Grid Margin="0,0,0,9"><Grid.ColumnDefinitions><ColumnDefinition Width="130"/><ColumnDefinition Width="*"/></Grid.ColumnDefinitions><TextBlock Text="Last diagnostic" Foreground="#60738A"/><TextBlock Name="TargetLastDiagnostic" Grid.Column="1" Text="None this session" TextWrapping="Wrap"/></Grid>
            <TextBlock Text="QUICK ACTIONS" FontSize="10" FontWeight="SemiBold" Foreground="#60738A" Margin="0,0,0,6"/>
            <WrapPanel><Button Name="QuickPing" Content="Ping"/><Button Name="QuickDns" Content="DNS Lookup"/><Button Name="QuickHealth" Content="Health Check"/></WrapPanel>
            <TextBlock Text="Authentication: Select Default or Alternate above; ADMIN$ status is shown separately" Foreground="#60738A" FontSize="11" TextWrapping="Wrap" Margin="0,4,0,0"/>
           </StackPanel>
          </Border>
         </Grid>
        </Border>
       </StackPanel>
      </Border>
      <Border Background="White" BorderBrush="#D7E0EB" BorderThickness="1" Padding="19" CornerRadius="5" Margin="0,0,0,15">
       <StackPanel><DockPanel Margin="0,0,0,12"><Button Name="EditPins" Content="Edit favorites" DockPanel.Dock="Right" Margin="0"/><TextBlock Text="FAVORITE SHORTCUTS" FontWeight="SemiBold" Foreground="#17365D" VerticalAlignment="Center"/></DockPanel>
        <UniformGrid Name="DashboardPins" Columns="10" Rows="0"/>
        <TextBlock Name="PinHint" Foreground="#60738A" FontSize="12" TextWrapping="Wrap"/>
       </StackPanel>
      </Border>
      <Grid Margin="0,0,0,15">
       <Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="16"/><ColumnDefinition Width="*"/></Grid.ColumnDefinitions>
       <Border Grid.Column="0" Background="White" BorderBrush="#D7E0EB" BorderThickness="1" Padding="15" CornerRadius="5">
        <StackPanel>
         <DockPanel Margin="0,0,0,10"><Button Name="ClearRecents" Content="Clear" DockPanel.Dock="Right" Margin="0"/><TextBlock Text="RECENT TARGETS" FontWeight="SemiBold" Foreground="#17365D" VerticalAlignment="Center"/></DockPanel>
         <StackPanel Name="RecentTargetRows"/>
        </StackPanel>
       </Border>
       <Border Grid.Column="2" Background="White" BorderBrush="#D7E0EB" BorderThickness="1" Padding="15" CornerRadius="5">
        <StackPanel>
         <DockPanel Margin="0,0,0,10"><Button Name="MoreReports" Content="View archive" DockPanel.Dock="Right" Margin="0"/><TextBlock Text="RECENT REPORTS" FontWeight="SemiBold" Foreground="#17365D" VerticalAlignment="Center"/></DockPanel>
         <StackPanel Name="RecentReportRows"/>
        </StackPanel>
       </Border>
      </Grid>

     </StackPanel>
     <StackPanel Name="PageDiagnostics" Visibility="Collapsed">
      <TextBlock Text="Diagnostics" FontSize="24" FontWeight="SemiBold"/>
      <TextBlock Text="Run the Classic toolkit's shared read-only diagnostic checks against the selected target." Margin="0,6,0,14" Foreground="#60738A" TextWrapping="Wrap"/>
      <Border Background="White" BorderBrush="#D7E0EB" BorderThickness="1" Padding="14" CornerRadius="5">
       <StackPanel>
        <TextBlock Text="DIAGNOSTIC REPORTS" Foreground="#17365D" FontWeight="SemiBold" Margin="0,0,0,8"/>
        <ComboBox Name="DiagnosticSection" Height="34" Margin="0,0,0,10" ToolTip="Choose one of the twenty existing reporting checks."/>
        <WrapPanel>
         <Button Name="RunDiagnostic" Content="Run selected check"/>
          <Button Name="RunElevatedLocalDiagnostic" Content="Run selected with UAC" ToolTip="Explicit administrator consent for local BitLocker or Policy only"/>
         <Button Name="RunAllDiagnostics" Content="Run all 20 checks"/>
         <Button Name="CreateSnapshotGUI" Content="Create Snapshot" ToolTip="Capture structured inventory for later comparison"/>
        </WrapPanel>
        <TextBlock Name="DiagnosticProgress" Text="Ready to run diagnostics." Foreground="#526B83" Margin="0,6,0,0" TextWrapping="Wrap"/>
       </StackPanel>
      </Border>
      <WrapPanel Margin="0,12,0,0"><Button Name="PingTarget" Content="Ping target"/><Button Name="DnsTarget" Content="Resolve DNS"/><Button Name="CheckAdmin" Content="Check ADMIN$"/></WrapPanel>
      <Border Background="White" BorderBrush="#D7E0EB" BorderThickness="1" Padding="14" Margin="0,8,0,0" CornerRadius="5"><TextBox Name="DiagnosticOutput" Text="Select a target, then choose a check." IsReadOnly="True" TextWrapping="Wrap" AcceptsReturn="True" FontFamily="Consolas" FontSize="12" VerticalScrollBarVisibility="Auto" HorizontalScrollBarVisibility="Auto" MinHeight="260" MaxHeight="500" Background="White" BorderThickness="0"/></Border>
      <Border Background="White" BorderBrush="#D7E0EB" BorderThickness="1" Padding="12" Margin="0,10,0,0" CornerRadius="5">
       <StackPanel>
        <DockPanel LastChildFill="False">
         <Button Name="CopyDiagnosticReport" DockPanel.Dock="Left" Content="Copy Report" Width="138" Height="34" IsEnabled="False" Background="#E7EEF7" Foreground="#17365D" FontWeight="SemiBold" Margin="0,0,14,0" ToolTip="Copy displayed diagnostic report to clipboard"/>
         <Button Name="SaveDiagnosticReport" DockPanel.Dock="Right" Content="Save Report" Width="138" Height="34" IsEnabled="False" Background="#17365D" Foreground="White" FontWeight="SemiBold" Margin="14,0,0,0"/>
         <StackPanel DockPanel.Dock="Right" Orientation="Horizontal" VerticalAlignment="Center">
          <TextBlock Text="Format" Margin="0,0,8,0" VerticalAlignment="Center" Foreground="#42566D"/>
          <ComboBox Name="DiagnosticReportFormat" Width="90" Height="32" SelectedIndex="0">
           <ComboBoxItem Content="HTML"/><ComboBoxItem Content="CSV"/><ComboBoxItem Content="TXT"/>
          </ComboBox>
         </StackPanel>
         <TextBlock Text="Save the results shown above" VerticalAlignment="Center" Foreground="#17365D" FontWeight="SemiBold" TextWrapping="Wrap"/>
        </DockPanel>
        <TextBlock Name="DiagnosticSaveStatus" Text="Run a diagnostic to enable Save Report." TextWrapping="Wrap" FontSize="12" Foreground="#526B83" Margin="0,8,0,0"/>
       </StackPanel>
      </Border>
      <TextBlock Text="Queries are read-only. Unavailable results may indicate insufficient permissions, disabled services, or network restrictions. Running all checks can take several minutes." Foreground="#60738A" TextWrapping="Wrap" Margin="0,12,0,0"/>
     </StackPanel>
     <StackPanel Name="PageTools" Visibility="Collapsed">
      <TextBlock Text="Tools" FontSize="24" FontWeight="SemiBold"/>
      <TextBlock Text="Launch built-in or personal tools, choose up to ten favorites, or open publisher download pages. Hover over a tool for details." Foreground="#60738A" TextWrapping="Wrap" Margin="0,6,0,15"/>
      <Border Background="White" BorderBrush="#D7E0EB" BorderThickness="1" CornerRadius="6" Padding="14" Margin="0,0,0,14">
       <StackPanel>
        <WrapPanel>
         <StackPanel Margin="0,0,12,8"><TextBlock Text="Find a tool" Margin="0,0,0,4" Foreground="#526B83"/><TextBox Name="ToolSearch" Width="235" Height="32" Padding="8,5" ToolTip="Search tool name, group, or description"/></StackPanel>
         <StackPanel Margin="0,0,12,8"><TextBlock Text="Show" Margin="0,0,0,4" Foreground="#526B83"/><ComboBox Name="ToolFilter" Width="155" Height="32" SelectedIndex="0"><ComboBoxItem Content="All tools"/><ComboBoxItem Content="Installed"/><ComboBoxItem Content="Favorites"/><ComboBoxItem Content="Unavailable"/></ComboBox></StackPanel>
         <Button Name="ToolRefresh" Content="Refresh Detection" Height="32" VerticalAlignment="Bottom" Margin="0,0,0,8" ToolTip="Check installed tools again"/>
        </WrapPanel>
        <TextBlock Name="ToolSummary" Text="Checking tools..." Foreground="#526B83" FontSize="12"/>
        <Button Name="AddCustomTool" Content="+ Add Tool" Width="120" HorizontalAlignment="Left" Margin="0,9,0,0" Background="#17365D" Foreground="White" ToolTip="Register a trusted executable or MSC console in your personal tools catalog"/>
       </StackPanel>
      </Border>
      <StackPanel Name="ToolRows"/>
     </StackPanel>
     <StackPanel Name="PageReports" Visibility="Collapsed">
      <TextBlock Text="Report Archive" FontSize="24" FontWeight="SemiBold"/>
      <TextBlock Text="Browse saved diagnostics and compare structured snapshots. Run and save new diagnostics from the Diagnostics page." Foreground="#60738A" TextWrapping="Wrap" Margin="0,6,0,14"/>
      <TabControl Name="ArchiveTabs" Background="White" BorderBrush="#D7E0EB">
       <TabItem Header="Saved Reports">
        <StackPanel Margin="14">
         <WrapPanel Margin="0,0,0,10">
          <StackPanel Margin="0,0,12,5"><TextBlock Text="Search file name" Foreground="#526B83" Margin="0,0,0,4"/><TextBox Name="ArchiveSearch" Width="290" Height="31" Padding="7,4"/></StackPanel>
          <StackPanel Margin="0,0,12,5"><TextBlock Text="Format" Foreground="#526B83" Margin="0,0,0,4"/><ComboBox Name="ArchiveFormat" Width="145" Height="31" SelectedIndex="0"><ComboBoxItem Content="All formats"/><ComboBoxItem Content="HTML"/><ComboBoxItem Content="CSV"/><ComboBoxItem Content="TXT"/></ComboBox></StackPanel>
         </WrapPanel>
         <ListView Name="ArchiveList" MinHeight="260" MaxHeight="470" SelectionMode="Single" Margin="0,0,0,10">
          <ListView.View><GridView><GridViewColumn Header="Report file" Width="345" DisplayMemberBinding="{Binding Name}"/><GridViewColumn Header="Modified" Width="155" DisplayMemberBinding="{Binding Modified}"/><GridViewColumn Header="Format" Width="85" DisplayMemberBinding="{Binding Format}"/><GridViewColumn Header="Size (KB)" Width="85" DisplayMemberBinding="{Binding SizeKB}"/></GridView></ListView.View>
         </ListView>
         <WrapPanel><Button Name="ArchiveRefresh" Content="Refresh"/><Button Name="ArchiveOpen" Content="Open Report" IsEnabled="False"/><Button Name="ArchiveFolder" Content="Open Folder"/><Button Name="ArchiveCopyPath" Content="Copy Folder Path"/></WrapPanel>
         <TextBlock Name="ArchiveStatus" Foreground="#526B83" TextWrapping="Wrap" Margin="0,3,0,0"/>
        </StackPanel>
       </TabItem>
       <TabItem Header="Snapshot Comparisons">
        <StackPanel Margin="14">
         <TextBlock Text="Compare two snapshots for the same computer. Snapshots contain structured inventory data; formatted HTML, CSV and TXT reports are not used for comparisons." TextWrapping="Wrap" Foreground="#60738A" Margin="0,0,0,12"/>
         <TextBlock Text="Older snapshot (baseline)" FontWeight="SemiBold" Margin="0,0,0,4"/>
         <ComboBox Name="SnapshotOlder" Height="32" Margin="0,0,0,12" DisplayMemberPath="Display"/>
         <TextBlock Text="Newer snapshot" FontWeight="SemiBold" Margin="0,0,0,4"/>
         <ComboBox Name="SnapshotNewer" Height="32" Margin="0,0,0,12" DisplayMemberPath="Display"/>
         <WrapPanel><Button Name="SnapshotsRefresh" Content="Refresh snapshots"/><Button Name="CompareSnapshotsGUI" Content="Compare Selected" Background="#17365D" Foreground="White"/><TextBlock Text="Save as" VerticalAlignment="Center" Margin="16,0,6,0"/><ComboBox Name="ComparisonFormat" Width="95" Height="30" SelectedIndex="0" Margin="0,0,7,0"><ComboBoxItem Content="HTML"/><ComboBoxItem Content="CSV"/><ComboBoxItem Content="TXT"/></ComboBox><Button Name="SaveComparisonGUI" Content="Save Comparison" IsEnabled="False"/></WrapPanel>
         <TextBlock Name="SnapshotStatus" Foreground="#526B83" Margin="0,0,0,8" TextWrapping="Wrap"/>
         <TextBox Name="ComparisonOutput" IsReadOnly="True" AcceptsReturn="True" TextWrapping="NoWrap" FontFamily="Consolas" FontSize="12" MinHeight="250" MaxHeight="440" VerticalScrollBarVisibility="Auto" HorizontalScrollBarVisibility="Auto" Text="Select two snapshots and click Compare Selected."/>
        </StackPanel>
       </TabItem>
      </TabControl>
     </StackPanel>
     <StackPanel Name="PageSettings" Visibility="Collapsed" MaxWidth="1080" HorizontalAlignment="Stretch">
      <TextBlock Text="GUI Settings" FontSize="24" FontWeight="SemiBold"/>
      <TextBlock Text="Toolkit configuration is shared with the Classic interface and launcher. Technician preferences are saved separately." Foreground="#60738A" TextWrapping="Wrap" Margin="0,6,0,16"/>
      <Border Background="White" BorderBrush="#D1DDEC" BorderThickness="1" CornerRadius="6" Padding="18" Margin="0,0,0,12">
       <StackPanel>
        <TextBlock Text="ORGANIZATION / AUTHENTICATION" FontWeight="SemiBold" Foreground="#17365D" Margin="0,0,0,12"/>
        <TextBlock Text="Organization name" FontWeight="SemiBold"/><TextBox Name="SetOrgName" Height="32" Margin="0,4,0,10" Padding="8,4"/>
        <TextBlock Text="Default authentication domain" FontWeight="SemiBold"/><TextBox Name="SetAuthDomain" Height="32" Margin="0,4,0,5" Padding="8,4" ToolTip="For bare usernames in the launcher; DOMAIN\user and UPN entries override it."/>
        <TextBlock Text="Changes to launcher branding and authentication defaults apply when the launcher is restarted." Foreground="#60738A" FontSize="11" TextWrapping="Wrap"/>
       </StackPanel>
      </Border>
      <Border Background="White" BorderBrush="#D1DDEC" BorderThickness="1" CornerRadius="6" Padding="18" Margin="0,0,0,12">
       <StackPanel>
        <TextBlock Text="TOOLS / REPORTS" FontWeight="SemiBold" Foreground="#17365D" Margin="0,0,0,12"/>
        <TextBlock Text="Sysinternals folder (Auto or absolute folder path)" FontWeight="SemiBold"/><TextBox Name="SetSysinternals" Height="32" Margin="0,4,0,10" Padding="8,4"/>
        <TextBlock Text="PortQry executable (absolute path)" FontWeight="SemiBold"/><TextBox Name="SetPortQry" Height="32" Margin="0,4,0,10" Padding="8,4"/>
        <TextBlock Text="Report folder (relative to toolkit or absolute path)" FontWeight="SemiBold"/><TextBox Name="SetReportsFolder" Height="32" Margin="0,4,0,10" Padding="8,4"/>
        <TextBlock Text="Default report format" FontWeight="SemiBold"/>
        <ComboBox Name="SetReportsFormat" Width="150" HorizontalAlignment="Left" Height="32" Margin="0,4,0,0"><ComboBoxItem Content="HTML"/><ComboBoxItem Content="CSV"/><ComboBoxItem Content="TXT"/></ComboBox>
       </StackPanel>
      </Border>
      <Border Background="White" BorderBrush="#D1DDEC" BorderThickness="1" CornerRadius="6" Padding="18" Margin="0,0,0,12">
       <StackPanel>
        <TextBlock Text="BRANDING FILES" FontWeight="SemiBold" Foreground="#17365D" Margin="0,0,0,12"/>
        <TextBlock Text="Logo path" FontWeight="SemiBold"/><TextBox Name="SetLogoPath" Height="32" Margin="0,4,0,10" Padding="8,4"/>
        <TextBlock Text="Login background image path" FontWeight="SemiBold"/><TextBox Name="SetLoginPath" Height="32" Margin="0,4,0,10" Padding="8,4"/>
        <TextBlock Text="Application icon path" FontWeight="SemiBold"/><TextBox Name="SetIconPath" Height="32" Margin="0,4,0,5" Padding="8,4"/>
        <TextBlock Text="Missing optional image files are allowed. Images and colors are applied when the respective window is restarted." Foreground="#60738A" FontSize="11" TextWrapping="Wrap"/>
       </StackPanel>
      </Border>
      <WrapPanel Margin="0,0,0,10">
       <Button Name="SetSaveConfig" Content="Save organization settings" Background="#17365D" Foreground="White"/>
       <Button Name="SetReloadConfig" Content="Reload saved settings"/>
      </WrapPanel>
      <TextBlock Name="SetConfigStatus" Foreground="#526B83" TextWrapping="Wrap" Margin="0,0,0,12"/>
      <Border Background="White" BorderBrush="#D1DDEC" BorderThickness="1" CornerRadius="6" Padding="18" Margin="0,0,0,12">
       <StackPanel>
        <TextBlock Text="TECHNICIAN PREFERENCES" FontWeight="SemiBold" Foreground="#17365D" Margin="0,0,0,8"/>
        <TextBlock Name="SettingsInfo" TextWrapping="Wrap" Foreground="#60738A" Margin="0,0,0,10"/>
        <WrapPanel><Button Name="SetClearTargets" Content="Clear recent targets"/><Button Name="SetClearFavorites" Content="Clear favorites"/></WrapPanel>
        <TextBlock Text="These actions affect only this technician profile, not the shared toolkit configuration." Foreground="#60738A" FontSize="11" TextWrapping="Wrap"/>
       </StackPanel>
      </Border>
      <TextBlock Text="Configuration file: Toolkit-config.json" Foreground="#60738A" FontSize="11"/>
     </StackPanel>
    </StackPanel>
   </ScrollViewer>
  </Grid>
  <Border Grid.Row="2" Background="#E8EEF5" BorderBrush="#CDD9E7" BorderThickness="0,1,0,0" Padding="12,4">
   <Grid>
    <Grid.ColumnDefinitions>
     <ColumnDefinition Width="2*"/><ColumnDefinition Width="2*"/><ColumnDefinition Width="1.7*"/><ColumnDefinition Width="1.6*"/>
    </Grid.ColumnDefinitions>
    <TextBlock Grid.Column="0" Name="Status" Text="Ready" Foreground="#35516B" VerticalAlignment="Center" TextTrimming="CharacterEllipsis" Margin="0,0,12,0"/>
    <Grid Grid.Column="1" VerticalAlignment="Center" Margin="0,0,12,0">
     <Grid.ColumnDefinitions><ColumnDefinition Width="Auto"/><ColumnDefinition Width="*"/></Grid.ColumnDefinitions>
     <TextBlock Text="TECHNICIAN  " FontSize="10" FontWeight="SemiBold" Foreground="#61748B" VerticalAlignment="Center"/>
     <TextBlock Grid.Column="1" Name="LocalUser" Foreground="#17365D" FontSize="11" VerticalAlignment="Center" TextTrimming="CharacterEllipsis"/>
    </Grid>
    <Grid Grid.Column="2" VerticalAlignment="Center" Margin="0,0,12,0">
     <Grid.ColumnDefinitions><ColumnDefinition Width="Auto"/><ColumnDefinition Width="*"/></Grid.ColumnDefinitions>
     <TextBlock Text="COMPUTER  " FontSize="10" FontWeight="SemiBold" Foreground="#61748B" VerticalAlignment="Center"/>
     <TextBlock Grid.Column="1" Name="LocalComputer" Foreground="#17365D" FontSize="11" VerticalAlignment="Center" TextTrimming="CharacterEllipsis"/>
    </Grid>
    <DockPanel Grid.Column="3" LastChildFill="True" VerticalAlignment="Center">
     <TextBlock Name="FooterRight" DockPanel.Dock="Right" Visibility="Collapsed"/>
     <TextBlock Text="POWERSHELL  " FontSize="10" FontWeight="SemiBold" Foreground="#61748B" DockPanel.Dock="Left"/>
     <TextBlock Name="LocalPSVersion" Foreground="#17365D" FontSize="11" TextTrimming="CharacterEllipsis"/>
    </DockPanel>
   </Grid>
  </Border>
 </Grid>
</Window>
'@
$reader = New-Object System.Xml.XmlNodeReader $xaml
$window = [Windows.Markup.XamlReader]::Load($reader)
$ui = @{}
foreach ($name in @('Heading','Subtitle','HeaderLogo','NavDashboard','NavDiagnostics','NavTools','NavReports','NavSettings','SwitchClassic','PageDashboard','PageDiagnostics','PageTools','PageReports','PageSettings','SideTarget','SideIPv4','SideAccess','SideStatusCard','SideAccessBadge','TargetInput','SetTarget','UseLocalTarget','ClearTarget','UseAlternate','AlternateUserLabel','ChangeAlternate','AlternateProbeSummary','TargetDnsSummary','TargetPingSummary','TargetCheckTime','TargetLastDiagnostic','DashboardHealthSummary','HealthReviewCount','HealthAvailableCount','HealthUnavailableCount','HealthStorageDetail','HealthServicesDetail','HealthEventsDetail','HealthSystemDetail','HealthSecurityDetail','HealthUpdatesDetail','HealthRestartDetail','QuickPing','QuickDns','QuickHealth','TargetStatusCard','TargetNameText','TargetIpText','AdminBadge','AdminStatusText','AdminDetailBox','AdminDetailText','DashboardPins','PinHint','EditPins','RecentTargetRows','RecentReportRows','ClearRecents','MoreReports','LocalUser','LocalComputer','LocalPSVersion','PingTarget','DnsTarget','CheckAdmin','DiagnosticSection','RunDiagnostic','RunElevatedLocalDiagnostic','RunAllDiagnostics','CreateSnapshotGUI','DiagnosticProgress','DiagnosticOutput','CopyDiagnosticReport','SaveDiagnosticReport','DiagnosticReportFormat','DiagnosticSaveStatus','ToolRows','ToolSearch','ToolFilter','ToolRefresh','ToolSummary','AddCustomTool','ArchiveTabs','ArchiveSearch','ArchiveFormat','ArchiveList','ArchiveRefresh','ArchiveOpen','ArchiveFolder','ArchiveCopyPath','ArchiveStatus','SnapshotOlder','SnapshotNewer','SnapshotsRefresh','CompareSnapshotsGUI','SaveComparisonGUI','ComparisonFormat','SnapshotStatus','ComparisonOutput','SettingsInfo','SetOrgName','SetAuthDomain','SetSysinternals','SetPortQry','SetReportsFolder','SetReportsFormat','SetLogoPath','SetLoginPath','SetIconPath','SetSaveConfig','SetReloadConfig','SetConfigStatus','SetClearTargets','SetClearFavorites','FooterRight','Status')) { $ui[$name] = $window.FindName($name) }
$window.Title = "$displayName - Graphical Interface"
$ui.Heading.Text = $displayName
$ui.Subtitle.Text = "Graphical Interface  |  Toolkit v$version"
$ui.FooterRight.Text = [Security.Principal.WindowsIdentity]::GetCurrent().Name
$ui.LocalUser.Text = [Security.Principal.WindowsIdentity]::GetCurrent().Name
$ui.LocalComputer.Text = $env:COMPUTERNAME
$ui.LocalUser.ToolTip = $ui.LocalUser.Text
$ui.LocalComputer.ToolTip = $ui.LocalComputer.Text
$ui.LocalPSVersion.Text = [string]$PSVersionTable.PSVersion
$ui.SettingsInfo.Text = "Personal preferences: $prefsPath`nMaximum dashboard favorites: 10`nRecent targets retained: 8"

function Load-GUIImage([string]$configured, [string]$fallback) {
    $path = if (-not [string]::IsNullOrWhiteSpace($configured)) { $configured } else { $fallback }
    if (-not [IO.Path]::IsPathRooted($path)) { $path = Join-Path $script:ToolkitRoot $path }
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { return $null }
    try {
        $bitmap = New-Object Windows.Media.Imaging.BitmapImage
        $bitmap.BeginInit(); $bitmap.CacheOption = [Windows.Media.Imaging.BitmapCacheOption]::OnLoad; $bitmap.UriSource = New-Object Uri($path, [UriKind]::Absolute); $bitmap.EndInit(); $bitmap.Freeze()
        return $bitmap
    } catch { return $null }
}
$logoPath = if ($cfg.Branding) { [string]$cfg.Branding.LogoPath } else { '' }
$logo = Load-GUIImage $logoPath 'Branding\Logo.png'
if ($logo) { $ui.HeaderLogo.Source = $logo; $ui.HeaderLogo.Visibility = 'Visible' }
$iconPath = if ($cfg.Branding -and $cfg.Branding.AppIconPath) { [string]$cfg.Branding.AppIconPath } else { 'Branding\AppIcon.ico' }
$icon = Load-GUIImage $iconPath 'Branding\AppIcon.ico'
if ($icon) { $window.Icon = $icon }

$script:GUIAuthContext = $null
$script:GUIAlternateUser = ''
$script:GUIAlternateMode = $false
$script:GUIAlternateTarget = ''
$script:TargetComputer = $null
$script:LocalTargetMode = $false
$script:TargetIPv4 = '(not selected)'
$script:AdminStatus = 'Not checked'
$script:AdminDetail = 'Select a target first.'
$script:TargetLastChecked = $null
$script:TargetPingState = 'Not checked'
$script:LastDiagnosticSummary = 'None this session'
function Update-TargetInfo {
    if (-not $script:TargetComputer) {
        $ui.TargetDnsSummary.Text = 'Not checked'
        $ui.TargetPingSummary.Text = 'Not checked'
        $ui.TargetCheckTime.Text = 'Not checked'
        $ui.TargetLastDiagnostic.Text = $script:LastDiagnosticSummary
        return
    }
    $ui.TargetDnsSummary.Text = if ($script:TargetIPv4 -match '^\d{1,3}\.') { 'Resolved: ' + $script:TargetIPv4 } else { [string]$script:TargetIPv4 }
    $ui.TargetPingSummary.Text = [string]$script:TargetPingState
    $ui.TargetCheckTime.Text = if ($script:TargetLastChecked) { $script:TargetLastChecked.ToString('g') } else { 'Not checked' }
    $ui.TargetLastDiagnostic.Text = [string]$script:LastDiagnosticSummary
}
function Clear-DashboardHealthDetails {
    $ui.DashboardHealthSummary.Text = 'Run Health Check for the selected local or remote computer to populate evidence.'
    foreach ($name in @('HealthReviewCount','HealthAvailableCount','HealthUnavailableCount')) { $ui[$name].Text = '—' }
    $ui.HealthStorageDetail.Text = 'Storage: Not assessed'
    $ui.HealthServicesDetail.Text = 'Services: Not assessed'
    $ui.HealthEventsDetail.Text = 'Events: Not assessed'
    $ui.HealthSystemDetail.Text = 'System: Not assessed'
    $ui.HealthSecurityDetail.Text = 'Security: Not assessed'
    $ui.HealthUpdatesDetail.Text = 'Updates: Not assessed'
    $ui.HealthRestartDetail.Text = 'Restart: Not assessed'
}
function Update-TargetView {
    # Do not display another target's prior health observations as current.
    $currentHealthMode = if ($script:LocalTargetMode) { 'Local' } elseif ($script:GUIAlternateMode) { 'Alternate' } else { 'Default' }
    $currentHealthIdentity = if ($script:GUIAlternateMode) { [string]$script:GUIAlternateUser } else { [Security.Principal.WindowsIdentity]::GetCurrent().Name }
    if ($script:DashboardHealthTarget -and
        ($script:DashboardHealthTarget -ine $script:TargetComputer -or
         $script:DashboardHealthMode -ne $currentHealthMode -or
         $script:DashboardHealthIdentity -ine $currentHealthIdentity)) {
        $script:DashboardHealthTarget = $null
        Clear-DashboardHealthDetails
    }
    $label = if ($script:TargetComputer) { $script:TargetComputer } else { 'Not selected' }
    $ipText = if ($script:TargetIPv4) { [string]$script:TargetIPv4 } else { '(not selected)' }
    $statusText = [string]$script:AdminStatus
    $detailText = [string]$script:AdminDetail

    $ui.SideTarget.Text = $label
    $ui.SideTarget.ToolTip = $label
    $ui.SideIPv4.Text = $ipText
    $ui.SideIPv4.Visibility = if ($script:TargetComputer) { 'Visible' } else { 'Collapsed' }
    $ui.SideAccess.Text = $statusText
    $ui.TargetNameText.Text = $label
    $ui.TargetNameText.ToolTip = $label
    $ui.TargetIpText.Text = $ipText
    $ui.AdminStatusText.Text = $statusText
    $ui.AdminDetailText.Text = $detailText

    # ADMIN$ access alone is not proof of all administrative privileges.
    $palette = switch -Regex ($statusText) {
        '^Admin share accessible$' { @('#DDF4E6','#8CCCAA','#176A3A','#F0FAF4','#C1E6CF'); break }
        '^Failed - Access denied$' { @('#FDE5E8','#E4A3AD','#9C2436','#FFF2F3','#F0C4CB'); break }
        '^(Unable to verify|Check failed)$' { @('#FFF0D9','#E8C28F','#935713','#FFFAF0','#F1D9B5'); break }
        '^Credential conflict$' { @('#FFF0D9','#E8C28F','#935713','#FFFAF0','#F1D9B5'); break }
        '^Checking' { @('#E0EFFD','#9FC8EA','#205D9D','#F0F7FF','#C9DFF4'); break }
        default { @('#E5EAF0','#BBC8D5','#51667B','#F1F5FA','#D4DEE9') }
    }
    $brush = New-Object System.Windows.Media.BrushConverter
    foreach ($badge in @($ui.AdminBadge, $ui.SideAccessBadge)) {
        $badge.Background = $brush.ConvertFromString($palette[0])
        $badge.BorderBrush = $brush.ConvertFromString($palette[1])
    }
    $ui.AdminStatusText.Foreground = $brush.ConvertFromString($palette[2])
    $ui.SideAccess.Foreground = $brush.ConvertFromString($palette[2])
    $ui.AdminDetailBox.Background = $brush.ConvertFromString($palette[3])
    $ui.AdminDetailBox.BorderBrush = $brush.ConvertFromString($palette[4])
    $ui.AdminDetailText.Foreground = $brush.ConvertFromString($palette[2])
    $ui.SideStatusCard.BorderBrush = $brush.ConvertFromString($palette[1])
    $ui.TargetStatusCard.BorderBrush = $brush.ConvertFromString($palette[1])
    Update-TargetInfo
}
function Test-GUIAdminShare {
    if ($script:LocalTargetMode) { return }
    if (-not $script:TargetComputer) { return }
    $script:AdminStatus = 'Checking ADMIN$'
    $script:AdminDetail = 'Checking share access with the selected authentication mode.'
    Update-TargetView
    try {
        if ($script:GUIAlternateMode) {
            # Never silently fall back to default credentials.
            if (-not $script:GUIAuthContext -or
                $script:GUIAuthContext.Mode -ne 'Alternate' -or
                $script:GUIAuthContext.ComputerName -ine $script:TargetComputer -or
                $null -eq $script:GUIAuthContext.Credential) {
                $script:AdminStatus = 'Not checked'
                $script:AdminDetail = 'Alternate credentials are required before testing ADMIN$.'
                Update-TargetView
                return
            }
            $context = $script:GUIAuthContext
        } else {
            $context = New-ToolkitAuthContext -ComputerName $script:TargetComputer -Mode Default
        }
        $test = Test-ToolkitAdminShare -Context $context
        switch ([string]$test.Status) {
            'Passed'   { $script:AdminStatus = 'Admin share accessible' }
            'Denied'   { $script:AdminStatus = 'Failed - Access denied' }
            'Conflict' { $script:AdminStatus = 'Credential conflict' }
            'Skipped'  { $script:AdminStatus = 'Not checked' }
            'Failed'   { if ([string]$test.Detail -match '(?i)access (is )?denied|unauthorized|0x80070005|Windows error 5') { $script:AdminStatus = 'Failed - Access denied' } else { $script:AdminStatus = 'Check failed' } }
            default    { $script:AdminStatus = 'Unable to verify' }
        }
        $script:AdminDetail = [string]$test.Detail
        if ($script:GUIAlternateMode -and $test.Cleanup -and $test.Cleanup -ne 'Not needed') {
            $script:AdminDetail += ' ' + [string]$test.Cleanup
        }
        $script:TargetLastChecked = $test.CheckedAt
    } catch {
        $script:AdminStatus = if ($_.Exception -is [System.UnauthorizedAccessException] -or $_.Exception.Message -match '(?i)access (is )?denied|unauthorized|0x80070005') { 'Failed - Access denied' } else { 'Check failed' }
        $script:AdminDetail = $_.Exception.Message
        $script:TargetLastChecked = Get-Date
    }
    Update-TargetView
}
# Store only the outcome of the most recent ADMIN$ check; never passwords or credentials.
function Update-GUIRecentTargetStatus {
    if (-not $script:TargetComputer) { return }
    $latest = [pscustomobject]@{
        Name = [string]$script:TargetComputer
        IPv4 = [string]$script:TargetIPv4
        LastStatus = [string]$script:AdminStatus
        LastChecked = (Get-Date).ToString('o')
        CredentialMode = $(if ($script:GUIAlternateMode) { 'Alternate' } else { 'Default' })
        CredentialUser = $(if ($script:GUIAlternateMode) { [string]$script:GUIAlternateUser } else { '' })
    }
    $script:RecentTargets = @(@($latest) + @($script:RecentTargets | Where-Object { $_.Name -ine $latest.Name }) | Select-Object -First 8)
    Save-GUIPreferences
    Refresh-RecentTargets
}
function Clear-GUIAlternateContext {
    if ($null -ne $script:GUIAuthContext) { Clear-ToolkitAuthContext -Context $script:GUIAuthContext }
    $script:GUIAuthContext = $null
    $script:GUIAlternateUser = ''
    $script:GUIAlternateTarget = ''
}
function Set-GUIAuthView {
    $ui.UseAlternate.IsEnabled = -not $script:LocalTargetMode
    $ui.AlternateUserLabel.Text = if ($script:GUIAlternateMode -and $script:GUIAlternateUser) { [string]$script:GUIAlternateUser } else { '' }
    $ui.ChangeAlternate.IsEnabled = [bool]$script:GUIAlternateMode
    $ui.CheckAdmin.IsEnabled = -not $script:GUIAlternateMode -and -not $script:LocalTargetMode
    # Health uses the same credential-aware diagnostic dispatcher as other checks.
    $ui.QuickHealth.IsEnabled = $true
    # Diagnostic execution is enabled for either mode; alternate runs require a live auth context.
    $ui.RunDiagnostic.IsEnabled = $true
    $ui.RunAllDiagnostics.IsEnabled = $true
    if (-not $script:GUIAlternateMode) { $ui.AlternateProbeSummary.Text = 'Default toolkit identity. Diagnostics and ADMIN$ work as before.' }
}
function Confirm-GUIAlternateCredential {
    if (-not $script:GUIAlternateMode) { return $true }
    $target = $ui.TargetInput.Text.Trim()
    if (-not $target -or $target -notmatch '^[a-zA-Z0-9_.-]+$') {
        [Windows.MessageBox]::Show('Enter a target before supplying credentials.','Target required') | Out-Null
        return $false
    }
    if ($script:GUIAuthContext -and $script:GUIAlternateTarget -ieq $target) { return $true }
    $dlg = New-Object Windows.Window
    $dlg.Title = 'Alternate credentials - ' + $target
    $dlg.Width = 440; $dlg.Height = 270; $dlg.MinWidth = 400
    $dlg.WindowStartupLocation = 'CenterOwner'; $dlg.Owner = $window
    $dlg.ResizeMode = 'NoResize'; $dlg.Background = '#F4F7FB'
    $stack = New-Object Windows.Controls.StackPanel; $stack.Margin = '22'
    $txt = New-Object Windows.Controls.TextBlock; $txt.Text = 'Username (DOMAIN\\user, COMPUTER\\user or UPN)'; $txt.Margin = '0,0,0,6'
    [void]$stack.Children.Add($txt)
    $nameInput = New-Object Windows.Controls.TextBox; $nameInput.Height = 30; $nameInput.Padding = '6,4'; $nameInput.Text = [string]$script:GUIAlternateUser
    if (-not $nameInput.Text -and $cfg.AuthenticationDomain) { $nameInput.Text = [string]$cfg.AuthenticationDomain + '\' }
    [void]$stack.Children.Add($nameInput)
    $pt = New-Object Windows.Controls.TextBlock; $pt.Text = 'Password (never saved)'; $pt.Margin = '0,14,0,6'; [void]$stack.Children.Add($pt)
    $passwordInput = New-Object Windows.Controls.PasswordBox; $passwordInput.Height = 30; $passwordInput.Padding = '6,4'; [void]$stack.Children.Add($passwordInput)
    $buttons = New-Object Windows.Controls.StackPanel; $buttons.Orientation='Horizontal'; $buttons.HorizontalAlignment='Right'; $buttons.Margin='0,19,0,0'
    $ok = New-Object Windows.Controls.Button; $ok.Content='Test credentials'; $ok.Width=132; $ok.Height=32; $ok.IsDefault=$true
    $cancel = New-Object Windows.Controls.Button; $cancel.Content='Cancel'; $cancel.Width=90; $cancel.Height=32; $cancel.IsCancel=$true
    [void]$buttons.Children.Add($ok); [void]$buttons.Children.Add($cancel); [void]$stack.Children.Add($buttons)
    $dlg.Content=$stack
    $ok.Add_Click({
        try {
            $user = Resolve-ToolkitAuthUserName -UserName $nameInput.Text -DefaultDomain ([string]$cfg.AuthenticationDomain)
            if ($passwordInput.SecurePassword.Length -eq 0) { throw 'Enter a password.' }
            $dlg.Tag = [System.Management.Automation.PSCredential]::new($user,$passwordInput.SecurePassword.Copy())
            $dlg.DialogResult = $true
        } catch { [Windows.MessageBox]::Show($_.Exception.Message,'Invalid credentials') | Out-Null }
    })
    if ($dlg.ShowDialog() -ne $true) { return $false }
    $credential = [System.Management.Automation.PSCredential]$dlg.Tag
    try {
        $candidate = New-ToolkitAuthContext -ComputerName $target -Mode Alternate -Credential $credential
        $ui.AlternateProbeSummary.Text = 'Testing WMI/DCOM and WinRM...'; $window.Dispatcher.Invoke([Action]{},[Windows.Threading.DispatcherPriority]::Background)
        $probes = @(Get-ToolkitAuthProbeSummary -Context $candidate)
        $wmi = @($probes | Where-Object { $_.Method -eq 'WMI' })[0]
        $winrm = @($probes | Where-Object { $_.Method -eq 'WinRM' })[0]
        Clear-GUIAlternateContext
        $script:GUIAuthContext = $candidate
        $script:GUIAlternateTarget = $target
        $script:GUIAlternateUser = $credential.UserName
        $ui.AlternateProbeSummary.Text = "Last probe: WMI $($wmi.Status); WinRM $($winrm.Status). Use Set target / Check access to test ADMIN`$ with the selected identity."
        Set-GUIAuthView
        if ($wmi.Status -ne 'Passed' -or $winrm.Status -ne 'Passed') {
            [Windows.MessageBox]::Show(($probes | Format-Table Method,Status,Detail -Wrap | Out-String),'Connection test results') | Out-Null
        }
        return $true
    } catch {
        [Windows.MessageBox]::Show($_.Exception.Message,'Credential probe failed') | Out-Null
        return $false
    } finally { $dlg.Tag = $null; $credential = $null }
}

function Resolve-GUITarget {
    if ($null -ne $script:DiagnosticPS -or $null -ne $script:SnapshotPS) {
        [Windows.MessageBox]::Show('Wait for the active collection to finish before changing targets.','Collection in progress') | Out-Null
        return
    }
    Clear-GUIReportState
    $value = $ui.TargetInput.Text.Trim()
    if (-not $value -or $value -notmatch '^[a-zA-Z0-9_.-]+$') { [Windows.MessageBox]::Show('Enter a valid hostname or IPv4 address.', 'Target computer') | Out-Null; return }
    if ($script:GUIAlternateTarget -and $script:GUIAlternateTarget -ine $value) { Clear-GUIAlternateContext }
    if ($script:GUIAlternateMode -and -not (Confirm-GUIAlternateCredential)) { return }
    $script:LocalTargetMode = $false
    Set-GUIAuthView
    $script:TargetComputer = $value
    $script:TargetPingState = 'Checking ICMP...'
    $script:TargetLastChecked = $null
    $script:LastDiagnosticSummary = 'None this session'
    $script:AdminStatus = 'Not checked'; $script:AdminDetail = 'Resolving target.'
    $script:TargetIPv4 = '(DNS lookup failed)'
    $ip = $null
    if ([Net.IPAddress]::TryParse($value,[ref]$ip) -and $ip.AddressFamily -eq [Net.Sockets.AddressFamily]::InterNetwork) { $script:TargetIPv4 = $value }
    else {
        try { $ips = @([Net.Dns]::GetHostAddresses($value) | Where-Object { $_.AddressFamily -eq [Net.Sockets.AddressFamily]::InterNetwork } | ForEach-Object { $_.ToString() } | Select-Object -Unique); $script:TargetIPv4 = if ($ips.Count) { $ips -join ', ' } else { '(no IPv4 DNS record)' } } catch { }
    }
    # ICMP status is independent of authentication and ADMIN$ access.
    # A blocked ping does not imply that WMI or WinRM diagnostics will fail.
    try {
        $replied = [bool](Test-Connection -ComputerName $value -Count 1 -Quiet -ErrorAction Stop)
        $script:TargetPingState = if ($replied) { 'Responding to ping' } else { 'No ICMP response' }
    } catch {
        $script:TargetPingState = 'Ping not available: ' + $_.Exception.Message
    }
    $script:AdminStatus = 'Not checked'
    $script:AdminDetail = 'ADMIN$ access has not been tested.'
    Update-TargetView
    $ui.Status.Text = "Target selected: $value"; $window.Dispatcher.Invoke([Action]{},[Windows.Threading.DispatcherPriority]::Background)
    Test-GUIAdminShare
    Update-GUIRecentTargetStatus
    $ui.Status.Text = "Target selected: $value"
}
# Window placement is read/written only when opening or closing the main GUI.
# Normal restore bounds are preserved when maximized, so unmaximizing works.
function Save-GUIWindowPlacement {
    $bounds = if ($window.WindowState -eq [Windows.WindowState]::Maximized) {
        $window.RestoreBounds
    } else {
        [Windows.Rect]::new($window.Left, $window.Top, $window.Width, $window.Height)
    }
    $script:GUIWindowPlacement = [ordered]@{
        Left = [double]$bounds.Left
        Top = [double]$bounds.Top
        Width = [double]$bounds.Width
        Height = [double]$bounds.Height
        Maximized = ($window.WindowState -eq [Windows.WindowState]::Maximized)
    }
}
function Restore-GUIWindowPlacement {
    $saved = $script:GUIWindowPlacement
    if ($null -eq $saved) { return }
    try {
        $left = [double]$saved.Left; $top = [double]$saved.Top
        $width = [double]$saved.Width; $height = [double]$saved.Height
        foreach ($number in @($left,$top,$width,$height)) {
            if ([double]::IsNaN($number) -or [double]::IsInfinity($number)) { return }
        }
        if ($width -lt $window.MinWidth -or $height -lt $window.MinHeight -or
            $width -gt 10000 -or $height -gt 10000) { return }

        # Ensure at least a meaningful portion remains on a connected monitor.
        # Screen bounds use device pixels; WPF coordinates use device-independent units.
        Add-Type -AssemblyName System.Windows.Forms -ErrorAction Stop
        $source = [Windows.PresentationSource]::FromVisual($window)
        $scaleX = 1.0; $scaleY = 1.0
        if ($null -ne $source -and $null -ne $source.CompositionTarget) {
            $scaleX = $source.CompositionTarget.TransformToDevice.M11
            $scaleY = $source.CompositionTarget.TransformToDevice.M22
        }
        $visible = $false
        foreach ($screen in [System.Windows.Forms.Screen]::AllScreens) {
            $work = $screen.WorkingArea
            $screenLeft = $work.Left / $scaleX; $screenTop = $work.Top / $scaleY
            $screenRight = $work.Right / $scaleX; $screenBottom = $work.Bottom / $scaleY
            if ([math]::Min($left + $width,$screenRight) - [math]::Max($left,$screenLeft) -ge 100 -and
                [math]::Min($top + $height,$screenBottom) - [math]::Max($top,$screenTop) -ge 80) {
                $visible = $true; break
            }
        }
        if (-not $visible) { return }
        $window.WindowStartupLocation = [Windows.WindowStartupLocation]::Manual
        $window.Width = $width; $window.Height = $height
        $window.Left = $left; $window.Top = $top
        if ($saved.Maximized -eq $true) {
            $window.WindowState = [Windows.WindowState]::Maximized
        }
    } catch {
        # Malformed preferences or unavailable display APIs use XAML defaults.
    }
}
function Show-GUIPage([string]$name) {
    if ($name -notin @('Dashboard','Diagnostics','Tools','Reports','Settings')) { return }
    $script:LastGUIPage = $name
    foreach ($page in @('Dashboard','Diagnostics','Tools','Reports','Settings')) { $ui["Page$page"].Visibility = if ($page -eq $name) { 'Visible' } else { 'Collapsed' } }
    $ui.Status.Text = "$name - Ready"
}
function Start-GUITool([string]$id) {
    $app = $script:Apps | Where-Object { $_.Id -eq $id } | Select-Object -First 1
    if (-not $app) { return }
    $exe = $script:ResolvedApps[$id]
    if (-not $exe) { [Windows.MessageBox]::Show("$($app.Name) was not found on this computer.", 'Tool unavailable') | Out-Null; return }
    try {
        if ($id -eq 'powershell-admin') {
            # Windows requests the administrator identity through UAC. Do not
            # forward alternate target credentials or elevate the toolkit.
            $confirm = [Windows.MessageBox]::Show(
                'Open a separate Windows PowerShell session as administrator? Windows UAC will request approval or credentials. IT Toolkit stays under your current account.',
                'Open elevated PowerShell',
                [Windows.MessageBoxButton]::YesNo,
                [Windows.MessageBoxImage]::Question)
            if ($confirm -ne [Windows.MessageBoxResult]::Yes) { return }
            Start-Process -FilePath $exe -ArgumentList '-NoLogo' -Verb RunAs -ErrorAction Stop | Out-Null
        }
        elseif ($id -in @('portqry','psexec')) {
            # Command-line utilities: keep help, EULA prompts, and error output visible.
            Start-Process -FilePath $env:ComSpec -ArgumentList ('/k ""' + $exe + '" -?"') -ErrorAction Stop | Out-Null
        }
        elseif ($app.Args) { Start-Process -FilePath $exe -ArgumentList $app.Args -ErrorAction Stop | Out-Null }
        else { Start-Process -FilePath $exe -ErrorAction Stop | Out-Null }
        $ui.Status.Text = "Launched: $($app.Name)"
    } catch { [Windows.MessageBox]::Show($_.Exception.Message, 'Unable to launch tool') | Out-Null }
}
# Shared multiline labels for dynamically generated Tools and Dashboard buttons.
# A bounded TextBlock width is needed because UniformGrid/WrapPanel content can
# otherwise measure wider than its button, defeating TextWrapping.
function New-GUIToolButtonLabel([string]$text, [double]$maxWidth) {
    $label = New-Object Windows.Controls.TextBlock
    $label.Text = $text
    $label.TextWrapping = [Windows.TextWrapping]::Wrap
    $label.TextAlignment = [Windows.TextAlignment]::Center
    $label.VerticalAlignment = [Windows.VerticalAlignment]::Center
    $label.HorizontalAlignment = [Windows.HorizontalAlignment]::Center
    $label.MaxWidth = $maxWidth
    $label.FontSize = 12
    return $label
}
function Update-FavoriteColumns {
    $width = $ui.DashboardPins.ActualWidth
    if ($width -le 0) { $width = $window.ActualWidth - 260 }
    $columns = if ($width -ge 1300) { 10 } elseif ($width -ge 720) { 5 } else { 2 }
    if ($ui.DashboardPins.Columns -ne $columns) { $ui.DashboardPins.Columns = $columns }
}
function Refresh-DashboardPins {
    $ui.DashboardPins.Children.Clear()
    $valid = @($script:FavoriteIds | Select-Object -First 10)
    foreach ($id in $valid) {
        $item = $script:Apps | Where-Object { $_.Id -eq $id } | Select-Object -First 1
        if (-not $item) { continue }
        $button = New-Object Windows.Controls.Button
        $button.Content = New-GUIToolButtonLabel ([string]$item.Name) 110; $button.MinWidth = 0; $button.MinHeight = 70; $button.HorizontalAlignment = [Windows.HorizontalAlignment]::Stretch
        $button.ToolTip = $item.Description
        $button.Margin = [Windows.Thickness]::new(0,0,7,7)
        $button.IsEnabled = [bool]$script:ResolvedApps[$id]
        $selectedId = $id
        $button.Add_Click({ Start-GUITool $this.Tag }.GetNewClosure())
        $button.Tag = $selectedId
        [void]$ui.DashboardPins.Children.Add($button)
    }
    Update-FavoriteColumns
    $ui.PinHint.Text = if ($valid.Count) { "Showing $($valid.Count) of 10 favorite shortcuts. Unavailable tools are disabled." } else { 'No favorites selected. Open Tools to choose up to ten.' }
}
# Recent targets are non-secret per-user history; selecting one performs a fresh lookup/check.
function Refresh-RecentTargets {
    $ui.RecentTargetRows.Children.Clear()
    if (@($script:RecentTargets).Count -eq 0) {
        $empty = New-Object Windows.Controls.TextBlock
        $empty.Text = 'No recent targets yet.'; $empty.Foreground = '#60738A'
        [void]$ui.RecentTargetRows.Children.Add($empty)
        return
    }
    $brush = New-Object System.Windows.Media.BrushConverter
    foreach ($entry in @($script:RecentTargets | Select-Object -First 8)) {
        $row = New-Object Windows.Controls.DockPanel
        $row.Margin = '0,0,0,5'
        $button = New-Object Windows.Controls.Button
        $button.Content = New-GUIToolButtonLabel ([string]$entry.Name) 145
        $button.Tag = [string]$entry.Name
        $button.Margin = '0,0,8,0'; $button.MinWidth = 140; $button.MaxWidth = 175; $button.MinHeight = 36
        $rememberedMode = if ($entry.PSObject.Properties['CredentialMode']) { [string]$entry.CredentialMode } else { 'Default' }
        $rememberedUser = if ($entry.PSObject.Properties['CredentialUser']) { [string]$entry.CredentialUser } else { '' }
        $button.Tag = [pscustomobject]@{ Name = [string]$entry.Name; Mode = $rememberedMode; User = $rememberedUser }
        $button.Add_Click({
            $data = $this.Tag
            Clear-GUIAlternateContext
            $script:GUIAlternateMode = ([string]$data.Mode -eq 'Alternate')
            $ui.UseAlternate.IsChecked = $script:GUIAlternateMode
            $script:GUIAlternateUser = [string]$data.User
            Set-GUIAuthView
            $ui.TargetInput.Text = [string]$data.Name
            Resolve-GUITarget
        })

        # These colors indicate a SAVED check result, not current connectivity.
        $lastStatus = if ($entry.PSObject.Properties['LastStatus']) { [string]$entry.LastStatus } else { 'Not checked' }
        $lastChecked = if ($entry.PSObject.Properties['LastChecked']) { [string]$entry.LastChecked } else { '' }
        $colors = switch ($lastStatus) {
            'Admin share accessible' { @('#DDF4E6','#8CCCAA','#176A3A'); break }
            'Failed - Access denied' {  @('#FDE5E8','#E4A3AD','#9C2436'); break }
            'Check failed'          { @('#FFF0D9','#E8C28F','#935713'); break }
            'Unable to verify'       { @('#FFF0D9','#E8C28F','#935713'); break }
            default                  { @('#E5EAF0','#BBC8D5','#51667B') }
        }
        $button.Background = $brush.ConvertFromString($colors[0])
        $button.BorderBrush = $brush.ConvertFromString($colors[1])
        $button.Foreground = $brush.ConvertFromString($colors[2])
        $checkedText = 'Not recorded'
        if (-not [string]::IsNullOrWhiteSpace($lastChecked)) {
            try { $checkedText = ([datetime]::Parse($lastChecked)).ToString('g') } catch { $checkedText = $lastChecked }
        }
        $button.ToolTip = "Last known ADMIN`$ status: $lastStatus`nLast checked: $checkedText`nLast IPv4: $($entry.IPv4)`nClick to recheck."
        [Windows.Controls.DockPanel]::SetDock($button, 'Left')
        [void]$row.Children.Add($button)
        $ip = New-Object Windows.Controls.TextBlock
        $ip.Text = [string]$entry.IPv4
        $ip.Foreground = '#60738A'; $ip.VerticalAlignment = 'Center'; $ip.TextTrimming = [Windows.TextTrimming]::CharacterEllipsis; $ip.ToolTip = $ip.Text
        [void]$row.Children.Add($ip)
        [void]$ui.RecentTargetRows.Children.Add($row)
    }
}
function Open-GUISavedReport {
    param([Parameter(Mandatory=$true)][string]$Path)
    $fullPath = [IO.Path]::GetFullPath($Path)
    if (-not (Test-Path -LiteralPath $fullPath -PathType Leaf)) { throw "Report file not found: $fullPath" }
    if ([IO.Path]::GetExtension($fullPath).Equals('.html', [StringComparison]::OrdinalIgnoreCase)) {
        # Explicit Edge launch avoids silent shell association failures in alternate-credential sessions.
        $edgePaths = @(
            (Join-Path ${env:ProgramFiles(x86)} 'Microsoft\Edge\Application\msedge.exe'),
            (Join-Path $env:ProgramFiles 'Microsoft\Edge\Application\msedge.exe')
        )
        $edge = $edgePaths | Where-Object { $_ -and (Test-Path -LiteralPath $_ -PathType Leaf) } | Select-Object -First 1
        if ($edge) {
            $uri = ([System.Uri]::new($fullPath)).AbsoluteUri
            Start-Process -FilePath $edge -ArgumentList ('--new-window "' + $uri + '"') -ErrorAction Stop | Out-Null
            return
        }
    }
    Start-Process -FilePath $fullPath -Verb Open -ErrorAction Stop | Out-Null
}
function Refresh-RecentReports {
    $ui.RecentReportRows.Children.Clear()
    $folder = Get-GUIArchiveFolder
    $reports = @()
    if (Test-Path -LiteralPath $folder -PathType Container) {
        $reports = @(Get-ChildItem -LiteralPath $folder -File -ErrorAction SilentlyContinue | Where-Object { $_.Extension -in @('.html','.csv','.txt') } | Sort-Object LastWriteTime -Descending | Select-Object -First 5)
    }
    if ($reports.Count -eq 0) {
        $empty = New-Object Windows.Controls.TextBlock
        $empty.Text = 'No saved reports yet.'; $empty.Foreground = '#60738A'
        [void]$ui.RecentReportRows.Children.Add($empty)
        return
    }
    foreach ($file in $reports) {
        $row = New-Object Windows.Controls.DockPanel
        $row.Margin = '0,0,0,5'
        $button = New-Object Windows.Controls.Button
        $button.Content = New-GUIToolButtonLabel ([string]$file.Name) 165; $button.Tag = [string]$file.FullName
        $button.ToolTip = 'Open saved report: ' + $file.FullName
        $button.MaxWidth = 185; $button.MinHeight = 36; $button.Margin = '0,0,8,0'
        $button.Add_Click({
            try { Open-GUISavedReport -Path ([string]$this.Tag) }
            catch { [Windows.MessageBox]::Show("Unable to open report: $($_.Exception.Message)", 'Report Archive') | Out-Null }
        })
        [Windows.Controls.DockPanel]::SetDock($button, 'Left')
        [void]$row.Children.Add($button)
        $date = New-Object Windows.Controls.TextBlock
        $date.Text = $file.LastWriteTime.ToString('yyyy-MM-dd')
        $date.Foreground = '#60738A'; $date.VerticalAlignment = 'Center'
        [void]$row.Children.Add($date)
        [void]$ui.RecentReportRows.Children.Add($row)
    }
}
function Show-GUICustomToolEditor([string]$toolId) {
    $existing = $null
    if ($toolId) { $existing = $script:CustomApps | Where-Object { $_.Id -eq $toolId } | Select-Object -First 1 }
    [xml]$dialogXaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" Title="Custom Tool" Width="650" Height="520" MinWidth="580" WindowStartupLocation="CenterOwner" ResizeMode="NoResize" Background="#F4F7FB" FontFamily="Segoe UI">
 <Grid Margin="20">
  <Grid.RowDefinitions><RowDefinition Height="*"/><RowDefinition Height="Auto"/></Grid.RowDefinitions>
  <StackPanel>
   <TextBlock Text="Tool name"/><TextBox Name="CTName" Margin="0,4,0,12" Height="28"/>
   <TextBlock Text="Executable or MMC console path (.exe / .msc)"/>
   <DockPanel Margin="0,4,0,12"><Button Name="CTBrowse" Content="Browse..." DockPanel.Dock="Right" Width="85" Margin="8,0,0,0"/><TextBox Name="CTPath" Height="28"/></DockPanel>
   <TextBlock Text="Category"/><TextBox Name="CTGroup" Margin="0,4,0,12" Height="28"/>
   <TextBlock Text="Description (displayed on hover)"/><TextBox Name="CTDescription" Margin="0,4,0,12" Height="28"/>
   <TextBlock Text="Optional arguments"/><TextBox Name="CTArgs" Margin="0,4,0,12" Height="28"/>
   <TextBlock Text="Official download page (optional, HTTPS)"/><TextBox Name="CTUrl" Margin="0,4,0,7" Height="28"/>
   <TextBlock Name="CTError" Foreground="#9B2835" TextWrapping="Wrap"/>
  </StackPanel>
  <StackPanel Grid.Row="1" Orientation="Horizontal" HorizontalAlignment="Right" Margin="0,12,0,0">
   <Button Name="CTCancel" Content="Cancel" Width="100" Height="32" Margin="0,0,10,0"/>
   <Button Name="CTSave" Content="Save Tool" Width="110" Height="32" Background="#17365D" Foreground="White"/>
  </StackPanel>
 </Grid>
</Window>
'@
    $reader = New-Object System.Xml.XmlNodeReader $dialogXaml
    $editor = [Windows.Markup.XamlReader]::Load($reader)
    $editor.Owner = $window
    $controls = @{}
    foreach ($controlName in @('CTName','CTPath','CTGroup','CTDescription','CTArgs','CTUrl','CTBrowse','CTError','CTCancel','CTSave')) { $controls[$controlName] = $editor.FindName($controlName) }
    if ($existing) {
        $editor.Title = 'Edit Custom Tool'
        $controls.CTName.Text = $existing.Name
        $controls.CTPath.Text = $existing.Exe
        $controls.CTGroup.Text = $existing.Group
        $controls.CTDescription.Text = $existing.Description
        $controls.CTArgs.Text = $existing.Args
        $controls.CTUrl.Text = $existing.DownloadUrl
    } else { $controls.CTGroup.Text = 'Custom' }
    $controls.CTCancel.Add_Click({ $editor.DialogResult = $false; $editor.Close() })
    $controls.CTBrowse.Add_Click({
        $fileDialog = New-Object Microsoft.Win32.OpenFileDialog
        $fileDialog.Filter = 'Applications and MMC consoles (*.exe;*.msc)|*.exe;*.msc|All files (*.*)|*.*'
        $fileDialog.CheckFileExists = $true
        if ($fileDialog.ShowDialog($editor) -eq $true) { $controls.CTPath.Text = $fileDialog.FileName }
    })
    $controls.CTSave.Add_Click({
        $name = $controls.CTName.Text.Trim()
        $path = [Environment]::ExpandEnvironmentVariables($controls.CTPath.Text.Trim().Trim('"'))
        $group = $controls.CTGroup.Text.Trim()
        $description = $controls.CTDescription.Text.Trim()
        $args = $controls.CTArgs.Text.Trim()
        $url = $controls.CTUrl.Text.Trim()
        if (-not $name -or -not $path) { $controls.CTError.Text = 'Provide a name and executable path.'; return }
        if (-not [IO.Path]::IsPathRooted($path) -or $path -notmatch '(?i)\.(exe|msc)$') { $controls.CTError.Text = 'Choose an absolute path ending in .exe or .msc.'; return }
        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { $controls.CTError.Text = 'The specified executable does not exist or cannot be accessed.'; return }
        if ($url -and $url -notmatch '^https://[^\s]+$') { $controls.CTError.Text = 'Download links must use HTTPS.'; return }
        if ($name.Length -gt 100 -or $group.Length -gt 70 -or $description.Length -gt 500 -or $args.Length -gt 1000 -or $url.Length -gt 1500) { $controls.CTError.Text = 'One or more fields are too long.'; return }
        $id = if ($existing) { [string]$existing.Id } else { 'custom-' + [guid]::NewGuid().ToString('N') }
        $candidate = [pscustomobject]@{ Id=$id; Name=$name; Group=$(if ($group) { $group } else { 'Custom' }); Description=$description; Exe=$path; Args=$args; DownloadUrl=$url }
        $prior = @($script:CustomApps)
        $script:CustomApps = @($script:CustomApps | Where-Object { $_.Id -ne $id }) + @($candidate)
        try { Save-GUICustomTools } catch {
            $script:CustomApps = $prior
            $controls.CTError.Text = "Save failed: $($_.Exception.Message)"
            return
        }
        $editor.DialogResult = $true
        $editor.Close()
    })
    if ($editor.ShowDialog() -eq $true) { Sync-GUICustomCatalog; Refresh-DashboardPins; Refresh-Tools }
}
function Remove-GUICustomTool([string]$id) {
    $item = $script:CustomApps | Where-Object { $_.Id -eq $id } | Select-Object -First 1
    if (-not $item) { return }
    $answer = [Windows.MessageBox]::Show("Remove custom tool '$($item.Name)' from your catalog?`nThe executable itself will NOT be deleted.", 'Remove custom tool', [Windows.MessageBoxButton]::YesNo, [Windows.MessageBoxImage]::Question)
    if ($answer -ne [Windows.MessageBoxResult]::Yes) { return }
    $oldTools = @($script:CustomApps); $oldFavorites = @($script:FavoriteIds)
    $script:CustomApps = @($script:CustomApps | Where-Object { $_.Id -ne $id })
    $script:FavoriteIds = @($script:FavoriteIds | Where-Object { $_ -ne $id })
    try { Save-GUICustomTools; Save-GUIPreferences } catch { $script:CustomApps = $oldTools; $script:FavoriteIds = $oldFavorites; return }
    Sync-GUICustomCatalog; $script:ResolvedApps.Remove($id); Refresh-DashboardPins; Refresh-Tools
}
function Open-GUIToolDownload([string]$id) {
    $app = $script:Apps | Where-Object { $_.Id -eq $id } | Select-Object -First 1
    if (-not $app) { return }
    $url = if ($id -like 'custom-*') { [string]$app.DownloadUrl } else { [string]$script:DownloadUrls[$id] }
    if ($url -notmatch '^https://[^\s]+$') { return }
    try { Start-Process -FilePath $url -ErrorAction Stop | Out-Null }
    catch { [Windows.MessageBox]::Show("Could not open the browser: $($_.Exception.Message)`n$url", 'Download page') | Out-Null }
}

function Refresh-Tools {
    $ui.ToolRows.Children.Clear()
    $query = ([string]$ui.ToolSearch.Text).Trim()
    $filter = if ($ui.ToolFilter.SelectedItem) { [string]$ui.ToolFilter.SelectedItem.Content } else { 'All tools' }
    $visible = 0
    foreach ($app in ($script:Apps | Sort-Object Group,Name)) {
        $available = [bool]$script:ResolvedApps[$app.Id]
        $favorite = $app.Id -in $script:FavoriteIds
        if ($query -and ("$($app.Name) $($app.Group) $($app.Description)" -notlike "*$query*")) { continue }
        if ($filter -eq 'Installed' -and -not $available) { continue }
        if ($filter -eq 'Unavailable' -and $available) { continue }
        if ($filter -eq 'Favorites' -and -not $favorite) { continue }
        $visible++
        $row = New-Object Windows.Controls.WrapPanel
        $row.Margin = '0,0,0,8'; $row.Orientation = [Windows.Controls.Orientation]::Horizontal; $row.VerticalAlignment = [Windows.VerticalAlignment]::Center
        $launch = New-Object Windows.Controls.Button
        $launch.Width = 205; $launch.MinHeight = 54; $launch.Content = New-GUIToolButtonLabel ([string]$app.Name) 177; $launch.ToolTip = $app.Description
        $launch.IsEnabled = $available; $launch.Tag = $app.Id
        $launch.Add_Click({ Start-GUITool ([string]$this.Tag) })
        [void]$row.Children.Add($launch)
        $star = New-Object Windows.Controls.CheckBox
        $star.Content = 'Favorite'; $star.Width = 92; $star.VerticalAlignment = 'Center'; $star.Margin = '12,0,4,0'
        $star.IsChecked = $favorite; $star.Tag = $app.Id
        $star.Add_Click({
            $id = [string]$this.Tag
            if ($this.IsChecked) {
                if (@($script:FavoriteIds).Count -ge 10) {
                    [Windows.MessageBox]::Show('You can select up to ten dashboard favorites. Uncheck another favorite first.', 'Favorite limit') | Out-Null
                    $this.IsChecked = $false
                    return
                }
                $script:FavoriteIds = @($script:FavoriteIds + $id | Select-Object -Unique)
            } else { $script:FavoriteIds = @($script:FavoriteIds | Where-Object { $_ -ne $id }) }
            Save-GUIPreferences; Refresh-DashboardPins; Refresh-Tools
        })
        [void]$row.Children.Add($star)
        $downloadUrl = if ($app.Id -like 'custom-*') { [string]$app.DownloadUrl } else { [string]$script:DownloadUrls[$app.Id] }
        if ($downloadUrl -match '^https://') {
            $download = New-Object Windows.Controls.Button
            $download.Content = 'Download'; $download.Width = 88; $download.Height = 31
            $download.Margin = '0,0,9,0'; $download.Tag = $app.Id
            $download.ToolTip = 'Open official publisher download page in your browser'
            $download.Add_Click({ Open-GUIToolDownload ([string]$this.Tag) })
            [void]$row.Children.Add($download)
        }
        if ($app.Id -like 'custom-*') {
            $edit = New-Object Windows.Controls.Button
            $edit.Content = 'Edit'; $edit.Width = 55; $edit.Height = 31; $edit.Margin = '0,0,5,0'; $edit.Tag = $app.Id
            $edit.Add_Click({ Show-GUICustomToolEditor ([string]$this.Tag) })
            [void]$row.Children.Add($edit)
            $remove = New-Object Windows.Controls.Button
            $remove.Content = 'Remove'; $remove.Width = 76; $remove.Height = 31; $remove.ToolTip = 'Remove this custom tool from the list (does not uninstall it)'; $remove.Margin = '0,0,9,0'; $remove.Tag = $app.Id
            $remove.Add_Click({ Remove-GUICustomTool ([string]$this.Tag) })
            [void]$row.Children.Add($remove)
        }
        $status = New-Object Windows.Controls.TextBlock
        $status.Text = if ($available) { "$($app.Group)  |  Installed" } else { "$($app.Group)  |  Unavailable" }
        $status.Foreground = if ($available) { '#207647' } else { '#9A5923' }
        $status.VerticalAlignment = 'Center'; $status.ToolTip = if ($available) { $script:ResolvedApps[$app.Id] } else { 'Executable was not found on this workstation' }
        [void]$row.Children.Add($status)
        [void]$ui.ToolRows.Children.Add($row)
    }
    $installedCount = @($script:Apps | Where-Object { [bool]$script:ResolvedApps[$_.Id] }).Count
    $ui.ToolSummary.Text = "Showing $visible of $(@($script:Apps).Count) tools  |  $installedCount detected  |  $(@($script:FavoriteIds).Count) favorites  |  $(@($script:FavoriteIds).Count)/10 dashboard shortcuts"
    if ($visible -eq 0) {
        $empty = New-Object Windows.Controls.TextBlock
        $empty.Text = 'No tools match the current search or filter.'
        $empty.Foreground = '#60738A'; $empty.Margin = '6,12,0,0'
        [void]$ui.ToolRows.Children.Add($empty)
    }
}
$ui.AddCustomTool.Add_Click({ Show-GUICustomToolEditor '' })
$ui.ToolSearch.Add_TextChanged({ Refresh-Tools })
$ui.ToolFilter.Add_SelectionChanged({ Refresh-Tools })
$ui.ToolRefresh.Add_Click({
    $script:SysinternalsFolder = Find-GUISysinternalsFolder
    foreach ($app in $script:Apps) { $script:ResolvedApps[$app.Id] = Resolve-ApplicationPath $app.Exe }
    Refresh-DashboardPins; Refresh-Tools
    $ui.Status.Text = 'Tool availability refreshed.'
})
# The twenty GUI checks reuse the same read-only collectors as Classic.
# Run them in a separate runspace to avoid freezing the WPF dispatcher.
$script:DiagnosticSections = @(
    [pscustomobject]@{Id='Health'; Label='Quick health check'},
    [pscustomobject]@{Id='System'; Label='System information'},
    [pscustomobject]@{Id='Hardware'; Label='Hardware inventory'},
    [pscustomobject]@{Id='Network'; Label='Network diagnostics'},
    [pscustomobject]@{Id='Storage'; Label='Disk space'},
    [pscustomobject]@{Id='Services'; Label='Windows services'},
    [pscustomobject]@{Id='Events'; Label='Recent event errors'},
    [pscustomobject]@{Id='Policy'; Label='Group Policy'},
    [pscustomobject]@{Id='Software'; Label='Installed software'},
    [pscustomobject]@{Id='Updates'; Label='Windows updates'},
    [pscustomobject]@{Id='Tasks'; Label='Scheduled tasks'},
    [pscustomobject]@{Id='Users'; Label='Local users'},
    [pscustomobject]@{Id='Groups'; Label='Local groups'},
    [pscustomobject]@{Id='Administrators'; Label='Local administrators'},
    [pscustomobject]@{Id='Sessions'; Label='User sessions'},
    [pscustomobject]@{Id='Shares'; Label='Network shares'},
    [pscustomobject]@{Id='SharePermissions'; Label='Share permissions'},
    [pscustomobject]@{Id='Firewall'; Label='Windows Firewall'},
    [pscustomobject]@{Id='BitLocker'; Label='BitLocker status'},
    [pscustomobject]@{Id='Startup'; Label='Startup programs'}
)
foreach ($section in $script:DiagnosticSections) {
    $entry = New-Object Windows.Controls.ComboBoxItem
    $entry.Content = $section.Label
    $entry.Tag = $section.Id
    [void]$ui.DiagnosticSection.Items.Add($entry)
}
$ui.DiagnosticSection.SelectedIndex = 0
# Report is populated only after a completed diagnostic collection.
$script:LastGUIReport = $null
$script:PendingGUIReport = $null
$defaultFormat = if ([string]$cfg.ReportFormat -in @('HTML','CSV','TXT')) { ([string]$cfg.ReportFormat).ToUpperInvariant() } else { 'HTML' }
for ($i = 0; $i -lt $ui.DiagnosticReportFormat.Items.Count; $i++) {
    if ([string]$ui.DiagnosticReportFormat.Items[$i].Content -eq $defaultFormat) { $ui.DiagnosticReportFormat.SelectedIndex = $i; break }
}
function Clear-GUIReportState {
    $script:LastGUIReport = $null
    $ui.SaveDiagnosticReport.IsEnabled = $false
    $ui.CopyDiagnosticReport.IsEnabled = $false
    $ui.DiagnosticSaveStatus.Text = 'Run a diagnostic to enable Save Report.'
}
$script:DiagnosticPS = $null
$script:DiagnosticAsync = $null
$script:DiagnosticTimer = New-Object Windows.Threading.DispatcherTimer
$script:DiagnosticTimer.Interval = [TimeSpan]::FromMilliseconds(250)
$script:DiagnosticTimer.Add_Tick({
    if ($null -eq $script:DiagnosticPS -or $null -eq $script:DiagnosticAsync) { return }
    if (-not $script:DiagnosticAsync.IsCompleted) { return }
    $script:DiagnosticTimer.Stop()
    try {
        $output = @($script:DiagnosticPS.EndInvoke($script:DiagnosticAsync))
        $ui.DiagnosticOutput.Text = ($output | ForEach-Object { [string]$_ }) -join "`r`n"
        if (-not $ui.DiagnosticOutput.Text) { $ui.DiagnosticOutput.Text = '(The collector returned no output.)' }
        # Never save results under a target or identity different from the collection request.
        $completed = $script:PendingGUIReport
        $activeMode = if ($script:LocalTargetMode) { 'Local' } elseif ($script:GUIAlternateMode) { 'Alternate' } else { 'Default' }
        $activeIdentity = if ($script:GUIAlternateMode) { [string]$script:GUIAlternateUser } else { [Security.Principal.WindowsIdentity]::GetCurrent().Name }
        if ($null -eq $completed -or $completed.Target -ine $script:TargetComputer -or
            $completed.Mode -ne $activeMode -or $completed.Identity -ine $activeIdentity) {
            throw 'Target or credentials changed during collection. Results discarded; run diagnostics again.'
        }
        if ('Health' -in @($completed.Sections)) {
            $script:DashboardHealthTarget = [string]$completed.Target
            $script:DashboardHealthMode = [string]$completed.Mode
            $script:DashboardHealthIdentity = [string]$completed.Identity
            $summary = [regex]::Match($ui.DiagnosticOutput.Text, 'Review: (\d+) \| Available: (\d+) \| Unavailable: (\d+)')
            if ($summary.Success) {
                $ui.HealthReviewCount.Text = $summary.Groups[1].Value
                $ui.HealthAvailableCount.Text = $summary.Groups[2].Value
                $ui.HealthUnavailableCount.Text = $summary.Groups[3].Value
                foreach ($entry in @(
                    @{Name='HealthStorageDetail'; Check='SystemDrive'; Title='Storage'},
                    @{Name='HealthServicesDetail'; Check='AutomaticServices'; Title='Services'},
                    @{Name='HealthEventsDetail'; Check='RecentSystemEvents'; Title='Events'},
                    @{Name='HealthSystemDetail'; Check='SystemUptime'; Title='System'},
                    @{Name='HealthSecurityDetail'; Check='FirewallProfiles'; Title='Security'},
                    @{Name='HealthUpdatesDetail'; Check='InstalledHotfixes'; Title='Updates'},
                    @{Name='HealthRestartDetail'; Check='PendingRestart'; Title='Restart'}
                )) {
                    $pattern = '(?m)^\[(Review|Observed|Unavailable)\] ' + [regex]::Escape($entry.Check) + ': ([^\r\n]*)'
                    $finding = [regex]::Match($ui.DiagnosticOutput.Text, $pattern)
                    $ui[$entry.Name].Text = if ($finding.Success) {
                        $entry.Title + ': ' + $finding.Groups[1].Value + ' — ' + $finding.Groups[2].Value
                    } else { $entry.Title + ': Not assessed / unavailable' }
                }
                $ui.DashboardHealthSummary.Text = ("{0} ({1}): {2} review findings, {3} available checks, {4} unavailable checks. Requested identity: {5}; see Diagnostics for evidence and next steps." -f
                    $completed.Target,$completed.Mode,$summary.Groups[1].Value,$summary.Groups[2].Value,$summary.Groups[3].Value,$completed.Identity)
            } else {
                Clear-DashboardHealthDetails
                $ui.DashboardHealthSummary.Text = 'Health analysis unavailable. See the Diagnostics report for details.'
            }
        }
        # Keep exactly the completed, displayed output; no collection occurs when saving.
        $script:LastGUIReport = [pscustomobject]@{
            Mode = $script:PendingGUIReport.Mode
            Identity = $script:PendingGUIReport.Identity
            Target = $script:PendingGUIReport.Target
            Sections = @($script:PendingGUIReport.Sections)
            CollectedAt = $script:PendingGUIReport.Started
            Results = [string]$ui.DiagnosticOutput.Text
        }
        $ui.SaveDiagnosticReport.IsEnabled = $true
        $ui.CopyDiagnosticReport.IsEnabled = $true
        $ui.DiagnosticSaveStatus.Text = 'Results ready. Choose a format and click Save Report.'
        $script:LastDiagnosticSummary = if ($script:LastGUIReport.Sections.Count -eq 1) { [string]$script:LastGUIReport.Sections[0] } else { "All $($script:LastGUIReport.Sections.Count) checks" }
        $script:LastDiagnosticSummary += ' - ' + (Get-Date).ToString('g')
        Update-TargetInfo
        $ui.DiagnosticProgress.Text = 'Diagnostic collection finished.'
        $ui.Status.Text = 'Diagnostics completed.'
    } catch {
        Clear-GUIReportState
        $ui.DiagnosticOutput.Text = "Diagnostic collection failed: $($_.Exception.Message)"
        $ui.DiagnosticProgress.Text = 'Diagnostic collection failed.'
        $ui.Status.Text = 'Diagnostics failed.'
    } finally {
        $script:DiagnosticPS.Dispose()
        $script:DiagnosticPS = $null
        $script:DiagnosticAsync = $null
        $script:PendingGUIReport = $null
        $ui.RunDiagnostic.IsEnabled = $true
        $ui.RunElevatedLocalDiagnostic.IsEnabled = $true
        $ui.RunAllDiagnostics.IsEnabled = $true
    }
})
function Start-GUIDiagnostics([string[]]$sections,[bool]$elevatedLocal = $false,[bool]$allowRemoteSigned = $false) {
    if ($allowRemoteSigned -and -not $elevatedLocal) { throw 'Execution-policy consent requires a selected elevated local diagnostic.' }
    if ($elevatedLocal -and (-not $script:LocalTargetMode -or $sections.Count -ne 1 -or $sections[0] -notin @('BitLocker','Policy'))) {
        [Windows.MessageBox]::Show('UAC handoff is available only for one local BitLocker or Policy check.','Invalid elevation request') | Out-Null
        return
    }
    $mode = if ($script:LocalTargetMode) { 'Local' } elseif ($script:GUIAlternateMode) { 'Alternate' } else { 'Default' }
    $identity = if ($script:GUIAlternateMode) { [string]$script:GUIAlternateUser } else { [Security.Principal.WindowsIdentity]::GetCurrent().Name }
    $alternateCredential = $null
    if ($mode -eq 'Alternate') {
        if (-not $script:TargetComputer -or -not $script:GUIAuthContext -or
            $script:GUIAlternateTarget -ine $script:TargetComputer -or
            $script:GUIAuthContext.ComputerName -ine $script:TargetComputer -or
            $script:GUIAuthContext.Mode -ne 'Alternate' -or
            $null -eq $script:GUIAuthContext.Credential) {
            [Windows.MessageBox]::Show('Choose Enter credentials / Test for this target before running alternate diagnostics.','Credentials required') | Out-Null
            return
        }
        $alternateCredential = $script:GUIAuthContext.Credential
    }
    if (-not $script:TargetComputer) {
        [Windows.MessageBox]::Show('Select a target on the Dashboard first.', 'No target') | Out-Null
        return
    }
    if ($null -ne $script:DiagnosticPS) { return }
    Clear-GUIReportState
    $script:PendingGUIReport = $null
    $reportModule = Join-Path $script:ToolkitRoot 'Modules\ITToolkit-Reports.ps1'
    $configModule = Join-Path $script:ToolkitRoot 'Modules\ITToolkit-Config.ps1'
    $coreModule = Join-Path $script:ToolkitRoot 'Modules\ITToolkit-Core.ps1'
    foreach ($required in @($reportModule,$configModule,$coreModule)) {
        if (-not (Test-Path -LiteralPath $required -PathType Leaf)) {
            $ui.DiagnosticOutput.Text = "Required Classic component missing: $required"
            return
        }
    }
    $script:PendingGUIReport = [pscustomobject]@{
        Elevated = $elevatedLocal
        PolicyConsent = $allowRemoteSigned
        Mode = $mode
        Identity = $identity
        Target = [string]$script:TargetComputer
        Sections = @($sections)
        Started = Get-Date
    }
    $ui.DiagnosticOutput.Text = "Collecting $($sections.Count) diagnostic check(s) from $($script:TargetComputer). Please wait ..."
    $ui.DiagnosticProgress.Text = "Running $($sections.Count) check(s) against $($script:TargetComputer) ..."
    $ui.Status.Text = 'Collecting diagnostic information ...'
    $ui.RunDiagnostic.IsEnabled = $false
    $ui.RunElevatedLocalDiagnostic.IsEnabled = $false
    $ui.RunAllDiagnostics.IsEnabled = $false
    $worker = @'
param([string]$root,[string]$target,[string[]]$requested)
$ErrorActionPreference = 'Stop'
$script:ToolkitRoot = $root
. (Join-Path $root 'Modules\ITToolkit-Config.ps1')
. (Join-Path $root 'Modules\ITToolkit-Core.ps1')
. (Join-Path $root 'Modules\ITToolkit-Reports.ps1')
. (Join-Path $root 'Modules\ITToolkit-DiagnosticDispatcher.ps1')
$lines = New-Object System.Collections.Generic.List[string]
$lines.Add("Target: $target")
$lines.Add("Collected: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')")
$lines.Add('Read-only diagnostics; a successful query does not establish system health.')
if ('Health' -in $requested) {
    . (Join-Path $root 'Modules\ITToolkit-Authentication.ps1')
    . (Join-Path $root 'Modules\ITToolkit-WmiDiagnostics.ps1')
    . (Join-Path $root 'Modules\ITToolkit-CompositeDiagnostics.ps1')
    . (Join-Path $root 'Modules\ITToolkit-HealthAnalysis.ps1')
    $healthContext = New-ToolkitAuthContext -ComputerName $target -Mode Default
}
foreach ($section in $requested) {
    $lines.Add('')
    $lines.Add(('=' * 65))
    $lines.Add("$section REPORT")
    $lines.Add(('=' * 65))
    try {
        $content = [string](Get-ReportSection $section $target)
        $status = Get-SectionStatus $section $content
        $lines.Add("STATUS: $status")
        $lines.Add("Status category: $(Get-ToolkitDiagnosticStatusCategory -Status $status)")
        $lines.Add($content)
        if ($section -eq 'Health') {
            $remoteHealth = Get-ToolkitCompositeDiagnostic -Context $healthContext -Section Health
            $lines.Add('')
            $lines.Add('Remote Health evidence collected separately through the selected Default identity over WinRM; unavailable transport is not a passed check.')
            $lines.Add((Format-ToolkitHealthAnalysis -Analysis (Get-ToolkitRemoteHealthAnalysis -Result $remoteHealth)))
        }
    } catch {
        $failureMessage = [string]$_.Exception.Message
        $failureStatus = Get-ToolkitDiagnosticExceptionStatus -Message $failureMessage
        $lines.Add("STATUS: $failureStatus")
        $lines.Add("Status category: $(Get-ToolkitDiagnosticStatusCategory -Status $failureStatus)")
        $lines.Add("Error details: $failureMessage")
    }
}
return ($lines -join "`r`n")
'@
    if ($mode -eq 'Local') {
        # Direct-local collection only; no remote fallback and no credential elevation.
        $worker = @'
param([string]$root,[string]$target,[string[]]$requested,[bool]$elevated,[bool]$policyConsent)
$ErrorActionPreference = 'Stop'
. (Join-Path $root 'Modules\ITToolkit-LocalDiagnostics.ps1')
. (Join-Path $root 'Modules\ITToolkit-HealthAnalysis.ps1')
$lines = New-Object System.Collections.Generic.List[string]
$lines.Add("Target: $target")
$lines.Add('Collection mode: Local (current Windows identity)')
$lines.Add("Collected: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')")
$lines.Add('Diagnostic queries are read-only; separately approved PowerShell policy changes are identified below. Query success does not establish system health.')
foreach ($section in $requested) {
    $lines.Add('')
    $lines.Add(('=' * 65))
    $lines.Add("$section REPORT")
    $lines.Add(('=' * 65))
    if ($section -notin @('System','Firewall','Services','Storage','Network','Hardware','Users','Groups','Administrators','Shares','Software','Updates','Tasks','Events','Startup','BitLocker','Sessions','Policy','SharePermissions','Health')) {
        $lines.Add('STATUS: NOT TESTED')
        $lines.Add('Status category: NotTested')
        $lines.Add('Error details: Direct-local collection is not implemented for this section yet.')
        continue
    }
    $result = if ($elevated -and $section -in @('BitLocker','Policy')) {
        Invoke-ToolkitElevatedLocalDiagnostic -Section $section -AllowCurrentUserRemoteSigned:$policyConsent
    } else {
        Get-ToolkitLocalDiagnostic -Section $section
    }
    if ($elevated) {
        $lines.Add('Collection authorization: Windows UAC (explicit administrator approval).')
        $lines.Add("Initiating technician: $($result.InitiatingIdentity)")
        $lines.Add("Actual collection identity: $($result.CollectionIdentity)")
        $lines.Add("PowerShell execution policy: $($result.ExecutionPolicyBefore) -> $($result.ExecutionPolicyAfter)")
        $lines.Add("CurrentUser policy changed for elevated account: $([bool]$result.ExecutionPolicyChanged)")
    }
    $lines.Add("STATUS: $($result.Status)")
    $lines.Add("Status category: $($result.StatusCategory)")
    if ($result.Error) { $lines.Add("Error details: $($result.Error)") }
    foreach ($record in @($result.Data)) {
        $lines.Add(($record | Format-List * | Out-String -Width 200).TrimEnd())
    }
    if ($section -eq 'Health') {
        $lines.Add('')
        $lines.Add((Format-ToolkitHealthAnalysis -Analysis (Get-ToolkitLocalHealthAnalysis -Result $result)))
    }
}
return ($lines -join "`r`n")
'@
    }
    if ($mode -eq 'Alternate') {
        # Credentials cross into the in-process runspace as PSCredential, never via a command line or file.
        $worker = @'
param([string]$root,[string]$target,[string[]]$requested,[System.Management.Automation.PSCredential]$credential)
$ErrorActionPreference = 'Stop'
$script:ToolkitRoot = $root
foreach ($name in @('ITToolkit-Authentication.ps1','ITToolkit-WmiDiagnostics.ps1',
    'ITToolkit-WinRMDiagnostics.ps1','ITToolkit-MixedDiagnostics.ps1',
    'ITToolkit-CompositeDiagnostics.ps1','ITToolkit-DetailDiagnostics.ps1',
    'ITToolkit-DiagnosticDispatcher.ps1','ITToolkit-ClassicDispatcher.ps1','ITToolkit-HealthAnalysis.ps1')) {
    $path = Join-Path $root ('Modules\' + $name)
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "Missing Phase 5B dependency: $path" }
    . $path
}
$context = New-ToolkitAuthContext -ComputerName $target -Mode Alternate -Credential $credential
$lines = New-Object System.Collections.Generic.List[string]
# Collection metadata is added once by the GUI Save Report handler.
# Worker output contains only the diagnostic section content.
foreach ($section in $requested) {
    $lines.Add('')
    $lines.Add(('=' * 65))
    $lines.Add("$section REPORT")
    $lines.Add(('=' * 65))
    try {
        $result = Invoke-ToolkitDiagnostic -Context $context -Section $section
        $lines.Add("STATUS: $($result.Status)")
        $lines.Add((Convert-ClassicDispatcherResult -Result $result))
        if ($section -eq 'Health') {
            $lines.Add('')
            $lines.Add((Format-ToolkitHealthAnalysis -Analysis (Get-ToolkitRemoteHealthAnalysis -Result $result)))
        }
    } catch {
        $failureMessage = [string]$_.Exception.Message
        $failureStatus = Get-ToolkitDiagnosticExceptionStatus -Message $failureMessage
        $lines.Add("STATUS: $failureStatus")
        $lines.Add("Status category: $(Get-ToolkitDiagnosticStatusCategory -Status $failureStatus)")
        $lines.Add("Error details: $failureMessage")
    }
}
$context = $null
$credential = $null
return ($lines -join "`r`n")
'@
    }
    try {
        $script:DiagnosticPS = [PowerShell]::Create()
        $pipeline = $script:DiagnosticPS.AddScript($worker).AddArgument($script:ToolkitRoot).AddArgument([string]$script:TargetComputer).AddArgument([string[]]$sections)
        if ($mode -eq 'Alternate') { [void]$pipeline.AddArgument($alternateCredential) }
        elseif ($mode -eq 'Local') {
            [void]$pipeline.AddArgument([bool]$elevatedLocal)
            [void]$pipeline.AddArgument([bool]$allowRemoteSigned)
        }
        $script:DiagnosticAsync = $script:DiagnosticPS.BeginInvoke()
        $script:DiagnosticTimer.Start()
    } catch {
        if ($script:DiagnosticPS) { $script:DiagnosticPS.Dispose() }
        $script:DiagnosticPS = $null
        $script:DiagnosticAsync = $null
        $ui.RunDiagnostic.IsEnabled = $true
        $ui.RunAllDiagnostics.IsEnabled = $true
        $script:PendingGUIReport = $null
        $ui.DiagnosticProgress.Text = 'Could not start diagnostics.'
        $ui.DiagnosticOutput.Text = $_.Exception.Message
    }
}
# Snapshot capture is separate from displayed diagnostic output and never reuses a cached report.
$script:SnapshotPS = $null
$script:SnapshotAsync = $null
$script:SnapshotRequested = $null
$script:SnapshotTimer = New-Object Windows.Threading.DispatcherTimer
$script:SnapshotTimer.Interval = [TimeSpan]::FromMilliseconds(250)
$script:SnapshotTimer.Add_Tick({
    if ($null -eq $script:SnapshotPS -or $null -eq $script:SnapshotAsync -or -not $script:SnapshotAsync.IsCompleted) { return }
    $script:SnapshotTimer.Stop()
    try {
        $items = @($script:SnapshotPS.EndInvoke($script:SnapshotAsync))
        $snapshot = $items | Where-Object { $_ -and $_.PSObject.Properties['SchemaVersion'] } | Select-Object -Last 1
        if ($null -eq $snapshot) { throw 'Snapshot collector returned no structured snapshot.' }
        $request = $script:SnapshotRequested
        $mode = if ($script:LocalTargetMode) { 'Local' } elseif ($script:GUIAlternateMode) { 'Alternate' } else { 'Default' }
        $identity = if ($mode -eq 'Alternate') { [string]$script:GUIAlternateUser } else { [Security.Principal.WindowsIdentity]::GetCurrent().Name }
        if (-not $request -or $request.Target -ine $script:TargetComputer -or $request.Mode -ne $mode -or $request.Identity -ine $identity) {
            throw 'Target or credentials changed during capture. Snapshot discarded.'
        }
        $good = @($snapshot.Categories.PSObject.Properties).Count
        if ($good -lt 1) { throw 'All seven snapshot categories failed. Nothing was saved.' }
        $folder = Get-GUIArchiveFolder
        if (-not (Test-Path -LiteralPath $folder -PathType Container)) { [void](New-Item -ItemType Directory -Path $folder -Force -ErrorAction Stop) }
        $safe = $request.Target -replace '[^a-zA-Z0-9_.-]','_'
        $time = Get-Date -Format 'yyyyMMdd_HHmmss_fff'
        $file = Join-Path $folder "${safe}_Complete_${time}.snapshot.json"
        $temp = Join-Path $folder ('.snapshot-' + [guid]::NewGuid().ToString('N') + '.tmp')
        try {
            $json = ConvertTo-Json -InputObject $snapshot -Depth 16 -ErrorAction Stop
            [IO.File]::WriteAllText($temp,$json + [Environment]::NewLine,(New-Object Text.UTF8Encoding($false)))
            Move-Item -LiteralPath $temp -Destination $file -ErrorAction Stop
        } finally { if (Test-Path -LiteralPath $temp) { Remove-Item -LiteralPath $temp -Force -ErrorAction SilentlyContinue } }
        $failed = @( $snapshot.Errors.PSObject.Properties | ForEach-Object { $_.Name } )
        $message = "Snapshot saved: $file ($good/7 categories)."
        if ($failed.Count -gt 0) { $message += " Unavailable: $($failed -join ', '). Comparison will mark these NOT COMPARABLE." }
        $ui.SnapshotStatus.Text = $message
        $ui.DiagnosticProgress.Text = $message
        $ui.Status.Text = 'Snapshot capture complete.'
        Refresh-SnapshotArchive
        $ui.SnapshotStatus.Text = $message
    } catch {
        $ui.DiagnosticProgress.Text = "Snapshot failed: $($_.Exception.Message)"
        $ui.Status.Text = 'Snapshot capture failed.'
    } finally {
        $script:SnapshotPS.Dispose(); $script:SnapshotPS = $null
        $script:SnapshotAsync = $null; $script:SnapshotRequested = $null
        $ui.CreateSnapshotGUI.IsEnabled = $true
    }
})
$ui.CreateSnapshotGUI.Add_Click({
    if ($null -ne $script:SnapshotPS) { return }
    $target = [string]$script:TargetComputer
    if ([string]::IsNullOrWhiteSpace($target)) { [Windows.MessageBox]::Show('Select a target on Dashboard first.','Snapshot') | Out-Null; return }
    $mode = if ($script:LocalTargetMode) { 'Local' } elseif ($script:GUIAlternateMode) { 'Alternate' } else { 'Default' }
    $identity = if ($mode -eq 'Alternate') { [string]$script:GUIAlternateUser } else { [Security.Principal.WindowsIdentity]::GetCurrent().Name }
    $credential = $null
    if ($mode -eq 'Alternate') {
        if (-not (Confirm-GUIAlternateCredential)) { return }
        $identity = [string]$script:GUIAlternateUser
        if (-not $script:GUIAuthContext -or $script:GUIAlternateTarget -ine $target -or
            $script:GUIAuthContext.ComputerName -ine $target -or $script:GUIAuthContext.Mode -ne 'Alternate' -or
            $null -eq $script:GUIAuthContext.Credential) {
            [Windows.MessageBox]::Show('No valid alternate credentials for this target.','Snapshot') | Out-Null; return
        }
        $credential = $script:GUIAuthContext.Credential
    }
    $module = Join-Path (Join-Path $script:ToolkitRoot 'Modules') 'ITToolkit-GUISnapshotCollector.ps1'
    if (-not (Test-Path -LiteralPath $module -PathType Leaf)) { [Windows.MessageBox]::Show("Missing snapshot collector: $module",'Snapshot') | Out-Null; return }
    if ($mode -eq 'Local' -and $target -ine $env:COMPUTERNAME) {
        [Windows.MessageBox]::Show('Local snapshot target does not match the current computer.','Snapshot') | Out-Null; return
    }
    $script:SnapshotRequested = [pscustomobject]@{ Target=$target; Mode=$mode; Identity=$identity }
    $ui.CreateSnapshotGUI.IsEnabled = $false
    $ui.DiagnosticProgress.Text = "Capturing snapshot for $target ($mode). Please wait ..."
    $script:SnapshotPS = [PowerShell]::Create()
    try {
        $worker = @'
param([string]$collector,[string]$target,[string]$mode,[System.Management.Automation.PSCredential]$credential,[string]$version)
$ErrorActionPreference = 'Stop'
. $collector
Get-ToolkitGUISnapshot -Target $target -Mode $mode -Credential $credential -ToolkitVersion $version
'@
        [void]$script:SnapshotPS.AddScript($worker).AddArgument($module).AddArgument($target).AddArgument($mode).AddArgument($credential).AddArgument([string]$version)
        $script:SnapshotAsync = $script:SnapshotPS.BeginInvoke()
        $script:SnapshotTimer.Start()
    } catch {
        if ($script:SnapshotPS) { $script:SnapshotPS.Dispose() }
        $script:SnapshotPS = $null; $script:SnapshotAsync = $null; $script:SnapshotRequested = $null
        $ui.CreateSnapshotGUI.IsEnabled = $true
        $ui.DiagnosticProgress.Text = "Could not start snapshot: $($_.Exception.Message)"
    }
})

# Save only the completed diagnostic text already displayed in the GUI.
$ui.CopyDiagnosticReport.Add_Click({
    if ($null -eq $script:LastGUIReport -or $null -ne $script:DiagnosticPS) { return }
    $captured = $script:LastGUIReport
    $currentMode = if ($script:LocalTargetMode) { 'Local' } elseif ($script:GUIAlternateMode) { 'Alternate' } else { 'Default' }
    $currentIdentity = if ($script:GUIAlternateMode) { [string]$script:GUIAlternateUser } else { [Security.Principal.WindowsIdentity]::GetCurrent().Name }
    if ($captured.Target -ine $script:TargetComputer -or $captured.Mode -ne $currentMode -or
        $captured.Identity -ine $currentIdentity -or $ui.DiagnosticOutput.Text -cne $captured.Results) {
        Clear-GUIReportState
        $ui.DiagnosticSaveStatus.Text = 'Report context changed. Run the diagnostic again before copying.'
        return
    }
    try {
        [Windows.Clipboard]::SetText([string]$captured.Results)
        $ui.DiagnosticSaveStatus.Text = 'Displayed report copied to clipboard.'
        $ui.Status.Text = 'Diagnostic report copied.'
    } catch {
        $ui.DiagnosticSaveStatus.Text = "Could not copy report: $($_.Exception.Message)"
    }
})
$ui.SaveDiagnosticReport.Add_Click({
    if ($null -eq $script:LastGUIReport -or $null -ne $script:DiagnosticPS) { return }
    $captured = $script:LastGUIReport
    $currentMode = if ($script:LocalTargetMode) { 'Local' } elseif ($script:GUIAlternateMode) { 'Alternate' } else { 'Default' }
    $currentIdentity = if ($script:GUIAlternateMode) { [string]$script:GUIAlternateUser } else { [Security.Principal.WindowsIdentity]::GetCurrent().Name }
    if ($captured.Target -ine $script:TargetComputer -or $captured.Mode -ne $currentMode -or
        $captured.Identity -ine $currentIdentity) {
        Clear-GUIReportState
        $ui.DiagnosticSaveStatus.Text = 'Target or credentials changed. Collect a fresh report.'
        return
    }
    if ($ui.DiagnosticOutput.Text -cne $captured.Results) {
        Clear-GUIReportState
        $ui.DiagnosticSaveStatus.Text = 'Results have changed. Rerun the diagnostic before saving.'
        return
    }
    $format = [string]$ui.DiagnosticReportFormat.SelectedItem.Content
    if ($format -notin @('HTML','CSV','TXT')) { $format = 'HTML' }
    $label = if (@($captured.Sections).Count -eq 20) { 'Complete' } else { [string]($captured.Sections -join '-') }
    $safeTarget = [regex]::Replace([string]$captured.Target,'[^A-Za-z0-9_.-]','_')
    $safeLabel = [regex]::Replace($label,'[^A-Za-z0-9_.-]','_')
    $folder = if ($cfg.ReportFolder) { [string]$cfg.ReportFolder } else { 'Reports' }
    if (-not [IO.Path]::IsPathRooted($folder)) { $folder = Join-Path $script:ToolkitRoot $folder }
    $org = if ($cfg.Branding -and $cfg.Branding.OrganizationName) { [string]$cfg.Branding.OrganizationName } else { 'Your Organization' }
    $appTitle = if ($cfg.Branding -and $cfg.Branding.ApplicationName) { [string]$cfg.Branding.ApplicationName } else { 'IT Toolkit' }
    $title = "$org $appTitle - $label - $($captured.Target)"
    try {
        # Use the Classic toolkit's presentation converters, not its interactive
        # Save-DiagnosticReport routine (which would rerun the collectors).
        # The Classic formatter expects the configuration in its script scope.
        $script:Config = $cfg
        . (Join-Path $script:ToolkitRoot 'Modules\ITToolkit-Reports.ps1')
        $disclaimer = if ($captured.Mode -eq 'Alternate') {
            'Read-only diagnostics; SUCCESS indicates query success, not system health. Health ADMIN$ is NOT TESTED.'
        } else {
            'Read-only diagnostics; a successful query does not establish system health.'
        }
        $reportScope = if ($captured.Mode -eq 'Local') { 'LOCAL' } else { 'REMOTE' }
        $reportText = "${org} ${appTitle} - $reportScope DIAGNOSTIC REPORT`r`nReport: $label`r`nCollected: $($captured.CollectedAt.ToString('yyyy-MM-dd HH:mm:ss zzz'))`r`nSaved: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss zzz')`r`nTechnician account: $([Security.Principal.WindowsIdentity]::GetCurrent().Name)`r`nDiagnostic authentication: $($captured.Mode)`r`nDiagnostic identity: $($captured.Identity)`r`n$disclaimer`r`n$($captured.Results)"
        $lines = [string[]]@($reportText -split '\r?\n')
        switch ($format) {
            'HTML' { $contents = Convert-ReportHtml $reportText $title }
            'CSV'  { $contents = Convert-ReportCsv $lines }
            default { $contents = $reportText }
        }
        if (-not (Test-Path -LiteralPath $folder -PathType Container)) {
            [void](New-Item -Path $folder -ItemType Directory -Force -ErrorAction Stop)
        }
        $file = '{0}_{1}_{2}.{3}' -f $safeTarget,$safeLabel,(Get-Date -Format 'yyyyMMdd_HHmmss_fff'),$format.ToLowerInvariant()
        $destination = Join-Path $folder $file
        [IO.File]::WriteAllText($destination,[string]$contents,(New-Object System.Text.UTF8Encoding($false)))
        $ui.DiagnosticSaveStatus.Text = "Saved: $destination"
        $ui.Status.Text = "Saved $format report."
    } catch {
        $message = "Could not save report: $($_.Exception.Message)"
        $ui.DiagnosticSaveStatus.Text = $message
        [Windows.MessageBox]::Show($message,'Report save failed') | Out-Null
    }
})
$ui.RunDiagnostic.Add_Click({
    if ($null -eq $ui.DiagnosticSection.SelectedItem) { return }
    Start-GUIDiagnostics @([string]$ui.DiagnosticSection.SelectedItem.Tag)
})
$ui.RunElevatedLocalDiagnostic.Add_Click({
    if ($null -eq $ui.DiagnosticSection.SelectedItem) { return }
    $section = [string]$ui.DiagnosticSection.SelectedItem.Tag
    if (-not $script:LocalTargetMode -or $section -notin @('BitLocker','Policy')) {
        [Windows.MessageBox]::Show('Select the local computer and BitLocker or Policy first.','Elevation scope') | Out-Null
        return
    }
    $approval = [Windows.MessageBox]::Show(
        "Windows will request administrator credentials for this local $section check. The GUI will remain non-elevated. Continue?",
        'Authorize diagnostic elevation',
        [Windows.MessageBoxButton]::YesNo,
        [Windows.MessageBoxImage]::Question)
    if ($approval -ne [Windows.MessageBoxResult]::Yes) { return }
    $policyChoice = [Windows.MessageBox]::Show(
        'If the UAC administrator account has Restricted PowerShell execution policy, allow IT Toolkit to permanently change only that account''s CurrentUser policy to RemoteSigned? This is a separate persistent configuration change.' + [Environment]::NewLine +
        'YES = approve that account-level change if needed.' + [Environment]::NewLine +
        'NO = run UAC diagnostic without changing execution policy.' + [Environment]::NewLine +
        'CANCEL = do not run.',
        'Authorize optional PowerShell policy change',
        [Windows.MessageBoxButton]::YesNoCancel,
        [Windows.MessageBoxImage]::Warning)
    if ($policyChoice -eq [Windows.MessageBoxResult]::Cancel) { return }
    Start-GUIDiagnostics @($section) $true ($policyChoice -eq [Windows.MessageBoxResult]::Yes)
})
$ui.RunAllDiagnostics.Add_Click({
    Start-GUIDiagnostics @($script:DiagnosticSections | ForEach-Object { [string]$_.Id })
})
$window.Add_Closing({
    try { Save-GUIWindowPlacement; Save-GUIPreferences } catch { }
    Clear-GUIAlternateContext
    $script:DiagnosticTimer.Stop()
    if ($null -ne $script:DiagnosticPS) {
        try { $script:DiagnosticPS.Stop() } catch { }
        try { $script:DiagnosticPS.Dispose() } catch { }
    }
})

$ui.NavDashboard.Add_Click({ Refresh-RecentTargets; Refresh-RecentReports; Show-GUIPage 'Dashboard' })
$ui.NavDiagnostics.Add_Click({ Show-GUIPage 'Diagnostics' })
$ui.NavTools.Add_Click({ Refresh-Tools; Show-GUIPage 'Tools' })
$ui.NavReports.Add_Click({ Refresh-Archive; Refresh-SnapshotArchive; Show-GUIPage 'Reports' })
$ui.NavSettings.Add_Click({ Show-GUIPage 'Settings' })
$ui.SwitchClassic.Add_Click({
    if ($null -ne $script:DiagnosticPS -or $null -ne $script:SnapshotPS) {
        [Windows.MessageBox]::Show('Finish the active collection before switching interfaces.', 'Collection in progress') | Out-Null
        return
    }
    $classicScript = Join-Path $PSScriptRoot 'ITToolkit.ps1'
    if (-not (Test-Path -LiteralPath $classicScript -PathType Leaf)) {
        [Windows.MessageBox]::Show('Classic script was not found; remaining in GUI.', 'Switch unavailable') | Out-Null
        return
    }
    try {
        # Launch under the current Windows token, without credential or target handoff.
        $psExe = Join-Path $PSHOME 'powershell.exe'
        $arguments = '-NoLogo -NoProfile -STA -File "' + $classicScript + '"'
        $process = Start-Process -FilePath $psExe -ArgumentList $arguments -WorkingDirectory $PSScriptRoot -PassThru -ErrorAction Stop
        if ($null -eq $process) { throw 'Windows did not return a process.' }
        $window.Close()
    } catch {
        [Windows.MessageBox]::Show("Could not open Classic; remaining in GUI: $($_.Exception.Message)", 'Switch failed') | Out-Null
    }
})

$ui.EditPins.Add_Click({ Refresh-Tools; Show-GUIPage 'Tools' })
$ui.ClearRecents.Add_Click({
    $script:RecentTargets = @()
    Save-GUIPreferences
    Refresh-RecentTargets
})
$ui.MoreReports.Add_Click({ Refresh-Archive; Refresh-SnapshotArchive; Show-GUIPage 'Reports' })
$ui.UseAlternate.Add_Checked({
    if ($script:LocalTargetMode) { $ui.UseAlternate.IsChecked = $false; return }
    $script:GUIAlternateMode = $true
    Clear-GUIAlternateContext
    Clear-GUIReportState
    $script:AdminStatus = 'Not checked'
    $script:AdminDetail = 'Alternate mode selected; ADMIN$ has not been tested with alternate credentials.'
    $script:TargetLastChecked = $null
    Update-TargetView
    $ui.AlternateProbeSummary.Text = 'Choose Enter credentials / Test, then Set target / Check access to verify ADMIN$ in alternate mode.'
    Set-GUIAuthView
})
$ui.UseAlternate.Add_Unchecked({
    $script:GUIAlternateMode = $false
    Clear-GUIAlternateContext
    Clear-GUIReportState
    $script:AdminStatus = 'Not checked'
    $script:AdminDetail = 'Select Set target / Check access to verify ADMIN$ with the default account.'
    $script:TargetLastChecked = $null
    Update-TargetView
    Set-GUIAuthView
})
$ui.ChangeAlternate.Add_Click({ [void](Confirm-GUIAlternateCredential) })
$ui.SetTarget.Add_Click({ Resolve-GUITarget })
$ui.UseLocalTarget.Add_Click({
    if ($null -ne $script:DiagnosticPS -or $null -ne $script:SnapshotPS) {
        [Windows.MessageBox]::Show('Wait for the active collection to finish before changing targets.','Collection in progress') | Out-Null
        return
    }
    Clear-GUIAlternateContext
    $script:LocalTargetMode = $true
    $script:GUIAlternateMode = $false
    $ui.UseAlternate.IsChecked = $false
    Clear-GUIReportState
    $script:TargetComputer = [string]$env:COMPUTERNAME
    $ui.TargetInput.Text = $script:TargetComputer
    $script:TargetIPv4 = '(local collection)'
    $script:TargetPingState = 'Not needed (local)'
    $script:TargetLastChecked = Get-Date
    $script:LastDiagnosticSummary = 'None this session'
    $script:AdminStatus = 'Local mode'
    $script:AdminDetail = 'All 20 local diagnostics and local snapshots use direct-local collection. BitLocker and Policy can request separate Windows UAC approval when needed.'
    Set-GUIAuthView
    Update-TargetView
    $ui.Status.Text = 'Local computer selected — System and Firewall available.'
})
$ui.ClearTarget.Add_Click({ if ($null -ne $script:DiagnosticPS -or $null -ne $script:SnapshotPS) { [Windows.MessageBox]::Show('Wait for the active collection to finish before clearing the target.','Collection in progress') | Out-Null; return }; $script:LocalTargetMode=$false; Clear-GUIAlternateContext; $script:GUIAlternateMode=$false; $ui.UseAlternate.IsChecked=$false; Set-GUIAuthView; Clear-GUIReportState; $script:TargetPingState = 'Not checked'; $script:TargetLastChecked = $null; $script:LastDiagnosticSummary = 'None this session'; $script:TargetComputer = $null; $script:TargetIPv4 = '(not selected)'; $script:AdminStatus = 'Not checked'; $script:AdminDetail = 'Select a target first.'; $ui.TargetInput.Text = ''; Update-TargetView })
$ui.CheckAdmin.Add_Click({ if ($script:LocalTargetMode) { [Windows.MessageBox]::Show('ADMIN$ is a remote access check and is not applicable to direct-local collection.','Local mode') | Out-Null; return }; Clear-GUIReportState; if (-not $script:TargetComputer) { [Windows.MessageBox]::Show('Select a target on the Dashboard first.', 'No target') | Out-Null; return }; Test-GUIAdminShare; Update-GUIRecentTargetStatus; $ui.DiagnosticOutput.Text = "ADMIN`$: $($script:AdminStatus)`n$($script:AdminDetail)" })
$ui.DnsTarget.Add_Click({ Clear-GUIReportState;
    if (-not $script:TargetComputer) { [Windows.MessageBox]::Show('Select a target on the Dashboard first.', 'No target') | Out-Null; return }
    try { $all = [Net.Dns]::GetHostAddresses($script:TargetComputer); $ui.DiagnosticOutput.Text = "DNS: $($script:TargetComputer)`n" + (($all | ForEach-Object { $_.ToString() }) -join "`n") } catch { $ui.DiagnosticOutput.Text = $_.Exception.Message }
})
$ui.PingTarget.Add_Click({ Clear-GUIReportState;
    if (-not $script:TargetComputer) { [Windows.MessageBox]::Show('Select a target on the Dashboard first.', 'No target') | Out-Null; return }
    try { $results = @(Test-Connection -ComputerName $script:TargetComputer -Count 2 -ErrorAction Stop); $ui.DiagnosticOutput.Text = "Ping: $($script:TargetComputer)`n" + (($results | ForEach-Object { "Reply from $($_.Address): $($_.ResponseTime) ms" }) -join "`n"); $script:TargetPingState = 'Reachable (' + (Get-Date).ToString('t') + ')' } catch { $ui.DiagnosticOutput.Text = "Ping failed: $($_.Exception.Message)"; $script:TargetPingState = 'No response (' + (Get-Date).ToString('t') + ')' }
    Update-TargetInfo
})
# Quick actions delegate to the existing Diagnostics handlers; no parallel diagnostic engine.
$ui.QuickPing.Add_Click({
    if (-not $script:TargetComputer) { [Windows.MessageBox]::Show('Select a target first.','No target') | Out-Null; return }
    Show-GUIPage 'Diagnostics'
    $ui.PingTarget.RaiseEvent(([Windows.RoutedEventArgs]::new([Windows.Controls.Primitives.ButtonBase]::ClickEvent)))
})
$ui.QuickDns.Add_Click({
    if (-not $script:TargetComputer) { [Windows.MessageBox]::Show('Select a target first.','No target') | Out-Null; return }
    Show-GUIPage 'Diagnostics'
    $ui.DnsTarget.RaiseEvent(([Windows.RoutedEventArgs]::new([Windows.Controls.Primitives.ButtonBase]::ClickEvent)))
})
$ui.QuickHealth.Add_Click({
    if (-not $script:TargetComputer) { [Windows.MessageBox]::Show('Select a target first.','No target') | Out-Null; return }
    Show-GUIPage 'Diagnostics'
    Start-GUIDiagnostics @('Health')
})
# Report Archive: read-only listing of the configured report directory.
function Get-GUIArchiveFolder {
    $folder = if ($cfg.ReportFolder) { [string]$cfg.ReportFolder } else { 'Reports' }
    if (-not [IO.Path]::IsPathRooted($folder)) { $folder = Join-Path $script:ToolkitRoot $folder }
    return $folder
}
function Refresh-Archive {
    $ui.ArchiveList.Items.Clear()
    $ui.ArchiveOpen.IsEnabled = $false
    $folder = Get-GUIArchiveFolder
    if (-not (Test-Path -LiteralPath $folder -PathType Container)) {
        $ui.ArchiveStatus.Text = 'No archive folder found: ' + $folder
        return
    }
    $search = $ui.ArchiveSearch.Text.Trim()
    $format = [string]$ui.ArchiveFormat.SelectedItem.Content
    $files = @(Get-ChildItem -LiteralPath $folder -File -ErrorAction SilentlyContinue | Where-Object {
        $_.Extension -in @('.html','.csv','.txt') -and
        ([string]::IsNullOrWhiteSpace($search) -or $_.Name.IndexOf($search,[StringComparison]::OrdinalIgnoreCase) -ge 0) -and
        ($format -eq 'All formats' -or $_.Extension -ieq ('.' + $format))
    } | Sort-Object LastWriteTime -Descending)
    foreach ($file in $files) {
        [void]$ui.ArchiveList.Items.Add([pscustomobject]@{
            Name=$file.Name; Modified=$file.LastWriteTime.ToString('yyyy-MM-dd HH:mm');
            Format=$file.Extension.TrimStart('.').ToUpperInvariant();
            SizeKB=[math]::Round($file.Length / 1KB,1).ToString('N1'); Path=$file.FullName
        })
    }
    $ui.ArchiveStatus.Text = "$($files.Count) saved report(s) in $folder"
}
function Refresh-SnapshotArchive {
    $ui.SnapshotOlder.Items.Clear(); $ui.SnapshotNewer.Items.Clear()
    $ui.SaveComparisonGUI.IsEnabled = $false
    $script:GUIComparisonText = $null
    $script:GUIComparisonTarget = $null
    $folder = Get-GUIArchiveFolder
    if (-not (Test-Path -LiteralPath $folder -PathType Container)) {
        $ui.SnapshotStatus.Text = 'No snapshot folder found.'; return
    }
    $count = 0
    foreach ($file in @(Get-ChildItem -LiteralPath $folder -Filter '*.snapshot.json' -File -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending)) {
        try {
            $snapshot = Get-Content -LiteralPath $file.FullName -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
            if ($snapshot.SchemaVersion -ne 1 -or -not $snapshot.Target -or -not $snapshot.Categories) { continue }
            $item = [pscustomobject]@{ Display="$($snapshot.Target) | $($snapshot.CapturedAt) | $($file.Name)"; Target=[string]$snapshot.Target; CapturedAt=[datetime]$snapshot.CapturedAt; Path=$file.FullName }
            [void]$ui.SnapshotOlder.Items.Add($item); [void]$ui.SnapshotNewer.Items.Add($item)
            $count++
        } catch { } # Ignore malformed/unsupported snapshots.
    }
    $ui.SnapshotStatus.Text = "$count compatible snapshot(s) found."
}
function Compare-GUISnapshotFiles([string]$olderPath,[string]$newerPath) {
    $older = Get-Content -LiteralPath $olderPath -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
    $newer = Get-Content -LiteralPath $newerPath -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
    if ($older.SchemaVersion -ne 1 -or $newer.SchemaVersion -ne 1) { throw 'Unsupported snapshot schema.' }
    if ($older.Target -ine $newer.Target) { throw 'Snapshots are for different target computers. Select two snapshots from the same target.' }
    $lines = New-Object System.Collections.Generic.List[string]
    $lines.Add("$displayName - SAVED SNAPSHOT COMPARISON")
    $lines.Add("Target: $($newer.Target)")
    $lines.Add("Baseline: $($older.CapturedAt)")
    $lines.Add("Newer:    $($newer.CapturedAt)")
    $lines.Add('Inventory differences only. Missing/failed collections are not interpreted as removed entries.')
    $lines.Add('')
    $total = 0
    foreach ($category in @('Services','Software','Updates','Users','Groups','Administrators','Shares')) {
        $lines.Add("--- $category ---")
        $oldProp = $older.Categories.PSObject.Properties[$category]
        $newProp = $newer.Categories.PSObject.Properties[$category]
        if ($null -eq $oldProp -or $null -eq $newProp) {
            $lines.Add('NOT COMPARABLE (missing inventory in one or both snapshots).'); $lines.Add(''); continue
        }
        $oldMap = @{}; $newMap = @{}
        foreach ($entry in @($oldProp.Value)) { if ($null -ne $entry -and $entry.Key) { $oldMap[[string]$entry.Key] = $entry } }
        foreach ($entry in @($newProp.Value)) { if ($null -ne $entry -and $entry.Key) { $newMap[[string]$entry.Key] = $entry } }
        $changed = 0
        foreach ($key in @($newMap.Keys | Sort-Object)) {
            if (-not $oldMap.ContainsKey($key)) { $lines.Add("ADDED: $key"); $changed++; continue }
            foreach ($property in $newMap[$key].PSObject.Properties) {
                if ($property.Name -eq 'Key') { continue }
                $oldField = $oldMap[$key].PSObject.Properties[$property.Name]
                $previous = if ($oldField) { [string]$oldField.Value } else { '' }
                $current = [string]$property.Value
                if ($previous -cne $current) { $lines.Add("CHANGED: $key | $($property.Name): '$previous' => '$current'"); $changed++ }
            }
        }
        foreach ($key in @($oldMap.Keys | Sort-Object)) {
            if (-not $newMap.ContainsKey($key)) { $lines.Add("REMOVED: $key"); $changed++ }
        }
        if (-not $changed) { $lines.Add('No changes found.') }
        $total += $changed
        $lines.Add('')
    }
    $lines.Add("Total reported differences: $total")
    return ($lines -join "`r`n")
}
$ui.ArchiveSearch.Add_TextChanged({ Refresh-Archive })
$ui.ArchiveFormat.Add_SelectionChanged({ if ($null -ne $ui.ArchiveList) { Refresh-Archive } })
$ui.ArchiveRefresh.Add_Click({ Refresh-Archive })
$ui.ArchiveList.Add_SelectionChanged({ $ui.ArchiveOpen.IsEnabled = $null -ne $ui.ArchiveList.SelectedItem })
$ui.ArchiveList.Add_MouseDoubleClick({ if ($ui.ArchiveList.SelectedItem) { $ui.ArchiveOpen.RaiseEvent((New-Object Windows.RoutedEventArgs([Windows.Controls.Button]::ClickEvent))) } })
$ui.ArchiveOpen.Add_Click({
    $item = $ui.ArchiveList.SelectedItem
    if ($null -eq $item) { return }
    try {
        $root = [IO.Path]::GetFullPath((Get-GUIArchiveFolder)).TrimEnd([IO.Path]::DirectorySeparatorChar) + [IO.Path]::DirectorySeparatorChar
        $path = [IO.Path]::GetFullPath([string]$item.Path)
        if (-not $path.StartsWith($root,[StringComparison]::OrdinalIgnoreCase)) { throw 'Report path is outside the configured archive.' }
        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw 'The selected report no longer exists. Refresh the archive.' }
        Open-GUISavedReport -Path $path
    } catch { [Windows.MessageBox]::Show($_.Exception.Message,'Unable to open report') | Out-Null }
})
$ui.ArchiveFolder.Add_Click({
    $folder = Get-GUIArchiveFolder
    if (-not (Test-Path -LiteralPath $folder -PathType Container)) {
        $ui.ArchiveStatus.Text = "Reports folder not found: $folder"
        [Windows.MessageBox]::Show("Reports folder does not exist:`n$folder", 'Report Archive') | Out-Null
        return
    }
    try {
        # Direct Explorer launches return without error from the GUI but do
        # not display a window in the tested alternate-admin desktop context.
        # A separate Windows PowerShell process launching Explorer with /n
        # opened the folder in a technician test. Preserve the same identity,
        # with no elevated handoff, credentials, ACL changes or policy override.
        $fullFolder = [IO.Path]::GetFullPath($folder)
        $explorer = Join-Path $env:WINDIR 'explorer.exe'
        $powerShell = Join-Path $PSHOME 'powershell.exe'
        if (-not (Test-Path -LiteralPath $explorer -PathType Leaf)) {
            throw "Windows Explorer executable not found: $explorer"
        }
        if (-not (Test-Path -LiteralPath $powerShell -PathType Leaf)) {
            throw "Windows PowerShell executable not found: $powerShell"
        }
        # Encode only the validated absolute path in a literal child command;
        # no input is interpreted as PowerShell code from the path itself.
        $quotedExplorer = "'" + $explorer.Replace("'", "''") + "'"
        $quotedFolder = "'" + $fullFolder.Replace("'", "''") + "'"
        $launchScript = "try { Start-Process -FilePath $quotedExplorer -ArgumentList ('/n,' + [char]34 + $quotedFolder + [char]34) -ErrorAction Stop | Out-Null; exit 0 } catch { [Console]::Error.WriteLine(\u0024_.Exception.Message); exit 1 }"
        $encoded = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($launchScript))
        # Capture the child PowerShell result rather than interpreting process
        # creation alone as an Explorer launch success. No temporary log files,
        # background credentials, or permission changes are required.
        $startInfo = New-Object System.Diagnostics.ProcessStartInfo
        $startInfo.FileName = $powerShell
        $startInfo.Arguments = "-NoLogo -NoProfile -NonInteractive -EncodedCommand $encoded"
        $startInfo.UseShellExecute = $false
        $startInfo.CreateNoWindow = $true
        $startInfo.RedirectStandardError = $true
        $child = [System.Diagnostics.Process]::Start($startInfo)
        if ($null -eq $child) { throw 'Windows PowerShell child process did not start.' }
        try {
            if (-not $child.WaitForExit(5000)) {
                $ui.ArchiveStatus.Text = "Explorer child PowerShell is still running (PID $($child.Id)). If no folder appears, use Copy Folder Path."
                return
            }
            $childError = $child.StandardError.ReadToEnd().Trim()
            if ($child.ExitCode -ne 0) {
                if ([string]::IsNullOrWhiteSpace($childError)) { $childError = 'No error text was returned.' }
                throw "Explorer child PowerShell exited with code $($child.ExitCode): $childError"
            }
            $ui.ArchiveStatus.Text = "Explorer child completed (exit 0, PID $($child.Id)); window visibility not verified. If the folder does not appear, use Copy Folder Path."
        } finally {
            $child.Dispose()
        }
    } catch {
        $ui.ArchiveStatus.Text = "Explorer could not open this directory. Use Copy Folder Path: $folder"
        [Windows.MessageBox]::Show("Unable to open the reports folder in Explorer.`n$folder`n`n$($_.Exception.Message)`n`nYou can use Copy Folder Path and paste it in Explorer.", 'Report Archive') | Out-Null
    }
})
$ui.ArchiveCopyPath.Add_Click({
    $folder = Get-GUIArchiveFolder
    try {
        [Windows.Clipboard]::SetText([IO.Path]::GetFullPath($folder))
        $ui.ArchiveStatus.Text = "Copied folder path to clipboard: $folder"
    } catch { [Windows.MessageBox]::Show("Unable to copy folder path: $($_.Exception.Message)", 'Report Archive') | Out-Null }
})
$ui.SnapshotsRefresh.Add_Click({ Refresh-SnapshotArchive })
$ui.CompareSnapshotsGUI.Add_Click({
    $older = $ui.SnapshotOlder.SelectedItem; $newer = $ui.SnapshotNewer.SelectedItem
    if ($null -eq $older -or $null -eq $newer) { [Windows.MessageBox]::Show('Choose an older and a newer snapshot.','Snapshot comparison') | Out-Null; return }
    if ($older.Path -eq $newer.Path) { [Windows.MessageBox]::Show('Select two different snapshots.','Snapshot comparison') | Out-Null; return }
    if ($older.CapturedAt -ge $newer.CapturedAt) { [Windows.MessageBox]::Show('The baseline must be older than the newer snapshot.','Snapshot comparison') | Out-Null; return }
    $ui.SaveComparisonGUI.IsEnabled = $false
    $script:GUIComparisonText = $null
    try {
        $result = Compare-GUISnapshotFiles $older.Path $newer.Path
        $ui.ComparisonOutput.Text = $result
        $script:GUIComparisonText = $result
        $script:GUIComparisonTarget = [string]$newer.Target
        $ui.SaveComparisonGUI.IsEnabled = $true
        $ui.SnapshotStatus.Text = 'Comparison complete. Review results or save the comparison.'
    } catch { $ui.ComparisonOutput.Text = $_.Exception.Message; $ui.SnapshotStatus.Text = 'Comparison failed.' }
})
# Export the exact comparison currently displayed; never rerun snapshots on Save.
function Convert-GUIComparisonCsv([string]$comparison) {
    $rows = New-Object System.Collections.Generic.List[object]
    $category = 'Summary'
    foreach ($line in ($comparison -split "`r?`n")) {
        if ($line -match '^--- (.+) ---$') { $category = $Matches[1]; continue }
        if (-not $line.Trim()) { continue }
        $kind = if ($line -match '^(ADDED|REMOVED|CHANGED):') { $Matches[1] } elseif ($line -match '^NOT COMPARABLE') { 'NOT COMPARABLE' } elseif ($line -eq 'No changes found.') { 'NO CHANGES' } else { 'INFO' }
        $rows.Add([pscustomobject][ordered]@{ Category = $category; Change = $kind; Detail = $line })
    }
    return ($rows | ConvertTo-Csv -NoTypeInformation) -join "`r`n"
}
function Convert-GUIComparisonHtml([string]$comparison) {
    $title = [System.Net.WebUtility]::HtmlEncode("$displayName - Snapshot Comparison")
    $body = [System.Net.WebUtility]::HtmlEncode($comparison)
    return @"
<!DOCTYPE html>
<html lang="en"><head><meta charset="utf-8"><title>$title</title>
<style>body{font-family:Segoe UI,Arial,sans-serif;margin:36px;background:#f4f7fb;color:#17365d}main{background:white;border:1px solid #d7e0eb;border-radius:8px;padding:24px}h1{font-size:23px}pre{color:#24364a;font:13px/1.65 Consolas,monospace;white-space:pre-wrap;overflow-wrap:anywhere}</style>
</head><body><main><h1>$title</h1><pre>$body</pre></main></body></html>
"@
}
$ui.SaveComparisonGUI.Add_Click({
    if ([string]::IsNullOrWhiteSpace($script:GUIComparisonText)) { return }
    try {
        $folder = Get-GUIArchiveFolder
        if (-not (Test-Path -LiteralPath $folder -PathType Container)) { [void](New-Item -Path $folder -ItemType Directory -Force -ErrorAction Stop) }
        $format = [string]$ui.ComparisonFormat.SelectedItem.Content
        if ($format -notin @('HTML','CSV','TXT')) { throw 'Select a valid comparison report format.' }
        $safeTarget = [regex]::Replace($script:GUIComparisonTarget,'[^A-Za-z0-9_.-]','_')
        $ext = $format.ToLowerInvariant()
        $path = Join-Path $folder ('{0}_Comparison_{1}.{2}' -f $safeTarget,(Get-Date -Format 'yyyyMMdd_HHmmss_fff'),$ext)
        $output = switch ($format) {
            'HTML' { Convert-GUIComparisonHtml $script:GUIComparisonText }
            'CSV'  { Convert-GUIComparisonCsv $script:GUIComparisonText }
            'TXT'  { $script:GUIComparisonText }
        }
        [IO.File]::WriteAllText($path,[string]$output,(New-Object Text.UTF8Encoding($false)))
        $ui.SnapshotStatus.Text = "Saved $format comparison: $path"
        Refresh-Archive
    } catch { [Windows.MessageBox]::Show($_.Exception.Message,'Unable to save comparison') | Out-Null }
})
# GUI settings edit the same JSON configuration file as Classic mode and the launcher.
function Set-GUIConfigProperty($object, [string]$property, $value) {
    if ($null -ne $object.PSObject.Properties[$property]) { $object.$property = $value }
    else { $object | Add-Member -NotePropertyName $property -NotePropertyValue $value }
}
function Load-GUIConfigSettings {
    $script:cfg = Get-Content -LiteralPath $configPath -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
    $ui.SetOrgName.Text = [string]$script:cfg.Branding.OrganizationName
    $ui.SetAuthDomain.Text = [string]$script:cfg.AuthenticationDomain
    $ui.SetSysinternals.Text = [string]$script:cfg.SysinternalsPath
    $ui.SetPortQry.Text = [string]$script:cfg.PortQryPath
    $ui.SetReportsFolder.Text = [string]$script:cfg.ReportFolder
    $fmt = ([string]$script:cfg.ReportFormat).ToUpperInvariant()
    if ($fmt -notin @('HTML','CSV','TXT')) { $fmt = 'HTML' }
    foreach ($item in $ui.SetReportsFormat.Items) {
        if ([string]$item.Content -eq $fmt) { $ui.SetReportsFormat.SelectedItem = $item; break }
    }
    $ui.SetLogoPath.Text = [string]$script:cfg.Branding.LogoPath
    $ui.SetLoginPath.Text = [string]$script:cfg.Branding.LoginImagePath
    $ui.SetIconPath.Text = [string]$script:cfg.Branding.AppIconPath
}
function Test-GUIConfigPath([string]$value, [bool]$allowRelative) {
    if ([string]::IsNullOrWhiteSpace($value)) { return $false }
    if ($value -match '[\r\n]') { return $false }
    if ($allowRelative) { return $true }
    return [IO.Path]::IsPathRooted($value)
}
$ui.SetReloadConfig.Add_Click({
    try { Load-GUIConfigSettings; $ui.SetConfigStatus.Text = 'Saved configuration reloaded; unsaved edits discarded.' }
    catch { [Windows.MessageBox]::Show($_.Exception.Message,'Unable to reload settings') | Out-Null }
})
$ui.SetSaveConfig.Add_Click({
    try {
        $org = $ui.SetOrgName.Text.Trim()
        $domain = $ui.SetAuthDomain.Text.Trim()
        $sys = $ui.SetSysinternals.Text.Trim()
        $port = $ui.SetPortQry.Text.Trim()
        $folder = $ui.SetReportsFolder.Text.Trim()
        $fmt = [string]$ui.SetReportsFormat.SelectedItem.Content
        if (-not $org) { throw 'Organization name cannot be blank.' }
        if ($domain -match '[\r\n\\/@ ]') { throw 'Default authentication domain must be a domain name without spaces, slashes or @.' }
        if ($sys -ne 'Auto' -and -not (Test-GUIConfigPath $sys $false)) { throw 'Sysinternals must be Auto or an absolute folder path.' }
        if (-not (Test-GUIConfigPath $port $false)) { throw 'PortQry must be an absolute executable path.' }
        if (-not (Test-GUIConfigPath $folder $true)) { throw 'Enter a valid Reports folder path.' }
        if ($fmt -notin @('HTML','CSV','TXT')) { throw 'Choose a report format.' }
        foreach ($imagePath in @($ui.SetLogoPath.Text,$ui.SetLoginPath.Text,$ui.SetIconPath.Text)) {
            if ($imagePath -match '[\r\n]') { throw 'Image paths cannot contain line breaks.' }
        }
        # Read the latest file immediately before writing; retain all unrelated settings.
        $current = Get-Content -LiteralPath $configPath -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
        if (-not $current.Branding) { Set-GUIConfigProperty $current 'Branding' ([pscustomobject]@{}) }
        Set-GUIConfigProperty $current 'AuthenticationDomain' $domain
        Set-GUIConfigProperty $current 'SysinternalsPath' $sys
        Set-GUIConfigProperty $current 'PortQryPath' $port
        Set-GUIConfigProperty $current 'ReportFolder' $folder
        Set-GUIConfigProperty $current 'ReportFormat' $fmt
        Set-GUIConfigProperty $current.Branding 'OrganizationName' $org
        Set-GUIConfigProperty $current.Branding 'LogoPath' $ui.SetLogoPath.Text.Trim()
        Set-GUIConfigProperty $current.Branding 'LoginImagePath' $ui.SetLoginPath.Text.Trim()
        Set-GUIConfigProperty $current.Branding 'AppIconPath' $ui.SetIconPath.Text.Trim()
        $serialized = ConvertTo-Json -InputObject $current -Depth 30 -ErrorAction Stop
        $backupFile = $configPath + '.bak'
        [IO.File]::Copy($configPath,$backupFile,$true)
        $tmpFile = $configPath + '.tmp'
        try {
            [IO.File]::WriteAllText($tmpFile,$serialized + [Environment]::NewLine,(New-Object Text.UTF8Encoding($false)))
            [IO.File]::Copy($tmpFile,$configPath,$true)
        } finally { if (Test-Path -LiteralPath $tmpFile) { Remove-Item -LiteralPath $tmpFile -Force -ErrorAction SilentlyContinue } }
        Load-GUIConfigSettings
        $script:organization = $org
        $window.Title = "$org $($script:appName) - Graphical Interface"
        $ui.Heading.Text = "$org $($script:appName)"
        $ui.SetConfigStatus.Text = 'Settings saved. Launcher defaults and branding images refresh when restarted. Restart GUI to apply all settings.'
        $ui.Status.Text = 'Organization settings saved.'
    } catch { [Windows.MessageBox]::Show($_.Exception.Message,'Unable to save configuration') | Out-Null }
})
$ui.SetClearTargets.Add_Click({
    if ([Windows.MessageBox]::Show('Clear your recent target history?','Confirm',[Windows.MessageBoxButton]::YesNo,[Windows.MessageBoxImage]::Question) -ne [Windows.MessageBoxResult]::Yes) { return }
    $script:RecentTargets = @(); Save-GUIPreferences; Refresh-RecentTargets
    $ui.SetConfigStatus.Text = 'Recent targets cleared for this technician.'
})
$ui.SetClearFavorites.Add_Click({
    if ([Windows.MessageBox]::Show('Remove all ten Favorites and dashboard shortcuts?','Confirm',[Windows.MessageBoxButton]::YesNo,[Windows.MessageBoxImage]::Question) -ne [Windows.MessageBoxResult]::Yes) { return }
    $script:FavoriteIds = @(); Save-GUIPreferences; Refresh-DashboardPins; Refresh-Tools
    $ui.SetConfigStatus.Text = 'Favorites cleared for this technician.'
})
try { Load-GUIConfigSettings } catch { $ui.SetConfigStatus.Text = "Unable to load settings: $($_.Exception.Message)" }

Set-GUIAuthView
Update-TargetView
Refresh-DashboardPins
Refresh-Tools
Refresh-RecentTargets
Refresh-RecentReports
# Restore the last page without connecting to any remembered target.
switch ($script:LastGUIPage) {
    'Tools' { Refresh-Tools; Show-GUIPage 'Tools' }
    'Reports' { Refresh-Archive; Refresh-SnapshotArchive; Show-GUIPage 'Reports' }
    'Settings' { Show-GUIPage 'Settings' }
    'Diagnostics' { Show-GUIPage 'Diagnostics' }
    default { Show-GUIPage 'Dashboard' }
}
Restore-GUIWindowPlacement
# Hide only the console owned by this PowerShell process, after WPF is visible.
# Keep this separate from the launcher so Classic mode remains unchanged.
$window.Add_ContentRendered({
    try {
        if (-not ('ITToolkitConsoleWindow' -as [type])) {
            Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class ITToolkitConsoleWindow {
    [DllImport("kernel32.dll")] public static extern IntPtr GetConsoleWindow();
    [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
}
'@ -ErrorAction Stop
        }
        $consoleHandle = [ITToolkitConsoleWindow]::GetConsoleWindow()
        if ($consoleHandle -ne [IntPtr]::Zero) {
            [void][ITToolkitConsoleWindow]::ShowWindow($consoleHandle, 0)
        }
    } catch {
        # Console-hiding failure must never prevent the GUI from running.
    }
})
$window.Add_SizeChanged({ Update-FavoriteColumns })
[void]$window.ShowDialog()
