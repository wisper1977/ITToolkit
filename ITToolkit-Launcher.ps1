# IT Toolkit WPF launcher - branding and version come from Toolkit-config.json (Windows PowerShell 5.1, STA)
# Supports current-session launch or explicitly supplied Windows credentials.
# No passwords are written to disk, logs, command lines, or preferences.
# GUI selection is retained for later development; GUI does not launch until installed.

$ErrorActionPreference = 'Stop'
$toolkitRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$configPath = Join-Path $toolkitRoot 'Toolkit-config.json'
$classicPath = Join-Path $toolkitRoot 'ITToolkit.ps1'
$guiPath = Join-Path $toolkitRoot 'ITToolkit-GUI.ps1'
$settingsDir = Join-Path ([Environment]::GetFolderPath('LocalApplicationData')) 'CochiseCounty\ITToolkit'
$settingsPath = Join-Path $settingsDir 'UserSettings.json'

if ([Threading.Thread]::CurrentThread.GetApartmentState() -ne [Threading.ApartmentState]::STA) {
    throw 'The launcher requires STA. Use Launch.cmd, or powershell.exe -STA -File ITToolkit-Launcher.ps1.'
}
if (-not (Test-Path -LiteralPath $configPath -PathType Leaf)) { throw "Missing toolkit configuration: $configPath" }
if (-not (Test-Path -LiteralPath $classicPath -PathType Leaf)) { throw "Missing Classic toolkit: $classicPath" }

$config = Get-Content -LiteralPath $configPath -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
$version = if ($config.Version) { [string]$config.Version } else { 'Unknown' }
$orgName = if ($config.Branding -and $config.Branding.OrganizationName) { [string]$config.Branding.OrganizationName } else { 'Your Organization' }
$appName = if ($config.Branding -and $config.Branding.ApplicationName) { [string]$config.Branding.ApplicationName } else { 'IT Toolkit' }
$defaultDomain = if (
    $config.AuthenticationDomain -and
    -not [string]::IsNullOrWhiteSpace([string]$config.AuthenticationDomain)
) {
    [string]$config.AuthenticationDomain
} else {
    ''
}
$settings = [ordered]@{ Username = ''; PreferredInterface = 'Classic'; RememberUsername = $true; RememberInterface = $true; UseCurrentSession = $false }
if (Test-Path -LiteralPath $settingsPath -PathType Leaf) {
    try {
        $saved = Get-Content -LiteralPath $settingsPath -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
        if ($saved.Username -is [string]) { $settings.Username = $saved.Username }
        if ($saved.PreferredInterface -in @('Classic','GUI')) { $settings.PreferredInterface = $saved.PreferredInterface }
        if ($null -ne $saved.RememberUsername) { $settings.RememberUsername = [bool]$saved.RememberUsername }
        if ($null -ne $saved.RememberInterface) { $settings.RememberInterface = [bool]$saved.RememberInterface }
        if ($null -ne $saved.UseCurrentSession) { $settings.UseCurrentSession = [bool]$saved.UseCurrentSession }
    } catch { Write-Warning "Could not load personal launcher preferences: $($_.Exception.Message)" }
}

