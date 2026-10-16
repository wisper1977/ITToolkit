# Changelog

Changes to **IT Toolkit** are documented by release version. Development changes for v1.27 are recorded together under **1.27**, not as separate lettered releases. Windows testing and remaining limitations are distinguished from implemented code.

The toolkit targets Windows PowerShell 5.1, with a WPF graphical interface and a Classic text-menu interface.

## [1.27] — In development (not released)

### Windows validation update — October 15, 2026

- **Home GUI UAC BitLocker verified:** Technician confirmed `DESKTOP-8EHGAPD\wispe` launched a local BitLocker check through explicit Windows UAC and received a `SUCCESS` report under the same account. C: and E: reported FullyDecrypted, Protection Off, 0% encryption, and no encryption method. The report showed RemoteSigned → RemoteSigned, with no CurrentUser execution-policy change. Local Policy also succeeded through UAC. These validate the tested same-account paths, **not** separate-admin UAC, cancellation handling, or other Windows configurations. The earlier no-result error was not reproduced after the instrumentation change; its underlying cause remains unconfirmed.

### Changed

- **Mutually exclusive selected-check actions (technician-confirmed on home Windows GUI):** GUI now hides **Run selected check** whenever the existing scoped **Run Elevated (UAC)** action is shown for local BitLocker or Policy under a non-elevated token. Other local/remote checks and already-elevated processes retain **Run selected check**. No diagnostic execution, credential handling, elevation scope, or Run all behavior was changed.

### Added

- **Shared execution-context foundation (Windows validation pending):** Added `Modules/ITToolkit-ExecutionContext.ps1` with an explicit validated launcher mode, actual process Windows identity/SID, administrator token state, and process session ID. GUI and Classic load the same module, and the mode follows GUI ↔ Classic switching without forwarding credentials or target state. Direct script execution defaults to Current mode. The launcher passes a non-secret mode argument. Mode is informational and never grants privileges; remote Default/Alternate selection and UAC remain separate. Existing GUI UAC visibility uses the shared token-elevation evidence.


- **Execution Mode dropdown (Windows validation pending):** Replaced the temporary current-user checkbox in the WPF launcher with three remembered choices: **Current Windows User**, **Separate Administrative Account**, and **Standard Session + On-Demand Administration**. The latter two current-token modes (Current and On-Demand) inherit the launcher's token and disable username/password fields; Separate Account retains the explicit credential process launch. On-Demand uses only the toolkit's existing explicitly authorized Alternate-credential and UAC operations, not an automatic privilege broker. Saved earlier checkbox preferences are migrated; passwords are never persisted. Both GUI and Classic start from the chosen process context. No change to collectors, remote authentication, or Explorer desktop handoff.


- **Launcher execution mode (Windows test pending):** Added an explicit **Run as my current Windows user** checkbox for GUI and Classic. Checked mode starts without a second account or password and inherits the launcher's existing Windows token; unchecked mode retains the previous separate-account credential launch. The non-secret mode preference is stored per launcher user. No identity escalation, token handoff, or remote diagnostic credential change is implied. The separate-admin Reports-folder Explorer issue remains unresolved.

