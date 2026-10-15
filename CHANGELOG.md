# Changelog

Documented changes to **IT Toolkit** are recorded here. This file distinguishes confirmed release changes from development milestones. Dates are included only where established; historical versions have not been assigned speculative dates.

The project is a Windows PowerShell 5.1 toolkit. The GUI uses Windows Presentation Foundation (WPF); the Classic interface uses a text menu.

## [1.27] — In development (local snapshot Windows testing pending)

### Workplace validation checklist completion — technician confirmation (2026-10-15)

- Technician reports completing the agreed workplace test checklist: Classic/GUI switching, Classic BitLocker UAC, cancelled UAC handling, GUI elevated HTML/CSV/TXT save/open and report archive/recent reports, copied-report provenance, normal and alternate remote authentication, target/identity isolation, GUI startup/preferences, local collection without WinRM/ADMIN$, and endpoint-security checks.
- This is a **technician-reported confirmation** of completion, not a newly executed automated suite or separately supplied test output for every item. The earlier GUI cross-account BitLocker SUCCESS result was explicitly provided.
- **Environment limitation:** Policy computer RSoP queries continue to report ACCESS DENIED even when `gpresult.exe /SCOPE COMPUTER /R` runs in a separate elevated administrator console; preserve accurate status rather than interpreting as a toolkit malfunction or healthy result.
- No changes to production `main`; v1.27 awaits explicit release approval and final branch review.



### v1.27 — Explicit CurrentUser RemoteSigned option for UAC diagnostics (Windows testing pending, 2026-10-15)

- Wired the existing optional execution-policy adjustment into both GUI and Classic local BitLocker/Policy UAC workflows, using a **separate explicit confirmation**. GUI approval choices allow or decline the persistent policy change; Cancel stops collection. Classic asks before UAC retry.
- When explicitly authorized, an elevated administrator account with effective `Restricted` PowerShell policy can set its own persistent **CurrentUser** policy to `RemoteSigned`, provided MachinePolicy and UserPolicy are confirmed Undefined. No change to computer-wide policy or the initiating standard-user identity. Without approval, the diagnostic attempts its existing execution path and reports any block.
- Records elevated collection identity and effective execution-policy before/after, including whether policy was changed; a subsequent child failure reports the account-level change where possible. Fixed execution-policy scope inspection to use actual Scope/ExecutionPolicy rows rather than property names on the result array.
- **Not Windows-validated:** domain credential UAC, approved/declined policy paths, script execution after change, GUI and Classic reports, and regression/security testing. Production main not modified.


### GUI direct Edge report-opening compatibility (2026-10-15)

- Follow-up to the shell `Open` verb attempt: that change did not resolve the reported GUI symptom on the affected workstation. HTML reports now use an explicit Edge executable and file URI when Edge is installed; otherwise the Windows `Open` verb remains the fallback. Recent reports and the Reports archive share this implementation.
- CSV/TXT continue using the Windows shell. **Windows technician validation:** The direct Edge change resolved the original Open Report failure when launching the development GUI with administrative credentials on the affected workstation. Dashboard versus archive coverage, browser availability, other-format regressions and Classic parity remain to be confirmed.

### GUI report opening compatibility (2026-10-15)

- Updated the GUI's recent-report buttons and Reports archive Open Report action to explicitly use the Windows shell `Open` verb when launching saved files.
- On the affected workstation, a report opened with `Start-Process -Verb Open` under `runas` while the implicit launch did not. The revised GUI behavior still requires Windows testing through the normal credential launcher; production and Classic code are unchanged.


### Documentation — Consolidated v1.27 roadmap (2026-10-15)

- Reorganized `ROADMAP.md` into one unified v1.27 development milestone rather than separate lettered sub-milestones; consolidated repetitive collector-by-collector notes into implemented capabilities, confirmed Windows validation, open tests, and later planned features.
- Preserved the distinction between 20 successful command-line local collectors, 18 GUI/Classic HTML-validated local sections, and outstanding elevated GUI/Classic Policy and BitLocker reporting, Avast compatibility, regression and format checks. Earlier detailed implementation/test history remains in this changelog.
- Updated README development status wording to align with the current v1.27 work. No toolkit implementation or production branch changes.


### v1.27C — Sessions verified; Local Computer Policy implemented (2026-10-15)

- **Technician-confirmed Windows test:** Local Sessions returned a valid active console session in GUI and Classic; HTML reports saved and reopened.
- Added read-only direct-local Computer Policy collection using `gpresult.exe /SCOPE COMPUTER /R`. Its output is preserved as lines and nonzero exit codes fail visibly. Does not refresh Group Policy, elevate privileges, or switch identities.
- Enabled Policy in the local GUI/Classic routes and changed the reusable smoke test's default to Policy. Existing remote Policy behavior remains unchanged.
- **Pending:** Local Policy Windows output or access/RSoP error handling, both interfaces, HTML saved-report validation, alternate environment validation and remote regression. BitLocker authorized positive-path validation remains pending.


### v1.27C — Events verified; Local Startup implementation (2026-10-15)

- **Windows technician confirmed:** Events worked in GUI and Classic and HTML reports saved and opened. The System log had 13 error events over seven days; the Application log returned no matching errors (`NoData`). The overall query reported `SUCCESS`. DCOM connection attempts to `WisperPC` and WindowsUpdateClient app install failures were observed but are not automatic health verdicts.
- Added local read-only Startup program inventory via `Win32_StartupCommand`, exposing name, location, user, and command without starting or changing entries. This does not cover every possible Windows autostart mechanism.
- Enabled Startup in GUI and Classic local section routing; updated reusable test script default to Startup. **Pending:** Windows collector, both interfaces, HTML report save/open, no-results/permission cases, and remote regression. Existing remote Startup behavior remains unchanged.


### v1.27C — Scheduled Tasks validated; Events implementation (2026-10-15)

- **Windows technician confirmed:** Local Scheduled Tasks worked in GUI and Classic and HTML reports saved and reopened. Task Scheduler statuses, last/next runs and result codes were reported; nonzero codes and placeholder timestamps have not been labeled system failures.
- Implemented read-only direct-local Events collection for System and Application errors in the previous seven days, at most 25 records per log. Per-log summaries distinguish data, no matching events, and query failure; an inaccessible log yields PARTIAL rather than misleading overall SUCCESS. Captured fields include event time, ID, provider, level, and shortened message.
- Enabled Events in local GUI/Classic and updated the reusable test's default to Events. **Pending:** Windows collector/UI, no-error or restricted-log behavior, HTML save/reopen, and remote regression. Existing remote event functionality remains unchanged.


### v1.27C — Updates validated; local Scheduled Tasks implementation (2026-10-15)