Add-Type -AssemblyName PresentationFramework,PresentationCore,WindowsBase
[xml]$xaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" Title="IT Toolkit Launcher" Width="510" Height="555" MinWidth="480" MinHeight="555" WindowStartupLocation="CenterScreen" ResizeMode="CanMinimize" Background="#F4F7FB" FontFamily="Segoe UI">
  <Grid>
    <Grid.RowDefinitions>
      <RowDefinition Height="92"/>
      <RowDefinition Name="BannerRow" Height="0"/>
      <RowDefinition Height="*"/>
      <RowDefinition Height="Auto"/>
    </Grid.RowDefinitions>
    <Border Background="#17365D" Grid.Row="0" Padding="23,12">
      <Grid>
        <Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions>
        <StackPanel Grid.Column="0" VerticalAlignment="Center">
          <TextBlock Name="Heading" FontSize="22" FontWeight="SemiBold" Foreground="White" TextTrimming="CharacterEllipsis"/>
          <TextBlock Name="Subheading" Margin="0,7,0,0" FontSize="12" Foreground="#CFDFEF"/>
        </StackPanel>
        <Image Name="OrganizationLogo" Grid.Column="1" Height="65" Width="72" Margin="12,0,0,0" Stretch="Uniform" Visibility="Collapsed"/>
      </Grid>
    </Border>
    <Border Grid.Row="1" Background="#E4EDF7" ClipToBounds="True">
      <Image Name="LoginBackground" Height="105" Stretch="UniformToFill" Visibility="Collapsed"/>
    </Border>
    <ScrollViewer Grid.Row="2" VerticalScrollBarVisibility="Auto" HorizontalScrollBarVisibility="Disabled">
      <StackPanel Margin="25,20,25,4">
        <CheckBox Name="UseCurrentSession" Content="Run as my current Windows user" FontWeight="SemiBold" Foreground="#24364A" Margin="0,0,0,5" ToolTip="Do not use another account. Toolkit will inherit the launcher Windows identity and its available permissions."/>
        <TextBlock Name="ExecutionNote" TextWrapping="Wrap" FontSize="11" Foreground="#526477" Margin="0,0,0,12" Text="Unchecked: launch under a separate administrative Windows account."/>
        <TextBlock Text="Administrative username (separate-account mode)" FontWeight="SemiBold" Foreground="#24364A"/>
        <TextBox Name="Username" Height="32" Margin="0,6,0,12" Padding="8,5" ToolTip="Enter username, DOMAIN\username, or username@domain"/>
        <TextBlock Text="Password" FontWeight="SemiBold" Foreground="#24364A"/>
        <PasswordBox Name="Password" Height="32" Margin="0,6,0,13" Padding="8,5"/>
        <TextBlock Text="Choose interface" FontWeight="SemiBold" Foreground="#24364A"/>
        <ComboBox Name="Interface" Height="33" Margin="0,6,0,12" SelectedIndex="0">
          <ComboBoxItem Content="Classic PowerShell menu" Tag="Classic"/>
          <ComboBoxItem Content="Graphical user interface" Tag="GUI"/>
        </ComboBox>
        <CheckBox Name="RememberUser" Content="Remember my username" Margin="0,1,0,8"/>
        <CheckBox Name="RememberInterface" Content="Remember my interface preference" Margin="0,0,0,10"/>
        <TextBlock Name="Message" TextWrapping="Wrap" Foreground="#8A3C11" FontSize="12" MinHeight="38"/>
      </StackPanel>
    </ScrollViewer>
    <StackPanel Grid.Row="3" Margin="25,8,25,20">
      <DockPanel LastChildFill="False">
        <Button Name="Cancel" Content="Cancel" Width="95" Height="35" DockPanel.Dock="Right" Margin="10,0,0,0"/>
        <Button Name="Launch" Content="Launch Toolkit" Width="155" Height="35" DockPanel.Dock="Right" Background="#17365D" Foreground="White" FontWeight="SemiBold"/>
      </DockPanel>
      <TextBlock Name="Footer" Margin="0,12,0,0" FontSize="11" Foreground="#66788B" TextWrapping="Wrap"/>
    </StackPanel>
  </Grid>
