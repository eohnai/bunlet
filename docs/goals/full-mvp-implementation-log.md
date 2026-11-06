# Goal log: Implement the full local Codex and Claude MVP

- Goal file: goals/full-mvp-implementation.md
- Created: 2026-11-06 11:47 +08
- Turn limit: 60
- Status: active since 2026-11-06; execution turn 4
- Scope: all nine source criteria; four milestones are not separate completion goals
- Verification: tests, builds, runtime checks and provider qualification NOT RUN by user instruction
- Branch/base: feat/codex-mvp / 8707bdf; current checkout only
- Local commits: authorized at coherent milestones; record hashes and NOT RUN verification; no push/PR

## Turns

| Turn | Time | Criteria passing | What changed / evidence |
|---|---|---|---|
| 1 | 2026-11-06 12:11 +08 | Source 2 implemented; 1, 3–9 incomplete. Acceptance unverified. | Started the full goal. Added bounded Claude forwarding executable and packaging; session-hashed source projection; per-socket buffers; private receiver lease/refused-socket recovery; Claude-only validation; bounded inbox/app receipt; source expiry and loss/health feedback; Codex retry; session capacity/overflow UI. See source audit below. Coherent local source commit being saved; hash recorded after creation. Tests/builds/runtime/qualification NOT RUN. |
| 2 | 2026-11-06 13:20 +08 | Sources 1–3 implemented; 4–9 incomplete. Acceptance unverified. | Previous turn classified as progress (`299d021`). Generalized guarded provider setup/recovery; concrete documented release/policy bindings; native controls for both agents; independent consent/cutoffs/cancellation; separate owned Claude status-line wrapping/restoration and cross-scope recovery. Corrected Codex launch arguments against official stdio documentation without executing a probe. Relevant source audit below. Preparing a scoped local milestone commit. Tests/builds/runtime/qualification NOT RUN. |
| 3 | 2026-11-06 14:43 +08 | Sources 1–3 implemented; 4 partial; 5–9 incomplete. Acceptance unverified. | Previous turn was progress (`32f7b0f`). Added separate Claude permission/question/Stop-feedback adapters, bounded private interactive IPC/helper and inbox, transient action/draft/receipt state, app-owned lifecycle/validation and native composers. Guarded interactive-hook setup/removal is still missing; criterion 4 remains incomplete. All tests/builds/runtime/qualification NOT RUN. |
| 4 | 2026-11-06 14:58 +08 | Sources 1–4 implemented; 5–7 incomplete; 8 partial; 9 incomplete. All acceptance unverified. | Finished separate guarded Claude action scope, shared recovery/lock, explicit response consent, Settings composers, disconnect partial-removal reporting and bounded transient-history cleanup. Removed ambiguous shared composer shortcut. Preserved unrelated drafts. Tests/builds/runtime/qualification NOT RUN. |

Preparation is not an execution turn. Continue numbering from the latest execution row after activation.
Each row must account for all nine criteria and separate missing source implementation from unverified behavior.
The saved Codex-focused slice does not count as full MVP completion.

## Local commit authorization

On 2026-11-06 the user instructed "commit where it's good to do so". Save coherent, reviewable milestone
changes on feat/codex-mvp without repeated approval. Record each hash, scope and nine-criterion progress.
Preserve unrelated FM7/editor/CI drafts unstaged; never imply tests/builds ran or that a partial milestone
completes the full MVP. Pushes, PRs, extra branches/worktrees and runtime checks remain unauthorized.
The prepared goal/policy were saved as `38c6139`. Execution has now started with the full scope intact.

## Turn 1 source audit

These statuses concern source implementation only. No build, test, probe, launch, capture, installed
configuration access or runtime qualification occurred. Primary official documentation was read.

1. **Incomplete — both provider setup/controls.** `Sources/Integration/CodexSetupService.swift:32`
   still declares `qualifiedReleases = [:]`; `HookSetupPlanner.plan` rejects non-Codex providers.
   Documented support bindings, Claude owned setup and per-provider pause/disconnect remain.
