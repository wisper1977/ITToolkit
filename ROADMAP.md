# IT Toolkit Development Roadmap

> **Status:** Planning document for future work on `develop/v1.27` and later versions. None of the features listed here should be treated as shipped until implemented, tested on Windows, and recorded in [CHANGELOG.md](CHANGELOG.md). The stable production release remains v1.26 on `main`.

This document describes proposed work, design requirements, dependencies, and deferred validation. Milestone names and sequencing may change as testing reveals new requirements.

## Development sequence

| Milestone | Focus | Status |
| --- | --- | --- |
| v1.27B | Shared diagnostic result handling and cross-interface validation | In progress |
| v1.27C | Local computer diagnostics in GUI and Classic | In progress — System, Firewall, Services, Storage, Network, Hardware, Users, Groups, Administrators, Shares, Software, Updates, Tasks, Events and Startup validated locally; BitLocker newly implemented; independent Windows Services collector test passed, switch and report-save tests pending |
| v1.27D | Evidence-based health analysis | Planned |
| Later milestone | Technician-confirmed Quick Fix menu | Planned; version not assigned |
| Later milestone | NIST / Best Practices Computer Check | Planned; version not assigned |

## v1.27B — Finish shared diagnostic result handling

**Goal:** Make diagnostic statuses, categories, and error messages consistent and understandable across the GUI and Classic interfaces, without changing credentials behind the technician's back.

- Keep the raw collector status and actual error details. Distinguish `Success`, `NoData`, `Review`, `Partial`, `Unavailable`, `AccessDenied`, `NotTested`, and `Unknown`.
- Continue cross-interface regression tests on Windows, including representative available, unavailable, no-results, and permission-denied outcomes.
- Validate GUI Alternate and Classic Alternate credentials against an authorized remote target when available. Confirm no silent fallback to the signed-in identity.
- Complete Classic-mode parity testing and regression checks for saved reports, snapshots, and existing diagnostics.
- Record tests in [CHANGELOG.md](CHANGELOG.md). Partial GUI Default validation has been completed; v1.27B is **not yet complete**.

## v1.27C — Local Computer Diagnostics

**Maintenance during this milestone:** Corrected two `ITToolkit-Core.ps1` function names to use approved PowerShell verbs while retaining compatibility aliases for current callers. VS Code/PSScriptAnalyzer and Windows smoke tests remain pending.


**Implementation progress:** Initial shared direct-local System and Firewall collector added in `Modules/ITToolkit-LocalDiagnostics.ps1` (current-user only; Windows collector success paths validated on Windows 11 Pro with WinRM stopped). The second increment adds explicit local target selection in GUI and Classic and routes System/Firewall diagnostic reports to the local collector; unsupported local sections are reported as `NOT TESTED` and local snapshot capture is blocked. **Partial Windows integration validation passed:** GUI local Firewall returned `SUCCESS`, local Users returned `NOT TESTED`, and Classic local reports saved. The GUI Local-mode report-save fix passed a Windows save test using an unsupported Services diagnostic (`NOT TESTED`); the user confirmed successful opening of all saved reports tested. Local Services collection is implemented using `Win32_Service` with a count of nonrunning automatic-start services. Independent Windows testing passed (`SUCCESS` / `Success`, 324 queried, seven not running, no error); GUI report display and Classic local Services execution passed; GUI/Classic report-save validation remains pending. Explicit per-format verification remains outstanding. Further GUI/Classic and remote regression checks remain pending. Still outstanding: remaining local collectors, secure alternate-admin process, full snapshot integration, and regression testing.


**Goal:** Diagnose the machine running IT Toolkit without requiring its remote WinRM or `ADMIN$` endpoints. Use a **shared implementation** in GUI and Classic.

### Target selection and collection

