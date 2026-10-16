# Read-only identity verification test; no remote connection or credential secrets.
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$files = @('Modules\ITToolkit-Authentication.ps1','Modules\ITToolkit-ReportMenu.ps1','ITToolkit-GUI.ps1')
foreach ($relative in $files) {
    $tokens = $null; $problems = $null
    $null = [System.Management.Automation.Language.Parser]::ParseFile((Join-Path $root $relative),[ref]$tokens,[ref]$problems)
    if (@($problems).Count -gt 0) { throw ('Parse failure in ' + $relative + ': ' + ($problems -join '; ')) }
}
Write-Host 'PASS: GUI, Classic and authentication modules parse on Windows PowerShell 5.1.'
. (Join-Path $root 'Modules\ITToolkit-Authentication.ps1')
$password = ConvertTo-SecureString 'DUMMY-TEST-ONLY' -AsPlainText -Force
$credential = New-Object System.Management.Automation.PSCredential('EXAMPLE\Admin',$password)
$ctx = New-ToolkitAuthContext -ComputerName 'EXAMPLEHOST' -Mode Alternate -Credential $credential
function script:Invoke-Command {
    param($ComputerName,$ScriptBlock,$Credential,$Authentication,$SessionOption,$ErrorAction)
    if ($ComputerName -ne 'EXAMPLEHOST' -or $Credential.UserName -ne 'EXAMPLE\Admin' -or $Authentication -ne 'Negotiate') { throw 'Credential not forwarded correctly.' }
    switch ($script:MockIdentityMode) {
        'match' { return 'EXAMPLE\Admin' }
        'mismatch' { return 'EXAMPLE\Other' }
        'failure' { throw 'Test remote connection failure' }
    }
}
$script:MockIdentityMode = 'match'
$a = Test-ToolkitRemoteExecutionIdentity -Context $ctx
if ($a.Verification -ne 'VERIFIED' -or $a.ActualIdentity -ne 'EXAMPLE\Admin') { throw 'Matching identity not verified.' }
$script:MockIdentityMode = 'mismatch'
$b = Test-ToolkitRemoteExecutionIdentity -Context $ctx
if ($b.Verification -ne 'MISMATCH') { throw 'Mismatched identity wrongly trusted.' }
$script:MockIdentityMode = 'failure'
$c = Test-ToolkitRemoteExecutionIdentity -Context $ctx
if ($c.Verification -ne 'NOT VERIFIED' -or $c.ActualIdentity -ne 'Not verified') { throw 'Unavailable identity wrongly trusted.' }
$gui = Get-Content -LiteralPath (Join-Path $root 'ITToolkit-GUI.ps1') -Raw
$classic = Get-Content -LiteralPath (Join-Path $root 'Modules\ITToolkit-ReportMenu.ps1') -Raw
if (-not $gui.Contains('Format-ToolkitRemoteExecutionIdentity -Result $identityEvidence')) { throw 'GUI identity evidence integration missing.' }
if (-not $classic.Contains('Format-ToolkitRemoteExecutionIdentity -Result $remoteIdentityEvidence')) { throw 'Classic identity evidence integration missing.' }
Write-Host 'PASS: Explicit credentials are forwarded and matching identity is VERIFIED.'
Write-Host 'PASS: Mismatched identity is marked MISMATCH.'
Write-Host 'PASS: Failed identity probe is marked NOT VERIFIED.'
Write-Host 'PASS: Both GUI and Classic embed remote identity evidence.'
Write-Host 'NOTE: Run a live county domain Alternate report to validate actual remote identity.'
