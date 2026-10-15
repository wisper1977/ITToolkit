# IT Toolkit

**Development version 1.27 (v1.27A completed)** · Windows PowerShell 5.1 · Windows administration and diagnostics

> **Release status:** `develop/v1.27` is the active development branch. **v1.26 on `main` remains the stable production release.** The v1.27 GUI refinements have been tested on Windows; later v1.27 milestones are still planned and are not included yet.

The **IT Toolkit** is a portable, PowerShell-based utility for IT technicians who troubleshoot and document Windows workstations and servers. It provides a graphical interface and a Classic console menu for remote diagnostics, access checks, reporting, and system inventory comparisons.

> **Platform support:** The current toolkit is designed for **Windows**. Its graphical interface uses Windows Presentation Foundation (WPF), and several collectors use Windows-specific management APIs. **macOS and Linux are not supported by this release.** A cross-platform edition is a potential future project.

## Features

- **Two interfaces:** Windows GUI and numbered Classic PowerShell menus.
- **v1.27A GUI refinements (development branch):** Multiline labels on Tools and Dashboard favorite buttons; improved display of long target names, recent reports, and footer text in narrower windows.
- **v1.27A window preferences (development branch; Windows-tested):** Remembers main GUI size, position, maximized state, and last open page per technician. Off-screen or invalid saved layouts fall back to default placement; previously selected targets are not automatically reconnected.
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


## Screenshots

### Graphical Dashboard

The IT Toolkit provides a graphical dashboard for remote system diagnostics, administrative access checks, reporting, and favorite utilities.

![IT Toolkit Dashboard](Screenshots/Dashboard.png)

## Installation

1. For the stable release, download the **v1.26 release ZIP** from [GitHub Releases](https://github.com/wisper1977/ITToolkit/releases/tag/v1.26). For the in-progress v1.27 build, switch to [`develop/v1.27`](https://github.com/wisper1977/ITToolkit/tree/develop/v1.27) and clone or download that branch. Extract into a local folder, such as `C:\ITToolkit`.
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
└── Reports/
```

The release distribution may omit development test scripts. They are not required for routine use.

## Security and responsible use

This toolkit is intended for **authorized administration only**. Remote checks can reveal sensitive host, account, share, software, and network information.

- Run it only against systems you are authorized to administer.
- Treat generated reports and snapshots as potentially sensitive operational data.
- Never commit passwords, credential files, private keys, or report archives to GitHub.
- The `ADMIN$` check uses SMB; existing sessions and credential conflicts can affect its result. Avoid disrupting pre-existing SMB connections.
- Review the repository contents and branding before publishing. The included configuration contains **Cochise County-specific defaults** and should be adapted for other environments.

## Current limitations

- Windows PowerShell 5.1 and WPF are Windows-specific; this is **not** a native MacBook application.
- Remote feature availability depends on permissions, operating-system capabilities, protocol configuration, and firewall settings.
- An access check succeeding does not guarantee that every diagnostic collector will succeed.
- Snapshot collection and comparison are designed for the supported inventory categories; they do not represent a complete forensic record.

## Version history

### v1.27 (in development)

**v1.27A — GUI refinement (completed and Windows-tested)**

- Updated the Tools page and Dashboard Favorite Shortcuts to display long tool names on multiple lines with centered labels.
- Improved layout handling for long target computer names and recent target entries.
- Adjusted recent report filename display while retaining full paths in tooltips.
- Improved footer handling of technician and computer names when space is limited.
- Updated `Toolkit-config.json` to version `1.27` on the development branch.

**v1.27A follow-up — Window state persistence (implemented; Windows-tested)**

- Saves the main GUI's normal restore bounds, maximized state, and last opened page in the existing per-user `GUISettings.json` preferences.
- Checks saved dimensions and monitor visibility before restoring; malformed or off-screen values use defaults.
- Restores page navigation only, without automatically selecting or reconnecting to previous targets. The launcher remains independent.
- **Validated on Windows:** Restored moved/resized and maximized windows, last-page navigation, Favorites and Recent Targets preservation, and startup without automatically selecting a target. Disconnected-monitor and corrupted-preference recovery have not been separately tested.

**v1.27B — Shared diagnostic status handling (first increment; Windows testing pending)**

- A shared diagnostic classification now distinguishes `Success`, `NoData`, `Review`, `Partial`, `Unavailable`, `AccessDenied`, `NotTested`, and `Unknown` without replacing the collectors' original status or error detail.
- The shared dispatcher adds a `StatusCategory` field to its results; the Classic alternate-credential formatter and GUI default/alternate diagnostic reports can display the category.
- Classic alternate-credential report section objects retain the structured `StatusCategory` field.
- **v1.27B follow-up:** Shared exception handling in the dispatcher and both GUI diagnostic modes now distinguishes explicit authorization-denied errors (`ACCESS DENIED` / `AccessDenied`) from other failures (`UNAVAILABLE` / `Unavailable`). The original exception message is preserved. A nonexistent or unreachable host is not classified as access denied solely because collection failed.
- **v1.27B message clarity (GUI Default Windows-tested):** New collection failures display `Error details:` rather than the ambiguous `UNAVAILABLE / ACCESS DENIED / ERROR:` heading. Status and category remain separate. The Classic/GUI Default status parser accepts both new and legacy headings, classifying from the actual error message; GUI worker exception output uses the same neutral wording. GUI Default Firewall diagnostic against a computer with WinRM stopped confirmed `STATUS: UNAVAILABLE`, `Status category: Unavailable`, and the original WinRM connection message under `Error details:`.
- **v1.27B correction (Windows-tested in GUI Default mode):** The shared Classic/GUI Default report status parser now removes the generic `UNAVAILABLE / ACCESS DENIED / ERROR:` prefix before looking for explicit permission-denied evidence. An RPC-unavailable message was confirmed to display `STATUS: UNAVAILABLE` and `Status category: Unavailable`, while retaining its original error text.
- The existing Classic Default diagnostics continue using their established `Get-SectionStatus` logic; a full cross-mode parity test is still pending.
- Existing diagnostic collection methods, authentication selection, and saved report formats remain in place. **The change needs Windows regression testing before v1.27B can be considered complete.**

**Future development:** See the [IT Toolkit Roadmap](ROADMAP.md) for upcoming milestones, enterprise local diagnostics, Quick Fix, NIST/best-practices checks, and additional proposals. Planned features are not included in the current build.

### v1.26

- Expanded Default and Alternate credential support across diagnostic workflows.
- Integrated credential-aware access checking for WMI, WinRM, and `ADMIN$`.
- Improved GUI and Classic reporting and result-status presentation.
- Added GUI and Classic snapshot creation with structured JSON comparisons.

See the [complete changelog](CHANGELOG.md) for the documented release history through v1.26. The v1.27 work above is currently documented in this development-branch README.
---
## License

Cochise County IT Toolkit is licensed under the
GNU General Public License, Version 2.0 (GPL-2.0-only).

Copyright (C) 2026 Chris Collins

See the [LICENSE](LICENSE) file for the full license text.

*Developed for IT workflows. This development-branch README documents v1.27 work in progress; v1.26 remains the stable Windows release.*
