# Changelog

All notable documented changes to **Cochise County IT Toolkit** are recorded here. This file distinguishes confirmed release changes from development milestones. Dates are included only where established; historical versions have not been assigned speculative dates.

The project is a Windows PowerShell 5.1 toolkit. The GUI uses Windows Presentation Foundation (WPF); the Classic interface uses a text menu.

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

## [1.25.7] — 2026-10-14

**Protected stable baseline before v1.26 development.**

- Unified catalog of **22 tools** across the toolkit's relevant interfaces.
- Synchronized Favorites and custom-tool configuration.
- Refined GUI, reporting, archive, and comparison workflows.
- Improved portable launcher and branding behavior.
- Restored and validated detection of x64 Sysinternals tools.
- Used as the known-working rollback baseline while v1.26 was developed in a separate copy.

## [1.25.0–1.25.6] — Development series, October 2026

**Progressive introduction of the graphical toolkit.** Individual patch-level feature attribution within this range is not fully documented in the available historical material.

- Developed a Windows Presentation Foundation (WPF) launcher, with optional organization logo, background, application icon, and colors.
- Added credential entry, Classic/GUI selection, and per-user preferences for remembered username and preferred interface. Passwords were not intended to be persisted.
- Replaced the initial GUI placeholder with a functional desktop interface for targets, diagnostics, tools, reports, and settings.
- Iterated on target selection, Favorites, custom external tools, report browsing, snapshot comparisons, and general UI integration.

## [1.24] — October 2026

**Modularized the Classic toolkit.**

- Refactored the previously more monolithic Classic program into **seven dot-sourced components**.
- Consolidated configuration around the root `Toolkit-config.json`.
- Corrected configuration-path resolution after modularization.
- Preserved the established Classic menus, diagnostic tools, reporting, and snapshot/comparison functionality.
- Retained v1.23 as the fallback during validation.

## [1.0–1.23] — Earlier development history

**Original Classic PowerShell toolkit and subsequent iterations.**

The original project progressed through numbered releases v1.0–v1.23 before the documented v1.24 modularization. Earlier work established the Classic menu-driven troubleshooting utility and the diagnostics/reporting/snapshot functionality carried forward into v1.24.

A historical master changelog covering v1.0–v1.23 was reportedly maintained during development, but its version-by-version entries are not presently available for independent verification. Rather than assign changes to the wrong versions, this section intentionally remains a historical summary until that original changelog is recovered.

## Release history policy

- **Release versions** describe shipped or protected baselines, not every internal test ZIP.
- **Development phases** (for example v1.26 Phase 3A or Phase 6F) are implementation/test milestones within a release, not separate published versions.
- Future release notes should be added under their exact Git tag, with date, Added/Changed/Fixed/Security categories when applicable.
- Do not treat a diagnostic collection status of **Success** as proof that the target system itself is healthy.

[1.26]: https://github.com/wisper1977/ITToolkit/releases/tag/v1.26