</Window>
'@
$reader = New-Object System.Xml.XmlNodeReader $xaml
$window = [Windows.Markup.XamlReader]::Load($reader)
$ui = @{}
foreach ($name in @('Heading','Subheading','Username','Password','Interface','RememberUser','RememberInterface','UseCurrentSession','ExecutionNote','Message','Launch','Cancel','Footer','OrganizationLogo','LoginBackground','BannerRow')) {
    $ui[$name] = $window.FindName($name)
}
$window.Title = "$orgName $appName - Launcher"
$ui.Heading.Text = "$orgName $appName"
$ui.Subheading.Text = "Launcher  |  Toolkit v$version"
$ui.Footer.Text = 'Your password is never saved. Classic mode uses the existing production toolkit.'
$ui.Username.Text = [string]$settings.Username
$ui.RememberUser.IsChecked = [bool]$settings.RememberUsername
$ui.RememberInterface.IsChecked = [bool]$settings.RememberInterface
$ui.UseCurrentSession.IsChecked = [bool]$settings.UseCurrentSession
function Update-LauncherIdentityFields {
    $usingCurrent = [bool]$ui.UseCurrentSession.IsChecked
    $ui.Username.IsEnabled = -not $usingCurrent
    $ui.Password.IsEnabled = -not $usingCurrent
    $ui.RememberUser.IsEnabled = -not $usingCurrent
    $ui.ExecutionNote.Text = if ($usingCurrent) {
        "Toolkit runs as $([Security.Principal.WindowsIdentity]::GetCurrent().Name). This does not elevate or grant administrator permissions."
    } else {
        'Toolkit runs as the supplied Windows account. Windows Explorer may still belong to a different signed-in user.'
    }
}
$ui.UseCurrentSession.Add_Checked({ Update-LauncherIdentityFields })
$ui.UseCurrentSession.Add_Unchecked({ Update-LauncherIdentityFields })
Update-LauncherIdentityFields
if ($settings.PreferredInterface -eq 'GUI') { $ui.Interface.SelectedIndex = 1 }

# Load a configurable branding image. Relative paths resolve under the toolkit root.
# Missing or unreadable images are optional: the launcher keeps its standard layout.
function Get-BrandingImage {
    param([string]$ConfiguredPath, [string]$FallbackPath)

    $imagePath = $ConfiguredPath
    if ([string]::IsNullOrWhiteSpace($imagePath)) { $imagePath = $FallbackPath }
    if ([string]::IsNullOrWhiteSpace($imagePath)) { return $null }
    if (-not [IO.Path]::IsPathRooted($imagePath)) { $imagePath = Join-Path $toolkitRoot $imagePath }
    if (-not (Test-Path -LiteralPath $imagePath -PathType Leaf)) { return $null }

    try {
        $bitmap = New-Object Windows.Media.Imaging.BitmapImage
        $bitmap.BeginInit()
        $bitmap.CacheOption = [Windows.Media.Imaging.BitmapCacheOption]::OnLoad
        $bitmap.UriSource = [Uri]::new([IO.Path]::GetFullPath($imagePath), [UriKind]::Absolute)
        $bitmap.EndInit()
        $bitmap.Freeze()
        return $bitmap
    } catch {
        Write-Warning "Could not load optional branding image '$imagePath': $($_.Exception.Message)"
        return $null
    }
}

$logoSetting = if ($config.Branding -and $config.Branding.LogoPath) { [string]$config.Branding.LogoPath } else { '' }
$logoImage = Get-BrandingImage -ConfiguredPath $logoSetting -FallbackPath 'Branding\Logo.png'
if ($null -ne $logoImage) {
    $ui.OrganizationLogo.Source = $logoImage
    $ui.OrganizationLogo.Visibility = [Windows.Visibility]::Visible
}

$bannerSetting = if ($config.Branding -and $config.Branding.LoginImagePath) { [string]$config.Branding.LoginImagePath } else { '' }
$bannerImage = Get-BrandingImage -ConfiguredPath $bannerSetting -FallbackPath 'Branding\LoginBackground.png'
if ($null -ne $bannerImage) {
    $ui.LoginBackground.Source = $bannerImage
    $ui.LoginBackground.Visibility = [Windows.Visibility]::Visible
    $ui.BannerRow.Height = [Windows.GridLength]::new(105)
    $window.Height = 660
    $window.MinHeight = 660
}

# Optional organization logo in the title-bar icon (configured path must remain local).
try {
    if ($config.Branding -and $config.Branding.AppIconPath) {
        $iconPath = [string]$config.Branding.AppIconPath
        if (-not [IO.Path]::IsPathRooted($iconPath)) { $iconPath = Join-Path $toolkitRoot $iconPath }
        if (Test-Path -LiteralPath $iconPath -PathType Leaf) {
            $window.Icon = [Windows.Media.Imaging.BitmapFrame]::Create((New-Object Uri($iconPath, [UriKind]::Absolute)))
        }
    }
} catch { }

