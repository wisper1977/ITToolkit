# IT Toolkit Development Roadmap

> **Active development:** v1.28 on `develop/v1.28`. **Stable production:** v1.27 on `main`. This document lists **unfinished work and proposals only**. Implemented release changes belong in [CHANGELOG.md](CHANGELOG.md); general product guidance belongs in [README.md](README.md). Individual commits provide detailed engineering history.

## v1.28 — Diagnostic completeness review

- Audit the usefulness, missing evidence, authorization boundaries, and GUI/Classic parity of all **20 diagnostic sections**, comparing direct-local, remote Default and remote Alternate output.
- Start with **Network**: compare local structured adapter inventory to remote `ipconfig /all` evidence, including DNS, DHCP, gateways, routes, and disconnected adapters; design a clear consistent output format.
- Review remaining diagnostic sections for accurate, actionable detail while preserving readable reports, structured snapshot compatibility, least privilege, and honest unavailable/denied states.
- Deliver focused, Windows-tested improvements incrementally after v1.28 stabilizes.
  
## v1.28 — Remaining release requirements

## Deferred regression and usability work

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