- **Windows technician confirmed:** Local Updates worked in both GUI and Classic, including HTML saving/opening. Six installed QFE records were displayed; one missing installation date/installer was preserved without a fabricated value.
- Added read-only local Scheduled Tasks inventory using `Get-ScheduledTask` and `Get-ScheduledTaskInfo`: task path/name/state, last/next run, last task result. Each task-info failure is shown explicitly rather than silently claiming complete detail. Task result codes are data, not collector errors.
- Enabled local Tasks in GUI/Classic, and changed `Test-LocalDiagnostics.ps1` default to Tasks. Remote Tasks behavior unchanged.
- **Pending Windows tests:** Tasks collector, UI rendering and performance with large inventories, HTML save/open, permission/failure paths, remote regression, and remaining CSV/TXT format checks.


### v1.27C — Software verified; Local Updates increment (2026-10-15)

- **Windows technician confirmed:** Local Software worked in GUI and Classic and HTML saving/opening passed. The collector listed many machine-wide uninstall registry entries, including names, versions and publishers. Some records have blank metadata as supplied by the registry.
- Added direct-local, read-only installed-hotfix inventory through `Win32_QuickFixEngineering`, exposing HotFixID, Description, InstalledOn and InstalledBy. An empty result is `NO RESULTS` / `NoData`, not a compliant or up-to-date verdict.
- Enabled Updates in local GUI and Classic routes and made Updates the default of `Test-LocalDiagnostics.ps1`. The remote Updates diagnostic remains unchanged. This local first increment does not include recent Windows Update failure events, missing patches or update scans.
- **Pending Windows tests:** Updates collector, both UIs, HTML saved report, unavailable/empty cases and remote regression; Software CSV/TXT formats not separately verified.


### v1.27C — Shares Windows verification; Local Software implementation (2026-10-15)

- **Windows technician confirmed:** Local Shares ran successfully in GUI and Classic, including saved/reopened HTML. Four shares were listed: ADMIN$, C$, E$, IPC$. Reported share presence does not verify SMB access or NTFS/share permissions.
- Implemented read-only HKLM uninstall registry collection in both 64-bit and 32-bit registry views on supported OS versions, returning application name, version and publisher, with duplicate records removed. This deliberately matches the machine-wide remote Software report scope and does not invoke `Win32_Product` or change software.
- Enabled Software in GUI and Classic local routing; updated `Test-LocalDiagnostics.ps1` default to Software.
- **Pending Windows validation:** collector, both interfaces, HTML saving/reopening, registry missing/permission cases, report size, remote regression; CSV/TXT format verification remains open.


### v1.27C — Administrators verified; Local Shares implementation (2026-10-15)

- **Windows technician confirmed:** Local Administrators returned `SUCCESS` in GUI and Classic, and HTML reports saved and opened. It listed two direct members: built-in local Administrator (previously reported disabled) and a Microsoft-account-backed local user. Membership is not proof of successful sign-in or effective elevated token.
- Added local read-only `Win32_Share` inventory (share name, path, description, type), including administrative shares, to shared collector. GUI and Classic local section routing now includes Shares; existing remote paths are unchanged.
- Updated reusable test script default to Shares. Permissions, NTFS ACLs and network accessibility are **not** checked by this section. Windows Shares collector, GUI/Classic display, HTML saving, error/no-data paths and remote regression remain pending.


### v1.27C — Users validated; Groups implementation (2026-10-15)

- **Windows technician confirmed:** Local Users worked in GUI and Classic, and the HTML reports saved and reopened. Seven local accounts appeared with account-state fields; no security-health conclusion was drawn from disabled accounts.
- Added read-only local `Win32_Group` enumeration for local groups (domain, name, SID, description) in the shared collector and wired GUI and Classic local collection to it. Group **membership is not included** in this increment and must not be represented as tested.
- Set the reusable smoke test's default section to Groups. **Pending Windows tests:** direct collector, both interfaces, HTML save/open, no-data/denied cases, and remote regressions. Users CSV/TXT coverage remains pending.


### v1.27C — Network validated; Hardware implementation (2026-10-15)

- **Windows technician confirmed:** Local Network works in GUI and Classic and its HTML report saves and opens. Two IP-enabled adapters were reported; an Ethernet adapter had a 169.254.x.x link-local address and Wi-Fi had a routable private address and gateway. These are observed configurations, not health verdicts.
- Added read-only Hardware collection using direct local CIM: computer manufacturer/model and installed RAM, BIOS manufacturer/version/serial, processor name and core/logical-processor counts, and physical drive model/type/capacity. No remote-management transport, credential substitution, or system changes.
- Enabled Hardware in both local interface paths and changed the reusable test script default to Hardware.
- **Pending:** Hardware direct Windows collector test, GUI/Classic output, HTML save/reopen, negative cases and remote regressions. Network CSV/TXT formats and remote regressions remain pending.



### v1.27C — Storage interface validation and Local Network increment (2026-10-14)

- **Windows technician confirmed:** Local Storage works in GUI and Classic, and its HTML report saves and opens. CSV/TXT and remote regressions remain pending.
- Implemented direct-local Network collection through read-only `Win32_NetworkAdapterConfiguration` for IP-enabled adapters, including adapter identity, IP/subnet, default gateways, DNS servers, MAC and DHCP state. Does not attempt network changes, remote WinRM, or remote-target ping/traceroute.
- Enabled Network in the GUI and Classic local collection allowlists. Updated `Test-LocalDiagnostics.ps1` to default to Network; the same `-Section` parameter remains available.
- **Pending Windows validation:** Network direct collector, GUI/Classic display and report save, no-adapter and error paths, and remote regression. No claim of Network completion yet.


### v1.27C — Local Storage (implementation; Windows testing pending)

