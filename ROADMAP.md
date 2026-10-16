# IT Toolkit Development Roadmap

> **Active development:** v1.27 on `develop/v1.27`. **Stable production:** v1.26 on `main`. This document lists **unfinished work and proposals only**. Implemented release changes belong in [CHANGELOG.md](CHANGELOG.md); general product guidance belongs in [README.md](README.md). Individual commits provide detailed engineering history.

## v1.27 — Remaining release requirements

- **Clean-build smoke test — technician accepted (2026-10-16):** Technician reports the fresh-install smoke test is complete and the toolkit appears to run as intended. This is overall technician acceptance; individual checklist item results and displayed build identifier were not separately supplied. Application code has not changed since this acceptance.
- **Release sign-off:** Review candidate source and documentation, record the approved release commit, obtain explicit authorization before updating stable version to `1.27`, promoting `develop/v1.27` to `main`, or tagging `v1.27`.

## Deferred regression and usability work

- **Remote timeout and cancellation edge cases:** Exercise automatic 60-second cancellation of an actually stalled diagnostic, Classic interruption of blocked Windows calls, and save behavior for cancelled partial output. Existing Enterprise-tested timeout, cancellation, and target-switch flows are accepted for v1.27.
- **Authorization and health negative cases:** Expand UAC refusal/different-identity, malformed or incomplete remote evidence, unavailable WinRM, and unusual authentication-path tests. Review local 10% versus remote 15% storage-warning thresholds and prevent inventory evidence from being mistaken for compliance certification.
- **Reports and snapshots:** Investigate partial-category comparisons, optional snapshot sidecars, and formats beyond Enterprise-tested reporting and HTML comparisons. Keep unavailable or failed categories distinct from actual removals.
- **GUI polish:** Refine empty numbered System/Policy entries, duplicated Groups/SharePermissions labels, repetitive Events text, and high-DPI/small-window display. Extend optional tools/favorites and other interface edge-case regression coverage.
- **Separate Admin Reports folder:** Consider a user-session-aware folder-opening handoff that avoids the extra UAC prompt where safe. Current scoped UAC opens a real Explorer folder and is Enterprise-accepted; do not weaken Windows security boundaries. Optional cancellation-path regression may accompany later refinement.
- **Remote authentication:** Defer more transport-by-transport negative-path audits and On-Demand snapshot-specific credential retry; supported target-bound Alternate Credentials already provide the accepted remote workflow.

## v1.28 — Diagnostic completeness review

- Audit the usefulness, missing evidence, authorization boundaries, and GUI/Classic parity of all **20 diagnostic sections**, comparing direct-local, remote Default and remote Alternate output.
- Start with **Network**: compare local structured adapter inventory to remote `ipconfig /all` evidence, including DNS, DHCP, gateways, routes, and disconnected adapters; design a clear consistent output format.
- Review remaining diagnostic sections for accurate, actionable detail while preserving readable reports, structured snapshot compatibility, least privilege, and honest unavailable/denied states.
- Deliver focused, Windows-tested improvements incrementally after v1.27 stabilizes.

## Future proposals

- **Local administrator Alternate Credentials:** Evaluate and test explicit remote administration using a target computer's local administrator account (including managed/LAPS accounts) in GUI and Classic. Validate Windows remote UAC token filtering, local-account NTLM/WinRM authentication and HTTPS/server identity requirements, WMI/DCOM authorization, and permission-denied behavior. Preserve Enterprise security policy: never automatically modify TrustedHosts, disable remote UAC filtering, or relax transport authentication. Deferred until after v1.27.
- **Technician-confirmed Quick Fix:** Explicitly approved, auditable corrective actions (for example, flush DNS or restart a selected service), with target/identity verification, risk preview, and post-action confirmation. No automatic repair triggered by a health finding.
- **NIST / Best Practices Computer Check:** Read-only, OS-aware, evidence-backed configuration assessment against a defined baseline; do not claim certification or compliance based only on inventory.
- **Additional investigation:** Expanded DNS/routing and multi-NIC diagnostics, stronger comparison workflows, and clearer ticket-ready reports. Evaluate useful code from other repositories without committing to integrations before a scope review.

## Documentation policy

- **README:** Concise feature summary, installation, and usage; change only when user-facing capabilities or instructions materially change.
- **ROADMAP:** Outstanding work, release blockers, and future proposals; remove completed items.
- **CHANGELOG:** Meaningful implemented features, changes, fixes, and release-level validation status grouped by version; avoid individual test transcripts and commit-by-commit narratives.
- **Git history:** The authoritative detailed development record. Do not repeat the commit journal in documentation.