- Add an explicit **Use Local Computer** target option in GUI and Classic. Selecting local mode resolves the local computer name automatically; remote mode keeps its existing target selection behavior.
- Local collection uses suitable Windows local PowerShell, CIM/WMI, registry, and system tools. WinRM must not be a prerequisite for local runs.
- Target all existing 20 diagnostic sections **where supported**, while distinguishing `Not Applicable`, `Unavailable`, and `Access Denied` rather than treating unknown results as healthy.
- Preserve the shared result shape, report formats, and structured snapshots. Mark local versus remote collection clearly without manufacturing a system difference in snapshot comparisons.
- Restore or switch navigation without automatically reconnecting to an earlier remote target.

### Enterprise authentication requirement

- Support **current-user/standard local checks** and an explicitly chosen **alternate administrative identity** for privileged local checks, in both interfaces.
- Privileged local collection requires a distinct properly authenticated process and appropriate access token. Passing a `PSCredential` into an ordinary local cmdlet does **not** elevate it.
- Respect least privilege and separation of standard and administrative accounts (e.g., NIST SP 800-53 AC-6 and NIST SP 800-171 Rev. 3 03.01.06–03.01.07).
- Never silently fall back to Default credentials or change identity; do not store passwords or put credential material in reports.
- Do not claim privileged collection succeeded when authorization failed. Explicit elevation/launch consent and sound process-boundary design need security review.

### Testing

- Test GUI and Classic in local standard and alternate-admin modes, including non-elevated sessions.
- Test switching between local and remote computers, denied permissions, report saving, and snapshots.
- Test against a workstation with WinRM stopped or unavailable; local firewall and other supported checks should still collect directly.

## v1.27D — Evidence-based Health Analysis

- Summarize findings grounded in successfully collected data across local and remote checks.
- Keep failed/unavailable and not-applicable checks separate from healthy readings.
- Present useful diagnostics and suggested next investigation steps without overstating certainty.
- Integrate into existing Diagnostics and reports, with any Dashboard summary optional and unobtrusive.

## Later milestone — Quick Fix menu

**Goal:** A shared, deliberately invoked **repair** workflow for GUI and Classic. Repairs are never triggered automatically by a diagnostic result.

### Candidate fixes

- Flush the DNS resolver cache **on the selected machine**. A technician-side flush does not flush the remote computer's cache.
- Restart Print Spooler or other explicitly selected services.
- Diagnose/recover appropriate Windows Update service issues.
- Run appropriate SFC / DISM checks or repairs with clear duration and permissions warnings.
- Enable/configure WinRM **only with technician approval** and an authorized management path.
- Consider DHCP renewal, network adapter changes, and reboot only with strong disruption safeguards.

### Remote operation and safety

- Check target identity, access rights, transport availability, and required privileges before presenting an action as runnable.
- **Do not attempt to bootstrap WinRM over WinRM.** On a remote machine with WinRM disabled, use another authorized management channel (such as supported RPC/service-management paths or centrally administered policy) or explain why remote repair is unavailable.
- Offer a preview of the proposed action and its risks, require explicit confirmation, and never silently choose different credentials.
- Warn or disable actions likely to break connectivity, especially DHCP renewal, network resets, or restarts on remote systems.
- Record actions, results, errors, and verification evidence for ticket documentation.

## Later milestone — NIST / Best Practices Computer Check

**Goal:** Read-only, evidence-based Windows configuration/security posture assessment in GUI and Classic, using common local/remote collectors. **This cannot certify full NIST or organizational compliance.**

- Select an OS-appropriate, versioned baseline; map each automated check to named benchmark recommendations or NIST controls, using suitable NIST checklist guidance (including SP 800-70 Rev. 5 / National Checklist Program) and relevant Microsoft security baselines.
- Candidate checks: local administrators and privileged accounts, UAC and account policies, Windows Firewall, BitLocker, Microsoft Defender, audit policy, updates, RDP/WinRM exposure, SMB configuration, and observable password/lockout policies.
- Distinguish **Pass**, **Finding**, **Not Applicable**, and **Unable to Verify**; include evidence, mapped source/version, severity where appropriate, and remediation guidance.
- Account for domain-managed settings, documented exceptions, differing OS roles, and checks that cannot be evaluated using host data alone.
- Remain read-only. A future integration may offer a separate, technician-approved Quick Fix based on a finding, never an automatic change.