- **Direct-local diagnostics:** Introduced explicit **Use Local Computer** mode and shared, read-only collectors for all 20 categories: Health, System, Hardware, Network, Storage, Services, Events, Policy, Users, Groups, Shares, Software, Updates, Tasks, Administrators, Sessions, SharePermissions, Firewall, BitLocker, and Startup. Local collection uses the current Windows identity and does not require local WinRM or `ADMIN$`.
- **Local snapshots:** Added seven-category direct-local snapshot capture through the existing schema and archive workflow, including GUI and Classic capture paths and an optional Classic saved-report snapshot sidecar. Existing remote snapshot capture is preserved; evidence from inaccessible categories is not silently treated as comparable.
- **Scoped local administrator checks:** Added explicit Windows UAC elevation for selected local BitLocker or Policy diagnostics rather than elevating the toolkit. Supports a different Windows-authorized administrator identity while recording both initiating and actual collector identities. Temporary result transfer is restricted and validated; recovery secrets and credentials are not stored.
- **Conditional PowerShell execution-policy option:** Where the elevated administrator's effective policy is Restricted and neither Group Policy scope controls it, a **separately confirmed** action may set only that account's `CurrentUser` policy to `RemoteSigned`. This is a disclosed persistent change, not a silent bypass or machine-wide change.
- **Elevated PowerShell tool:** Added **Windows PowerShell (Administrator)** to the built-in Tools catalog for GUI and Classic, with explicit confirmation and Windows UAC. It opens a separate console without elevating the toolkit or reusing remote-target credentials. The ordinary PowerShell tool remains.
- **Health analysis:** Added a shared, read-only evidence interpreter used by GUI and Classic. Seven independently assessed observations cover system-drive free space, non-running automatic-start services, recent System critical/error events, OS uptime, Windows Firewall profile status, installed QFE hotfix inventory, and selected pending-restart indicators (CBS, Windows Update, and pending-file-rename registry signals).
- **GUI Computer Health:** Added a compact, independently scrollable health pane beneath the selected target in the left sidebar, with Review / Checked / Unknown counts, category-specific evidence, collection scope, and follow-up guidance. Classic retains the same analysis in its report output without a persistent text dashboard, by design.
- **Report copying:** Added GUI **Copy Report** for the exact displayed diagnostic result with collection-scope protections; copying does not rerun a diagnostic.

### Changed

- **GUI usability:** Improved multiline tool/favorite labels, target and report-name wrapping, dashboard spacing and footer readability. Persisted per-technician GUI window bounds, maximized state, and last page, with off-screen recovery and no automatic target reconnection.
- **Classic menus and interface switching:** Organized Classic choices consistently and provided GUI ↔ Classic switching under the currently authorized Windows identity. Target state and alternate credentials are never silently carried into the other interface; active collection blocks unsafe switching.
- **Shared diagnostic status semantics:** Introduced consistent success, no-data, review, partial, unavailable, access-denied, not-tested and unknown classifications while preserving error details and actual data. No collector success is presented as an overall system-health verdict.
- **Remote health parity:** Extended Health evidence to remote Default and Alternate modes using the selected credential-scoped WinRM path; unavailable remote evidence is not replaced with a local query or another identity. Shared findings appear in GUI and Classic reports.
- **Report formats and access:** Preserved HTML/CSV/TXT saving and report provenance. GUI saved-HTML opening uses explicit Microsoft Edge launch where available, with the Windows shell as fallback; Recent Reports and Reports Archive share the opening workflow.

### Fixed

- **Elevated local diagnostic handoff instrumentation (Windows test pending):** Following a technician test where BitLocker UAC returned process exit code 0 but no accessible result file, added a temporary non-secret child execution-stage checkpoint to the existing restricted ACL folder. Missing-result failures now distinguish no checkpoint, child started, and report write reached. No access-control broadening, credential storage, or changes to UAC/collection behavior; checkpoints are deleted with the handoff directory. The cause of the missing report is **not yet confirmed**.


- **GUI/Classic startup regression — Windows error reproduced (2026-10-15):** The shared execution-context integration assigned to PowerShell's built-in, read-only `$ExecutionContext` automatic variable, causing GUI startup to fail with `VariableNotWritable`. Renamed all application-specific references in both interfaces to `$script:ToolkitExecutionContext`. No security logic or privilege behavior changed. **Windows GUI and Classic launch retest pending.**


- **Context-sensitive UAC action (GUI, Windows test pending):** The existing **Run Elevated (UAC)** diagnostic button is now hidden by default and appears only for local **BitLocker** or **Policy** selections when the current toolkit token is not elevated. Its visibility refreshes on target/section changes, and the handler independently enforces its scope. Windows continues to own UAC approval; no automatic elevation or credential reuse is introduced. An already elevated toolkit uses the normal diagnostic button. Other diagnostics are not represented as having a generic UAC execution path. Classic's existing explicit UAC menu behavior is unchanged pending parity review.

- **Launcher vertical scrollbar (layout change, Windows retest pending):** Increased the default launcher window height and compacted execution-mode, credential, interface, message, and footer spacing. Reduced the optional banner height and constrained the window to the usable screen area. Ordinary desktop layouts should show the full form without a scrollbar; scrolling remains an accessibility fallback on small/high-DPI screens. No authentication or login-mode logic changed.