- Added read-only fixed logical disk capacity/free-space enumeration to the shared local collector using `Win32_LogicalDisk` (`DriveType=3`), without remote WinRM or `ADMIN# Changelog

Documented changes to **IT Toolkit** are recorded here. This file distinguishes confirmed release changes from development milestones. Dates are included only where established; historical versions have not been assigned speculative dates.

The project is a Windows PowerShell 5.1 toolkit. The GUI uses Windows Presentation Foundation (WPF); the Classic interface uses a text menu.

## [1.27] — In development

### v1.27C — Network validated; Hardware implementation (2026-10-15)

- **Windows technician confirmed:** Local Network works in GUI and Classic and its HTML report saves and opens. Two IP-enabled adapters were reported; an Ethernet adapter had a 169.254.x.x link-local address and Wi-Fi had a routable private address and gateway. These are observed configurations, not health verdicts.
- Added read-only Hardware collection using direct local CIM: computer manufacturer/model and installed RAM, BIOS manufacturer/version/serial, processor name and core/logical-processor counts, and physical drive model/type/capacity. No remote-management transport, credential substitution, or system changes.
- Enabled Hardware in both local interface paths and changed the reusable test script default to Hardware.
- **Pending:** Hardware direct Windows collector test, GUI/Classic output, HTML save/reopen, negative cases and remote regressions. Network CSV/TXT formats and remote regressions remain pending.



### v1.27C — Storage interface validation and Local Network increment (2026-10-14)

- **Windows technician confirmed:** Local Storage works in GUI and Classic, and its HTML report saves and opens. CSV/TXT and remote regressions remain pending.
- Implemented direct-local Network collection through read-only `Win32_NetworkAdapterConfiguration` for IP-enabled adapters, including adapter identity, IP/subnet, default gateways, DNS servers, MAC and DHCP state. Does not attempt network changes, remote WinRM, or remote-target ping/traceroute.
- Enabled Network in the GUI and Classic local collection allowlists. Updated `Test-LocalDiagnostics.ps1` to default to Network; the same `-Section` parameter remains available.
- **Pending Windows validation:** Network direct collector, GUI/Classic display and report save, no-adapter and error paths, and remote regression. No claim of Network completion yet.


### v1.27C — Local Storage (implementation; Windows testing pending)

.
- Included DeviceID, volume label, size GB, free GB and free percent, with null for unavailable/zero-capacity percentage rather than reporting a misleading 0%.
- Wired the existing Storage choice into both GUI and Classic local paths while leaving remote adapters unchanged. An empty fixed-drive result is `NO RESULTS` / `NoData`; collection exceptions retain their error and status category.
- **Pending:** Windows PowerShell 5.1 direct collector test, GUI/Classic output and report-save tests, negative/empty cases, and remote regression. This increment is not yet Windows-validated.
**Development branch:** `develop/v1.27`. Version 1.26 on `main` remains the stable production release. The entries below describe implemented development work, not a published v1.27 release.

### v1.27A — GUI refinements (completed; Windows-tested)

#### Changed
- Introduced a shared WPF multiline, centered button-label helper for dynamically generated tool buttons.
- Enabled wrapped labels and increased minimum button height on both the **Tools** page and **Dashboard Favorite Shortcuts**, including long names such as *Active Directory Users and Computers*.
- Improved handling of long selected-target names, recent-target buttons, and recent-report filenames in the dashboard.
- Adjusted technician and computer-name footer layouts to support truncation in limited horizontal space.
- Preserved full target identity in tooltips and existing full report paths in report tooltips.
- Set the development branch's `Toolkit-config.json` version to **1.27**.
- Updated the development-branch README to distinguish v1.27 work in progress from the stable v1.26 release.

#### Validation
- The Tools page and Dashboard favorite button wrapping were confirmed working in Windows testing.
- The subsequent dashboard and footer layout refinements were reviewed in Windows and accepted.
- Tool launching, favorites, report opening, and authentication behaviors were intended to remain unchanged; no comprehensive regression test of these areas is claimed.

### v1.27A follow-up — Window state persistence (completed; Windows-tested)

#### Added
- Main GUI per-technician window size, position, maximized state, and last opened page saved in the existing `GUISettings.json` preferences.
- Restored normal window bounds after maximizing, with minimum-size validation and monitor-visibility safeguards.
- Invalid or off-screen saved placement falls back to default startup placement without blocking the GUI.
- Page restoration does not automatically reconnect to a previous target; launcher behavior is unchanged.

#### Validation
- Windows testing confirmed restoration of moved and resized windows, maximized state, and last opened page across GUI sessions.
- Favorites and Recent Targets were preserved, and the GUI reopened without automatically selecting a target.
- Multi-monitor disconnection and corrupted-preference recovery safeguards are implemented but have not been separately validated.

### v1.27B — Shared status classification (first increment; awaiting Windows testing)

#### Added
- A common `Get-ToolkitDiagnosticStatusCategory` classifier with explicit categories for success, no data, review, partial, unavailable, access denied, not tested, and unknown outcomes.
- Additive `StatusCategory` output from the shared diagnostic dispatcher, while preserving original `Status`, `Error`, and collected records.
- Status category display in the Classic alternate-credential report formatter and GUI diagnostic output (including Default mode).
- **Second increment:** Propagated `StatusCategory` from the Classic alternate-credential report bridge as a structured property alongside the existing `Status` and `Content` fields.
- Added explicit `Status category: Unavailable` lines to both GUI diagnostic worker exception paths while keeping existing exception detail text unchanged.
- **Third increment:** Replaced the GUI workers' blanket `UNAVAILABLE` exception label with shared classification that reports `ACCESS DENIED` only for explicit authorization-related errors, while retaining `UNAVAILABLE` for other failures. The shared dispatcher uses the same classification in its exception path, and detailed error messages remain visible.
- **Regression fix:** Corrected `Get-SectionStatus` (Classic/GUI Default report status parsing) so the historic generic error prefix does not itself trigger `ACCESS DENIED`. The actual error details are evaluated instead; `The RPC server is unavailable` should yield `UNAVAILABLE`.
- **Windows retest passed (GUI Default mode):** An RPC-unavailable System diagnostic reported `STATUS: UNAVAILABLE` and `Status category: Unavailable`, preserving `The RPC server is unavailable.` as the underlying error. This validates the specific misclassification fix; alternate credentials and genuine access-denied responses remain untested.

- **Message clarity update:** Changed the shared Classic/GUI Default collection failure output to `Error details:` and both GUI diagnostic worker exception paths to the same neutral label. The report status parser continues to recognize legacy `UNAVAILABLE / ACCESS DENIED / ERROR:` text, using only the underlying error for classification. GUI Default Windows retest passed: Firewall diagnostics against a machine with WinRM stopped displayed `UNAVAILABLE` / `Unavailable` and the original WinRM error under `Error details:`. Classic and Alternate paths have not been separately tested.

#### Validation pending
- GUI Default mode and status display received initial Windows confirmation; GUI Alternate and Classic alternate credentials remain untested pending access to an authorized remote target.
- Regression-test this increment with a nonexistent target (expected `UNAVAILABLE`) and, later, a real explicit permission rejection (expected `ACCESS DENIED`). Other collector-reported statuses remain unchanged.
- Confirm report saving, snapshots, and existing diagnostics remain operational; **v1.27B is not yet marked complete**.

### v1.27C — GUI switch positioning (Windows layout retest pending)

- Moved **Switch to Classic** from the primary navigation group to the bottom of the GUI left sidebar, beneath Target Computer. The sidebar now uses a three-row Grid so the switch stays bottom-aligned when the window is resized.
- The button uses the existing click handler; interface switching, identity handling, and active-collection safeguards are unchanged. Windows GUI positioning and basic switching were confirmed by the technician; broader regressions remain pending.

### v1.27C — Classic Services and interface switching (implementation; Windows switch validation pending)

- **Windows tester confirmed:** Classic Local Services executed successfully and produced expected output; report saving and remote regression were not separately verified in this test.
- Grouped Classic main-menu choices sequentially: categories 1–6, target actions 7–10, settings 11–13, interface switching 14. Local Computer moved from 13 to 10; Settings, Tools, and Target Credentials moved to 11, 12, and 13 respectively. Updated stale local-services descriptions.
- Added Classic `14 Switch to GUI` and a GUI sidebar `Switch to Classic` button. Each starts the other entry point with the **current Windows identity** via a new Windows PowerShell process. No credential, target, or session-state handoff; switch only closes the source interface after successful process startup.
- GUI switching is blocked while diagnostic/snapshot collection is active. Failed launches leave the source interface available. Explicitly chosen alternate target credentials are not reused or silently substituted.
- **Windows validation pending:** both switch directions, menu numbering, authentication boundaries, report save/reopen, and regression tests. The new switching feature must not be treated as complete until tested.

### v1.27C — Local Services collector Windows verification

- **Confirmed collector success on Windows workstation `DESKTOP-8EHGAPD`:** Explicitly reloaded the current `Modules/ITToolkit-LocalDiagnostics.ps1` function; `Get-ToolkitLocalDiagnostic -Section Services` returned `SUCCESS` / `Success` with no error, 324 service records queried, and seven automatic-start services currently not running.
- The seven records were AppXSvc, AsusUpdateCheck, edgeupdate, Intel(R) TPM Provisioning Service, MapsBroker, sppsvc, and TrustedInstaller. These findings are **not** automatically service failures; idle, trigger-start, and on-demand behavior require context.
- The collector test is complete for this successful local path only. **GUI and Classic Local Services integration, report saving and formatting, error paths, and remote regression remain unverified.** No repairs or service-state changes were performed.

### v1.27C — Local diagnostics foundation (first increment; partially Windows-tested)

#### Added
- New `Modules/ITToolkit-LocalDiagnostics.ps1` with `Get-ToolkitLocalDiagnostic` for direct local System and Firewall collection, using the current Windows security token and no remote WinRM/ADMIN$ dependency.
- Sanitized, structured local results with target, identity label, collection mode, status/category, data and underlying error details.
- Firewall profile state is reported as observed data; a disabled profile is not mistaken for a collection failure.

#### Limitations and validation pending
- The collector is not yet connected to GUI or Classic target selection, diagnostics, reports, or snapshots. Alternate local administrative identity execution has not been built. Neither interface should claim local diagnostic mode is ready.
- **Windows validation passed (current-user success paths):** On Windows 11 Pro, local System and Firewall returned `SUCCESS` / `Success`, populated data, and empty `Error` values, using the current identity while WinRM was stopped. Firewall showed enabled Domain, Private, and Public profiles. The results confirm direct collection without a responding WinRM endpoint.
- **Validation still pending:** permission-denied and collection-failure paths, GUI/Classic integration, snapshots/reports, and alternate-administrator execution.

### v1.27C — Local target selection and reporting (second increment; Windows testing pending)

#### Added
- GUI Dashboard **Use Local Computer** selection and Classic main menu option **13** to choose the machine running IT Toolkit.
- Shared direct-local System and Firewall collection in the GUI asynchronous diagnostic worker and Classic reports. Local output includes status/category, identity context, evidence, and error details.
- Explicit `NOT TESTED` results for local diagnostic sections that do not yet have collectors, instead of silently using remote collection.

#### Safeguards and limitations
- Existing remote target selection remains available. GUI target switches are blocked during diagnostic/snapshot collection; Classic remote tool categories cannot run under explicit local mode.
- The GUI prevents ADMIN$ checks for local selection, and both modes decline local snapshot capture rather than running remote snapshot collectors.
- Current-user token only. Secure alternate-administrator local execution, remaining local collectors, and structured local snapshots are not yet implemented.
- Windows validation confirmed GUI local Firewall `SUCCESS` and local Users `NOT TESTED`; the user confirmed Classic local reports save successfully.
- **GUI report-save regression fix:** The Save Report handler now recognizes `Local` alongside `Default` and `Alternate`, without weakening its target/identity checks. Saved local reports use a `LOCAL DIAGNOSTIC REPORT` heading instead of `REMOTE`.
- **Windows GUI Local save regression retest passed:** A Services diagnostic was collected and its report saved successfully. This validates saving under Local mode, **not** local Services data collection (still unsupported and expected to be `NOT TESTED`). The user subsequently confirmed that all saved reports tested opened successfully; exact per-format coverage remains unspecified. Additional GUI/Classic scenarios and remote regression testing remain pending; do **not** mark v1.27C complete.

### Core PowerShell verb naming cleanup (Windows retest pending)

- Renamed the function definitions `Pause-Toolkit` to `Wait-ToolkitContinue` and `Change-Target` to `Set-ToolkitTarget` in `Modules/ITToolkit-Core.ps1` to address VS Code/PSScriptAnalyzer `PSUseApprovedVerbs` warnings.
- Kept aliases for both previous names so existing module and Classic menu calls continue to resolve. No change intended to target authentication or collection behavior; Windows validation and a PSScriptAnalyzer rerun are pending.

### v1.27C — Direct-local Services diagnostic (third increment; Windows validation pending)

#### Added
- Extended `Get-ToolkitLocalDiagnostic` to support `Services` through local `Win32_Service` CIM enumeration using the current Windows identity, with no WinRM/ADMIN$ dependency.
- Like the existing remote Services diagnostic, report nonrunning services whose start mode is `Auto`, plus total service and finding counts. Query success with zero findings reports `SUCCESS`; zero enumerated service records is treated as `UNAVAILABLE`, not a healthy result.
- Enabled the shared local Services path in GUI and Classic; other unsupported local sections remain explicitly `NOT TESTED`.

#### Validation pending
- Windows 11 / Windows PowerShell 5.1 GUI and Classic Services collection, stopped automatic service cases, saved reports, and regression tests; no changes to remote collectors, credential selection, or service state were intended.

### Documentation organization

- Added [ROADMAP.md](ROADMAP.md) as the dedicated plan for pending v1.27B validation, v1.27C local diagnostics, v1.27D health analysis, the proposed Quick Fix menu, NIST/best-practices checks, and later enhancements.
- Replaced the lengthy planned-feature section in [README.md](README.md) with a link to the roadmap. No runtime functionality changed.

### Planned (not yet implemented)

Future milestones, security requirements, and proposed features are maintained in [ROADMAP.md](ROADMAP.md). These are not part of the current release.

## [1.26] — 2026-10-14

**Major update: credential-aware diagnostics, verified remote access checks, and snapshot creation from both interfaces.**

### Added
- **Alternate credentials** for supported remote diagnostics without requiring technicians to start the entire application under an administrative Windows logon.
- Explicit authentication selection in the GUI and Classic interface, with an in-memory credential workflow.
- Credential-aware WMI/DCOM, WinRM, and mixed-method diagnostic collectors.
- A consolidated diagnostic dispatcher supporting 20 diagnostic sections and more detailed output for services, events, scheduled tasks, firewall, groups, and policy.
- Credential-aware `ADMIN$` access verification in the GUI, including differentiated access-denied, conflict, and untested outcomes.
- **GUI Create Snapshot** action with background collection.
- **Classic Create Snapshot** command under the Reports menu.
- JSON snapshots covering services, software, updates, users, groups, administrators, and shares, with authentication and collection metadata.

### Changed
- Integrated alternate-identity diagnostics into both GUI and Classic workflows while preserving Default-identity behavior.
- Improved HTML/CSV/TXT report generation, metadata presentation, cached report behavior, and diagnostic status descriptions.
- Improved dashboard checks for DNS resolution, ping reachability, Health diagnostics, and `ADMIN$` status.
- Distinguished successful, partial, unavailable, access-denied, credential-conflict, and not-tested results where supported.
- Corrected duplicate headings and report labels in selected diagnostic output.
- Kept snapshot comparison compatible with the structured JSON baseline format and prevented failed/missing collections from being interpreted as removed items.

### Security and limitations
- Selected Alternate credentials must not silently fall back to the technician's Default identity.
- Passwords are not intended to be written to saved reports or configuration.
- The SMB `ADMIN$` adapter does not forcibly disconnect existing network sessions. A successful check may leave an SMB session when exclusive ownership cannot be demonstrated.
- Some tests legitimately return **Unavailable**, including BitLocker information where the remote collection method is unsupported; unavailable is not equivalent to disabled.
- Windows-only release; macOS and Linux are not supported.

### Validation notes
- Functional validation completed during development for GUI and Classic alternate-credential diagnostics, snapshot creation and comparison, and dashboard `ADMIN$` success/failure classification.
- Static preflight checks of the development installation passed. A separately extracted final release-package clean-install test was recommended; no completed clean-install result has been documented here.

## [1.25.7]

**Protected stable baseline before v1.26 development.**

- Unified catalog of **22 tools** across the toolkit's relevant interfaces.
- Synchronized Favorites and custom-tool configuration.
- Refined GUI, reporting, archive, and comparison workflows.
- Improved portable launcher and branding behavior.
- Restored and validated detection of x64 Sysinternals tools.
- Used as the known-working rollback baseline while v1.26 was developed in a separate copy.

## [1.25.0–1.25.6] — Development series

**Progressive introduction of the graphical toolkit.** Individual patch-level feature attribution within this range is not fully documented in the available historical material.

- Developed a Windows Presentation Foundation (WPF) launcher, with optional organization logo, background, application icon, and colors.
- Added credential entry, Classic/GUI selection, and per-user preferences for remembered username and preferred interface. Passwords were not intended to be persisted.
- Replaced the initial GUI placeholder with a functional desktop interface for targets, diagnostics, tools, reports, and settings.
- Iterated on target selection, Favorites, custom external tools, report browsing, snapshot comparisons, and general UI integration.

## [1.24]

**Modularized the Classic toolkit.**

- Refactored the previously more monolithic Classic program into **seven dot-sourced components**.
- Consolidated configuration around the root `Toolkit-config.json`.
- Corrected configuration-path resolution after modularization.
- Preserved the established Classic menus, diagnostic tools, reporting, and snapshot/comparison functionality.
- Retained v1.23 as the fallback during validation.

## [1.0–1.23] — Original Classic development (historical entries)

The entries below are preserved from the project's **Master Version Changelog**. They record the individual milestones as documented at that time.

### [1.0] — Initial Toolkit

- Created the original PowerShell-based IT Toolkit.
- Established the menu-driven interface for administrative and troubleshooting utilities.
- Began organizing commonly used tools and diagnostic functions into one application.

### [1.01] — PortQry Integration

- Added support for Microsoft's PortQry utility.
- Expanded the toolkit's network troubleshooting capabilities.
- Continued organizing external troubleshooting utilities within the menu system.

### [1.02] — Menu Improvements

- Improved descriptions of available tools and submenu options.
- Separated functionality into more clearly identified sections.
- Improved menu readability and navigation.

### [1.03] — Utility Organization

- Continued improvements to menu spacing and organization.
- Added or improved access to Active Directory Explorer.
- Refined the presentation of the available utilities.

### [1.04] — PortQry Configuration

- Expanded PortQry configuration and management.
- Improved the way external utility settings were handled.

### [1.05] — Target and Settings Separation

- Improved separation between target computer selection and toolkit configuration.
- Refined the workflow for choosing remote systems and managing settings.

### [1.06] — Reporting Foundation

- Introduced or substantially expanded the diagnostic reporting system.
- Added the ability to run a comprehensive, all-in-one report.
- Added individual diagnostic reports for targeted troubleshooting.
- Established the foundation for the reporting features developed in subsequent releases.


### [1.07] — Administrative Access Checks

- Improved remote administrative access testing.
- Added cached or manually initiated access checks to reduce unnecessary repeated testing.
- Refined remote target handling and diagnostic readiness checks.

### [1.08] — User, Group, and Share Reporting

- Expanded diagnostic coverage for local user accounts.
- Improved local group and group membership reporting.
- Added or enhanced shared resource inventories.

### [1.09] — Comprehensive Diagnostic Coverage

- Expanded reporting toward the full set of approximately 20 diagnostic sections.
- Added or improved permission reporting, including share and NTFS access information.
- Expanded reporting formats and diagnostic output.
- Improved coverage of system configuration, security, and remote administration information.

### [1.10] — Diagnostic Status and Fallback Improvements

- Introduced clearer diagnostic execution statuses.
- Distinguished successful queries from queries returning no results.
- Improved reporting of inaccessible or unavailable diagnostic sources.
- Added more resilient Event Log query fallback behavior.
- Improved BitLocker detection using alternative query methods.
- Clarified that successful data collection does not necessarily mean a system is healthy.


### [1.11] — Configuration and Snapshot Improvements

- Migrated toolkit configuration to `Toolkit-config.json`.
- Added Sysinternals utility auto-detection with support for manual configuration.
- Improved portable launcher and deployment behavior.
- Expanded diagnostic snapshots and comparison functionality.
- Improved service configuration capture and comparison details.
- Continued centralizing configuration values rather than hardcoding them.

### [1.12] — HTML Reporting Improvements

- Added improved color-coded HTML diagnostic output.
- Made success, warning, error, and unavailable statuses easier to distinguish.
- Added or improved the ability to open generated HTML reports after saving.
- Improved the readability of generated diagnostic reports.

### [1.13] — Menu and Settings Refinement

- Reorganized menu numbering into a more consistent sequential structure.
- Centralized settings and configuration options.
- Improved general navigation through the toolkit.
- Preserved existing diagnostics and reporting capabilities.


### [1.14] — Scheduled Tasks and Comparison Fixes

- Fixed Scheduled Tasks reporting that incorrectly returned `NO RESULTS`.
- Improved BitLocker status reporting when required providers or features were unavailable.
- Prevented unavailable BitLocker queries from being mistaken for an unencrypted system.
- Corrected JSON snapshot comparison totals and summary calculations.

### [1.15] — Remote IP Configuration

- Added remote `ipconfig /all` collection to the Network Report.
- Used PowerShell Remoting when available.
- Added fallback collection through Windows management interfaces.
- Ensured the reported configuration came from the target computer rather than the technician's workstation.

### [1.16] — Service Comparison Improvements

- Improved detection of service status and startup configuration changes.
- Verified that comparisons could identify a service changing from `Running / Automatic` to `Stopped / Manual`.
- Continued validating network and scheduled task reporting.

### [1.17] — Scheduled Tasks Summary

- Improved Scheduled Tasks inventory accuracy and summary counts.
- Normalized placeholder dates to indicate tasks that had never run.
- Added clearer summaries of nonzero task results.
- Introduced a count of scheduled task results needing review.
- Improved task table output without omitting entries from the full inventory.

### [1.18] — Scheduled Task Result Explanations

- Added human-readable descriptions for recognized Scheduled Task result codes.
- Preserved original numeric result codes for troubleshooting.
- Distinguished standard Task Scheduler informational results from potentially problematic results.
- Avoided classifying every nonzero result as a confirmed failure.
- Added explanations for unmapped or task-specific codes.


### [1.19] — HTML Report Redesign

- Redesigned the HTML report presentation.
- Added section bookmarks for navigating large reports.
- Added collapsible and expandable diagnostic sections.
- Improved Scheduled Tasks tables with defined columns.
- Preserved task result descriptions and rows requiring review.
- Improved overall formatting without changing diagnostic collection behavior.

### [1.20] — Multi-Column Bookmarks

- Replaced the single flowing bookmark list with a responsive grid.
- Added four-column navigation on wider displays.
- Added automatic adjustment to three, two, or one column on smaller displays.
- Preserved existing section links and collapsible report sections.

### [1.21] — Alternating Row Colors

- Removed unnecessary text separator lines from generated HTML reports.
- Introduced alternating light-blue row backgrounds for text-based report sections.
- Improved readability when following long lines of diagnostic information.
- Preserved green, yellow, and red diagnostic highlighting.
- Extended consistent alternating row formatting to Scheduled Tasks tables.
- Left TXT, CSV, JSON, and diagnostic collection behavior unchanged.

### [1.22] — Improved Color Contrast

- Darkened alternating blue report rows to `#C9E0F8`.
- Improved visibility on displays where the previous shading was difficult to distinguish.
- Strengthened Scheduled Tasks row hover highlighting.
- Preserved warning, error, success, and unavailable status colors.
- Verified the updated appearance using a newly generated Complete Report.