2. **Implemented in source — shared observation/session/notch.** SessionKey uses agent plus session ID
   (`SessionObservationV1.swift:51`), not folder. `SessionStore.swift:95` bounds receipt age; event
   identity conflicts/duplicates and expiry retain unknown semantics. The response-ready branch
   requires the current observed turn (`guard record.baseline, let turn, turn == record.turn`).
   `NotchPresentation.card` labels same-folder sessions separately; `selection` retains an existing
   key; `promptTimer` stops only on observed response ready. `SessionStore.swift:81` now records
   refused capacity and `NotchSessionView.swift:66` renders it: "New sessions are not being observed."
   Bounds/retention remain unchanged. `SessionEventInbox` remains bounded to 128.
3. **Incomplete — quota setup/health.** The real new path is
   `NotchPetStatusLine/main.swift:95` → `ClaudeUsageProvider.forward` → `UsageDelivery.send` →
   `UsageReceiver.swift:78` (`UsageValidation.acceptsClaudeIngress`) →
   `NotchPetApp.swift:180` (`UsageInbox`, generation check) → `UsageStore.receiveClaudeBatch` →
   `NotchAllowanceStrip` (`Text("stale")`, receiver/loss help). `UsageEndpointLease:29` recovers
   only refused owned sockets. `AgentUsageController` selects delays `[5, 15, 30, 60, 120]` and
   stops on cancellation. `scripts/run.sh` packages the helper. Owned wrapper setup and Settings
   health presentation remain; no live output/cancellation or socket result is established.
4. **Incomplete — concrete actions.** `NotchRequestCard.swift:19` still renders
   `Text("Answer in the terminal")`; no request/reply/action adapter is connected.
5. **Incomplete — pet reactions.** `PetPanelController.swift:24` creates
   `PetView(presentation: presentation, isVisible: visible, isSleeping: sleeping)` without session
   inputs. `PetPresentation.animation` has idle fallback, but no app-owned reaction adapter.
6. **Incomplete — movement/return.** `PetPanelController.swift:21` still sets
   `panel.ignoresMouseEvents = true`; `show()` only orders front. No drag/overlap-return path.
7. **Incomplete — custom packs/preferences.** `PetPreferences.swift:12` persists size only
   (`defaults.set(safe, forKey: "pet.size")`). No asset import/selection/placement/sound path.
8. **Incomplete — navigation/desktop.** `NotchPanelController.swift:22` has
   `.canJoinAllSpaces, .fullScreenAuxiliary`, and placement respects Reduce Motion, but controllers
   lack display-change recovery and exact target navigation. Native Settings already exists.
9. **Incomplete — full handoff.** Architecture, status, quota policy/spec and this log now describe
   actual source behavior. Criteria 1 and 3–8 remain missing; no 9/9 claim or acceptance ticks.

The quota implementation policy is recorded in `docs/contracts/usage-intake.md`. Earlier receiver
proposals and stale view-owned wiring descriptions were reconciled while preserving historical evidence.
Existing UsageReceiver tests target the old provider/source/recovery contract; they were not run or
weakened. Existing unrelated FM7/editor/CI changes remain outside this implementation commit.

Saved implementation commit: `299d021` — `feat: wire Claude quota intake and bounded forwarding`.
It contains the source paths, packaging and directly relevant records described above. No tests,
builds, runtime checks or qualification ran. The full goal remains active; next work is provider setup.

## Turn 2 source audit

1. **Implemented in source — both provider setup/controls.** `ProviderHookPolicy` binds the documented
   Codex 0.164.0/Claude 2.1.306 shapes separately from the empty runtime-qualified registry.
   `ProviderSetupService.swift:71` calls the real guarded transaction; its `.documented` branch
   does not manufacture qualification. `CodexHookPolicyProbe` implements bounded initialize,
   config/read and configRequirements/read. Known disabled/managed-only policy blocks installation;
   absent fields and Claude effective project/managed policy remain unverified.
   `HookSetupPlanner` validates provider-bound ownership and emits `--agent claude` or `--agent codex`.
   `ProviderHookTransaction` performs the inherited guarded journal/recovery/removal; removal uses
   recorded helper identity without requiring the CLI or old helper. `ProviderSetupController`
   routes Connect/Check/Repair/Remove/Disconnect; `ProviderSetupView` and both menu submenus call it.
   Repair is idempotent/recovery-only for exact ownership, never reconstruction over edited groups.
   Moved helpers need Remove then Connect, explicitly documented.
