# IT Toolkit

**Version 1.26** · Windows PowerShell 5.1 · Windows administration and diagnostics

The **Cochise County IT Toolkit** is a portable, PowerShell-based utility for IT technicians who troubleshoot and document Windows workstations and servers. It provides a graphical interface and a Classic console menu for remote diagnostics, access checks, reporting, and system inventory comparisons.

> **Platform support:** Version 1.26 is designed for **Windows**. Its graphical interface uses Windows Presentation Foundation (WPF), and several collectors use Windows-specific management APIs. **macOS and Linux are not supported by this release.** A cross-platform edition is a potential future project.

## Features

- **Two interfaces:** Windows GUI and numbered Classic PowerShell menus.
- **Remote access checks:** DNS resolution, ICMP reachability, WMI, WinRM, and `ADMIN$` accessibility.
- **Credential selection:** Run supported diagnostics with your current Windows identity or explicitly supplied alternate administrative credentials. Credentials are not intended to be stored in configuration files.
- **Windows diagnostics:** Collect information across system, storage, services, hardware, local accounts and groups, shares, software, updates, tasks, firewall, events, and related categories. Some checks require particular remote services or privileges.
- **Health-oriented reporting:** Review collected findings and access-check results; unavailable or unsuccessful checks are reported separately from successful results.
- **Exportable reports:** Save diagnostic output in HTML, CSV, or TXT, and browse previously saved reports.
- **Snapshots and comparisons:** Create structured JSON inventory snapshots from the GUI or Classic interface, then compare two captures to identify changes in services, installed software, updates, users, groups, administrators, and shares.
- **Tool integration:** Locate and launch supported external troubleshooting utilities, including optional Microsoft Sysinternals tools and PortQry when installed.

## Requirements

- **Windows 10/11 or supported Windows Server**, with **Windows PowerShell 5.1** and .NET/WPF support for the graphical interface.
- Network connectivity to the systems being checked.
- Appropriate authorization on each remote target. Individual diagnostics may require WMI/DCOM, WinRM, SMB, firewall rules, or elevated permissions.
- Optional: [Microsoft Sysinternals](https://learn.microsoft.com/en-us/sysinternals/) and [PortQry](https://www.microsoft.com/en-us/download/details.aspx?id=17148) for the related external-tool integrations. The toolkit can warn if an optional dependency is not found.

No agent is installed on remote target computers by the toolkit's launcher.

## Installation

1. Download the v1.26 release ZIP and extract its contents into a local folder, such as `C:\ITToolkit`.
2. Keep `Modules`, `Branding`, the `.ps1` files, and `Toolkit-config.json` together in their original relative paths.
3. Review `Toolkit-config.json` and update paths, reporting options, and the default authentication domain for your environment.
4. On Windows, run **`Launch.cmd`** to open the launcher and choose the GUI or Classic interface.

You can also start the Classic console directly:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "C:\ITToolkit\ITToolkit.ps1"
```

Or start the GUI in an STA Windows PowerShell session:

```powershell
powershell.exe -NoProfile -STA -ExecutionPolicy Bypass -File "C:\ITToolkit\ITToolkit-GUI.ps1"
```

The example commands use a process-only execution-policy override; follow your organization's script-execution and code-signing requirements rather than bypassing enforced policies.

## Basic workflow

1. Select or enter a Windows computer or server as the target.
2. Choose **Default** credentials, or explicitly provide **Alternate** credentials when needed.
3. Run access checks and the diagnostics relevant to the issue.
4. Save a report for documentation, or create a snapshot as a baseline.
5. After a change or later investigation, capture another snapshot and compare the two.

Snapshot comparisons are inventory differences, **not** a substitute for security auditing or a guarantee that a computer is healthy. Some services normally stop when idle, and some collectors can return partial results due to permissions or transport restrictions.

## Project layout

```text
ITToolKit/
├── Launch.cmd
├── ITToolkit-Launcher.ps1
├── ITToolkit-GUI.ps1
├── ITToolkit.ps1
├── Toolkit-config.json
├── Branding/
├── Modules/
└── Reports/            # Generated report output; do not commit reports
```

The release distribution may omit development test scripts. They are not required for routine use.

## Security and responsible use

This toolkit is intended for **authorized administration only**. Remote checks can reveal sensitive host, account, share, software, and network information.

- Run it only against systems you are authorized to administer.
- Treat generated reports and snapshots as potentially sensitive operational data.
- Never commit passwords, credential files, private keys, or report archives to GitHub.
- The `ADMIN$` check uses SMB; existing sessions and credential conflicts can affect its result. Avoid disrupting pre-existing SMB connections.
- Review the repository contents and branding before publishing. The included configuration contains **Cochise County-specific defaults** and should be adapted for other environments.

### Recommended `.gitignore`

If you publish the source, consider excluding generated files and local settings:

```gitignore
Reports/*
!Reports/.gitkeep
*.snapshot.json
*.html
*.csv
*.log
*.tmp
*.bak
.DS_Store
```

Review these patterns for your own repository before adopting them; excluding all HTML or CSV files may be too broad if you later add documentation samples.

## Current limitations

- Windows PowerShell 5.1 and WPF are Windows-specific; this is **not** a native MacBook application.
- Remote feature availability depends on permissions, operating-system capabilities, protocol configuration, and firewall settings.
- An access check succeeding does not guarantee that every diagnostic collector will succeed.
- Snapshot collection and comparison are designed for the supported inventory categories; they do not represent a complete forensic record.

## Version history

### v1.26

- Expanded Default and Alternate credential support across diagnostic workflows.
- Integrated credential-aware access checking for WMI, WinRM, and `ADMIN$`.
- Improved GUI and Classic reporting and result-status presentation.
- Added GUI and Classic snapshot creation with structured JSON comparisons.

## License and attribution

**No license is specified in this README.** Before making the repository public, select an appropriate license and confirm you have permission to publish the source code, organization name, logos, and other included assets. Without a license, others generally do not receive permission to reuse or redistribute the code.

---

*Developed for Cochise County IT workflows. This README documents the v1.26 Windows release.*
