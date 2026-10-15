# IT Toolkit v1.27C - repeatable direct-local collector smoke test.
# Windows PowerShell 5.1. Read-only; no WinRM, elevation or credentials supplied.
# Change the default Section when the next collector is ready to test.
[CmdletBinding()]
param(
    [string]$Section = 'Network'
)

$ErrorActionPreference = 'Stop'
$modulePath = Join-Path $PSScriptRoot 'Modules\ITToolkit-LocalDiagnostics.ps1'

try {
    if (-not (Test-Path -LiteralPath $modulePath -PathType Leaf)) {
        throw "Local diagnostics module not found: $modulePath"
    }

    # Force the current checked-out function to replace any stale session copy.
    . $modulePath
    $command = Get-Command Get-ToolkitLocalDiagnostic -CommandType Function -ErrorAction Stop
    $set = @($command.Parameters['Section'].Attributes |
        Where-Object { $_ -is [System.Management.Automation.ValidateSetAttribute] })
    if ($set.Count -eq 0) {
        throw 'The loaded diagnostic function has no Section ValidateSet.'
    }
    $supported = @($set[0].ValidValues)
    if ($Section -notin $supported) {
        throw "Section '$Section' is not supported by the checked-out collector. Available: $($supported -join ', ')"
    }

    Write-Host ''
    Write-Host "IT Toolkit - Direct Local Diagnostic Test" -ForegroundColor Cyan
    Write-Host "Computer : $env:COMPUTERNAME"
    Write-Host "Section  : $Section"
    Write-Host "Module   : $modulePath"
    Write-Host "Identity : $([Security.Principal.WindowsIdentity]::GetCurrent().Name)"
    Write-Host ''

    # A fresh scoped variable prevents old results from being displayed after failures.
    $testResult = Get-ToolkitLocalDiagnostic -Section $Section
    if ($null -eq $testResult -or [string]$testResult.Section -ne $Section -or
        [string]$testResult.Mode -ne 'Local') {
        throw 'Collector returned an empty or mismatched local diagnostic result.'
    }

    $testResult | Select-Object Target,Mode,Section,Status,StatusCategory,Error |
        Format-List | Out-Host
    $records = @($testResult.Data | Where-Object { $null -ne $_ })
    Write-Host "Records returned: $($records.Count)" -ForegroundColor Cyan
    if ($records.Count -gt 0) {
        if ($Section -eq 'Storage') {
            $records | Select-Object DeviceID,VolumeName,SizeGB,FreeGB,FreePercent |
                Format-Table -AutoSize | Out-Host
        } else {
            # Different record types can have different property sets (e.g. Services).
            foreach ($record in $records) {
                $record | Format-List * | Out-Host
            }
        }
    } else {
        Write-Host 'No records returned. Check the status/category above.'
    }

    if ([string]$testResult.Status -ne 'SUCCESS' -or
        [string]$testResult.StatusCategory -ne 'Success') {
        Write-Warning "Collection did not report SUCCESS. Status: $($testResult.Status). Error: $($testResult.Error)"
        exit 1
    }
    Write-Host 'COLLECTOR TEST PASSED: query returned SUCCESS (not a system-health verdict).' -ForegroundColor Green
    exit 0
} catch {
    Write-Host "COLLECTOR TEST FAILED: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