### [1.23] — Back to Top Navigation

- Added a `Back to Top` link to HTML report sections.
- Allowed technicians to return quickly to the title and bookmark navigation.
- Hid navigation links from printed reports.
- Preserved the existing responsive bookmarks, collapsible sections, and alternating row formatting.
- Confirmed that Back to Top navigation worked during testing.

## Release history policy

- **Release versions** describe shipped or protected baselines, not every internal test ZIP.
- **Development phases** (for example v1.26 Phase 3A or Phase 6F) are implementation/test milestones within a release, not separate published versions.
- Future release notes should be added under their exact Git tag, with date, Added/Changed/Fixed/Security categories when applicable.
- Do not treat a diagnostic collection status of **Success** as proof that the target system itself is healthy.

[1.26]: https://github.com/wisper1977/ITToolkit/releases/tag/v1.26

- **GUI local Services display retest passed (2026-10-14):** The GUI report for `DESKTOP-8EHGAPD` showed Local/current-identity collection, `SUCCESS` / `Success`, all 324 queried services in the summary, and the same seven stopped automatic-start services as the independent collector test. This validates the report content and presentation only; GUI Services report save/reopen, Classic Services execution, and remote regression tests remain pending.

- **Windows validation passed (2026-10-14):** Technician confirmed the relocated bottom-aligned GUI **Switch to Classic** button works as intended after pulling the updated development branch. No new code changes were needed. Remaining diagnostic/report/credential regressions are tracked separately.

