# v1.26 Phase 3D: isolated mixed-method diagnostic probes.
# Remote commands execute inside one authenticated WinRM operation.
# No credential fallback, remote mutations, or secret collection.
function Get-ToolkitMixedDiagnostic {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]$Context,
        [Parameter(Mandatory=$true)]
        [ValidateSet('SystemInfo','GroupPolicy','Sessions','Events','RegistrySoftware')]
        [string]$Section
    )
    if ($null -eq $Context -or $Context.PSTypeNames -notcontains 'ITToolkit.AuthenticationContext') {
        throw 'Expected an authentication context from New-ToolkitAuthContext.'
    }
    if ($Context.Mode -notin @('Default','Alternate')) { throw 'Unknown authentication mode.' }
    if ($Context.Mode -eq 'Alternate' -and $null -eq $Context.Credential) {
        throw 'Alternate credentials missing: refusing to use current Windows identity.'
    }
    $started = Get-Date
    $status = 'UNAVAILABLE'
    $details = ''
    $results = @()
    try {
        $scriptBlock = {
            param([string]$Kind)
            $ErrorActionPreference = 'Stop'
            switch ($Kind) {
                'SystemInfo' {
                    # Run locally on the TARGET, avoiding systeminfo /s and its implicit credentials.
                    $output = @(& "$env:SystemRoot\System32\systeminfo.exe" /FO LIST 2>&1)
                    $exitCode = $LASTEXITCODE
                    if ($exitCode -ne 0) { throw "systeminfo failed (exit $exitCode): $($output -join ' ')" }
                    foreach ($line in $output) { if ($null -ne $line) { [pscustomobject]@{ Line = [string]$line } } }
                }
                'GroupPolicy' {
                    # Computer RSOP; reports may be unavailable for some system configurations.
                    $output = @(& "$env:SystemRoot\System32\gpresult.exe" /SCOPE COMPUTER /R 2>&1)
                    $exitCode = $LASTEXITCODE
                    if ($exitCode -ne 0) { throw "gpresult failed (exit $exitCode): $($output -join ' ')" }
                    foreach ($line in $output) { if ($null -ne $line) { [pscustomobject]@{ Line = [string]$line } } }
                }
                'Sessions' {
                    $exe = "$env:SystemRoot\System32\quser.exe"
                    if (-not (Test-Path -LiteralPath $exe -PathType Leaf)) { throw 'quser.exe unavailable on the target.' }
                    $output = @(& $exe 2>&1)
                    $exitCode = $LASTEXITCODE
                    if ($exitCode -ne 0) { throw "quser failed (exit $exitCode): $($output -join ' ')" }
                    foreach ($line in $output) { if ($null -ne $line) { [pscustomobject]@{ Line = [string]$line } } }
                }
                'Events' {
                    # Critical/Error events, System log, last seven days, max 20.
                    try {
                        Get-WinEvent -FilterHashtable @{
                            LogName='System'; Level=@(1,2); StartTime=(Get-Date).AddDays(-7)
                        } -MaxEvents 20 -ErrorAction Stop | ForEach-Object {
                            [pscustomobject]@{
                                TimeCreated = $_.TimeCreated
                                Id = $_.Id
                                LevelDisplayName = [string]$_.LevelDisplayName
                                ProviderName = [string]$_.ProviderName
                                Message = [string]$_.Message
                            }
                        }
                    } catch {
                        if ($_.FullyQualifiedErrorId -match 'NoMatchingEventsFound') { return }
                        throw
                    }
                }
                'RegistrySoftware' {
                    # HKLM-only uninstall entries (both views). Do NOT enumerate credentials or keys.
                    $locations = @(
                        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*',
                        'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*'
                    )
                    foreach ($loc in $locations) {
                        Get-ItemProperty -Path $loc -ErrorAction SilentlyContinue |
                            Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_.DisplayName) } |
                            ForEach-Object {
                                [pscustomobject]@{
                                    Name = [string]$_.DisplayName
                                    Version = [string]$_.DisplayVersion
                                    Publisher = [string]$_.Publisher
                                    InstallDate = [string]$_.InstallDate
                                }
                            }
                    }
                }
                default { throw 'Unsupported mixed diagnostic section.' }
            }
        }
        $parameters = @{
            ComputerName = [string]$Context.ComputerName
            ScriptBlock = $scriptBlock
            ArgumentList = @($Section)
            ErrorAction = 'Stop'
        }
        if ($Context.Mode -eq 'Alternate') {
            $parameters.Credential = $Context.Credential
            $parameters.Authentication = 'Negotiate'
        }
        $results = @(Invoke-Command @parameters)
        $status = if ($results.Count -gt 0) { 'SUCCESS' } else { 'NO RESULTS' }
    } catch {
        $details = [string]$_.Exception.Message
        $results = @()
    }
    [pscustomobject]@{
        Target = [string]$Context.ComputerName
        Mode = [string]$Context.Mode
        UserName = [string]$Context.UserName
        Section = $Section
        CollectedAt = $started
        Status = $status
        Count = @($results).Count
        Data = @($results)
        Error = $details
    }
}
