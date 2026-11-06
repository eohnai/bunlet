# Notch

Owns the native session interface, attention presentation, desktop recovery, and accessible notch controls.
Code: `Sources/NotchPet/` and shared presentation services in `Sources/SessionState/`.

## Specs

- `session-island`: Open, expand, collapse, and inspect sessions and requests without unsolicited focus, replacing the menu session list. Needs: sessions/session-state.
- `session-cards`: Show compact session cards with a prompt timer and tool-name request cards, and resize the expanded panel. Comes before session-island's acceptance checks, by the user's choice on 2026-10-31.
- `allowance-strip`: Show each active provider's logo, 5-hour percent left, and reset countdown in the expanded top row, with details in a tooltip. Takes over the display part of usage/codex-allowance U5. Needs: session-cards.
- `attention-behavior`: Save expansion preferences, suppress automatic expansion for a verified foreground target, and provide optional haptic feedback. Needs: session-island, settings/settings-window.
- `desktop-recovery`: [Keep the notch accessible](desktop-recovery.md) through display changes, Spaces, fullscreen, and sleep/wake. Needs: session-island.
- `accessible-controls`: [Support native keyboard, motion and focus controls](accessible-controls.md) without unsolicited focus. Needs: session-island.
- `resource-efficiency`: Measure and constrain idle CPU, memory, wakeups, rendering, and provider refresh across native components.

## Shared context

- Sessions, Notch, and Usage are the immediate delivery priority, approved on 2026-10-30.
- The first delivery milestone is optional Codex setup, a visible real session, and real limits. Coordinate with sessions/codex-setup and usage/codex-allowance.
- Opening, closing, expansion, and collapse belong to session-island. Do not create a separate feature for the same island interactions.
- Retain pet-first startup and optional agent services. Island visibility does not enable monitoring or resolve retained notices.
- Refine Flux-like interaction details during feature planning. Existing implementation and approved area scope do not establish actual-app acceptance.
- Reference images approved on 2026-10-30 show a compact allowance strip above a session/request card. Keep session identity, request details, and any terminal-return action clear.
- Manual opening and closing remain in session-island. The new attention-behavior feature owns preferences and automatic expansion for response-ready notices or requests needing attention.
- Response ready means a finished response. It does not establish task success or a confirmed session end.
- Attention controls appear in the shared settings window. Haptic feedback is optional and receives its own reviewed trigger behavior.
- Focus-aware suppression requires evidence about the selected target. A foreground terminal application alone does not establish that its relevant tab or pane is visible.
- [Record layout decision](../../decisions/0011-organize-records-by-feature.md).
- [Terminal independence](../../decisions/0012-support-terminal-independent-operation.md) is accepted. Display sessions and notices without requiring navigation metadata.
- Expose only verified terminal navigation capabilities. Unavailable navigation must not hide alerts or disable provider actions that have a verified channel.
- [Source specification](../notch-companion.md): retain I1 and N3–N6 requirements and historical evidence during migration.
- Implemented: native expandable panel, placement calculation, session rows, selection, shared attention rules, and menu session-list removal.
- Existing implementation does not establish all N3–N6 acceptance checks. Preserve their unchecked states pending evidence review.
- R1–R3 supply notch placement, fullscreen/Spaces, hit-testing, and sleep/wake checks. Pet-specific checks belong to pets/detachable-pet.
- R4 supplies accessible notch controls. R5 includes the idle resource profile. Preserve these requirements when writing feature specs.
- Session state remains shared with the pet. New alerts must not acquire keyboard focus.

## Open questions

- Physical-notch focus, click-through, and desktop acceptance remain incomplete.
- Define automatic expansion defaults, dismissal, repeated-notice handling, and suppression when foreground-target evidence is unavailable.
- Review haptic support, fallback, and trigger frequency before implementation.