- **Local Services saved report (Windows technician confirmation, 2026-10-14):** Saving a Local Services diagnostic report worked. This confirms successful saving on the tested path; the exact interface and coverage of HTML, CSV, and TXT formats were not specified, so individual interface/format validation is not claimed. Remote collection regression testing remains pending.

### v1.27C — Local test harness and Storage collector validation

- Added `Test-LocalDiagnostics.ps1` at the repository root: reloads the checked-out collector on each run to avoid stale functions, validates the selected section, clears stale-output ambiguity using a fresh scoped result, prints status and records, and returns a nonzero process exit code on collection failure. Defaults to Storage and supports `-Section` for other implemented sections. Does not modify host state or write reports.
- **Windows collector test passed (technician-confirmed):** Direct local Storage returned `SUCCESS` / `Success` with no errors on `DESKTOP-8EHGAPD`; fixed volumes C: and E: were enumerated with capacity, free GB, and free percent.
- **Still pending:** Windows testing of the new test harness, Storage GUI and Classic integration, report saving and remote regression. A `SUCCESS` query does not establish healthy storage.

### v1.27C — Hardware validated and Local Users implemented (2026-10-15)

- Windows technician confirmed Hardware works in GUI and Classic, with HTML reports saving and reopening successfully. The reported CPU was an Intel i7-10700K (8 cores, 16 logical processors), with 31.9 GB RAM and one Samsung SSD listed. Inventory scope will be reviewed against the E: logical volume later.
- Added read-only local Users collector based on `Win32_UserAccount` with `LocalAccount=True` and fields Domain, Name, Disabled, Lockout and SID; enabled it in both local interfaces, leaving remote behavior unchanged.
- Updated the reusable local smoke-test script to default to Users. Windows Users testing, saved-report checks, negative paths and remote regression remain pending.

