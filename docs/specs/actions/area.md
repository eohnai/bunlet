# Actions

Owns explicit local permission decisions, structured answers, and follow-up replies to verified agent targets.
Code: `Sources/AgentActions/`, `Sources/NotchPetActionHook/` and native action service/controls. Pet controls remain future work.

## Specs

- `verified-channels`: Establish supported action mechanisms and their targeting, acknowledgement, and cancellation contracts.
- `permission-decisions`: Approve once or deny an exact pending request from the notch. Needs: verified-channels, notch/session-island.
- `structured-answers`: Answer a verified structured question from the notch. Needs: permission-decisions.
- `follow-up-replies`: Explicitly send text to the selected existing conversation. Needs: permission-decisions.

## Merged MVP status, 2026-11-06

Implementation is merged through PR #16 (including PR #15). See the
[nine-area handoff](../notch-companion.md#merged-mvp-handoff-2026-11-06) for production paths,
hosted build/test evidence and capability limits. Existing unchecked acceptance tasks are not
missing implementation by default; inspect their current feature handoff before selecting work.
Native/provider acceptance remains deferred. Broader roadmap entries without specs remain future work.

## Shared context

- Later priority after the session-and-limits delivery path, approved on 2026-10-30. Existing scope and dependencies remain intact.
- [Record layout decision](../../decisions/0011-organize-records-by-feature.md).
- [Source specification](../notch-companion.md): A1–A8 retain their original unrun acceptance. The full MVP has concrete Claude channels, guarded setup, native composers and source-only handoff; see local-actions-v1. Codex actions remain unsupported.
- [Accepted local-action scope](../../decisions/0010-add-local-agent-actions.md).
- [Terminal independence](../../decisions/0012-support-terminal-independent-operation.md) keeps provider action channels separate from terminal navigation.
- Verify attachment to the existing local agent session without requiring Otty. Missing navigation alone must not disable a supported action.
- For unavailable actions, offer verified pane navigation, verified application activation, or manual-return guidance. Never substitute terminal keystrokes.
- A1–A2 establish shared compatibility and contract prerequisites. They do not prove an end-to-end action works.
- Migrate A3–A4 and permission-specific A7–A8 coverage into permission-decisions.
- Migrate A5 and question-specific A7–A8 coverage into structured-answers.
- Migrate A6 and reply-specific A7–A8 coverage into follow-up-replies.
- Each capability needs actual-app acceptance. Keep provider/version gaps explicit.
- Keep action delivery separate from the one-way observation protocol. Never auto-approve or blindly replay uncertain delivery.
- Pet controls reuse these capabilities when pet presentation exists. Preserve pet action coverage during migration.

## Open questions

- Initial Claude channels now have primary documentation and source implementation under the full MVP verification waiver. Runtime behavior remains unverified; guarded action setup/check/removal, consent, Settings and disconnect integration are implemented in source. Codex response channels remain unsupported.
