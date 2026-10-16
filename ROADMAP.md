# IT Toolkit Development Roadmap

> **Current development:** v1.27 on `develop/v1.27`. **Production:** v1.26 on `main`. This roadmap lists outstanding work and future proposals, **not completed feature history**. Completed implementations, technician-confirmed Windows checks, limitations, and commit history belong under the single **v1.27** entry in [CHANGELOG.md](CHANGELOG.md) (not lettered subversions). The [README.md](README.md) describes current usage.

## Active milestones

| Milestone | Outstanding goal | State |
| --- | --- | --- |
| **v1.27 — Health analysis and release validation** | Validate edge cases, finish evidence interpretation and release checks without breaking GUI or Classic | In development |
| **v1.28 — Diagnostic completeness review** | Audit all 20 diagnostic categories for actionable detail, local/remote coverage and report parity | Planned after v1.27 release |
| **Technician-confirmed Quick Fix** | Explicitly authorized, previewed repairs with post-action verification | Proposed; version unassigned |
| **NIST / Best Practices Computer Check** | Versioned, evidence-backed Windows configuration/security posture assessment | Proposed; version unassigned |

## v1.27 — Remaining work

### Health analysis quality and parity

- **Failure and negative cases:** Exercise inaccessible/denied and partial checks, unavailable WinRM, malformed/missing evidence, and a machine without the selected pending-restart indicators. Confirm unavailable data are not interpreted as healthy, and a detected pending-file-rename operation is not claimed to be an update-required reboot.
- **Credential and target provenance:** Verify requested and actual remote identities where the transport exposes them. Changing target, authentication mode, or credentials must not display or save health evidence from the previous context; no silent local or default-identity fallback.
- **Evidence rules:** Reconcile the current local system-drive review threshold (**below 10%**) and remote threshold (**below 15%**) with a documented rule. Keep installed-QFE inventory distinct from **missing-update compliance**. Do not present enabled firewall profiles as proof of full security compliance.
- **Further analysis, if warranted:** Add only actionable, defensible security posture or Windows Update checks with an authoritative evidence source and clear uncertainty. Do not invent an overall health score or imply comprehensive policy/compliance assessment from seven inventory checks.

### Report, snapshot, and usability regression

- **Startup regression retest:** Verify GUI and Classic launch after replacing the conflicting automatic `$ExecutionContext` variable with `$script:ToolkitExecutionContext`; confirm Current, On-Demand, and Separate Administrative Account modes still launch correctly, then check interface switching.
- **Shared execution-context Windows validation:** Verify all three launcher modes produce correct Windows identity, elevated-token status and session ID in GUI and Classic; verify mode metadata survives GUI ↔ Classic switching and direct script starts default to Current. Check failures and remote Default/Alternate authentication remain independent of launcher mode. No automatic UAC should occur from merely choosing a mode.


- **UAC result-handoff follow-up:** Home BitLocker and Policy UAC runs subsequently succeeded under the same initiating/collecting Windows user (October 15, 2026), with no execution-policy change. Earlier missing-result failure is not explained by this success; capture stage diagnostics if it recurs. Still test UAC cancellation, explicitly authorized separate-administrator UAC, and failure reporting without broadening ACLs.
- **Selected-check button exclusivity (home GUI selection behavior confirmed):** Technician verified the new mutually exclusive button behavior on Windows. Remaining regression coverage: remote targets, already-elevated processes, and busy/completion states.
- **Context-sensitive elevation button validation:** On Windows, check GUI local BitLocker/Policy under non-elevated and elevated tokens, remote-mode and other-category hiding, switching targets and sections, UAC cancellation and reporting. Confirm an elevated standard diagnostic succeeds or accurately reports any access failure; validate Classic's explicit UAC workflow separately. Do not infer needed elevation solely from launcher mode.


- **Launcher layout Windows validation:** Confirm the execution-mode dropdown, username/password, interface selection and buttons are all visible without a vertical scrollbar at normal Windows screen size, both with and without configured banner art. Verify small work areas/high DPI still allow access to all controls and changing modes does not clip explanatory text.

- **Launcher execution-mode Windows validation:** Verify remembered dropdown modes in GUI and Classic: Current and On-Demand inherit the launcher identity without a second password; Separate Account still launches using the authorized account. Check dynamic field enablement, legacy checkbox preference migration, reload, non-admin tokens, explicit UAC/Alternate diagnostics in On-Demand, and no credential spillover. The separate-account Explorer desktop handoff remains unresolved.

