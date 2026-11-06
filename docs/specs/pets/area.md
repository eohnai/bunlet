# Pets

Owns pet rendering, detachment and return, safe artwork imports, preferences, and pet desktop behavior.
Code: `Sources/Pet/` and AppKit controllers in `Sources/NotchPet/`; an app-owned adapter translates shared session snapshots into pet-owned moods.

## Specs

- `built-in-pet`: [Set up and show a standalone pet](built-in-pet.md) without agent services or configuration.
- `agent-reactions`: Translate shared session presentation into optional pet reactions and notices. Needs: built-in-pet, sessions/session-state. Requires installed/enabled Agents at runtime; Notch is optional.
- `detachable-pet`: Drag the pet out, return it, and recover placement across desktop changes. Needs: built-in-pet.
- `custom-packs`: Validate, import, select, and restore manifest-based pet packs. Needs: built-in-pet.
- `sprite-sheet-import`: Settle and implement the optional sheet conversion proposal. Needs: custom-packs.

## Shared context

- Later priority after the session-and-limits delivery path, approved on 2026-10-30. Preserve pet-first startup and deferred acceptance.
- [Record layout decision](../../decisions/0011-organize-records-by-feature.md).
- [Terminal independence](../../decisions/0012-support-terminal-independent-operation.md) is accepted. Pet reactions must not require Otty or terminal navigation.
- [Standalone pet scope and packaging](../../decisions/0013-separate-standalone-pet-scope.md) is accepted. Use one app with an independent pet module and optional agent services.
- [D7](../../DECISIONS.md#d7-install-and-uninstall-features-from-settings) extends this to install/uninstall in Settings: Pet requires neither Notch nor Agents. Existing notch-positioned pet implementation does not establish independent desktop placement; plan that gap without rewriting historical built-in-pet acceptance.
- Set up the pet first. Agent setup is optional and skippable. After approved hook setup, observed sessions trigger agent features automatically.
- Pet-only startup starts no agent or usage services. The standalone pet no longer depends on notch session presentation.
- The app owns optional services. The pet module imports no agent session types. An optional adapter translates authoritative snapshots.
- Reaffirmed on 2026-11-02: standalone Pet keeps ordinary behavior; with enabled Agents, an app-owned adapter maps session evidence into pet-owned moods. Working, answer/approval attention and response-ready cues reuse the shared session authority. Trigger completion once per observed finished response, without claiming task success. This belongs to agent-reactions; modular feature management preserves its integration seam without inventing missing animations or making Notch a dependency.
- Unknown observations and retained requests must not disappear merely because events stop. Paused monitoring is distinct from a confirmed session end.
- P0's direction is accepted. Its original unchecked line remains in the source spec pending final planning review.
- [Source specification](../notch-companion.md): P1–P8 remain open. Shared presentation code exists, but does not establish implemented pet rendering.
- [Accepted asset-only pack format](../../decisions/0006-import-asset-only-pet-packs.md).
- P1 belongs to agent-reactions under the approved split. Keep its original line in the source spec until that feature is written.
- P2 and pet-specific R1–R3 checks belong to detachable-pet. Those checks must also preserve notices when agent reactions are enabled.
- P3–P4 and pack-selection preferences from P7 belong to custom-packs. Placement preferences from P7 belong to detachable-pet.
- P5–P6 belong to sprite-sheet-import. Preserve P6's blocked state until P5 is accepted.
- Divide P8 actual-app checks among the features they verify. Preserve pet Reduce Motion and hidden/asleep animation checks from R4.
- R5 includes the animated-pet resource profile on the target Mac. Do not replace measured acceptance with a native-stack assumption.
- Basic pet setup and size controls belong to built-in-pet. Custom artwork selection and desktop placement keep their existing owners.
- Connect and owned configuration removal belong to session setup. Runtime pause, resume, and disconnect belong to sessions/monitoring-controls.
- Monitoring controls reuse setup removal logic. Coordinate notice retention with agent-reactions and later collector lifecycle with telemetry.
- When no observed sessions or unresolved notices require agent presentation, show ordinary pet behavior without session or allowance panels.
- Preserve optional integration, unknown, ended, attention, and response-ready checks across the split. A pet-only feature does not complete them.
- Keep runtime files, imported packs, and fixture assets outside the repository. Invalid imports must preserve the selected pet.

## Decisions

- **Keep pet-first startup with optional agent services; add drag-out and overlap-return presentation.** Accepted on 2026-10-30: dragging the pet out hides the island, and overlapping the detached pet with the island's location returns the pet and restores the island. The user chose Flux's interaction while retaining decision 0013's independent pet module and optional services.
- **Make overlap-return conditional on installed Notch, 2026-11-02:** D7 permits Pet without Notch. Independent pet placement must remain usable in that combination; returning to a notch surface applies when that feature is installed. Detailed placement and dependency behavior remains to be planned.
- Detachment and return belong to `detachable-pet` and work without an agent connection. Switching surfaces does not start or stop monitoring, change connection settings, or resolve retained notices. This accepts behavior; the feature's task list and implementation plan still require approval.
- **Use original white lionhead rabbit artwork for the default pet.** Accepted on 2026-10-30: the user chose newly created original artwork over supplying an existing image, then specified a white lionhead rabbit. At this decision point the standalone-rabbit goal was prepared but not activated; its later approved asset step and implementation are summarized below.

## Implementation status

The original white lionhead idle PNG and manifest are bundled through the independent Pet target.
Built-in-pet implementation includes pet-first startup, optional agent services, saved size, setup/settings,
playback policy, and BP6b2 visibility/sleep wiring for the panel and preview. It merged into main in 1c5d9cf.
The implementation-only goal is closed. Full acceptance remains deferred by the user.
See the [current handoff](built-in-pet.md#implementation-handoff-after-testing-deferral-2026-10-30)
and [completion log](../../goals/complete-built-in-pet-log.md). Detachment and agent reactions now have source implementation under the full MVP goal; their acceptance remains unverified. Custom manifest/PNG import, selection and rollback also have source paths; all new behavior remains unverified.

## Open questions

- Setup/slider/menu interactions, actual multi-frame scheduling, Reduce Motion changes, and visual/fallback appearance remain unverified.
- Later nonvisual harness evidence is recorded in built-in-pet. Do not retry captures or resume tests without a user request.
- Detailed pause, disconnect, resume, and notice-retention behavior needs planning in sessions/monitoring-controls and agent-reactions.
- Sprite-sheet conversion versus a second runtime loader remains proposed. The optional importer is not a first-release dependency.
