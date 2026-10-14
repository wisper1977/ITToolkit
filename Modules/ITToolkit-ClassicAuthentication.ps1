# v1.26 Phase 2 - Classic target authentication UI. Phase 3 will adapt diagnostic execution.
$script:ToolkitAuthContext = $null
$script:ToolkitAuthMode = 'Default'
$script:ToolkitAuthUserName = ''

function Reset-ClassicAlternateCredential {
    if ($null -ne $script:ToolkitAuthContext) {
        Clear-ToolkitAuthContext -Context $script:ToolkitAuthContext
    }
    $script:ToolkitAuthContext = $null
    $script:ToolkitAuthMode = 'Default'
    $script:ToolkitAuthUserName = ''
}
function Set-ClassicTargetCredential {
    if (-not $script:TargetComputer) { Write-Host 'Choose a target first.' -ForegroundColor Yellow; Pause-Toolkit; return }
    Write-Host '1 Default toolkit account' -ForegroundColor Cyan
    Write-Host '2 Alternate account (probes and Classic diagnostic reports)' -ForegroundColor Cyan
    $answer = (Read-Host 'Choose 1 or 2 (blank cancels)').Trim()
    if (-not $answer) { return }
    if ($answer -eq '1') { Reset-ClassicAlternateCredential; Write-Host 'Using default identity.'; Pause-Toolkit; return }
    if ($answer -ne '2') { return }
    $default = if ($script:Config.AuthenticationDomain) { [string]$script:Config.AuthenticationDomain } else { '' }
    $entry = (Read-Host 'Alternate username (DOMAIN\\user or bare user)').Trim()
    if (-not $entry) { return }
    try {
        $user = Resolve-ToolkitAuthUserName -UserName $entry -DefaultDomain $default
        $credential = Get-Credential -UserName $user -Message "Credentials for $($script:TargetComputer) (password not saved)"
        if ($null -eq $credential) { return }
        $candidate = New-ToolkitAuthContext -ComputerName $script:TargetComputer -Mode Alternate -Credential $credential
        $results = @(Get-ToolkitAuthProbeSummary -Context $candidate)
        $results | Format-Table Method,Status,Detail -Wrap -AutoSize | Out-Host
        # Keep context in memory only for this target. No implicit default fallback.
        Reset-ClassicAlternateCredential
        $script:ToolkitAuthContext = $candidate
        $script:ToolkitAuthMode = 'Alternate'
        $script:ToolkitAuthUserName = $user
        Write-Host 'Alternate credentials selected. Classic diagnostic reporting uses the authenticated dispatcher. Other tools and ADMIN$ still use their original access rules.' -ForegroundColor Yellow
    } catch { Write-Host "Credential test failed: $($_.Exception.Message)" -ForegroundColor Yellow }
    Pause-Toolkit
}
function Assert-ClassicDefaultAuthentication {
    if ($script:ToolkitAuthMode -ne 'Alternate') { return $true }
    Write-Host 'Alternate credentials are selected. This menu action is not yet credential-aware.' -ForegroundColor Yellow
    Write-Host 'Choose default credentials using option 12 to use this menu action.' -ForegroundColor Yellow
    Pause-Toolkit
    return $false
}