- **Health reports:** Verify latest seven-check findings and collection provenance in GUI and Classic saved HTML/CSV/TXT, Copy Report, Recent Reports, and archive opening. Confirm partial/denied statuses survive formatting.
- **Report Archive folder button — unresolved:** Windows GUI child PowerShell exited with code 0, but Explorer did not display the folder. Manual and nested launches worked outside the GUI. Compare GUI/Explorer process owners and session IDs, investigate the desktop handoff, and verify a visible window before closing this item. Preserve Copy Folder Path.
- **Snapshots:** Local two-snapshot same-target comparison and its saved HTML report were confirmed from the technician's uploaded artifacts (nine service-property differences, no changes elsewhere). **Still check:** remote comparison, archive reload, partial/inaccessible categories, optional Classic report-sidecar creation, and target/identity mismatch protections. Local and remote capture was already technician-verified.
- **Privileged diagnostics:** Preserve separate-user UAC provenance and explicit consent behavior; test residual edge cases including cancellation and enterprise security controls as needed. On the tested workstation, computer-scope `gpresult /SCOPE COMPUTER /R` returns **ACCESS DENIED** even independently under an elevated administrator account; keep reporting that limitation rather than treating it as a successful Policy result.
- **UI/Classic regression:** Check compact and maximized GUI sizing, independently scrollable health evidence with fixed navigation/target/Classic switch, ordinary and alternate credential modes, normal and elevated PowerShell Tools launch, and retained Classic reporting behavior.

### Release gate

- Record Windows test evidence and outstanding limitations in [CHANGELOG.md](CHANGELOG.md), update [README.md](README.md) where functionality or usage changes, and resolve significant regressions.
- Obtain **explicit release approval** before version promotion or any changes to production `main`.

## v1.28 — Diagnostic completeness and quality audit

**Goal:** Ensure every diagnostic delivers the information an IT technician needs to investigate the target, rather than merely completing a successful collection.

- **Inventory all 20 diagnostics:** For each category, document the current GUI and Classic output, direct-local and remote Default/Alternate sources, missing fields, permissions, error cases, and differences between local and remote results. Prioritize technician usefulness and actionable context.
- **Network first — `ipconfig` versus `ipconfig /all`:** Audit IPv4/IPv6, adapter identity and status, per-adapter DNS and connection suffixes, domain/DNS suffix search lists, gateways, DHCP state and servers, lease obtained/expiry, MAC, routing-related indicators, and meaningful disabled/disconnected-adapter evidence. Existing remote Network already attempts `ipconfig /all` via credential-scoped WinRM; local Network currently emits a smaller structured CIM/WMI inventory. Design a consistent, readable schema and document any unavoidable source differences.
- **Then audit each remaining diagnostic:** Confirm that System, Hardware, Storage, Services, Events, Policy, Users, Groups, Administrators, Shares, SharePermissions, Software, Updates, Tasks, Sessions, Startup, Firewall, BitLocker and Health expose sufficient details for practical troubleshooting. Record any desired additional evidence without assuming it can be read from every target.
- **Output and parity:** Decide where structured values, concise summaries, and full command output are most useful. Avoid walls of irrelevant data or duplicating the same evidence. Preserve GUI/Classic parity, report formats, snapshot compatibility, provenance and the ability to distinguish query success from a healthy system.
- **Authentication, safety and testing:** Maintain read-only collection, least privilege, selected target and credential context, and honest NoData/Unavailable/AccessDenied statuses. Do not silently fall back to local/default credentials if a remote request fails. Implement improvements incrementally and validate each local, remote Default and remote Alternate path on Windows.

This is a **planned v1.28 audit**, not an implementation or Windows-validated feature. Do not expand v1.27 scope to cover the audit unless a release-blocking defect is identified.

## Future — Technician-confirmed Quick Fix

A shared, deliberately invoked repair workflow for authorized administrators. **No repair should run merely because a health finding exists.**

Possible tasks: flush DNS cache on the selected computer, restart an explicitly chosen service, inspect/repair Windows Update services, run approved SFC/DISM checks, or assist with WinRM configuration through an already authorized management path. Treat DHCP renewal, network adapter changes, and restarts as disruptive operations requiring stronger safeguards.

Before execution, verify target, actual identity, authorization, transport, proposed changes and risks; require explicit technician approval, record the result and recheck the target. Never silently switch identities or bootstrap WinRM over unavailable WinRM.

## Future — NIST / Best Practices Computer Check

Build a **read-only**, OS-aware and versioned security configuration assessment from verified local/remote evidence. This would **not** certify NIST or organization-wide compliance.

Candidate areas include privileged identities, UAC and account policy, firewall, BitLocker, endpoint security, auditing, patch/update compliance, RDP/WinRM, SMB, and password/lockout policy. Report **Pass / Finding / Not Applicable / Unable to Verify**, tied to the applicable approved baseline, policy scope, date and supporting evidence. Respect domain-managed controls and documented exceptions. Keep any remediation in a separate consent-driven workflow.

## Additional proposals

Unscheduled possibilities: expanded DNS/routing and multi-NIC diagnostics, improved inventory and snapshot comparison, and clearer ticket-ready or work-order reports. These are proposals, not promises for v1.27.

## Development rules

- **GitHub is the source of truth:** work on the latest active development branch; do not modify stable `main` without explicit permission.
- Preserve functionality and both interfaces; share collection and analysis code rather than duplicating interpretation where practical.
- Apply least privilege, explicit UAC and target/identity provenance. Keep collected diagnostic operations read-only, and never store credentials or silently substitute identities.
- Make incremental, testable changes and validate Windows-specific behavior on Windows.
- Record what was actually implemented and tested in [CHANGELOG.md](CHANGELOG.md). Keep [README.md](README.md) and this roadmap synchronized.
