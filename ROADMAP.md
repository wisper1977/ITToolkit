# IT Toolkit Development Roadmap

> **Current development:** v1.27 on `develop/v1.27`. **Stable production:** v1.26 on `main`. Work listed here is not considered released until the relevant Windows tests, regression checks, and release approval are complete. See [CHANGELOG.md](CHANGELOG.md) for implementation history and individual test results.

This roadmap tracks **current capabilities, remaining validation, and planned work** rather than a running diary of individual collectors. Milestone scope and ordering may change based on Windows test results.

## Development overview

| Milestone | Scope | Status |
| --- | --- | --- |
| **v1.27 — Current development build** | GUI/Classic parity, direct-local diagnostics and snapshots, scoped UAC, and evidence-based health dashboard | **In progress — first health analysis increment implemented, Windows validation pending** |
| **Future — Technician-confirmed Quick Fix** | Explicit, authorized repairs with a preview, consent and verification | Planned; version unassigned |
| **Future — NIST / Best Practices Computer Check** | Read-only, versioned Windows configuration/security posture checks | Planned; version unassigned |

## v1.27 — Current development build

**Goal:** Improve the technician experience while preserving existing remote diagnostics, authentication behavior, and parity between GUI and Classic. Keep read-only collection separate from future repair actions.

### Implemented development work

- **GUI usability and preferences:** Refined Dashboard and Tools layouts, multiline favorite/tool labels, narrower-window text handling, remembered window size/position/maximized state and last open page. Invalid or off-screen placement falls back safely; reopening does not silently reconnect a previous target.
- **Classic navigation and interface switching:** Sequential Classic menu numbers and GUI ↔ Classic switching under the current Windows identity. GUI switch control is placed at the bottom of the sidebar below Target Computer. Neither target selections nor alternate credentials transfer silently between interfaces.
- **Shared diagnostic results and reporting:** Common status semantics and explicit errors across supported paths, including `Success`, `NoData`, `Review`, `Partial`, `Unavailable`, `AccessDenied`, `NotTested`, and `Unknown` as applicable. Saved HTML/CSV/TXT reporting and snapshots must preserve the actual collection scope, result and identity; a successful query is **not** a system-health verdict.
- **Direct-local diagnostics in both interfaces:** Explicit **Use Local Computer** mode uses local PowerShell, CIM/WMI, registry and Windows utilities without requiring local WinRM or `ADMIN$`. All **20 report sections** now have read-only local collectors through the shared implementation: **Health, System, Hardware, Network, Storage, Services, Events, Policy, Users, Groups, Shares, Software, Updates, Tasks, Administrators, Sessions, SharePermissions, Firewall, BitLocker, and Startup.** Unsupported or inaccessible evidence is reported honestly rather than interpreted as healthy.
- **Scoped privileged local collection:** BitLocker and Policy can request explicit Windows UAC approval for the selected local diagnostic without elevating the entire GUI or Classic application. The handoff accepts a separately UAC-authorized administrator identity while recording both the initiating technician and actual collector, restricting and cleaning temporary output. With separate, explicit confirmation, the elevated account may have its own `CurrentUser` PowerShell execution policy changed from effective `Restricted` to `RemoteSigned` if no Group Policy scope controls it. This is a persistent administrative-account configuration change, distinct from the otherwise read-only diagnostic; the normal non-elevated workflow and remote authentication remain unchanged. Passwords and recovery secrets are not stored.

### Pending report-opening compatibility validation

- Verify GUI recent-report and Reports archive Open Report actions after the direct Microsoft Edge HTML launch change (following an unsuccessful shell `Open` verb attempt), especially when the GUI is started through the alternate-credentials launcher. Confirm behavior with HTML reports and relevant other saved formats, and regress the normal-account path. **Windows technician confirmed:** The updated development GUI now opens HTML reports through the administrative-credential launch path on the affected workstation. Separate Dashboard/archive verification, non-HTML formats and broader regression testing remain pending.

### Windows validation completed

- **GUI/Classic and HTML:** **18 of 20** local sections have successfully collected on Windows in both interfaces, with saved HTML reports reopened. This covers every section **except BitLocker and Policy** for their GUI/Classic elevated positive-path and report-flow tests.
- **All 20 collectors:** Every local collector has returned a successful read-only result in an authorized Windows PowerShell 5.1 command-line test. BitLocker and Policy returned `ACCESS DENIED` under a non-elevated token and `SUCCESS` with the same identity explicitly elevated.
- **Targeted GUI elevation:** BitLocker's **Run selected with UAC** successfully returned C: and E: volume data to the normal GUI. The parent GUI remained non-elevated. This establishes the collection/display path, **not yet the saved elevated HTML or full cross-interface workflow**.
- **Core interface behavior:** GUI window preferences and layout, Classic menu/navigation, and basic GUI ↔ Classic switching have had Windows checks. Broader regression coverage remains open.

