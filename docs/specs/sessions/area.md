# Sessions

Owns terminal-independent agent observation, session state, integration setup and health, monitoring controls, and optional terminal navigation.
Code: `Sources/EventBridge/`, `Sources/SessionState/`, `Sources/Integration/` and app integration controls.

## Specs

- `observation-bridge`: Deliver agent events through the helper into the running app, preserving the native shell and bridge foundation.
- `session-state`: Distinguish concurrent sessions, requests, response-ready notices, and unknown state. Needs: observation-bridge.
- `integration-health`: Report version, configuration, helper, receiver, and delivery evidence separately. Needs: observation-bridge.
- `codex-setup`: Connect, check, and remove owned Codex integration through explicit controls without overwriting user changes. Needs: integration-health, notch/session-island.
- `claude-setup`: Connect, check, and remove owned Claude lifecycle integration while preserving the status line. Needs: integration-health, notch/session-island.
- `monitoring-controls`: Pause, resume, and disconnect configured monitoring while preserving unresolved notices. Needs: codex-setup.
- `pane-navigation`: [Optional terminal navigation](pane-navigation.md) reports user-linked exact-pane, application-only, or manual-return capability through separate adapters. Needs: session-state.
- `first-use`: Verify setup, live alerts, navigation, removal, and release instructions. Needs: codex-setup, claude-setup, pane-navigation, notch/desktop-recovery, notch/accessible-controls, usage/refresh-recovery, actions/structured-answers, actions/follow-up-replies, pets/detachable-pet, pets/custom-packs.

## Merged MVP status, 2026-11-06

Implementation is merged through PR #16 (including PR #15). See the
[nine-area handoff](../notch-companion.md#merged-mvp-handoff-2026-11-06) for production paths,
hosted build/test evidence and capability limits. Existing unchecked acceptance tasks are not
missing implementation by default; inspect their current feature handoff before selecting work.
Native/provider acceptance remains deferred. Broader roadmap entries without specs remain future work.

## Shared context

- Roadmap approved on 2026-10-30: prioritize Sessions, Notch, and Usage. First deliver optional Codex setup, a visible real session, and real Codex limits.
- The user approved the [codex-setup](codex-setup.md) scope, menu-first controls, and eight-task list on 2026-10-30.
  Start with I3b1's design review. Open design choices, prerequisite closure, and renewed runtime checks remain separate gates.
- Resolve existing session-state closure and integration-health acceptance before dependent implementation. Roadmap approval does not complete those features.
- Setup features own configuration changes and removal logic. Monitoring controls own runtime behavior and reuse that removal logic.
- `monitoring-controls` initially depends on Codex setup. Extend it to Claude when Claude setup exists; Codex does not wait for Claude setup.
- Pause, resume, disconnect and notice-retention semantics have source contracts in monitoring-controls; acceptance is unrun. Coordinate later collector controls with telemetry/background-collection.
- These are approved feature boundaries and order. Full specifications and implementation task lists still need feature-level planning.
- Setup and monitoring controls contribute the Agents page when settings/settings-window exists. A shared settings shell does not replace setup ownership or authorize installed configuration changes.
- [Record layout decision](../../decisions/0011-organize-records-by-feature.md).
- [Terminal independence](../../decisions/0012-support-terminal-independent-operation.md) is accepted. Otty is not required; legacy hints remain untrusted. Exact-pane source support currently uses explicit user-linked iTerm2, with application/manual return for other terminals.
- Monitoring, alerts, pet reactions, and supported allowance reads must work without terminal metadata or an Otty installation.
- Missing navigation does not imply broken agent setup or unavailable provider actions. Report those capabilities separately.
- [Observation bridge](observation-bridge.md) owns its migrated completed tasks and historical evidence.
- [Source specification](../notch-companion.md): unmigrated tasks and evidence remain authoritative until their feature migration.
- Implemented: native app shell, bounded event bridge, both agent adapters, session store, and inbox. Preserve completed foundation tasks and G1–G2 evidence.
- Integration-health models/probes and both provider installers are implemented and included in hosted compilation/tests. I2c app-wiring and real setup/recovery acceptance remain deferred; historical I3a is documentation evidence only.
- Codex setup maps I3b–I3c and the Codex portion of I5–I6 to approved smaller tasks.
  Keep the original source checklist until shared acceptance has complete destinations. Migrate I4 and the Claude portion into claude-setup.
- Keep original source lines and checkbox states during that migration. Defining feature ownership does not move or complete those tasks.
- N1–N2 own exact-pane navigation. Live event coverage includes N6 and R6–R7. R8 owns final first-use acceptance.
- Preserve those Otty-specific checks. N7 defines general navigation capabilities; N8 adds live checks for both agents in another local terminal.
- Migrate N7 into pane-navigation and N8 into first-use. The terminal matrix records tested combinations, not universal compatibility.
- The first feature preserves the existing real helper-to-app path. Do not treat fixture checks as live-provider acceptance.
- Review features against approved behavior and accepted decisions, then check code for support and gaps. Existing code alone does not define scope.
- Keep agent configuration intact and captured session data outside the repository.

## Full MVP source update, 2026-11-06

Both provider setup services/controls, independent monitoring, scoped Claude quota setup and bounded
quota delivery have source implementations. See the detailed Claude/monitoring specs and
[provider contract](../../contracts/provider-setup.md). Local verification was deferred; subsequent hosted CI passed on the merged PR head.
That CI result does not close original live acceptance or change historical checkbox evidence.
Earlier ordering/gate proposals above remain historical where superseded by that explicit full goal.

## Open questions

- Monitoring controls now specify and implement intake/refresh gates, retained unconfirmed notices and fresh-evidence cutoffs. Native/live acceptance remains open.
- Owned interruption recovery has source implementation for both providers and Claude quota. The accepted contract and deferred runtime acceptance remain separate.
- During feature migration, divide shared acceptance checks without losing any original requirement or checkbox state.
