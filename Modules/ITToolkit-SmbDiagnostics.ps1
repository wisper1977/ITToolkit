# IT Toolkit v1.26 - Phase 3C: isolated SMB ADMIN$ authentication test.
# Windows PowerShell 5.1. Does not alter existing toolkit diagnostic code.
# WNetAddConnection2 creates or reuses a deviceless SMB connection.
# Best-effort detection of existing connections is available without elevation.
# The test never disconnects any session automatically (ownership may be ambiguous).

if (-not ('ITToolkitSmb.Native' -as [type])) {
    Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
namespace ITToolkitSmb {
  [StructLayout(LayoutKind.Sequential, CharSet=CharSet.Unicode)]
  public struct NetResource {
    public int Scope;
    public int Type;
    public int DisplayType;
    public int Usage;
    [MarshalAs(UnmanagedType.LPWStr)] public string LocalName;
    [MarshalAs(UnmanagedType.LPWStr)] public string RemoteName;
    [MarshalAs(UnmanagedType.LPWStr)] public string Comment;
    [MarshalAs(UnmanagedType.LPWStr)] public string Provider;
  }
  public static class Native {
    [DllImport("mpr.dll", CharSet=CharSet.Unicode, EntryPoint="WNetAddConnection2W")]
    public static extern int Add(ref NetResource resource, string password, string user, int flags);
    [DllImport("mpr.dll", CharSet=CharSet.Unicode, EntryPoint="WNetCancelConnection2W")]
    public static extern int Cancel(string remoteName, int flags, bool force);
  }
}
'@ -ErrorAction Stop
}

function Get-ToolkitSmbAliases {
    param([Parameter(Mandatory=$true)][string]$ComputerName)
    $aliases = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)
    [void]$aliases.Add($ComputerName.Trim().TrimEnd('.'))
    if ($ComputerName.Contains('.')) { [void]$aliases.Add($ComputerName.Split('.')[0]) }
    try {
        $entry = [Net.Dns]::GetHostEntry($ComputerName)
        [void]$aliases.Add($entry.HostName.TrimEnd('.'))
        if ($entry.HostName.Contains('.')) { [void]$aliases.Add($entry.HostName.Split('.')[0]) }
        foreach ($ip in $entry.AddressList) { [void]$aliases.Add($ip.ToString()) }
    } catch { } # DNS failure is handled by the connection test.
    return ,$aliases
}