$ui.Cancel.Add_Click({ $window.Close() })
$ui.Launch.Add_Click({
    $ui.Message.Text = ''
    $selection = [string]$ui.Interface.SelectedItem.Tag
    $userEntry = $ui.Username.Text.Trim()
    $usingCurrent = [bool]$ui.UseCurrentSession.IsChecked
    if (-not $usingCurrent -and [string]::IsNullOrWhiteSpace($userEntry)) { $ui.Message.Text = 'Enter an administrative username.'; return }
    if (-not $usingCurrent -and $ui.Password.SecurePassword.Length -eq 0) { $ui.Message.Text = 'Enter the password for that account.'; return }
    if ($selection -eq 'GUI' -and -not (Test-Path -LiteralPath $guiPath -PathType Leaf)) {
        $ui.Message.Text = 'The graphical interface is not installed yet. Select Classic PowerShell for now.'
        return
    }

    # Persist only non-secret preferences under the ORIGINAL interactive user.
    try {
        if (-not (Test-Path -LiteralPath $settingsDir -PathType Container)) { [void](New-Item -ItemType Directory -Path $settingsDir -Force -ErrorAction Stop) }
        $newSettings = [ordered]@{
            Username = if ([bool]$ui.RememberUser.IsChecked) { $userEntry } else { '' }
            PreferredInterface = if ([bool]$ui.RememberInterface.IsChecked) { $selection } else { 'Classic' }
            RememberUsername = [bool]$ui.RememberUser.IsChecked
            RememberInterface = [bool]$ui.RememberInterface.IsChecked
            UseCurrentSession = $usingCurrent
        }
        [IO.File]::WriteAllText($settingsPath, (ConvertTo-Json -InputObject $newSettings -Depth 3), (New-Object Text.UTF8Encoding($false)))
    } catch {
        $ui.Message.Text = "Preferences could not be saved; launch will continue. $($_.Exception.Message)"
    }

    $scriptFile = if ($selection -eq 'GUI') { $guiPath } else { $classicPath }
    $processInfo = New-Object System.Diagnostics.ProcessStartInfo
    $processInfo.FileName = Join-Path $PSHOME 'powershell.exe'
    $processInfo.Arguments = '-NoLogo -NoProfile -STA -ExecutionPolicy Bypass -File "' + $scriptFile + '"'
    $processInfo.WorkingDirectory = $toolkitRoot
    $processInfo.UseShellExecute = $false

    # Explicitly selected current-session mode inherits the launcher's Windows
    # identity and token. It does not elevate, authenticate, or substitute users.
    # Separate-account mode preserves the existing credential-based process launch.
    if (-not $usingCurrent) {
        $domain = $defaultDomain
        $username = $userEntry
        if ($userEntry.Contains('\')) {
            $parts = $userEntry.Split([char]'\',2)
            if ([string]::IsNullOrWhiteSpace($parts[0]) -or [string]::IsNullOrWhiteSpace($parts[1])) {
                $ui.Message.Text = 'Use DOMAIN\username or just username.'
                return
            }
            $domain = $parts[0]
            $username = $parts[1]
        } elseif ($userEntry.Contains('@')) {
            $domain = ''
            $username = $userEntry
        }
        $processInfo.LoadUserProfile = $true
        $processInfo.UserName = $username
        $processInfo.Domain = $domain
        $processInfo.Password = $ui.Password.SecurePassword.Copy()
    }
    try {
        $ui.Launch.IsEnabled = $false
        $proc = [System.Diagnostics.Process]::Start($processInfo)
        if ($null -eq $proc) { throw 'Windows did not start the selected process.' }
        $window.Close()
    } catch {
        $ui.Message.Text = "Could not launch toolkit: $($_.Exception.Message)"
        $ui.Launch.IsEnabled = $true
    } finally {
        if ($null -ne $processInfo.Password) { $processInfo.Password.Dispose() }
    }
})
$ui.Username.Focus() | Out-Null
[void]$window.ShowDialog()