## Additional proposals

These have no assigned milestone or implementation commitment:

- Expanded network diagnostics, including DNS/routing and multi-NIC troubleshooting.
- Snapshot comparison and inventory improvements.
- Clearer report and work-order/ticket summaries.

## Development and release rules

- Make feature changes only on the active development branch until approved for release.
- Implement GUI and Classic support where specified, preferably using shared collectors rather than duplicating logic.
- Update **README.md**, **CHANGELOG.md**, and this roadmap as milestones change; keep README focused on capabilities that actually exist.
- Verify Windows-specific behavior on a suitable Windows system before claiming a milestone is complete.

**Classic Local Services verified by technician; menu-navigation changes and new bidirectional GUI/Classic switching implemented pending Windows verification.** Classic menu options are now sequential (1–14). Switching launches the other interface with the current Windows identity without copying target selections or alternate credentials. The technician confirmed initial Classic menu and bidirectional switch operation on Windows. Following that confirmation, GUI switch positioning was changed to the bottom of the left sidebar below Target Computer; layout and basic switch test passed on Windows; broader regression testing remains pending.

**GUI Local Services verification (2026-10-14):** GUI Local Services output matched independent collector results: `SUCCESS` / `Success`, 324 queried and seven automatic-start services not running, with the individual service records displayed. GUI Services save/reopen, Classic Services, negative paths, and remote regression remain pending.

**GUI switch positioning validation (2026-10-14):** Technician confirmed the bottom-aligned Switch to Classic control beneath Target Computer works on Windows. Layout and basic switch behavior passed; unrelated regressions remain outstanding.

**Local Services report-saving confirmation (2026-10-14):** Technician reported that saving a Local Services report works. Specific GUI/Classic and HTML/CSV/TXT combinations were not identified; retain explicit per-format coverage and remote regression as pending.

**Local Storage increment (implementation; Windows test pending):** The shared direct-local collector and GUI/Classic local section allowlists now support Storage (fixed logical disks, size/free GB, free percentage). Zero or unknown capacity yields no free percentage; zero returned disks produces `NoData`. Remote diagnostics remain unchanged. Windows test, GUI/Classic reports, report saving and remote regression are outstanding.

**Storage direct collector validation (2026-10-14):** Windows test passed on DESKTOP-8EHGAPD with two fixed logical disks (C: and E:), `SUCCESS` / `Success`, and no error. GUI/Classic and report validation are pending. A root-level `Test-LocalDiagnostics.ps1` smoke-test harness now reloads the latest collector on every execution and defaults to Storage; harness Windows testing is pending. Future diagnostic increments can change the default while preserving the one-command test workflow.

**Storage GUI/Classic Windows confirmation (2026-10-14):** Both interfaces work, and the technician successfully saved and opened an HTML Storage report. CSV/TXT and remote regressions remain pending.

**Local Network implementation (Windows validation pending):** Added shared IP-enabled adapter configuration inventory (addresses, subnets, gateways, DNS, MAC, DHCP) to local GUI/Classic with no remote fallback. Updated single-command test harness default to Network. Network output, report formats, edge cases, and remote regression are still pending.

**Network GUI/Classic validation (2026-10-15):** Technician confirmed both local interfaces display Network successfully and HTML reports save and open. Remaining CSV/TXT and remote regression validation is pending.

**Local Hardware implementation (Windows validation pending):** Shared local CIM collector includes computer, BIOS, CPU, and physical-disk inventory. GUI and Classic local allowlists include Hardware, and `Test-LocalDiagnostics.ps1` defaults to Hardware. Hardware Windows collector and interface validation, saving, and regression are pending.