### v1.27C — Groups verified; Administrators added (2026-10-15)

- Windows technician confirmed Local Groups in GUI and Classic, including successful HTML report save and reopening.
- Added read-only direct membership inventory for the built-in Administrators group (SID S-1-5-32-544) to the shared local collector, including name, class, principal source, SID and summary. Nested group membership is not expanded.
- Connected GUI and Classic local Administrators sections; updated single-file smoke test default to Administrators. Windows collector, interface and saved-report validation, edge cases and remote regression remain pending.

### v1.27C — Startup verified; local BitLocker implemented (2026-10-15)

- Windows technician confirmed Startup worked in GUI and Classic, including HTML report save and reopening.
- Implemented direct-local read-only BitLocker volume status using `Get-BitLockerVolume`, with mount point, type, volume/encryption/protection/lock states and encryption percentage. No recovery keys, recovery passwords or key protector details are returned.
- Enabled both local interfaces and made BitLocker the smoke-test default. Missing cmdlet or access restrictions are surfaced as unavailable/denied, not as unencrypted drives. Windows and regression testing pending.

### v1.27C — BitLocker permission handling and Sessions (2026-10-15)

- Direct local BitLocker test returned ACCESS DENIED / AccessDenied on Windows. This confirms the negative path, not successful encryption inventory; positive-path validation remains outstanding.
- Implemented read-only local Sessions enumeration via local `quser.exe`, preserving output lines and checking the process exit code. Added local support in GUI/Classic and updated the test script default to Sessions.
- Windows Sessions and report testing, authorized BitLocker positive-path test, and remote regressions remain pending.

