# IT Toolkit Development Roadmap

> **Current development:** v1.27 on `develop/v1.27`. **Stable production:** v1.26 on `main`. Work listed here is not considered released until the relevant Windows tests, regression checks, and release approval are complete. See [CHANGELOG.md](CHANGELOG.md) for implementation history and individual test results.

This roadmap tracks **current capabilities, remaining validation, and planned work** rather than a running diary of individual collectors. Milestone scope and ordering may change based on Windows test results.

## Development overview

| Milestone | Scope | Status |
| --- | --- | --- |
| **v1.27 — Current development build** | GUI usability, Classic/GUI navigation, consistent diagnostic results, direct-local diagnostics, and scoped privileged checks | **In progress — implemented; final integration, security and regression validation pending** |
| **Future — Evidence-based health analysis** | Interpret confirmed diagnostic evidence without treating unavailable data as healthy | Planned |
| **Future — Technician-confirmed Quick Fix** | Explicit, authorized repairs with a preview, consent and verification | Planned; version unassigned |
| **Future — NIST / Best Practices Computer Check** | Read-only, versioned Windows configuration/security posture checks | Planned; version unassigned |

## v1.27 — Current development build

**Goal:** Improve the technician experience while preserving existing remote diagnostics, authentication behavior, and parity between GUI and Classic. Keep read-only collection separate from future repair actions.

### Implemented development work

- **GUI usability and preferences:** Refined Dashboard and Tools layouts, multiline favorite/tool labels, narrower-window text handling, remembered window size/position/maximized state and last open page. Invalid or off-screen placement falls back safely; reopening does not silently reconnect a previous target.
- **Classic navigation and interface switching:** Sequential Classic menu numbers and GUI ↔ Classic switching under the current Windows identity. GUI switch control is placed at the bottom of the sidebar below Target Computer. Neither target selections nor alternate credentials transfer silently between interfaces.
- **Shared diagnostic results and reporting:** Common status semantics and explicit errors across supported paths, including `Success`, `NoData`, `Review`, `Partial`, `Unavailable`, `AccessDenied`, `NotTested`, and `Unknown` as applicable. Saved HTML/CSV/TXT reporting and snapshots must preserve the actual collection scope, result and identity; a successful query is **not** a system-health verdict.
- **Direct-local diagnostics in both interfaces:** Explicit **Use Local Computer** mode uses local PowerShell, CIM/WMI, registry and Windows utilities without requiring local WinRM or `ADMIN$`. All **20 report sections** now have read-only local collectors through the shared implementation: **Health, System, Hardware, Network, Storage, Services, Events, Policy, Users, Groups, Shares, Software, Updates, Tasks, Administrators, Sessions, SharePermissions, Firewall, BitLocker, and Startup.** Unsupported or inaccessible evidence is reported honestly rather than interpreted as healthy.
- **Scoped privileged local collection:** BitLocker and Policy can request explicit Windows UAC approval for the selected local diagnostic without elevating the entire GUI or Classic application. The handoff runs only the read-only check, restricts and cleans up temporary output, and rejects results obtained under a different Windows identity. The standard non-elevated workflow remains unchanged. No alternate-account substitution, stored passwords or BitLocker recovery secrets are intended.

### Pending report-opening compatibility validation

- Verify GUI recent-report and Reports archive Open Report actions after the explicit Windows shell `Open` verb change, especially when the GUI is started through the alternate-credentials launcher. Confirm behavior with HTML reports and relevant other saved formats, and regress the normal-account path. The standalone `runas` PowerShell test succeeded, but the updated GUI has not yet been Windows-validated.

### Windows validation completed

- **GUI/Classic and HTML:** **18 of 20** local sections have successfully collected on Windows in both interfaces, with saved HTML reports reopened. This covers every section **except BitLocker and Policy** for their GUI/Classic elevated positive-path and report-flow tests.
- **All 20 collectors:** Every local collector has returned a successful read-only result in an authorized Windows PowerShell 5.1 command-line test. BitLocker and Policy returned `ACCESS DENIED` under a non-elevated token and `SUCCESS` with the same identity explicitly elevated.
- **Targeted GUI elevation:** BitLocker's **Run selected with UAC** successfully returned C: and E: volume data to the normal GUI. The parent GUI remained non-elevated. This establishes the collection/display path, **not yet the saved elevated HTML or full cross-interface workflow**.
- **Core interface behavior:** GUI window preferences and layout, Classic menu/navigation, and basic GUI ↔ Classic switching have had Windows checks. Broader regression coverage remains open.

Results above describe **tested behavior, not a completed release**. Historical test-by-test evidence is maintained in [CHANGELOG.md](CHANGELOG.md).

### Remaining v1.27 release checks

1. **Finish privileged diagnostic workflows:** Test GUI Policy with UAC; save and reopen elevated BitLocker and Policy HTML reports; test Classic's BitLocker/Policy ACCESS DENIED → explicit UAC retry → result/report flow. Verify denied/cancelled UAC and different-account prompts cannot be mislabeled as successful same-identity collection.
2. **Review antivirus interoperability:** Avast attempted to block the elevated BitLocker helper although the query succeeded. Capture the exact detection and review the signed/known code path and process launch design before considering changes. Do **not** disable protections or assume the detection is a false positive.
3. **Verify report/snapshot and status behavior:** Exercise HTML/CSV/TXT formats, local-vs-remote labeling, target/identity change protections, available/no-data/partial/denied results, snapshots and comparisons. Local snapshot handling should remain explicitly unavailable wherever it has not been implemented and verified.
4. **Run broader regression tests:** Recheck existing GUI and Classic remote diagnostics, Default/Alternate credential selection, no silent identity fallback, interface switching, target selection, and error handling on authorized Windows test environments. Confirm local checks remain independent of WinRM and `ADMIN$`.
5. **Release gate:** Complete appropriate Windows-specific checks, record results and unresolved limitations in [CHANGELOG.md](CHANGELOG.md), synchronize [README.md](README.md), and obtain approval before any promotion to production `main`.

### Security and behavior boundaries

- Current-user collection stays the default; privileged checks require deliberate, authorized UAC consent and a real elevated process token. Passing a `PSCredential` to an ordinary local cmdlet is **not** elevation.
- Do not silently switch to another authentication identity, expose secrets in reports, or fall back from a failed privileged/remote query to local information.
- Keep diagnostics read-only. Local failures, skipped checks and partial data are not evidence of a healthy system; observed findings (such as stopped services, event errors, or unencrypted volumes) need context before interpretation.
- Preserve working GUI/Classic functionality, remote support and report provenance during incremental changes.

## Future — Evidence-based health analysis

**Goal:** Give useful, defensible interpretations of successfully collected evidence rather than a simplistic health score.

- Summarize observed findings from supported local and remote diagnostics with clear source, time range and scope.
- Keep unavailable, failed, no-data and not-applicable checks separate from confirmed normal observations.
- Explain what warrants review and provide practical next investigative steps without overstating severity or certainty.
- Integrate results into Diagnostics and reports, with any Dashboard summary optional and unobtrusive.
- **Not yet implemented:** The existing local Health section is a read-only evidence summary, not this planned analysis capability.

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
