# Usage

Owns supported provider allowance reads, forwarding, freshness, account boundaries, and usage presentation in the notch.
Code: usage services in `Sources/SessionState/`, `Sources/NotchPet/AgentUsageController.swift`, usage views, and future forwarding helper code.

## Specs

- `codex-allowance`: Read real Codex allowance and show it for active Codex sessions, including the shared usage store. Needs: notch/session-island.
- `claude-allowance`: Forward real Claude allowance while preserving terminal output and cancellation. Needs: codex-allowance.
- `refresh-recovery`: Handle stale data, sparse updates, account changes, disconnects, cancellation, and bounded retries. Needs: codex-allowance, claude-allowance.

## Shared context

- Sessions, Notch, and Usage are the immediate priority, approved on 2026-10-30. First deliver optional Codex setup, a visible real session, and real Codex limits.
- Codex leads because its read-only quota path already exists. Claude follows with its separate status-line forwarding requirements.
- Preserve provider-specific values and active-session filtering. Session count must not multiply an account's allowance.
- [0015](../../decisions/0015-show-limits-only-for-active-providers.md) requires each provider to have its own observed active session. Unknown and Ended sessions do not keep usage limits visible or Codex reads running; their cards remain independent.
- Coordinate explicit monitoring pause/resume/disconnect with sessions/monitoring-controls. This roadmap does not settle their detailed semantics.
- The approved session-panel reference places compact provider usage limits above request details. Keep window durations, reset times, freshness, and account confidence in the store. The notch shows percent left under [D6](../../DECISIONS.md#d6-show-allowance-as-percent-left-not-percent-used); the [allowance strip](../notch/allowance-strip.md) owns that display. [0014](../../decisions/0014-omit-usage-limit-tooltips.md) removes hover details from the notch.
- Historical activity and token charts belong to telemetry/activity-statistics and telemetry/token-statistics. Keep their totals separate from subscription allowance.
- [Record layout decision](../../decisions/0011-organize-records-by-feature.md).
- [Source specification](../notch-companion.md): preserve the completed usage-source investigation and U1–U6 tasks and evidence.
- [Accepted provider sources](../../decisions/0007-read-supported-usage-data.md).
- [Terminal independence](../../decisions/0012-support-terminal-independent-operation.md) requires supported allowance reads and forwarding without Otty or navigation metadata.
- Preserve provider-source limits and terminal output. Terminal independence does not establish support for every shell, IDE, or remote environment.
- Implemented: shared usage store, Claude and Codex parsers, bounded read-only Codex protocol/process connection, private usage sender/receiver, and active-provider notch sections.
- Completed parser/transport tasks: U2a, U2c1, U2c2, U3a, U3b1. Preserve their checked states.
- U1, U3b2, and U5 have implementation or earlier evidence but remain unchecked in the source spec. Review evidence before changing their states.
- AgentUsageController now owns Codex reads outside SwiftUI. NotchPanelController still owns the usage store and controller.
- UsageReceiver exists, but the current optional app path does not start it. Claude forwarding and app receipt remain unfinished.
- Claude forwarding and live verification remain incomplete. Installed configuration changes need a reversible plan and explicit approval.
- Migrate U1, U3a–U3b2, and Codex U5/U6 coverage into codex-allowance. Migrate U2 and Claude U5/U6 coverage into claude-allowance.
- U3c, U4, and failure/reconnect/account-switch U6 coverage belong to refresh-recovery.
- Claude depends on the shared usage foundation delivered by codex-allowance, not on a Codex account or active Codex session.
- No credentials, private endpoints, token-based estimates, or agent turns for quota refresh.

## Open questions

- Review U3b2 evidence before ticking it. The usage socket has no crash-stale endpoint recovery.
- Reconcile stale ownership and build-error descriptions in codex-allowance and claude-allowance during their feature reviews.
- Settle the five recorded Claude receiver decisions against current code before U2c3. Moving reads out of SwiftUI only partly addresses service ownership.