### v1.27C — Policy denied case; local Share Permissions implemented (2026-10-15)

- Local Policy returned ACCESS DENIED on Windows, validating the permission-failure path only; applied-policy positive path remains unverified.
- Added read-only ordinary local SMB share inventory, share permission entries, and root NTFS ACL entries. Excludes administrative shares and does not evaluate effective access or change access control lists. Individual ACL failures are shown as PARTIAL.
- Enabled SharePermissions in GUI and Classic local routes; smoke-test default now SharePermissions. Windows UI, collector, HTML and remote regression remain pending. BitLocker positive path is also outstanding.

### v1.27C — Share Permissions validated; local Health evidence implemented (2026-10-15)

- **Windows technician confirmed:** SharePermissions succeeded in GUI and Classic with HTML saving/reopening. One ordinary SMB share was returned with share-level and NTFS root access lists; no effective-access calculation was claimed.
- Added read-only direct-local Health evidence summary for system-drive free percentage, count of nonrunning automatic services, and the latest 24h System critical/error count (up to 100 events). Distinguishes per-check availability, `NoData`, and overall `PARTIAL` when a collection fails; does not assign a health score.
- Enabled Health in both explicit local interfaces and changed smoke-test default to Health. Remote Health remains unchanged. Windows Health GUI/Classic/HTML and edge-case validation, plus authorized positive tests for BitLocker and Policy and remote regression, remain pending.

### v1.27C — Local Health Windows validation (2026-10-15)

- Technician confirmed GUI and Classic Health collection, plus HTML report save/open. C: free space 31.4% (145.72 GB), 324 services inspected with 6 automatic not running, and 8 System critical/error events in 24 hours.
- 18/20 local diagnostic sections now have successful Windows positive-path validation. BitLocker and Policy have only access-denied negative-path verification, not successful inventory.
- Health evidence does not establish system health. Other Windows environments, CSV/TXT formats, remote regression and authorized BitLocker/Policy positive-path tests remain outstanding. The v1.27D analysis milestone is not complete.

### v1.27C — Elevated BitLocker and Policy collector tests (2026-10-15)

- Windows PowerShell 5.1 elevated under the existing `wispe` identity (`IsInRole(Administrator) = True`) produced `SUCCESS` in the read-only test harness for both BitLocker and Policy, whereas prior unelevated tests returned ACCESS DENIED.
- BitLocker returned two volumes, C: and E:, both FullyDecrypted, protection Off, 0% encrypted, encryption method None and Unlocked. No recovery secrets collected.
- Policy returned 37 result lines for the standalone workstation's computer scope; Local Group Policy was reported Not Applied (Empty).
- **Validation remains open:** GUI and Classic elevated collection and saved/reopened HTML for BitLocker and Policy have not been reported. Existing 18 sections have GUI/Classic HTML confirmation; no promotion of v1.27C completion yet. Additional regression and output-format checks are outstanding.

### v1.27C — Targeted elevation for local BitLocker/Policy (Windows test pending)

- Added explicit GUI **Run selected with UAC** action, scoped to the currently selected Local BitLocker or Policy report. The normal GUI process and all other diagnostics remain non-elevated.
- In Classic, when one of those two local checks returns ACCESS DENIED, offer a Y/N retry through Windows UAC for that section only. A declined prompt keeps the original status.
- Added shared `Invoke-ToolkitElevatedLocalDiagnostic` UAC helper. Child PowerShell runs only the selected read-only local check, with temporary ACL-restricted CLIXML output and cleanup. Results are discarded if UAC runs under a different Windows identity. No passwords, elevation tokens, BitLocker key protectors, or recovery secrets are persisted.
- Elevated results enter existing GUI/Classic report formatting and saving rather than a separate report implementation. **Windows verification pending:** positive, denied, cancel, different identity, saved HTML, GUI responsiveness, and Classic/remote regression. No release completion claimed.

### v1.27C — GUI targeted BitLocker UAC test (2026-10-15)

- **Windows technician confirmation:** Normal GUI's explicit UAC BitLocker action returned SUCCESS with C: and E: volume records under the original Windows identity, establishing successful elevated data return to the GUI without elevating the parent process.
- **Security compatibility observation:** Avast repeatedly attempted to block this UAC handoff; collection nevertheless succeeded. The precise alert/detection has not yet been supplied or assessed. No security exclusions or bypasses are recommended or implemented.
- **Still pending:** GUI Policy UAC, Classic BitLocker/Policy retry, HTML save/reopen for newly elevated results, UAC declined/different-account scenarios, antivirus review, and regression validation. v1.27C is not complete.

### v1.27 — GUI Copy Report action (Windows validation pending)

- Added a far-left **Copy Report** button on the Diagnostics report action row, visually separated from the right-side save format and **Save Report** controls.
- Copies the currently displayed diagnostic output into the Windows clipboard without recollection or a file write. The button is enabled only after a valid report completes and disabled when report state is invalidated; copying checks current target, mode, identity and exact displayed text before proceeding. Clipboard failure is reported without disrupting save functionality.
- Windows GUI positioning, non-elevated and UAC report copying, clipboard/paste, stale-report handling and Save Report regressions remain to be tested. No change to Classic or collection logic.

### v1.27 — Workplace targeted-UAC failure reporting (2026-10-15)

- Technician observed correct non-elevated `ACCESS DENIED` for local BitLocker and Policy on workplace computer `IT-7PY1M84`. Both explicit GUI UAC attempts instead failed without a returned result. This is a **regression/compatibility issue under investigation**, not a successful privileged report test.
- Updated shared UAC helper to report cancelled consent separately, explain process launch exceptions, and include the child exit code when no accessible result exists. It explicitly identifies different-account UAC and endpoint controls as possibilities, not confirmed causes.
- Copy Report was used to share the displayed failure; the workplace test did not establish elevated HTML save/reopen or successful UAC. No workaround to administrative identity protections or endpoint security controls was added. Retesting on authorized Windows environment required.

### v1.27 — Explicit separate-administrator UAC collection (Windows test pending)

- Updated scoped read-only local BitLocker/Policy UAC handoff to accept administrator credentials entered into Windows UAC when they differ from the normally signed-in technician. The elevated child validates its administrator token, and returned data identify **initiating technician** separately from **actual collection identity**.
- Kept a restricted transfer folder, request nonce and section/target/mode validation. Added best-effort child error reporting and rejected results that lack elevation or request provenance. Normal non-elevated behavior, remote authentication and other collectors remain unchanged.
- GUI and Classic now visibly distinguish UAC collection identity without automatically relabeling it as the toolkit's user. No password storage or manual identity fallback added.
- **Pending:** authorized two-account Windows UAC success or actionable failure on a domain workstation, read/write access for the elevated administrator to the child module and temporary folder, HTML report and Copy Report, UAC cancel, endpoint protection compatibility, Classic parity and remote regression. Not promoted to stable.

### v1.27 — Elevated administrator execution-policy detection (2026-10-15)