2. **Implemented in source — shared sessions and independent monitoring.** Existing reducer/cards
   from turn 1 remain. `ProviderMonitoringModel.setEnabled` persists provider consent separately
   from the master switch. `AgentServices.setEnabledProviders` suspends only the removed provider,
   cancels quota work and advances monotonic/wall cutoffs. Delivery filters provider membership
   before reduction and requires capture/receipt after those cutoffs. `SessionStore.swift:70`
   retains notices while preserving terminal records (`key.agent == agent && !record.terminal`).
   Master pause cancels pending setup observation so a later Connect completion cannot resume it.
3. **Implemented in source — both quota paths and owned forwarding.** The real turn-1 sender,
   inbox/store/strip path is now reachable through optional Claude quota setup.
   `ClaudeStatusLinePlanner.swift:31` captures the original field; line 34 installs the wrapper;
   line 55 restores original bytes; line 80 refuses removal if the complete owned field changed.
   The original shell command is passed as one quoted wrapper argument, with other field members
   preserved. Separate quota ownership/pending records share the lifecycle writer lock; either
   known journal recovers before another Claude settings write. Disconnect pauses, restores quota,
   then removes lifecycle groups; partial removals remain paused and are reported. Settings exposes
   quota ownership/helper/receiver/last receipt; quota probes do not overwrite lifecycle helper health.
   Codex uses complete responses, discards sparse notifications, replaces changed/missing account
   windows in the managed snapshot, and retries with the already bounded backoff. Account/measurement
   identity stays unverified when absent; no immediate account-notification promise is made.
   The wrapper retains its child leader until cancellation escalation so it can terminate the owned
   process group before reaping, including descendants that ignored the initial cancellation signal.
4. **Incomplete — actions.** `NotchRequestCard.swift:19` still says `Text("Answer in the terminal")`.
   Concrete approval/answer/follow-up channels, targeting, drafts and acknowledgements are next.
5. **Incomplete — pet reactions.** `PetPanelController.swift:24` still constructs PetView with only
   presentation/visibility/sleep inputs. No app-owned session-to-pet adapter.
6. **Incomplete — pet movement.** `PetPanelController.swift:21` still sets
   `panel.ignoresMouseEvents = true`; no drag/overlap/menu-return behavior.
7. **Incomplete — custom packs/preferences.** `PetPreferences.swift:12` still has size only, saving
   `pet.size` at line 20. Asset import/selection, sound and screen-relative placement remain.
8. **Incomplete — navigation/desktop.** `NotchPanelController.swift:22` has Spaces/fullscreen flags
   and line 46 has placement, but display-recovery and validated terminal adapters are absent.
9. **Incomplete — handoff.** README/contracts/architecture and Claude/monitoring specs now describe
   implemented paths and unverified support. README explicitly lists the remaining action/pet/desktop
   work. No full 9/9 claim, changed acceptance checkbox, compiler or runtime qualification claim.

Source inspection found an undocumented `--stdio` argument in the inherited Codex quota launcher and
new policy inspector. Official app-server documentation specifies default stdio with `codex app-server`;
those two argument producers now use the documented default. This establishes a documentation/source
mismatch, not an observed runtime failure/root cause. Reproduction/tests were deliberately NOT RUN under
the user's waiver. No runtime probe, installed configuration/credential/transcript access or launch occurred.

Generic source files replace the old Codex-only setup type/file names. This is a functional reuse of the
same ownership/file transaction, not a copied independent Claude writer. Unrelated FM7/editor/CI drafts
remain preserved in the working copy and excluded from staging via index-only clean snapshots of the
three mixed app files and STATUS. The full goal remains active after this milestone.

