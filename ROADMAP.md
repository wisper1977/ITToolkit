# IT Toolkit Development Roadmap

> **Active development:** v1.27 on `develop/v1.27`. **Stable production:** v1.26 on `main`. This document lists **unfinished work and proposals only**. Implemented release changes belong in [CHANGELOG.md](CHANGELOG.md); general product guidance belongs in [README.md](README.md). Individual commits provide detailed engineering history.

## v1.27 — Release blockers

- **Remote failure-handling follow-up:** County technician confirmed GUI and Classic System Information and Health behavior on both ML-PCSCALE (authorized) and ML-DC1 (restricted): System Information on ML-DC1 returns UNAVAILABLE after the 30-second deadline; Health completes with PARTIAL / UNAVAILABLE, retaining separately accessible evidence without treating denied checks as successful. GUI manual cancellation and target-switch recovery were also verified. Remaining: test automatic 60-second cancellation of a genuinely stalled remote check, prevent saving cancelled partial results, and verify Classic interruption/recovery when an operation does not return. No server permission changes required.
- **County-network authentication and reporting:** GUI Alternate was technician-tested on ML-PCSCALE: standard county Windows session with explicit alternate administrative domain credentials completed System Information and Health reports. Default and restricted-target behavior were also tested in GUI/Classic. Remaining: Classic Alternate using the same standard-to-admin scenario; broader 20-section remote coverage; independent identity confirmation where observable; failure with invalid/mismatched credentials and no fallback; stale report invalidation after target/credential changes.
- **Local authorization regression:** Check interactive refusals, invalid targets/sections, successful normal diagnostic paths, batch reporting, and local BitLocker/Policy UAC under appropriate Windows identities. Include UAC cancellation, different administrator identities, and correct report provenance.
- **Launcher and interface identity:** Test Current Windows User, Separate Administrative Account, and On-Demand modes with the expected tokens and session identities. Verify startup, GUI ↔ Classic switching, preference migration, credential field behavior, and no automatic elevation or identity substitution.
- **Seven-check Computer Health:** Validate inaccessible or partially failed evidence, unavailable WinRM, malformed responses, negative pending-restart signals, and both authentication modes. Reconcile local **10%** versus remote **15%** system-drive free-space review thresholds. Ensure QFE inventory, firewall states, and registry reboot indicators are not overrepresented as compliance findings.
- **Reports and snapshots:** Test saved HTML/CSV/TXT output in GUI and Classic, report copying, recent/archive opening, and source-build version labeling. Validate remote and partial-category snapshot comparisons, archive reload, Classic optional snapshot sidecars, and target/identity consistency.
- **Report Archive folder opening:** Resolve the separately authorized administrator desktop-session case where GUI **Open Reports Folder** does not display Explorer even though the child process reports successful completion; retain **Copy Folder Path** as a fallback.
- **GUI/Classic regression:** Confirm small/high-DPI and maximized layout, health-sidebar scrolling/navigation, tools/favorites, ordinary and elevated PowerShell tool launch, and current diagnostic behavior in both interfaces.
- **Build and release traceability:** Replace the intentionally retained `1.27.aa028e` display value with a verified source-commit suffix when generating the final development build. Record exactly which revision was tested; repeat impacted tests if code changes.
- **Promotion decision:** Resolve release-blocking defects, review documentation for accuracy, complete required Windows validation, and obtain explicit approval before changing `main`, applying stable version `1.27`, or tagging `v1.27`.

## v1.28 — Diagnostic completeness review

- Audit the usefulness, missing evidence, authorization boundaries, and GUI/Classic parity of all **20 diagnostic sections**, comparing direct-local, remote Default and remote Alternate output.
- Start with **Network**: compare local structured adapter inventory to remote `ipconfig /all` evidence, including DNS, DHCP, gateways, routes, and disconnected adapters; design a clear consistent output format.
- Review remaining diagnostic sections for accurate, actionable detail while preserving readable reports, structured snapshot compatibility, least privilege, and honest unavailable/denied states.
- Deliver focused, Windows-tested improvements incrementally after v1.27 stabilizes.

## Future proposals

- **Technician-confirmed Quick Fix:** Explicitly approved, auditable corrective actions (for example, flush DNS or restart a selected service), with target/identity verification, risk preview, and post-action confirmation. No automatic repair triggered by a health finding.
- **NIST / Best Practices Computer Check:** Read-only, OS-aware, evidence-backed configuration assessment against a defined baseline; do not claim certification or compliance based only on inventory.
- **Additional investigation:** Expanded DNS/routing and multi-NIC diagnostics, stronger comparison workflows, and clearer ticket-ready reports. Evaluate useful code from other repositories without committing to integrations before a scope review.

## Documentation policy

- **README:** Concise feature summary, installation, and usage; change only when user-facing capabilities or instructions materially change.
- **ROADMAP:** Outstanding work, release blockers, and future proposals; remove completed items.
- **CHANGELOG:** Meaningful implemented features, changes, fixes, and release-level validation status grouped by version; avoid individual test transcripts and commit-by-commit narratives.
- **Git history:** The authoritative detailed development record. Do not repeat the commit journal in documentation.