- Workplace UAC now reaches the explicitly entered administrator identity, but the elevated Windows PowerShell process rejected toolkit module loading because script execution was disabled. The failure occurs before BitLocker or Policy collection.
- Updated the shared UAC helper to distinguish script execution-policy restrictions from a failed collector and provide an actionable message recommending authorized inspection of effective policies and an organization-approved signing/deployment approach. No execution-policy bypass, settings changes or silent account fallback were introduced.
- **Pending:** Resolve authorization through workplace policy, then repeat GUI and Classic positive-path/HTML tests and security regressions. No Windows success is claimed for this new scenario.

### v1.27 — Workplace cross-account UAC success; Policy access denied (2026-10-15)

- On `IT-7PY1M84`, Windows GUI's selected Policy UAC flow completed using separate standard and admin identities. The elevated account's `CurrentUser` execution policy changed from `Restricted` to `RemoteSigned` with approval; the diagnostic module loaded and returned a structured result.
- The underlying computer-scope `gpresult` query returned `ACCESS DENIED`. This is **not** a passed Policy data collection, and does not prove an implementation defect; verify gpresult permissions/RSoP behavior under the elevated token.
- Clarified the GUI Local report banner: diagnostic queries are read-only, but a separately approved persistent PowerShell execution-policy configuration change may have occurred and is disclosed in the report.
- GUI HTML save/open, workplace BitLocker UAC, Classic parity, and broader remote/security regression still require validation.

### v1.27 — Workplace GUI BitLocker cross-account UAC validated (2026-10-15)

- **Windows tested, SUCCESS:** `IT-7PY1M84` GUI BitLocker, initiated by standard `COCHISE\ccollins` and collected after Windows UAC authorization under `COCHISE\CCollinsadm`. Report preserved both account identities, collection status `SUCCESS` and volume findings (C: 100% encrypted, protection on, XTS-AES-256).
- Confirmed persistent administrator `CurrentUser` execution policy needed no repeat modification: RemoteSigned → RemoteSigned, changed False.
- **Still pending:** GUI Save HTML/reopen for this elevated report, Classic elevated reporting, cancellations, regression/security checks. Policy's `gpresult` query returns Access Denied even in a separately elevated administrator PowerShell session; preserve accurate failure rather than claim successful Policy data collection.

### v1.27 — Local snapshot support implemented (2026-10-15; Windows validation pending)

- Removed the local snapshot block in GUI and Classic. Expanded the shared seven-category structured GUI collector to support `Local`, keeping existing Default/Alternate remote paths unchanged. Local captures query WMI on the current system and enumerate installed software through the local registry.
- Classic Create Snapshot now uses the same schema-compatible collector and archive naming; its optional saved-report snapshot sidecar also supports Local Computer. Target and identity checks prevent labeling a different computer or administrator identity as the local collector. Failed categories remain unavailable/NOT COMPARABLE, and all-failed collection is not saved.
- **Release candidate revoked:** workplace checklist previously completed did not include successful local snapshot creation/comparison. Must validate GUI and Classic local snapshot creation, save/reload, two-snapshot comparison, partial failures, permissions and remote snapshot regression on Windows before promoting to production `main`.

### v1.27 — Local and remote snapshot capture verified on Windows (2026-10-15)

- **Technician-confirmed PASS:** local snapshot creation now works following the new Local collector integration.
- **Technician-confirmed PASS:** remote snapshot creation still works after the change, supporting basic remote regression compatibility.
- Snapshot comparison correctness, failure-category handling, archive reload, and optional Classic report snapshot sidecar are not independently confirmed by this report; retain these as final release-review checks rather than claiming they passed.
- Development remains on `develop/v1.27`; stable production `main` is unchanged.

### v1.27 — Elevated PowerShell built-in Tools entry (2026-10-15; Windows test pending)

- Added **Windows PowerShell (Administrator)** to the shared GUI/Classic built-in Tools catalog; it can also be pinned as a Favorite without affecting the existing normal Windows PowerShell entry.
- GUI and Classic require explicit user confirmation and use Windows UAC (`Start-Process -Verb RunAs`) to launch an independent elevated PowerShell 5.1 console, without elevating the toolkit, substituting remote credentials, collecting passwords, or changing execution policy.
- **Validation pending:** Windows approved/denied UAC flows, separate admin account identity and token, GUI and Classic launch, Favorite shortcut, and non-elevated PowerShell regression. Not promoted to stable `main`.

### v1.27 — Health analysis restored to active milestone; first dashboard increment (2026-10-15)

- Added a shared, read-only `ITToolkit-HealthAnalysis.ps1` engine to interpret structured local Health collector evidence. Produces review observations, unavailable checks, explanatory evidence and investigative next steps; does not equate successful collection with a healthy system.
- GUI local Health report includes formatted analysis, and Dashboard now displays a last-local-health review/available/unavailable summary. Classic local Health reports use the same analysis engine.
- Coverage in this increment is limited to system-drive capacity, automatic-start services, and last-day System critical/error events. Other collector categories and remote analysis are not yet analyzed. **Windows validation required** for local GUI/Classic presentation, report save/open, missing evidence and regression paths. v1.27 is **not ready for release** until the dashboard work is completed and verified.
- Separately, technician confirmed the Windows PowerShell (Administrator) launcher works as intended in Windows; no claim of exhaustive cancellation/favorite tests.

### v1.27 — Dashboard health category presentation and local-mode text (Windows validation pending)

- Replaced the single-line-only health presentation with Dashboard counters for review, available and unavailable local Health checks, plus evidence-specific Storage, Services and Events category details from the completed report.
- Labeled System, Security and Updates explicitly **Not assessed** pending expanded evidence collection; avoids presenting uncollected evidence as passing. Health detail counters and category findings clear on target change.
- Updated the stale local-mode detail in GUI and Classic: all 20 direct-local diagnostics and local snapshots are implemented; selected privileged checks may require explicit UAC.
- Reused the shared Health report in both interfaces without changing remote diagnostic collection. **New GUI layout and displayed category extraction await Windows verification.**

### v1.27 — Remote computer Health Dashboard parity (Windows validation pending)

- Corrected the local-only dashboard implementation: Health analysis now processes credential-scoped remote Health evidence from Default and Alternate collection paths without substituting local data or implicitly changing authentication.
- Added shared remote analysis for disk capacity, automatic services and 24-hour bounded System event counts. Remote failures and malformed evidence remain Unavailable; ADMIN$ is not inferred from health probes, and no overall health score is generated.
- GUI Health cards now support local or remote results and retain selected target, auth mode and requested identity; changes clear prior health evidence. Classic Default and Alternate remote Health reports now include the same analysis. Remote Default retains its existing main report and labels the independently collected WinRM evidence.
- **Not Windows-validated yet:** remote Health rendering, WinRM-unavailable cases, alternative identity and target switching, saved reports, full Classic/GUI parity. Local disk-review threshold is 10%, remote's existing health threshold is 15%; align rules in a later focused change after validation.
