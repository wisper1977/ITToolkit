# IT Toolkit - dot-sourced Settings component; loaded in parent script scope.
# Configuration actions are grouped here; diagnostics submenus remain read-only.
function Menu-Settings {
    while ($true) {
        Test-ToolkitDependencies
        Show-Header 'Settings'
        Write-Host ' TOOL CONFIGURATION' -ForegroundColor Yellow
        Write-Host ' 1 Sysinternals folder - Auto-detect or select a custom location'
        Write-Host "    Configured: $($script:Config.SysinternalsPath)" -ForegroundColor DarkGray
        Write-Host "    Active:     $($script:SysinternalsFolder)" -ForegroundColor DarkGray
        Write-Host ' 2 PortQry executable  - Set folder or portqry.exe path'
        Write-Host "    Current:    $($script:PortQryExecutable)" -ForegroundColor DarkGray
        Write-Host '------------------------------------------------------------' -ForegroundColor DarkGray
        Write-Host ' REPORT CONFIGURATION' -ForegroundColor Yellow
        Write-Host ' 3 Report folder       - Change destination for saved reports'
        Write-Host "    Current:    $($script:ReportFolder)" -ForegroundColor DarkGray
        Write-Host ' 4 Report format       - Choose TXT / CSV / HTML'
        Write-Host "    Current:    $($script:ReportFormat)" -ForegroundColor DarkGray
        Write-Host '------------------------------------------------------------' -ForegroundColor DarkGray
        Write-Host ' ORGANIZATION / AUTHENTICATION' -ForegroundColor Yellow
        Write-Host ' 5 Organization name   - Name shown in Classic menus and reports'
        Write-Host "    Current:    $($script:OrganizationName)" -ForegroundColor DarkGray
        Write-Host ' 6 Authentication domain - Default Windows domain used by the launcher'
        $domainValue = if ($script:Config.Contains('AuthenticationDomain') -and $script:Config.AuthenticationDomain) { [string]$script:Config.AuthenticationDomain } else { '(not configured)' }
        Write-Host "    Current:    $domainValue" -ForegroundColor DarkGray
        Write-Host '------------------------------------------------------------' -ForegroundColor DarkGray
        Write-Host ' B Back to main menu' 
        Write-Host '------------------------------------------------------------' -ForegroundColor DarkGray
        Write-Host ''
        $choice = (Read-Host 'Choose').Trim().ToUpperInvariant()
        switch ($choice) {
            '1' {
                Write-Host "Configured Sysinternals: $($script:Config.SysinternalsPath)" -ForegroundColor Cyan
                Write-Host "Currently detected: $($script:SysinternalsFolder)" -ForegroundColor Cyan
                $path=(Read-Host 'Enter Sysinternals Tools folder, AUTO to redetect, or B to cancel').Trim().Trim('"')
                if ($path -and $path -ine 'B') {
                    if ($path -ieq 'AUTO') {
                        $script:Config.SysinternalsPath='Auto'
                        $script:SysinternalsFolder=Find-SysinternalsFolder
                        [void](Save-ToolkitConfig)
                    } elseif (Test-Path -LiteralPath $path -PathType Container) {
                        $script:Config.SysinternalsPath=(Resolve-Path -LiteralPath $path).ProviderPath
                        $script:SysinternalsFolder=$script:Config.SysinternalsPath
                        [void](Save-ToolkitConfig)
                    } else { Write-Host 'Folder not found.' -ForegroundColor Yellow }
                    Write-Host "Active Sysinternals folder: $($script:SysinternalsFolder)"
                    Pause-Toolkit
                }
            }
            '2' { Set-PortQryPath }
            '3' { Set-ReportFolder }
            '4' { Set-ReportFormat }
            '5' {
                Write-Host "Current organization name: $($script:OrganizationName)" -ForegroundColor Cyan
                $newName = (Read-Host 'Enter organization name (blank or B to cancel)').Trim()
                if ($newName -and $newName -ine 'B') {
                    if (-not $script:Config.Contains('Branding') -or $null -eq $script:Config.Branding) {
                        $script:Config['Branding'] = [pscustomobject]@{}
                    }
                    $branding = $script:Config.Branding
                    $oldProperty = $branding.PSObject.Properties['OrganizationName']
                    $hadOldProperty = ($null -ne $oldProperty)
                    $oldName = if ($hadOldProperty) { $oldProperty.Value } else { $null }
                    if ($hadOldProperty) { $branding.OrganizationName = $newName }
                    else { $branding | Add-Member -NotePropertyName OrganizationName -NotePropertyValue $newName }
                    if (Save-ToolkitConfig) {
                        $script:OrganizationName = $newName
                        $script:ToolkitDisplayName = ($script:OrganizationName + ' ' + $script:ApplicationName).Trim()
                        Write-Host "Organization updated: $newName" -ForegroundColor Green
                    } else {
                        if ($hadOldProperty) { $branding.OrganizationName = $oldName }
                        else { $branding.PSObject.Properties.Remove('OrganizationName') }
                    }
                    Pause-Toolkit
                }
            }
            '6' {
                Write-Host "Current authentication domain: $domainValue" -ForegroundColor Cyan
                $newDomain = (Read-Host 'Enter default domain (blank or B to cancel)').Trim()
                if ($newDomain -and $newDomain -ine 'B') {
                    if ($newDomain -notmatch '^[A-Za-z0-9][A-Za-z0-9._-]*$') {
                        Write-Host 'Enter a domain name only (for example CONTOSO or corp.example.com), without a username or backslash.' -ForegroundColor Yellow
                    } else {
                        $hadOldDomain = $script:Config.Contains('AuthenticationDomain')
                        $oldDomain = if ($hadOldDomain) { $script:Config.AuthenticationDomain } else { $null }
                        $script:Config['AuthenticationDomain'] = $newDomain
                        if (Save-ToolkitConfig) {
                            Write-Host "Default authentication domain saved: $newDomain" -ForegroundColor Green
                            Write-Host 'The launcher will use this value when it is next started.' -ForegroundColor DarkGray
                        } else {
                            if ($hadOldDomain) { $script:Config['AuthenticationDomain'] = $oldDomain }
                            else { $script:Config.Remove('AuthenticationDomain') }
                        }
                    }
                    Pause-Toolkit
                }
            }
            'B' { return }
            '0' { return }
        }
    }
}