Saved implementation commit: `32f7b0f` — `feat: implement both provider setups and independent monitoring`.
Source criteria 1–3 are implemented to the documented contracts; 4–9 remain incomplete. Tests, builds,
runtime checks and qualification NOT RUN. Next: concrete local action channels and controls.

## Turn 3 source audit

1. **Implemented in source, unverified — provider setup.** `ProviderSetupService.execute` retains the
   documented-support branch (`.documented(version: version, helperAvailable: true)`) and guarded writer.
   This turn does not add the new action scope to that writer: installing/removing interactive hooks
   remains explicitly incomplete, separate from the existing lifecycle/quota scope finding.
2. **Implemented in source, unverified — sessions.** `SessionStore.suspendMonitoring(agent:)` still
   filters `key.agent == agent && !record.terminal`, retaining unconfirmed notices and ended records.
   The new action store reads those snapshots and never changes lifecycle/request truth.
3. **Implemented in source, unverified — quotas.** `ClaudeStatusLinePlanner` still captures the original
   field and verifies `document.rawValue(at: field) == owner.installed` before restoration. Existing
   Codex/Claude quota source paths remain separate from interactive response transport.
4. **Partial — concrete adapters/service/UI; guarded setup missing.**
   - `ClaudeHookActionAdapter` selects PermissionRequest, PreToolUse/AskUserQuestion and Stop from
     bounded input. Actual encoders return behavior allow/deny without permission rules, original
     question input plus `updated["answers"]`, and `object = ["decision": "block", "reason": text]`.
     Stop replies continue the same prompt as hook feedback; only a live 60-second window is supported,
     with stop_hook_active rejected. Codex remains unsupported; no fake existing-session channel.
   - The packaged `NotchPetActionHook --agent claude` projects an offer, waits on actions-v1.sock,
     validates a single decision against that offer, writes provider stdout, then acknowledges the write.
     Silent fallback emits no decision on timeout/cancel/app loss. The observer helper is unchanged.
   - `ActionSocketIO` reuses the existing private/same-user/bounded stream primitives. The listener
     owns a separate lock/endpoint and recovers only refused owned sockets. ActionTransport uses
     DispatchSource events and one-shot deadlines: 32 sockets, no idle user-wait polling. ActionInbox
     caps queued main-actor events at 128; overflow closes channels rather than losing authority.
   - `ActionStore.receive/reconcile/prepare/acknowledge` bind offer UUID, provider/session/turn and
     observed request identity. Ambiguity, competing offers, stale evidence and prior dispatched
     notices disable submission. Drafts are bounded and offer-owned; oversized drafts are visibly
     trimmed and need an edit before Send. No uncertain delivery can replay.
   - `LocalActionController.send` calls `refreshEvidence()` immediately before `store.prepare` and
     `transport.respond`. Pause/stop/staleness closes capabilities; helper receipts never change
     SessionStore or claim provider acceptance. App-owned AgentServices starts/stops this controller.
   - `LocalActionView` provides details plus Approve once/Deny, question options/custom answers, and
     an explicit Send follow-up composer. NotchSessionView matches these to their exact session.
     Only explicit Respond invokes native `beginInput`; incoming offers never activate the app.
   - Missing: guarded install/check/remove of the three interactive groups, Settings/disconnect
     integration and the complete action audit. These native controls are not counted as full delivery.
5. **Incomplete — pet reactions.** `PetPanelController` still builds PetView from presentation,
   visibility and sleep only; no session adapter or action reuse on the pet surface exists.
6. **Incomplete — pet movement.** `PetPanelController` still sets `panel.ignoresMouseEvents = true`.
   No dragging, island hide/overlap or menu Return Pet path.
7. **Incomplete — custom packs/preferences.** `PetPreferences` still persists only `pet.size`.
   Asset validation/import, selection, sound and screen-relative placement remain absent.