function Test-ToolkitAdminShare {
    [CmdletBinding()]
    param([Parameter(Mandatory=$true)][ValidateNotNull()]$Context)
    if ($Context.PSTypeNames -notcontains 'ITToolkit.AuthenticationContext') { throw 'Expected a New-ToolkitAuthContext value.' }
    $computer = [string]$Context.ComputerName
    $remote = '\\' + $computer + '\ADMIN$'
    $identity = [string]$Context.UserName
    $result = [ordered]@{ ComputerName=$computer; Mode=[string]$Context.Mode; UserName=$identity; Status='Failed'; Detail=''; Cleanup='Not needed'; CheckedAt=Get-Date }
    $created = $false
    $unc = $remote
    try {
        if ($Context.Mode -eq 'Default') {
            # No new explicit connection: access using current Windows identity.
            $null = Get-Item -LiteralPath $unc -ErrorAction Stop
            $result.Status = 'Passed'
            $result.Detail = 'ADMIN$ accessible using current Windows identity.'
        } elseif ($Context.Mode -eq 'Alternate') {
            if ($null -eq $Context.Credential) { throw 'Alternate credentials are required.' }
            $aliases = Get-ToolkitSmbAliases -ComputerName $computer
            # Get-SmbConnection requires elevated privileges on some Windows builds.
            # Use user-accessible mapping inventory as a best-effort conflict check.
            # This is not exhaustive; Windows error 1219 remains authoritative for conflicts.
            $known = New-Object 'System.Collections.Generic.List[string]'
            try {
                if (Get-Command Get-SmbMapping -ErrorAction SilentlyContinue) {
                    foreach ($mapping in @(Get-SmbMapping -ErrorAction Stop)) {
                        $path = [string]$mapping.RemotePath
                        $matched = [regex]::Match($path, '^\\\\([^\\]+)\\')
                        if ($matched.Success -and $aliases.Contains($matched.Groups[1].Value.TrimEnd('.'))) {
                            $known.Add($path)
                        }
                    }
                }
            } catch {
                # Mapping inventory failure is advisory. Never pretend it proves no connections.
                $result.Detail = 'Mapping inventory unavailable: ' + $_.Exception.Message
            }
            try {
                # net use is read-only here and usually works without elevation.
                $netOutput = @(& net.exe use 2>&1)
                foreach ($line in $netOutput) {
                    $lineText = [string]$line
                    foreach ($alias in $aliases) {
                        if ($lineText.IndexOf('\\' + $alias + '\', [StringComparison]::OrdinalIgnoreCase) -ge 0) {
                            $known.Add($lineText.Trim())
                            break
                        }
                    }
                }
            } catch { } # Never run net use with username/password or delete parameters.
            if ($known.Count -gt 0) {
                $result.Status='Skipped'
                $result.Detail='Existing SMB mapping or session reference to this target is visible. No new connection attempted or disconnected.'
            } else {
                # Non-elevated users can make this deviceless WNet connection.
                # The preflight is best-effort, not proof of exclusive ownership.
                # No existing session is intentionally disconnected, and 1219 is reported.
                        $resource = New-Object ITToolkitSmb.NetResource
                        $resource.Type = 1 # RESOURCETYPE_DISK
                        $resource.RemoteName = $unc
                        $ptr = [IntPtr]::Zero
                        $password = $null
                        try {
                            $ptr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($Context.Credential.Password)
                            $password = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($ptr)
                            # No password appears in a command line, file, or PowerShell transcript output.
                            $code = [ITToolkitSmb.Native]::Add([ref]$resource, $password, $Context.Credential.UserName, 4) # CONNECT_TEMPORARY
                        } finally {
                            $password = $null
                            if ($ptr -ne [IntPtr]::Zero) { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($ptr) }
                        }
                        if ($code -eq 0) {
                            $created = $true # Success does not conclusively prove the connection was newly created.
                            $null = Get-Item -LiteralPath $unc -ErrorAction Stop
                            $result.Status='Passed'
                            $result.Detail='ADMIN$ accessible with explicitly supplied alternate credentials.'
                        } elseif ($code -eq 1219) {
                            $result.Status='Conflict'
                            $result.Detail='Windows error 1219: a conflicting SMB credential/session exists. No sessions changed.'
                        } elseif ($code -eq 5 -or $code -eq 1326 -or $code -eq 86) {
                            $result.Status='Denied'
                            $result.Detail=('SMB authentication or access denied (Windows error {0}).' -f $code)
                        } else {
                            $result.Status='Failed'
                            $result.Detail=('SMB connection failed (Windows error {0}: {1}).' -f $code, ([ComponentModel.Win32Exception]::new($code).Message))
                        }
                    }
        } else { throw ('Unsupported mode: ' + $Context.Mode) }
    } catch {
        $result.Status = if ($_.Exception -is [System.UnauthorizedAccessException] -or $_.Exception.Message -match '(?i)access (is )?denied|unauthorized|0x80070005') { 'Denied' } else { 'Failed' }
        $result.Detail=$_.Exception.Message
    } finally {
        if ($created) {
            # A successful WNetAddConnection2 may reuse an unlisted existing connection.
            # Never automatically cancel an ambiguous shared SMB session.
            $result.Cleanup = 'Not automatically disconnected: SMB connection ownership cannot be proven. Review this account''s SMB connections before manually disconnecting, if appropriate.' 
        }
    }
    [pscustomobject]$result
}
