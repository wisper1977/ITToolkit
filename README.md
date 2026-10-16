# IT Toolkit

**v1.28 — Active development** · Windows PowerShell 5.1 · Windows administration and diagnostics

> **Release status:** v1.28 is in active development on [`develop/v1.28`](https://github.com/wisper1977/ITToolkit/tree/develop/v1.28). **v1.27** on `main` is the published stable Enterprise release. See [CHANGELOG.md](CHANGELOG.md) for completed changes and [ROADMAP.md](ROADMAP.md) for planned work.

IT Toolkit is a portable, PowerShell-based Windows administration utility for technicians. It combines system diagnostics, access checks, reporting, inventory comparisons, and frequently used tools in graphical and Classic console interfaces.

## v1.28 development focus

The v1.28 milestone is a **diagnostic completeness review** of all 20 sections, beginning with Network. Local Network adapter inventory and display corrections have been accepted in Enterprise Windows testing. The active-route inventory has been observed in Enterprise Windows testing; corrected adapter-to-route interface indexes and the default-route summary have now passed local Enterprise Windows testing. The remote WinRM adapter/route expansion is implemented and **awaits Enterprise Windows testing**; original ipconfig /all and credential-aware WMI fallback remain in place. Local, remote Default, and remote Alternate evidence will be compared while maintaining GUI/Classic parity, authentication boundaries, and report compatibility.

The v1.27 stable baseline already includes three launcher modes, shared authorization, verified remote identity evidence, seven-check Computer Health, HTML/CSV/TXT reports, structured inventory snapshots and comparisons, and the scoped UAC Reports-folder helper. See the [v1.27 release notes](CHANGELOG.md) for established features and testing.

## Features

- Graphical (WPF) and Classic PowerShell interfaces for Windows technicians.
- Windows workstation and server diagnostics, including a complete 20-section diagnostic workflow.
- Remote DNS, ping, WMI, WinRM, and ADMIN$ accessibility checks.
- Default and explicitly provided Alternate remote authentication where supported.
- Read-only health analysis and exportable HTML, CSV, and TXT reports.
- JSON inventory snapshots and comparisons covering supported system categories.
- Integrated utility catalog, custom tools, and favorites; optional Sysinternals and PortQry support.

## Screenshots

![IT Toolkit Launcher](Screenshots/login.png)

![IT Toolkit Dashboard](Screenshots/dashboard.png)

## Requirements

- Windows 10/11 or compatible Windows Server, Windows PowerShell 5.1, and .NET/WPF for the graphical interface.
- Network connectivity and appropriate authorization for remote targets.
- Relevant Windows remote-management services, firewall permissions, and administrative rights where required.
- Optional: [Microsoft Sysinternals](https://learn.microsoft.com/en-us/sysinternals/) and [PortQry](https://www.microsoft.com/en-us/download/details.aspx?id=17148).

macOS and Linux are not supported. The launcher does not install an agent on remote systems.

## Installation

1. For the **stable v1.27 release**, use [GitHub Releases](https://github.com/wisper1977/ITToolkit/releases/tag/v1.27). For ongoing **v1.28 development**, use the [development branch](https://github.com/wisper1977/ITToolkit/tree/develop/v1.28).
2. **Install to a local folder on `C:\`**, such as `C:\ITToolkit` (not directly in the root of `C:\`). Do **not** run the Toolkit from the Desktop: technicians have encountered environments where a Desktop-based installation fails to launch or run correctly. Preserve the `Modules`, `Branding`, scripts, and configuration file layout.
3. Review `Toolkit-config.json` and adapt the organization branding, default authentication domain, report directory, and optional tool paths.
4. Run `Launch.cmd`, choose an execution mode, then open the graphical or Classic interface.

**Launcher execution modes**

- **Current Windows User:** Start the Toolkit under the launcher's current Windows identity.
- **Separate Administrative Account:** Supply an explicitly authorized administrative identity for the Toolkit process.
- **Standard Session + On-Demand Administration:** Keep the regular session identity; use existing explicit Alternate authentication and scoped UAC operations when supported.

The Launcher does not automatically sign in as an administrator or store passwords. Direct script launches and interface switching do not silently substitute credentials.

To start either interface directly from Windows PowerShell:

```powershell
# Classic interface
powershell.exe -NoProfile -File "C:\ITToolkit\ITToolkit.ps1"

# Graphical interface
powershell.exe -NoProfile -STA -File "C:\ITToolkit\ITToolkit-GUI.ps1"
```

Follow your organization's script-execution policy and code-signing requirements.

## Basic workflow

1. Select the local computer or an authorized remote target.
2. Choose Default authentication or explicit Alternate credentials, where supported.
3. Run the desired diagnostics or Computer Health checks.
4. Save an HTML, CSV, or TXT report, or capture an inventory snapshot.
5. Capture a later snapshot and compare changes when investigating a system.

A successful query does not guarantee that the machine is healthy. Unavailable checks should not be interpreted as passing results.

## Development and release versions

- **Development:** `Major.Minor.Commit` (current application-code version: `1.28.372dc32`), where the suffix identifies the verified Network collector source revision `372dc32`. Documentation-only commits do not change it.
- **Stable:** `Major.Minor` (current production: `1.27`); v1.28 will use `1.28` only after Windows validation and explicit release approval.
- GUI, Classic, Launcher, and generated report metadata should consistently identify their source build. A configured suffix must not be assumed to identify a newer commit until the build version is regenerated and verified.

## Project layout

```text
ITToolkit/
├── Launch.cmd
├── ITToolkit-Launcher.ps1
├── ITToolkit-GUI.ps1
├── ITToolkit.ps1
├── Toolkit-config.json
├── Branding/
├── Modules/
└── Reports/
```

## Security and limitations

- Use IT Toolkit only for systems you are authorized to administer and follow least-privilege practices.
- Reports and snapshots may contain sensitive infrastructure details; do not commit them, credentials, or private keys to GitHub.
- Remote capabilities depend on the target OS, permissions, firewall, and management protocols.
- Inventory comparisons show collected differences, not comprehensive forensic changes or security compliance.
- Some separately authorized operations may require additional Windows permissions or UAC confirmation.
- The Report Archive **Open Folder** action requires explicit Windows UAC approval under a non-elevated Separate Administrative Account session; **Copy Folder Path** remains an alternative. See [ROADMAP.md](ROADMAP.md) for optional future refinements.

## Project history and plans

- [CHANGELOG.md](CHANGELOG.md) — development changes, fixes, and validation history.
- [ROADMAP.md](ROADMAP.md) — remaining v1.28 release checks and planned future work.
- [GitHub Releases](https://github.com/wisper1977/ITToolkit/releases) — published stable releases.
