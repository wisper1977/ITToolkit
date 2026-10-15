# IT Toolkit Development Roadmap

> **Status:** Planning document for future work on `develop/v1.27` and later versions. None of the features listed here should be treated as shipped until implemented, tested on Windows, and recorded in [CHANGELOG.md](CHANGELOG.md). The stable production release remains v1.26 on `main`.

This document describes proposed work, design requirements, dependencies, and deferred validation. Milestone names and sequencing may change as testing reveals new requirements.

## Development sequence

| Milestone | Focus | Status |
| --- | --- | --- |
| v1.27B | Shared diagnostic result handling and cross-interface validation | In progress |
| v1.27C | Local computer diagnostics in GUI and Classic | In progress — System, Firewall, and Services implemented in both; independent Windows Services collector test passed, switch and report-save tests pending |
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

**Classic Local Services verified by technician; menu-navigation changes and new bidirectional GUI/Classic switching implemented pending Windows verification.** Classic menu options are now sequential (1–14). Switching launches the other interface with the current Windows identity without copying target selections or alternate credentials. Both switch directions and regressions must be Windows-tested.

**GUI Local Services verification (2026-10-14):** GUI Local Services output matched independent collector results: `SUCCESS` / `Success`, 324 queried and seven automatic-start services not running, with the individual service records displayed. GUI Services save/reopen, Classic Services, negative paths, and remote regression remain pending.
