# IT Toolkit Development Roadmap

> **Active development:** v1.28 on `develop/v1.28`. **Stable production:** v1.27 on `main`. This document lists **unfinished work and proposals only**. Implemented release changes belong in [CHANGELOG.md](CHANGELOG.md); general product guidance belongs in [README.md](README.md). Individual commits provide detailed engineering history.

## v1.28 — Diagnostic completeness review

- Audit the usefulness, missing evidence, authorization boundaries, and GUI/Classic parity of all **20 diagnostic sections**, comparing direct-local, remote Default and remote Alternate output.
- Start with **Network**: compare local structured adapter inventory to remote `ipconfig /all` evidence, including DNS, DHCP, gateways, routes, and disconnected adapters; design a clear consistent output format.
- Review remaining diagnostic sections for accurate, actionable detail while preserving readable reports, structured snapshot compatibility, least privilege, and honest unavailable/denied states.
- Deliver focused improvements incrementally during v1.28 development, validating each changed collector on Enterprise Windows systems and preserving truthful error/partial states.
  
## v1.28 — Release acceptance criteria

- Verify each changed diagnostic section against representative Enterprise systems in direct-local, remote Default, and remote Alternate modes where applicable; document unavailable or permission-denied paths without claiming success.
- Check GUI/Classic output parity, identity provenance, HTML/CSV/TXT readability, and compatibility with existing snapshot/report formats for affected sections.
- Perform a clean-install Windows smoke test with an exact source-build identifier, preserve the stable v1.27 baseline, and obtain explicit approval before promotion to `main`.

## Deferred regression and usability work

- **Remote timeout and cancellation edge cases:** Exercise automatic 60-second cancellation of genuinely stalled diagnostics, Classic interruption of blocked Windows calls, and cancellation-before-save behavior. Existing Enterprise-tested timeout, cancellation, and target-switch workflows remain accepted.
- **Authorization and health negative cases:** Extend UAC refusal/different-identity tests, malformed or incomplete remote evidence, unavailable WinRM, and unusual authentication paths. Review local 10% vs remote 15% storage thresholds without treating health inventory as compliance certification.
- **Reports and snapshots:** Explore partial-category comparisons, optional snapshot sidecars, and alternate comparison exports while preserving honest partial/unavailable categories.
- **GUI polish:** Tidy empty numbered System/Policy entries, duplicate Groups/SharePermissions labels, repetitive Event output, and small-window/high-DPI usability. Continue optional tools/favorites edge-case regression coverage.
- **Separate Admin Reports folder:** Evaluate whether an approved user-session handoff can avoid an extra UAC request safely; the current scoped UAC method remains accepted and should not be weakened.
- **Remote authentication:** Defer transport-wide unusual-authentication audits and On-Demand snapshot-specific retries; target-bound Alternate credentials remain the supported approach.

## Future proposals

- **Local administrator Alternate Credentials:** Evaluate and test explicit remote administration using a target computer's local administrator account (including managed/LAPS accounts) in GUI and Classic. Validate Windows remote UAC token filtering, local-account NTLM/WinRM authentication and HTTPS/server identity requirements, WMI/DCOM authorization, and permission-denied behavior. Preserve Enterprise security policy: never automatically modify TrustedHosts, disable remote UAC filtering, or relax transport authentication. Deferred until after v1.28.
- **Technician-confirmed Quick Fix:** Explicitly approved, auditable corrective actions (for example, flush DNS or restart a selected service), with target/identity verification, risk preview, and post-action confirmation. No automatic repair triggered by a health finding.
- **NIST / Best Practices Computer Check:** Read-only, OS-aware, evidence-backed configuration assessment against a defined baseline; do not claim certification or compliance based only on inventory.
- **Additional investigation:** Expanded DNS/routing and multi-NIC diagnostics, stronger comparison workflows, and clearer ticket-ready reports. Evaluate useful code from other repositories without committing to integrations before a scope review.

## Documentation policy

- **README:** Concise feature summary, installation, and usage; change only when user-facing capabilities or instructions materially change.
- **ROADMAP:** Outstanding work, release blockers, and future proposals; remove completed items.
- **CHANGELOG:** Meaningful implemented features, changes, fixes, and release-level validation status grouped by version; avoid individual test transcripts and commit-by-commit narratives.
- **Git history:** The authoritative detailed development record. Do not repeat the commit journal in documentation.
