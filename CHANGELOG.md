# Changelog

Documented changes to **IT Toolkit** are recorded here. This file distinguishes confirmed release changes from development milestones. Dates are included only where established; historical versions have not been assigned speculative dates.

The project is a Windows PowerShell 5.1 toolkit. The GUI uses Windows Presentation Foundation (WPF); the Classic interface uses a text menu.

## [1.27] — In development (started 2026-10-14)

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

### Planned (not yet implemented)
- **v1.27B:** Shared diagnostic result handling and more consistent status/error reporting across GUI and Classic.
- Later proposals: evidence-based Health Analysis, expanded network diagnostics, snapshot enhancements, and clearer ticket/report summaries.

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