**Hardware Windows validation (2026-10-15):** Hardware ran and HTML reports saved/opened in GUI and Classic; physical-disk coverage remains an item for later inventory comparisons.

**Local Users implementation (Windows validation pending):** Shared local account inventory using `Win32_UserAccount` with a local-account filter is now wired to both interfaces; the single-command smoke test defaults to Users. User collector and report testing still required.

**Local Users Windows validation (2026-10-15):** Both interfaces ran successfully and HTML reports saved and reopened. Additional format and regression tests remain outstanding.

**Local Groups increment (Windows validation pending):** Added shared direct-local group inventory via `Win32_Group`, returning domain, name, SID and description. Both interfaces now support Groups locally, and the one-command test defaults to Groups. Membership, GUI/Classic Windows testing, report formats and negative-path checks remain outstanding.

**Groups verified (2026-10-15):** Local GUI and Classic reports succeeded, and HTML report save/open succeeded.

**Local Administrators next increment:** Shared direct member inventory of built-in Administrators is implemented for GUI and Classic; nested domain groups are not expanded. Test script defaults to Administrators. Windows validation pending.

**Local Administrators validation (2026-10-15):** Both Windows interfaces worked with a successful HTML report save/open. Two direct Administrators members reported; nested membership not expanded.

**Local Shares implementation (Windows validation pending):** Shared local `Win32_Share` inventory now returns share name, path, description and type in GUI and Classic. Test harness defaults to Shares. Permissions and share accessibility are out of scope; Windows collector, UI, report saving and regression testing remain pending.

**Local Shares verified (2026-10-15):** GUI and Classic reported standard Windows administrative shares and HTML saved/opened. This confirms collection, not network access or share permissions.

**Local Software increment (Windows validation pending):** Shared local inventory reads machine-wide uninstall entries from both native and 32-bit registry views. GUI and Classic now include Software in explicit local collection; `Test-LocalDiagnostics.ps1` defaults to Software. Installation changes are not performed. Windows collector/UI/HTML and edge-case validation remain pending.

**Software Windows verification (2026-10-15):** GUI and Classic completed successfully; HTML saved and reopened. Application inventory returned machine-wide uninstall registry entries.

**Local Updates increment (Windows validation pending):** Shared read-only installed QFE hotfix inventory enabled in GUI/Classic and test harness defaults to Updates. Does not check missing patches or recent update failure events. Windows and regression testing outstanding.

**Local Updates validated (2026-10-15):** Windows GUI and Classic checks and HTML report save/open passed. Six installed hotfix records returned; no compliance or missing-update claim.

**Local Tasks increment (Windows validation pending):** Shared read-only Scheduled Task inventory and individual task-info collection wired into both interfaces; smoke test defaults to Tasks. Windows output, runtime, HTML, permissions and regression checks remain outstanding.

**Local Tasks Windows validation (2026-10-15):** GUI and Classic checks plus HTML report saving/opening passed. Placeholder dates and nonzero scheduler result codes remain raw evidence without automatic health interpretation.

**Local Events implementation (Windows verification pending):** Shared collector now queries last-seven-day System and Application errors, maximum 25 each, and reports per-log status. Both interfaces support Events locally; test harness defaults to Events. Windows report, partial/error behavior, HTML saving, and remote regression remain pending.

**Events Windows confirmation (2026-10-15):** Both interfaces and HTML report save/open passed. System log found 13 errors; Application had no matching errors within the bounded window. DCOM and Windows Update installation findings reserved for evidence-based review.

**Local Startup implementation (Windows validation pending):** Shared read-only `Win32_StartupCommand` collector and GUI/Classic local routing now support Startup; single-command test defaults to Startup. Windows and report regression testing still needed.

**Local Startup confirmed (2026-10-15):** GUI and Classic completed, with successful HTML save/open.

**Local BitLocker next (Windows validation pending):** Shared collector now reports read-only volume protection and encryption state in both interfaces, without retrieving key material; the single-command test defaults to BitLocker. Windows and saved-report tests remain pending.