Results above describe **tested behavior, not a completed release**. Historical test-by-test evidence is maintained in [CHANGELOG.md](CHANGELOG.md).

### Workplace test completion reported (October 15, 2026)

The technician confirmed completion of the agreed workplace checklist after successfully validating GUI cross-account BitLocker and Classic/GUI switching. This confirmation covers the previously requested Classic BitLocker UAC path, honest Policy access-denied reporting, UAC cancellation, GUI HTML save/reopen and Recent Reports/Archive, Copy Report, CSV/TXT, Default/Alternate remote authentication, identity/target isolation, GUI preferences, local independence from WinRM/ADMIN$, and endpoint-security compatibility. These are **technician-reported results**, not an automated test suite or independent reproduction; individual logs were not supplied for every check.

**Known limitation remains:** computer-policy `gpresult /SCOPE COMPUTER /R` returns `ACCESS DENIED` even in the authorized elevated administrator console on the tested workstation. The toolkit should preserve this error rather than mark the underlying Policy evidence as successful.

**Release gate:** v1.27 may be considered a release candidate based on reported workplace tests. Do not modify production `main` before explicit approval and a final branch/version review.

### Release-candidate review and historical test checklist


**Validated October 15, 2026:** Separate-account GUI BitLocker UAC collected actual C: encryption data successfully on workplace computer IT-7PY1M84. It correctly distinguished initiating and elevated identities and did not repeat the previously approved RemoteSigned change. Still pending: saved reports, Classic elevation, cancellation and broader regression tests. Computer-policy retrieval separately returns Access Denied even when gpresult runs in an elevated administrator console.

1. **Finish privileged diagnostic workflows:** Test GUI Policy with UAC; save and reopen elevated BitLocker and Policy HTML reports; test Classic's BitLocker/Policy ACCESS DENIED → explicit UAC retry → result/report flow. Verify cancelled UAC, distinct-account collection provenance, optional RemoteSigned approval/decline, Group Policy protection, and unchanged ordinary non-elevated behavior.
2. **Review antivirus interoperability:** Avast attempted to block the elevated BitLocker helper although the query succeeded. Capture the exact detection and review the signed/known code path and process launch design before considering changes. Do **not** disable protections or assume the detection is a false positive.
3. **Verify report/snapshot and status behavior:** Exercise HTML/CSV/TXT formats, local-vs-remote labeling, target/identity change protections, available/no-data/partial/denied results, snapshots and comparisons. Local snapshot handling should remain explicitly unavailable wherever it has not been implemented and verified.
4. **Run broader regression tests:** Recheck existing GUI and Classic remote diagnostics, Default/Alternate credential selection, no silent identity fallback, interface switching, target selection, and error handling on authorized Windows test environments. Confirm local checks remain independent of WinRM and `ADMIN$`.
5. **Release gate:** Complete appropriate Windows-specific checks, record results and unresolved limitations in [CHANGELOG.md](CHANGELOG.md), synchronize [README.md](README.md), and obtain approval before any promotion to production `main`.

### Security and behavior boundaries

- Current-user collection stays the default; privileged checks require deliberate, authorized UAC consent and a real elevated process token. A separate persistent `CurrentUser` RemoteSigned change is permitted only with explicit approval when effective policy is Restricted and policy governance checks permit it. Passing a `PSCredential` to an ordinary local cmdlet is **not** elevation.
- Do not silently switch to another authentication identity, expose secrets in reports, or fall back from a failed privileged/remote query to local information.
- Keep diagnostics read-only. Local failures, skipped checks and partial data are not evidence of a healthy system; observed findings (such as stopped services, event errors, or unencrypted volumes) need context before interpretation.
- Preserve working GUI/Classic functionality, remote support and report provenance during incremental changes.

## v1.27 — Evidence-based health dashboard

**Goal:** Give useful, defensible interpretations of successfully collected evidence rather than a simplistic health score.