- Corrected diagnostic exception classification so an RPC/transport error is **Unavailable**, not **Access Denied**, merely because the legacy generic error label contains that phrase.
- Improved scoped UAC failure reporting for cancelled approvals, process-launch failures, script-policy restrictions, and missing elevated results.
- Corrected outdated GUI/Classic messages that had claimed most local diagnostics and local snapshots were unsupported.
- Replaced a crowded full-width health panel with the sidebar card, then kept navigation and selected target visible and **Switch to Classic** anchored at the bottom while only health evidence scrolls. An unnecessary scroll-reset experiment was reverted after the technician clarified the scrollbar had been moved intentionally.
- Prevented a prior target/authentication context's health evidence from being displayed as current after switching targets, modes or identities.

### Windows validation — completed or technician-confirmed (October 14–15, 2026)

- **Local diagnostics:** All 20 direct-local collectors were exercised in Windows PowerShell 5.1; the majority also had successful GUI/Classic and HTML reopen tests. The workplace checklist was technician-confirmed across GUI/Classic functionality, saved reports, UAC cancellation and core authentication regressions. Individual logs were not supplied for every check.
- **Cross-account UAC:** Workplace `IT-7PY1M84` GUI BitLocker succeeded when initiated by standard `COCHISE\ccollins` and collected under Windows-authorized `COCHISE\CCollinsadm`; C: was fully encrypted, XTS-AES-256, protection on. The administrator account had an explicitly approved `Restricted` → `RemoteSigned` CurrentUser change on an earlier run, and later reported no further policy change.
- **Known Policy limitation:** `gpresult.exe /SCOPE COMPUTER /R` returned **ACCESS DENIED** even in an independently verified elevated administrator PowerShell session on the affected workstation. The toolkit must continue reporting this failure and must not claim a successful Policy evidence query there.
- **Snapshots and launcher:** Technician confirmed **local and remote snapshot creation** works. The separate Windows PowerShell (Administrator) tool also launched as intended. Comparison correctness, archive reload and some edge cases have not been independently confirmed.
- **GUI layout:** The technician verified the compact sidebar at regular and smaller window sizes, including independent health scrolling, visible navigation, target status and bottom Classic switch.
- **Seven-check Health GUI:** Technician screenshots showed **7 Checked / 3 Review / 0 Unknown** for local `IT-7PY1M84` and remote `ML-PCSCALE` under Default credentials, with distinct storage/services/system evidence. Both displayed a pending-file-rename review indicator. Technician also reported a successful remote Alternate-mode run on `ML-PCSCALE`; the screenshot verifies populated results but does not independently identify the executing remote security token.
- **Seven-check Health Classic:** Technician confirmed Classic Health reports run and show the expected readings under Local, remote Default and remote Alternate account modes. Classic remains intentionally report-based rather than adding a persistent dashboard.

### Scope decision — diagnostic detail audit assigned to v1.28 (2026-10-15)

- Reserved **v1.28** for a systematic review of completeness and technician usefulness across all 20 diagnostic categories, starting with local-versus-remote Network evidence (`ipconfig` compared with `ipconfig /all`).
- Current remote Network attempts `ipconfig /all` through selected-identity WinRM; local Network currently returns a narrower set of structured adapter fields. This is a planned future audit and **no v1.28 collector code has been implemented** in this change.
- Kept v1.27 focused on remaining health-analysis quality and final release validation; see [ROADMAP.md](ROADMAP.md).

### Report Archive Explorer launch and local snapshot comparison verification (2026-10-15)

