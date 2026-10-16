# Windows PowerShell 5.1. No network activity, UAC, or real authentication.
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
. (Join-Path $root 'Modules\ITToolkit-ExecutionContext.ps1')
. (Join-Path $root 'Modules\ITToolkit-PrivilegeRequirements.ps1')
. (Join-Path $root 'Modules\ITToolkit-OperationAuthorization.ps1')
. (Join-Path $root 'Modules\ITToolkit-Authentication.ps1')

$all = @((Get-ToolkitDiagnosticRequirements).Section)
if ($all.Count -ne 20 -or @($all | Select-Object -Unique).Count -ne 20) { throw 'Expected 20 unique sections.' }
$default = @(Assert-ToolkitRemoteDiagnosticAuthorization -Sections $all -TargetComputer 'TESTSERVER' -Mode Default)
if ($default.Count -ne 20 -or @($default | Where-Object { $_.RequestedAuthenticationMode -ne 'Default' -or $_.Assessment -ne 'ReadyForAttempt' }).Count) {
    throw 'Default remote batch failed.'
}
Write-Host 'PASS: Default remote preflight accepts all 20 sections.'

# Dummy credentials are structurally valid and never used to contact TESTSERVER.
$password = ConvertTo-SecureString 'TestOnly-NoNetwork!' -AsPlainText -Force
$credential = New-Object System.Management.Automation.PSCredential('TESTDOMAIN\TestUser',$password)
$context = New-ToolkitAuthContext -ComputerName TESTSERVER -Mode Alternate -Credential $credential
try {
    $alternate = @(Assert-ToolkitRemoteDiagnosticAuthorization -Sections $all -TargetComputer TESTSERVER -Mode Alternate -AuthenticationContext $context)
    if ($alternate.Count -ne 20 -or @($alternate | Where-Object { $_.RequestedAuthenticationMode -ne 'Alternate' -or $_.RequestedIdentity -ne $credential.UserName -or $_.Assessment -ne 'ReadyForAttempt' }).Count) {
        throw 'Alternate remote batch failed.'
    }
    if (@($alternate[0].PSObject.Properties.Name | Where-Object { $_ -match 'Credential|Password' }).Count) { throw 'Sensitive credential fields leaked into assessment.' }
    Write-Host 'PASS: Explicit Alternate target-bound context accepts all 20 sections without credential exposure.'

    $attempts = 0
    function Invoke-SimulatedRemoteCollection {
        param([string[]]$Sections,[string]$Target,[string]$Mode,$Context)
        $null = Assert-ToolkitRemoteDiagnosticAuthorization -Sections $Sections -TargetComputer $Target -Mode $Mode -AuthenticationContext $Context
        $script:attempts++
    }
    function Assert-Denied {
        param([string[]]$Sections,[string]$Target,[string]$Mode,$Context)
        $blocked = $false
        try { Invoke-SimulatedRemoteCollection -Sections $Sections -Target $Target -Mode $Mode -Context $Context }
        catch { $blocked = $true }
        if (-not $blocked) { throw ('Expected a denial for ' + $Mode + '/' + $Target) }
    }
    Assert-Denied -Sections @('System') -Target TESTSERVER -Mode Alternate -Context $null
    Assert-Denied -Sections $all -Target OTHERSERVER -Mode Alternate -Context $context
    Assert-Denied -Sections @('System') -Target TESTSERVER -Mode Default -Context $context
    Assert-Denied -Sections @('System','INVALIDSECTION') -Target TESTSERVER -Mode Default -Context $null
    if ($attempts -ne 0) { throw 'Simulated remote collection executed after a blocked preflight.' }
    Write-Host 'PASS: Missing/mismatched Alternate, injected Default context, and invalid section all block before collection.'
} finally {
    Clear-ToolkitAuthContext -Context $context
    Remove-Variable context,credential,password -ErrorAction SilentlyContinue
}

# Validate real GUI/Classic entry-point references and Classic Alternate routing.
$gui = Get-Content -LiteralPath (Join-Path $root 'ITToolkit-GUI.ps1') -Raw
$classic = Get-Content -LiteralPath (Join-Path $root 'Modules\ITToolkit-ReportMenu.ps1') -Raw
if ($gui -notmatch 'Assert-ToolkitRemoteDiagnosticAuthorization -Sections' -or $classic -notmatch 'Assert-ToolkitRemoteDiagnosticAuthorization -Sections') {
    throw 'Shared remote preflight missing from GUI or Classic.'
}
if ($classic -notmatch 'Get-ClassicAlternateReportSection -Section') {
    throw 'Classic Alternate route is not using the credential-aware dispatcher.'
}
Write-Host 'PASS: GUI/Classic use shared remote preflight; Classic Alternate uses credential-aware dispatcher.'
Write-Host 'NOTE: No actual remote connections or GUI/Classic interactive sessions were tested.'
