# IT Toolkit v1.26 - GUI structured snapshot collector. Read only.
# SchemaVersion 1 matches the existing snapshot-comparison engine.
function Get-ToolkitGUISnapshot {
    param([Parameter(Mandatory=$true)][string]$Target,
          [Parameter(Mandatory=$true)][ValidateSet('Default','Alternate')][string]$Mode,
          [System.Management.Automation.PSCredential]$Credential,
          [string]$ToolkitVersion='1.26')
    if ($Mode -eq 'Alternate' -and $null -eq $Credential) { throw 'Alternate snapshot collection requires explicit credentials.' }
    $categories = [ordered]@{}
    $errors = [ordered]@{}
    $sections = @('Services','Software','Updates','Users','Groups','Administrators','Shares')
    $wmiArgs = @{ ComputerName=$Target; ErrorAction='Stop' }
    if ($Mode -eq 'Alternate') { $wmiArgs.Credential = $Credential }
    function Read-WmiSnapshotClass([string]$name,[string]$filter='') {
        $args = $wmiArgs.Clone(); $args.Class = $name
        if ($filter) { $args.Filter=$filter }
        @(Get-WmiObject @args)
    }
    function Get-SnapshotAccountName([string]$reference) {
        # WMI reference uses Domain="...",Name="..." with escaped quotes/backslashes.
        $domain = ''; $name = ''
        if ($reference -match 'Domain="((?:\\.|[^"])*)"') { $domain = $Matches[1] -replace '\\\\','\' }
        if ($reference -match 'Name="((?:\\.|[^"])*)"') { $name = $Matches[1] -replace '\\\\','\' }
        if ($domain -or $name) { return "$domain\$name" }
        return $reference
    }
    foreach ($section in $sections) {
        try {
            $entries = @()
            switch ($section) {
                'Services' {
                    $entries = @(Read-WmiSnapshotClass 'Win32_Service' | ForEach-Object {
                        [pscustomobject]@{ Key=[string]$_.Name; DisplayName=[string]$_.DisplayName; State=[string]$_.State; StartMode=[string]$_.StartMode; StartName=[string]$_.StartName }
                    })
                }
                'Updates' {
                    $entries = @(Read-WmiSnapshotClass 'Win32_QuickFixEngineering' | ForEach-Object {
                        [pscustomobject]@{ Key=[string]$_.HotFixID; Description=[string]$_.Description; InstalledOn=[string]$_.InstalledOn }
                    })
                }
                'Users' {
                    $entries = @(Read-WmiSnapshotClass 'Win32_UserAccount' 'LocalAccount=True' | ForEach-Object {
                        [pscustomobject]@{ Key=[string]$_.SID; Name=[string]$_.Name; Disabled=[string]$_.Disabled; Lockout=[string]$_.Lockout }
                    })
                }
                'Groups' {
                    $entries = @(Read-WmiSnapshotClass 'Win32_GroupUser' | ForEach-Object {
                        $group = Get-SnapshotAccountName ([string]$_.GroupComponent)
                        $member = Get-SnapshotAccountName ([string]$_.PartComponent)
                        [pscustomobject]@{ Key="$group -> $member"; Group=$group; Member=$member }
                    })
                }
                'Administrators' {
                    $admins = @(Read-WmiSnapshotClass 'Win32_Group' 'LocalAccount=True' | Where-Object { $_.SID -eq 'S-1-5-32-544' })
                    if ($admins.Count -eq 0) { throw 'Local Administrators group was not returned.' }
                    $groupName = "$($admins[0].Domain)\$($admins[0].Name)"
                    $entries = @(Read-WmiSnapshotClass 'Win32_GroupUser' | ForEach-Object {
                        if ((Get-SnapshotAccountName ([string]$_.GroupComponent)) -ieq $groupName) {
                            $member = Get-SnapshotAccountName ([string]$_.PartComponent)
                            [pscustomobject]@{ Key=$member; Member=$member }
                        }
                    })
                }
                'Shares' {
                    $entries = @(Read-WmiSnapshotClass 'Win32_Share' | ForEach-Object {
                        [pscustomobject]@{ Key=[string]$_.Name; Path=[string]$_.Path; Description=[string]$_.Description; Type=[string]$_.Type }
                    })
                }
                'Software' {
                    # Use WMI StdRegProv through an explicitly authenticated DCOM scope.
                    $options = New-Object System.Management.ConnectionOptions
                    if ($Mode -eq 'Alternate') {
                        $user = $Credential.UserName
                        $options.Username = $user
                        $options.SecurePassword = $Credential.Password
                    }
                    $scope = New-Object System.Management.ManagementScope("\\$Target\root\default",$options)
                    $scope.Connect()
                    $regPath = New-Object System.Management.ManagementPath('StdRegProv')
                    $reg = New-Object System.Management.ManagementClass($scope,$regPath,$null)
                    $hklm = [uint32]2147483650
                    $software = New-Object System.Collections.Generic.List[object]
                    foreach ($base in @('SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall','SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall')) {
                        $keyArgs = $reg.GetMethodParameters('EnumKey'); $keyArgs['hDefKey']=$hklm; $keyArgs['sSubKeyName']=$base
                        $response = $reg.InvokeMethod('EnumKey',$keyArgs,$null)
                        if ([uint32]$response['ReturnValue'] -ne 0) { throw "Cannot enumerate $base (registry error $($response['ReturnValue']))." }
                        foreach ($sub in @($response['sNames'])) {
                            if ([string]::IsNullOrWhiteSpace([string]$sub)) { continue }
                            $key="$base\$sub"
                            $values = @{}
                            foreach ($field in @('DisplayName','DisplayVersion','Publisher')) {
                                $valueArgs=$reg.GetMethodParameters('GetStringValue'); $valueArgs['hDefKey']=$hklm; $valueArgs['sSubKeyName']=$key; $valueArgs['sValueName']=$field
                                $out=$reg.InvokeMethod('GetStringValue',$valueArgs,$null)
                                $values[$field]=if ([uint32]$out['ReturnValue'] -eq 0) { [string]$out['sValue'] } else { '' }
                            }
                            if (-not $values['DisplayName']) { continue }
                            $software.Add([pscustomobject]@{ Key=$key; Name=$values['DisplayName']; Version=$values['DisplayVersion']; Publisher=$values['Publisher'] })
                        }
                    }
                    $entries=@($software.ToArray())
                }
            }
            $categories[$section] = @($entries)
        } catch {
            $errors[$section] = $_.Exception.Message
        }
    }
    $diagnosticIdentity = if ($Mode -eq 'Alternate') { $Credential.UserName } else { [Security.Principal.WindowsIdentity]::GetCurrent().Name }
    return [pscustomobject]@{
        SchemaVersion=1
        ToolkitVersion=$ToolkitVersion
        Target=$Target
        CapturedAt=(Get-Date).ToString('o')
        Technician=[Security.Principal.WindowsIdentity]::GetCurrent().Name
        AuthenticationMode=$Mode
        DiagnosticIdentity=$diagnosticIdentity
        Categories=[pscustomobject]$categories
        Errors=[pscustomobject]$errors
    }
}
