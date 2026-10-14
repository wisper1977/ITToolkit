# IT Toolkit v1.26 - Phase 1: isolated remote authentication foundation.
# Windows PowerShell 5.1. Dot-source this file; no changes to existing toolkit state.
# Does NOT create SMB sessions, save credentials, or alter remote computers.

function New-ToolkitAuthContext {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][ValidateNotNullOrEmpty()][string]$ComputerName,
        [ValidateSet('Default','Alternate')][string]$Mode = 'Default',
        [System.Management.Automation.PSCredential]$Credential
    )
    $computer = $ComputerName.Trim()
    if ($computer -notmatch '^[a-zA-Z0-9_.-]+$' -or $computer.Length -gt 253) {
        throw 'Target must be a valid hostname or IPv4 address (letters, numbers, dots, hyphens, underscores).'
    }
    if ($Mode -eq 'Alternate' -and $null -eq $Credential) {
        throw 'Alternate mode requires a PSCredential. Use Get-Credential to prompt securely.'
    }
    if ($Mode -eq 'Default' -and $null -ne $Credential) {
        throw 'Do not supply a credential in Default mode. Choose Alternate instead.'
    }
    $identity = if ($Mode -eq 'Alternate') { $Credential.UserName } else { [Security.Principal.WindowsIdentity]::GetCurrent().Name }
    # Credentials are available in memory only. Never pipe this object to JSON, reports or logs.
    [pscustomobject]@{
        PSTypeName = 'ITToolkit.AuthenticationContext'
        ComputerName = $computer
        Mode = $Mode
        UserName = $identity
        Credential = $Credential
        CreatedAt = Get-Date
    }
}

function Test-ToolkitAuthContext {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][ValidateNotNull()]$Context,
        [ValidateSet('All','DNS','WMI','WinRM')][string]$Method = 'All'
    )
    if ($Context.PSTypeNames -notcontains 'ITToolkit.AuthenticationContext') {
        throw 'Context must be created by New-ToolkitAuthContext.'
    }
    $computer = [string]$Context.ComputerName
    $alternate = ($Context.Mode -eq 'Alternate')
    $results = New-Object 'System.Collections.Generic.List[object]'
    $methods = if ($Method -eq 'All') { @('DNS','WMI','WinRM') } else { @($Method) }
    foreach ($item in $methods) {
        $state = 'Failed'
        $detail = ''
        try {
            switch ($item) {
                'DNS' {
                    $addresses = @([Net.Dns]::GetHostAddresses($computer) | Where-Object { $_.AddressFamily -eq [Net.Sockets.AddressFamily]::InterNetwork } | ForEach-Object { $_.ToString() })
                    if ($addresses.Count -eq 0) { throw 'No IPv4 addresses resolved.' }
                    $state = 'Passed'
                    $detail = ($addresses -join ', ') + ' (DNS does not validate credentials)'
                }
                'WMI' {
                    $arguments = @{ Class='Win32_OperatingSystem'; ComputerName=$computer; ErrorAction='Stop' }
                    if ($alternate) { $arguments.Credential = $Context.Credential }
                    $os = Get-WmiObject @arguments | Select-Object -First 1
                    if ($null -eq $os) { throw 'WMI returned no operating system data.' }
                    $state = 'Passed'
                    $detail = 'WMI/DCOM query succeeded using ' + $Context.Mode + ' identity.'
                }
                'WinRM' {
                    $arguments = @{ ComputerName=$computer; ErrorAction='Stop' }
                    if ($alternate) {
                        $arguments.Authentication = 'Negotiate'
                        $arguments.Credential = $Context.Credential
                    }
                    $null = Test-WSMan @arguments
                    $state = 'Passed'
                    $detail = if ($alternate) {
                        'WSMan authentication probe succeeded with supplied credentials; does not establish remote command authorization.'
                    } else {
                        'WSMan service responded; default-mode probe does not prove command authorization.'
                    }
                }
            }
        } catch {
            $detail = $_.Exception.Message
            # Never include credentials in result fields, even for unexpected provider errors.
        }
        $results.Add([pscustomobject]@{
            ComputerName = $computer
            Mode = [string]$Context.Mode
            UserName = [string]$Context.UserName
            Method = $item
            Status = $state
            Detail = $detail
            CheckedAt = Get-Date
        })
    }
    return $results.ToArray()
}

function Clear-ToolkitAuthContext {
    [CmdletBinding()]
    param([Parameter(Mandatory=$true)][ValidateNotNull()]$Context)
    if ($Context.PSTypeNames -notcontains 'ITToolkit.AuthenticationContext') {
        throw 'Context must be created by New-ToolkitAuthContext.'
    }
    # Drop this reference. Caller must also clear its own variable and any other copies.
    $Context.Credential = $null
    $Context.Mode = 'Default'
    $Context.UserName = ''
}

# Phase 2: normalize a bare username using the configured domain.
# For local accounts, always supply COMPUTER\username explicitly.
function Resolve-ToolkitAuthUserName {
    [CmdletBinding()]
    param([Parameter(Mandatory=$true)][string]$UserName,[string]$DefaultDomain='')
    $name = $UserName.Trim()
    if (-not $name) { throw 'Enter a username.' }
    if ($name.Contains('\') -or $name.Contains('@')) { return $name }
    if (-not [string]::IsNullOrWhiteSpace($DefaultDomain)) { return ($DefaultDomain.Trim() + '\' + $name) }
    throw 'Enter DOMAIN\username, COMPUTER\username or username@domain.'
}

# Read-only probe. A passing WinRM transport probe is not remote command authorization.
function Get-ToolkitAuthProbeSummary {
    [CmdletBinding()]
    param([Parameter(Mandatory=$true)]$Context)
    return @(Test-ToolkitAuthContext -Context $Context -Method All)
}
