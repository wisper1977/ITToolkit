# Shared built-in Tools catalog for both GUI and Classic interfaces.
# The definitions and publisher URLs below are the single source of truth.
# No user settings or executable paths are persisted by this module.
function Get-ToolkitBuiltInTools {
return @(
    [pscustomobject]@{Id='powershell'; Name='Windows PowerShell'; Group='Windows'; Description='Open a Windows PowerShell console.'; Exe='powershell.exe'; Args='-NoLogo'},
    [pscustomobject]@{Id='powershell-admin'; Name='Windows PowerShell (Administrator)'; Group='Windows'; Description='Open an elevated Windows PowerShell 5.1 console through Windows UAC; the toolkit remains under its original identity.'; Exe='powershell.exe'; Args='-NoLogo'},
    [pscustomobject]@{Id='eventvwr'; Name='Event Viewer'; Group='Windows'; Description='Review local Windows event logs.'; Exe='eventvwr.msc'; Args=''},
    [pscustomobject]@{Id='services'; Name='Services'; Group='Windows'; Description='Open the Services management console.'; Exe='services.msc'; Args=''},
    [pscustomobject]@{Id='compmgmt'; Name='Computer Management'; Group='Windows'; Description='Open Computer Management.'; Exe='compmgmt.msc'; Args=''},
    [pscustomobject]@{Id='devmgmt'; Name='Device Manager'; Group='Windows'; Description='Review device hardware and drivers.'; Exe='devmgmt.msc'; Args=''},
    [pscustomobject]@{Id='gpedit'; Name='Local Group Policy'; Group='Windows'; Description='Edit local group policy where supported.'; Exe='gpedit.msc'; Args=''},
    [pscustomobject]@{Id='taskschd'; Name='Task Scheduler'; Group='Windows'; Description='View local scheduled tasks.'; Exe='taskschd.msc'; Args=''},
    [pscustomobject]@{Id='mstsc'; Name='Remote Desktop'; Group='Network'; Description='Connect to a remote Windows computer.'; Exe='mstsc.exe'; Args=''},
    [pscustomobject]@{Id='wireshark'; Name='Wireshark'; Group='Optional'; Description='Open Wireshark if installed.'; Exe='Wireshark.exe'; Args=''},
    [pscustomobject]@{Id='adexplorer'; Name='AD Explorer'; Group='Optional'; Description='Open Sysinternals Active Directory Explorer.'; Exe='ADExplorer.exe'; Args=''},
    [pscustomobject]@{Id='procmon'; Name='Process Monitor'; Group='Optional'; Description='Open Sysinternals Process Monitor.'; Exe='Procmon.exe'; Args=''},
    [pscustomobject]@{Id='putty'; Name='PuTTY'; Group='Optional'; Description='Open PuTTY terminal client.'; Exe='putty.exe'; Args=''},
    [pscustomobject]@{Id='cmd'; Name='Command Prompt'; Group='Windows'; Description='Open a Windows command prompt.'; Exe='cmd.exe'; Args=''},
    [pscustomobject]@{Id='regedit'; Name='Registry Editor'; Group='Windows'; Description='Open the Windows Registry Editor.'; Exe='regedit.exe'; Args=''},
    [pscustomobject]@{Id='resmon'; Name='Resource Monitor'; Group='Windows'; Description='Inspect CPU, memory, disk, and network activity.'; Exe='resmon.exe'; Args=''},
    [pscustomobject]@{Id='perfmon'; Name='Performance Monitor'; Group='Windows'; Description='Inspect Windows performance counters.'; Exe='perfmon.msc'; Args=''},
    [pscustomobject]@{Id='dsa'; Name='Active Directory Users and Computers'; Group='Directory'; Description='Manage Active Directory user and computer objects (RSAT required).'; Exe='dsa.msc'; Args=''},
    [pscustomobject]@{Id='dns'; Name='DNS Manager'; Group='Directory'; Description='Manage Windows DNS servers (RSAT required).'; Exe='dnsmgmt.msc'; Args=''},
    [pscustomobject]@{Id='gpmc'; Name='Group Policy Management'; Group='Directory'; Description='Manage domain Group Policy (RSAT required).'; Exe='gpmc.msc'; Args=''},
    [pscustomobject]@{Id='psexec'; Name='PsExec'; Group='Optional'; Description='Sysinternals remote-process utility; opens Command Prompt for manual use.'; Exe='PsExec.exe'; Args='-?'},
    [pscustomobject]@{Id='tcpview'; Name='TCPView'; Group='Optional'; Description='View live TCP and UDP endpoints (Sysinternals).'; Exe='tcpview.exe'; Args=''},
    [pscustomobject]@{Id='portqry'; Name='PortQry'; Group='Network'; Description='Microsoft command-line TCP/UDP port connectivity troubleshooting utility. Path set in Toolkit Settings.'; Exe='portqry.exe'; Args='-?'}
)
}

function Get-ToolkitToolDownloadUrls {
return @{
    wireshark = 'https://www.wireshark.org/download.html'
    putty = 'https://www.chiark.greenend.org.uk/~sgtatham/putty/latest.html'
    adexplorer = 'https://learn.microsoft.com/en-us/sysinternals/downloads/adexplorer'
    procmon = 'https://learn.microsoft.com/en-us/sysinternals/downloads/procmon'
    psexec = 'https://learn.microsoft.com/en-us/sysinternals/downloads/psexec'
    tcpview = 'https://learn.microsoft.com/en-us/sysinternals/downloads/tcpview'
    portqry = 'https://www.microsoft.com/en-us/download/details.aspx?id=17148'
    dsa = 'https://www.microsoft.com/en-us/download/details.aspx?id=45520'
    dns = 'https://www.microsoft.com/en-us/download/details.aspx?id=45520'
    gpmc = 'https://www.microsoft.com/en-us/download/details.aspx?id=45520'
}
}
