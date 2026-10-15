# IT Toolkit Development Roadmap

> **Current development:** v1.27 on `develop/v1.27`. **Production:** v1.26 on `main`. This roadmap lists outstanding work and future proposals, **not completed feature history**. Completed implementations, technician-confirmed Windows checks, limitations, and commit history belong under the single **v1.27** entry in [CHANGELOG.md](CHANGELOG.md) (not lettered subversions). The [README.md](README.md) describes current usage.

## Active milestones

| Milestone | Outstanding goal | State |
| --- | --- | --- |
| **v1.27 — Health analysis and release validation** | Validate edge cases, finish evidence interpretation and release checks without breaking GUI or Classic | In development |
| **Technician-confirmed Quick Fix** | Explicitly authorized, previewed repairs with post-action verification | Proposed; version unassigned |
| **NIST / Best Practices Computer Check** | Versioned, evidence-backed Windows configuration/security posture assessment | Proposed; version unassigned |

## v1.27 — Remaining work

### Health analysis quality and parity

- **Failure and negative cases:** Exercise inaccessible/denied and partial checks, unavailable WinRM, malformed/missing evidence, and a machine without the selected pending-restart indicators. Confirm unavailable data are not interpreted as healthy, and a detected pending-file-rename operation is not claimed to be an update-required reboot.
- **Credential and target provenance:** Verify requested and actual remote identities where the transport exposes them. Changing target, authentication mode, or credentials must not display or save health evidence from the previous context; no silent local or default-identity fallback.
- **Evidence rules:** Reconcile the current local system-drive review threshold (**below 10%**) and remote threshold (**below 15%**) with a documented rule. Keep installed-QFE inventory distinct from **missing-update compliance**. Do not present enabled firewall profiles as proof of full security compliance.
- **Further analysis, if warranted:** Add only actionable, defensible security posture or Windows Update checks with an authoritative evidence source and clear uncertainty. Do not invent an overall health score or imply comprehensive policy/compliance assessment from seven inventory checks.

### Report, snapshot, and usability regression

- **Health reports:** Verify latest seven-check findings and collection provenance in GUI and Classic saved HTML/CSV/TXT, Copy Report, Recent Reports, and archive opening. Confirm partial/denied statuses survive formatting.
- **Snapshots:** Confirm two-snapshot baseline comparison and archive reload for Local and remote targets, partial/inaccessible categories, optional Classic report-sidecar creation, and no target/identity mix-up. **Local and remote snapshot capture itself has already been technician-confirmed and is not an outstanding implementation task.**
- **Privileged diagnostics:** Preserve separate-user UAC provenance and explicit consent behavior; test residual edge cases including cancellation and enterprise security controls as needed. On the tested workstation, computer-scope `gpresult /SCOPE COMPUTER /R` returns **ACCESS DENIED** even independently under an elevated administrator account; keep reporting that limitation rather than treating it as a successful Policy result.
- **UI/Classic regression:** Check compact and maximized GUI sizing, independently scrollable health evidence with fixed navigation/target/Classic switch, ordinary and alternate credential modes, normal and elevated PowerShell Tools launch, and retained Classic reporting behavior.

### Release gate

- Record Windows test evidence and outstanding limitations in [CHANGELOG.md](CHANGELOG.md), update [README.md](README.md) where functionality or usage changes, and resolve significant regressions.
- Obtain **explicit release approval** before version promotion or any changes to production `main`.

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