- Summarize observed findings from supported local and remote diagnostics with clear source, time range and scope.
- Keep unavailable, failed, no-data and not-applicable checks separate from confirmed normal observations.
- Explain what warrants review and provide practical next investigative steps without overstating severity or certainty.
- Integrate results into Diagnostics and reports, with any Dashboard summary optional and unobtrusive.
- **First implementation committed (Windows validation pending):** Shared local Health interpretation for system-drive capacity, automatic-start service observations, and bounded System event counts. Both GUI and Classic append explanatory findings to local Health reports, with a last-analysis summary on the GUI Dashboard.
- **Remaining v1.27 work:** Validate local GUI and Classic display, saved reports, partial/unavailable cases, target and identity changes. Extend analysis carefully into other 20 local sections and compatible remote evidence without mistaking status `SUCCESS` for healthy configuration. Provide richer category grouping and drill-down evidence before release.

## Future — Technician-confirmed Quick Fix

**Goal:** Offer a shared, deliberately invoked repair workflow in GUI and Classic. **Never perform a fix automatically** because a diagnostic produced a finding.

Possible authorized actions include flushing DNS on the **selected machine**, restarting Print Spooler or another selected service, Windows Update service remediation, appropriate SFC/DISM checks or repairs, and approved WinRM configuration. DHCP renewal, adapter changes and reboots require stronger disruption safeguards.

Before any action, verify target and account, supported management transport and privileges; show the proposed change and risks, obtain explicit technician consent, record the outcome and collect verification evidence. **Do not bootstrap WinRM over WinRM**: if WinRM is disabled remotely, use another approved management path or explain that remote repair cannot run.

## Future — NIST / Best Practices Computer Check

**Goal:** A read-only Windows configuration/security posture assessment using shared local and remote evidence. **This would not certify overall NIST or organizational compliance.**

- Select OS-appropriate, versioned Microsoft/security baselines and map checks to relevant published benchmarks and controls (including suitable NIST checklist guidance).
- Candidate areas: administrative identities, UAC and account policy, firewall, BitLocker, Microsoft Defender, auditing, installed updates, RDP/WinRM, SMB, and observable password/lockout configuration.
- Report **Pass**, **Finding**, **Not Applicable**, or **Unable to Verify** with evidence, scope, baseline version and actionable context.
- Handle domain-managed policies, authorized exceptions, operating-system roles and controls that cannot be verified from one endpoint.
- Keep checks read-only; any future remediation belongs in a separate, technician-confirmed Quick Fix flow.

## Additional proposals

Unscheduled possibilities include expanded DNS/routing and multi-NIC diagnostics, improved inventory and snapshot comparisons, and clearer ticket-ready reports and work-order summaries.

## Development and release rules

- GitHub is authoritative. Make changes on the latest active development branch, **not** production `main` without explicit authorization.
- Favor focused shared implementations and equivalent GUI/Classic behavior; preserve existing functions and credentials.
- Keep [README.md](README.md), [CHANGELOG.md](CHANGELOG.md) and this roadmap synchronized. Use the changelog for detailed dated implementation and verification history instead of repeating it here.
- Do not declare Windows-specific functionality fully validated until it has actually been tested on Windows; report commit references and outstanding tests after changes.

**v1.27 GUI usability addition (Windows validation pending):** Added a far-left **Copy Report** action to Diagnostics for copying the exact displayed result without running or saving again. Existing Save Report and format controls remain on the right. Verify layout, clipboard paste, disabled/stale-report handling, privileged-result copying, and save regression on Windows before signing off.

**Workplace targeted-UAC validation blocker (2026-10-15):** Normal GUI BitLocker and Policy on `IT-7PY1M84` returned expected ACCESS DENIED. Explicit UAC requests for both ended without accessible results, unlike the prior home GUI BitLocker success. Updated UAC error reporting distinguishes cancelled approval, process-start errors and child exit code on missing results. Cause remains unverified (check UAC account identity and enterprise endpoint controls without disabling protections). Copy Report was successfully used to capture the displayed error. Confirm elevated GUI/Classic results, HTML output and security compatibility before closing v1.27.

**v1.27 two-account UAC improvement (Windows validation pending):** Explicit BitLocker/Policy UAC collection now supports a different Windows-authorized administrator account and preserves both initiating and collection identities in GUI/Classic. The child confirms administrator elevation; transfer permissions remain restricted and the parent validates the returned request metadata. Test with an authorized standard-user plus separate-admin workplace account, including restricted profile paths, UAC cancellation, antivirus controls, copied/saved HTML reports and remote regressions before release. No credentials are stored or silently substituted.

**v1.27 workplace UAC blocker (2026-10-15):** Separate administrative UAC sign-in reaches the elevated PowerShell child, but that account's effective script execution policy blocks loading the local diagnostic module. The helper now explicitly reports this security-policy restriction. Supported remediation requires an approved script-signing/deployment or execution-policy configuration decision; no automatic bypass. Workplace GUI/Classic privileged collection remains unvalidated until approved execution and report-save testing pass.