- **Fixed in development:** Report Archive **Open Reports Folder** now starts the Windows `explorer.exe` executable with the validated full reports-folder path instead of invoking the folder's shell `open` verb. This addresses the technician-observed `Access is denied` on `C:\GitHub\ITToolkit\Reports` under the alternate-administrator launch context. **Windows retest pending**; the existing Copy Folder Path fallback remains.
- **Verified local snapshot comparison artifacts:** Two uploaded v1.27 SchemaVersion 1 snapshots of `IT-7PY1M84`, Local mode under the same collection identity, have all seven inventory categories present. Their uploaded HTML comparison lists **9 service-property changes** across Services (including BITS State Running→Stopped and StartMode Auto→Manual) and no differences for Software, Updates, Users, Groups, Administrators or Shares. These observations agree with the supplied snapshot values and validate this local baseline/newer comparison and HTML-output case; they do not establish remote, missing/failed inventory, or archive reload edge cases.
- No permissions, user identity, Explorer policy, collector, or production changes were made.

- **Reports-folder Explorer launch follow-up (2026-10-15):** The prior direct `explorer.exe` invocation returned successfully in GUI but displayed no folder in the separately authorized admin workflow. Technician tested the identical PowerShell command with Explorer's `/n,"C:\GitHub\ITToolkit\Reports"` argument and confirmed it opened the folder. GUI Report Archive → Open Reports Folder now uses that tested `/n` form, without altering credentials, directory permissions or the Copy Folder Path fallback. **GUI Windows retest still required**; success in standalone PowerShell does not prove the WPF button path works.

### Reports folder Explorer GUI follow-up — child-process launch (2026-10-15)

- Direct `explorer.exe` launch with `/n` from the Reports button returned without error but still did **not** display a folder in the GUI, although the same command worked interactively under the administrator account. A separate PowerShell process launched from an administrator PowerShell session also opened the folder successfully.
- Changed only the GUI **Open Reports Folder** handler to start an independent, same-identity Windows PowerShell process, which launches Explorer with the tested `/n` argument. The launch command is supplied using Unicode `-EncodedCommand` to retain path quoting, not to bypass execution policy. No credentials, UAC elevation, ACLs, or security policy are changed.
- **Windows GUI validation is pending.** Starting the child process is not proof that the Explorer window appeared. **Copy Folder Path** remains available. Production `main` unchanged.

### Report Archive diagnostic launch result (2026-10-15)

- Technician confirmed the previous separate-PowerShell Explorer attempt **still did not display the Reports folder** from the GUI; GUI status only reported that a launch had been requested.
- Updated the **Open Reports Folder** handler to wait briefly for the child PowerShell process, capture its exit code and standard-error details, and distinguish a completed child (which does not prove a visible Explorer window) from launch failure or timeout. Existing Copy Folder Path remains the workaround. No credentials, ACLs, or execution policies are modified.
- **Windows GUI test pending:** reproduce the failure using the instrumented handler and report the resulting status or error for diagnosis.

### Report Archive folder visibility diagnostics (2026-10-15)

- Added exit-code and stderr reporting for the same-identity child PowerShell that requests `explorer.exe` from GUI Report Archive. Process creation alone is not treated as confirmed folder visibility.
- **Windows technician observation:** the GUI reported `Explorer child completed (exit 0, PID 34660); window visibility not verified`, but the Reports folder did **not** appear. Direct and nested administrative PowerShell launches worked outside the GUI. Thus the GUI Open Folder issue remains unresolved; investigate Explorer desktop session and process ownership before another launcher change.
- **Copy Folder Path** remains functional. No execution-policy, account, ACL, or production-branch changes were made.

### Remaining release checks and limitations

- Validate unavailable/denied and partial Health paths, negative pending-restart indicators, and alternate remote authentication **provenance** where observable. Check latest saved seven-check output in the relevant HTML/CSV/TXT workflows.
- Validate baseline-to-current snapshot comparison, archive reload, partial-category and optional Classic sidecar behavior; verify source-target/identity labeling throughout.
- Reconcile the current local system-drive review threshold (below **10%** free) and remote threshold (below **15%** free) with one documented policy before release; continue regression testing.
- Installed QFE entries **do not** establish missing-update or patch compliance; enabled firewall profiles **do not** establish overall security compliance; pending-file-rename entries **do not** prove Windows Update requires a reboot. Findings are prompts for investigation, not automated repairs.
- v1.27 remains on `develop/v1.27`. Stable production v1.26 on `main` is unchanged; release promotion requires explicit approval. See [ROADMAP.md](ROADMAP.md) for the remaining plan.


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