8. **Partial, incomplete — desktop/navigation.** `NotchPanelController.beginInput` explicitly activates
   and makes the ActionNotchPanel key only on Respond; this enables native composers without incoming
   focus theft. Full terminal adapters, keyboard/focus recovery and display/Spaces recovery remain.
9. **Incomplete — full handoff.** Added action contract and four feature records, architecture/README
   updates and D10 implementation addendum distinguishing documented from runtime-qualified support.
   Original A1–A8 and native/live acceptance remain open. No full 9/9 or release claim.

All tests, builds/type checks, app/helper launches, provider probes, event injections, captures, installed
configuration access and runtime qualification: NOT RUN. Only repository inspection and primary
Claude documentation were used. No credentials/transcripts were read, and no trust/settings were changed.
The helper's concrete interface is implemented, but its guarded configuration path is the next source unit.
Unrelated FM7/editor/CI drafts remain excluded from staging; the mixed app-controller/status snapshots
are staged without discarding those working-copy edits. The full goal stays active after this save.

Saved implementation commit: `6554af7` — `feat: add documented Claude hook response channels`.
This saves the concrete adapters/helper/service/native controls, not completion of action criterion 4.
Guarded interactive-hook setup/removal is next. Tests/builds/runtime/qualification NOT RUN.

## Turn 4 source audit

1. **Implemented in source, unverified — providers.** `ProviderSetupController.start` dispatches lifecycle, quota and action operations separately. Claude Disconnect disables consent before removing actions, quota, then lifecycle; failures report completed removals and keep monitoring paused. `ProviderHookTransaction.run` recovers each other known Claude scope under the same writer lock.
2. **Implemented in source, unverified — sessions.** `SessionStore` keeps agent/session identities and seen event/turn bounds; observed end sets terminal state. Actions never resolve that store. Existing cards, selection, timers and delivery-capacity warnings remain the shared observation path.
3. **Implemented in source, unverified — quotas.** Existing `ClaudeStatusLinePlanner` and quota helper/receiver/store/strip remain separate from actions; action removal does not edit statusLine. Codex allowance reads/retries remain read-only.
4. **Implemented in source, unverified — actions.** `HookSetupPlanner.definitions` installs PermissionRequest/Stop plus AskUserQuestion-only PreToolUse with the separate helper and 75s outer timeout. Exact group validation/removal uses the actions ownership/journal files. Settings Connect actions enables explicit persisted consent; consent, Claude monitoring and Agents master gate `LocalActionController.startReceiver`. The same native composers work in Settings without Notch. `send` refreshes exact session evidence before `store.prepare` and single transport dispatch. Claude adapter encodes allow-once/deny, original question input plus answers, and Stop feedback; stdout receipt only proves the helper write. Stop replies last at most 60s and may delay prompt return, disclosed before installation. Unsupported Codex actions stay unsupported. Terminal action history now has one-shot cleanup even after monitoring stops. No runtime verification is claimed.
5. **Incomplete — pet reactions.** Pet still has no session adapter; next milestone.
6. **Incomplete — movement.** `PetPanelController` still ignores mouse input; no drag/hide/overlap-return workflow yet.
7. **Incomplete — custom packs/preferences.** Built-in artwork/size remain; import, selection, sound and placement restoration are missing.
8. **Partial — desktop/navigation.** Explicit Respond acquires focus via `NotchPanelController.beginInput`; full navigation and desktop recovery remain.
9. **Incomplete — full handoff.** Action/provider contracts, area specs, README, architecture and STATUS now reflect setup and consent, but pet/desktop paths and final 9/9 audit remain. No original acceptance boxes changed.

Source inspection only: git status/diff and diff whitespace check, targeted rg/nl excerpts. One inspection used the nonexistent `Sources/NotchPet/AgentServices.swift`; locating the real declaration corrected that lookup. No tests, builds, probes, app/helper launches, captures, installed configuration or credentials were accessed.

## Final result

_Active. On finish/stop, list all nine source statuses and evidence, remaining implementation gaps,
unsupported provider contracts and every unrun verification/qualification item. Mark done only when all
nine source criteria are implemented; do not claim runtime or release readiness._