**v1.27 workplace UAC validation (2026-10-15):** Separate-account GUI Policy UAC completed on `IT-7PY1M84`; the elevated admin's `CurrentUser` PowerShell execution policy was explicitly changed from Restricted to RemoteSigned and the shared collector ran. The computer-scope gpresult query itself returned ACCESS DENIED, so positive Policy data collection remains open. Next verify gpresult/RSoP access under authorized admin context; then test workplace BitLocker UAC, GUI HTML reports, Classic parity, cancellation, and remote regressions. The GUI report banner now distinguishes read-only diagnostics from an explicitly approved persistent policy change.

### Reopened v1.27 release gate — local snapshots

The user identified a missing workflow after the previous workplace validation checklist: **local snapshot capture** was blocked in both interfaces. Local seven-category snapshot capture has now been implemented using the existing SchemaVersion 1 comparison inventory with direct-local WMI/registry access. The Classic saved-report snapshot option now uses the same local capture method. **Release-candidate status is withdrawn until Windows testing is complete.** Required tests: GUI local snapshot creation, same-host baseline/current comparison, Classic local snapshot creation and optional saved-report sidecar, archive compatibility, category error handling, target/identity provenance, and remote Default/Alternate snapshot regressions. The known computer Policy gpresult Access Denied remains a separate Windows permission restriction.

**Windows snapshot verification (2026-10-15):** Technician confirms both local and remote snapshot capture work following the new seven-category local collector integration. Mark the primary local-capture and basic remote-regression tests as technician-verified. Two-snapshot comparison correctness, archived snapshot reload, partial/inaccessible category behavior, and optional Classic saved-report sidecar still require explicit verification before v1.27 promotion. Development branch only; stable `main` unchanged.

**v1.27 final Tools addition (Windows validation pending, 2026-10-15):** A shared **Windows PowerShell (Administrator)** launcher has been added to GUI/Classic Tools and Favorites. It prompts for explicit approval and delegates administrator authentication to Windows UAC, opening a separate elevated Windows PowerShell 5.1 process without elevating IT Toolkit or reusing remote credentials. Before release, verify GUI and Classic launch, Favorite pin, admin identity/token, declined or cancelled UAC, normal PowerShell launch, and no change to user settings or remote authentication. Production `main` remains untouched.

**Dashboard presentation increment (Windows validation pending):** GUI displays three actual local Health evidence categories (Storage, Services, Events) with counts and findings instead of only a summary sentence. System, Security and Updates are explicitly marked **not assessed** until source diagnostics are integrated; a successful collector query is not a passed health check. Both interfaces now describe direct-local and snapshot support accurately. Next milestone: Windows validate the dashboard cards and target switching, then add explicitly sourced System, Security, Updates and broader cross-section evidence without claiming checks ran when they did not. Full Classic analysis parity remains a release requirement.

**Remote dashboard integration (implementation committed; Windows tests pending):** The previous Dashboard health summary was local-only. Shared evidence-based interpretation now supports existing remote Health collector results with Default and Alternate authentication, and GUI + Classic use the same analysis. The remote adapter supplies disk free percentage, automatic service count and 24-hour bounded System error-event count; failures remain unavailable, and current selected remote identity/target is preserved. The Default report retains original content plus clearly labeled remote WinRM evidence. The difference between the local 10% disk-review threshold and remote adapter's existing 15% threshold must be deliberately resolved. Release testing must include remote Default and Alternate WinRM, refused access, identity/target changes, saved output, Classic parity and other 20-collector regression.

**GUI Health placement refinement (implemented, Windows test pending):** Local and remote Health dashboard evidence was confirmed by technician screenshots. To reduce crowding, health indicators were moved from the wide Dashboard page into a compact, independently scrollable left-sidebar panel below the target card; the Classic switch remains bottom anchored. Before release, verify sidebar layout on the workplace machine, narrow windows, scrolling, long evidence, identity/target changes, saved reports and Classic parity. Health interpretation remains limited to Storage, Services and Events until additional source evidence is integrated.

**Small-window GUI regression (fixed in development; Windows retest pending):** Compact-window screenshot confirmed scrolling the combined sidebar could hide Dashboard/Diagnostics/Tools navigation. New Grid layout keeps navigation, target status and Switch to Classic visible while only the Health evidence pane scrolls. Validate on Windows at minimum window dimensions, resized and maximized sizes before release. Current Health evidence and Classic reports remain unchanged.
