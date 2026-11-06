# Goal log: Implement the full local Codex and Claude MVP

- Goal file: goals/full-mvp-implementation.md
- Created: 2026-11-06 11:47 +08
- Turn limit: 60
- Status: implementation-only complete on 2026-11-06; execution turn 9
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
| 5 | 2026-11-06 15:07 +08 | Sources 1–6 implemented; 7 partial; 8 partial; 9 incomplete. Acceptance unverified. | Saved action milestone `521440b`. Added pet-owned moods, app-owned snapshot adapter, bounded deduplicated response cues, native alpha drag/pass-through, island hide/overlap/menu return and saved screen-relative placement/sound. Recorded missing Pets feature contracts before implementation. User excludes company code; original/repository code and public documentation only. Tests/builds/runtime/qualification NOT RUN. |
| 6 | 2026-11-06 15:16 +08 | Sources 1–7 implemented; 8 partial; 9 incomplete. Acceptance unverified. | Saved pet reactions/movement as `474188a`. Added bounded manifest/PNG loader, descriptor-relative asset reads, private staged persistence, revalidation/exclusive rename, immutable playback data/cache, import/selection UI and cancellation/rollback/built-in recovery. Company code excluded. Tests/builds/runtime/qualification NOT RUN. |
| 7 | 2026-11-06 15:39 +08 | Sources 1–7 implemented; 8 partial; 9 incomplete. Acceptance unverified. | User requested local PNG transforms and compatible sheet import, excluded AI workflow and company code, then resumed the full goal. Added shared bounded RGBA codec, affine frame generation, exhaustive alpha slicing, Settings input choices and reuse of existing private pack transaction/rollback. No tests/builds/runtime/qualification. |
| 8 | 2026-11-06 16:37 +08 | Sources 1–8 implemented; 9 incomplete. Acceptance unverified. | Added optional terminal-independent app activation/manual return, explicit iTerm2 pane adapter with process-addressed public events, retained Notch geometry/display/Space/sleep/focus/corner recovery and Settings clamping. No Otty prerequisite, replacement session, AI or company code. Tests/builds/runtime/qualification NOT RUN. |
| 9 | 2026-11-06 16:39 +08 | Sources 1–9 implemented; all runtime acceptance unverified. | Consolidated current production-path audit, reconciled current README/architecture/feature status and checkpoint. Saved navigation milestone 708db53. No source requirements missing under the nine-item goal; unsupported combinations and broader roadmap remain explicit. Tests/builds/type checks/runtime/qualification NOT RUN. |

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

## Turn 5 source audit

1. **Implemented in source, unverified — setup.** The prior `ProviderSetupController.start` path, shared guarded transaction and three Claude scopes remain unchanged. `521440b` saves actions setup/consent alongside provider monitoring without changing policy or trust.
2. **Implemented in source, unverified — sessions.** Pet observes the same SessionStore snapshots as Notch. No surface switch mutates session status, request notices, selected card or drafts. Existing event/turn bounds, duplicate handling and capacity feedback remain.
3. **Implemented in source, unverified — quotas.** The two concrete quota adapters, private bounded intake, separate store/strip and owned forwarding/removal remain unchanged. Pet imports no quota or provider module.
4. **Implemented in source, unverified — actions.** Shared ActionStore/native composers, exact revalidation, single dispatch, stdout receipt and uncertain/cancelled paths remain. Notch hide keeps the same hosting view and drafts. Settings remains an independent response surface.
5. **Implemented in source, unverified — reactions.** `PetSessionAdapter.update` consumes authoritative snapshots, maps confirmed notices/unknown/working/ready/ended, and deduplicates response identities (agent/session/turn/first Stop). Startup-ready records are baselined. Its 4096-entry saturation suppresses new cues. `PetPanelController.setReaction` supplies pet-owned mood/pose and text badge even for idle-only artwork, with a bounded two-second cue and optional system sound. Hidden/asleep/absent Pet never replays cues; no lifecycle event or claim of task success is invented.
6. **Implemented in source, unverified — movement.** `PetDragView.hitTest/accepts` samples rendered-image alpha; mouse-motion monitors update native pass-through without polling or global keys. Native drag hides the retained Notch view. Drop overlap and menu/Settings Return Pet restore it and clamp Pet; absent Notch uses desktop recovery. `PetPreferences.placement` saves display identity and normalized origin. Screen, wake and Space events restore/clamp; sleep stops animation/cues. All native interaction is NOT RUN.
7. **Partial — preferences, no imports yet.** Size, sound and placement are saved; custom pack importer/selection/rollback remain missing. Versioned bounded asset-only contract and feature spec are now written; optional sheets stay outside MVP.
8. **Partial — desktop/navigation.** Pet has real native recovery and pass-through paths. Notch display recovery and validated terminal/application/manual navigation still remain.
9. **Incomplete — full handoff.** Pet feature contracts, current README/architecture/STATUS and provenance constraint reflect source changes. Final 9/9 audit waits for imports and desktop/navigation. Historical acceptance boxes remain open.

Saved action commit: `521440b` — `feat: finish guarded Claude action setup and consent`.
No tests, builds, probes, launches, captures, installed configuration or credentials were accessed.
No company source, internal library or proprietary snippet was imported.

## Turn 6 source audit

1. **Implemented in source, unverified — setup.** Prior provider/controller/transaction paths remain; asset import neither reads nor edits provider configuration.
2. **Implemented in source, unverified — sessions.** Shared snapshots/cards/selection/timers and bounded event reduction remain. Changing artwork does not touch SessionStore or pending notices.
3. **Implemented in source, unverified — quotas.** Prior Codex read-only and Claude status-line intake paths remain. Pet has no usage dependency.
4. **Implemented in source, unverified — actions.** Prior guarded Claude channels, request validation/composers/receipt/uncertain state remain; selecting an asset cannot dispatch an action.
5. **Implemented in source, unverified — reactions.** PetSessionAdapter remains app-owned; a new artwork changes PetPresentation without changing mood/notices. Missing complete/attention art uses idle while text remains distinct. Response cues are bounded/deduplicated and never establish task success.
6. **Implemented in source, unverified — movement.** Native drag/pass-through/overlap return, retained Notch view and menu/Settings return remain; changing artwork refreshes the hit image and leaves normalized placement intact. Sleep cancels cue/playback.
7. **Implemented in source, unverified — custom pets/preferences.** `PetLibraryView` invokes the serialized app-owned model. A detached `PetPackLibrary` worker validates 64 KiB manifest, seven known poses, 64 frames/pose and 128 unique PNG bounds; 2 MiB/frame, 16 MiB encoded, 32 MiB decoded, matching 1–1024px dimensions, single-image PNG and alpha. `PetPackDirectory` walks no-follow descriptors, bounds reads and checks regular files/private ownership/ACLs. Import writes private staged assets, revalidates exact content, then uses exclusive rename; selection saves only after success and guarded readback. Invalid/cancelled input retains current presentation/selection. Saved generated IDs reload with full validation; missing assets retain saved ID and temporarily use bundled art. Built-in recovery works without pack storage. Playback uses immutable bytes and a bounded image cache. Selection, size, sound and normalized display placement live outside Git. Public SDK headers establish renameatx_np signature/RENAME_EXCL; no API or app was executed.
8. **Partial — navigation/desktop.** Pet recovery exists; exact-pane/application/manual navigation and full Notch recovery remain the next source unit.
9. **Incomplete — full handoff.** Current Pet contracts/specs/README/architecture/STATUS now map all pet paths. Original acceptance remains unrun/unticked; final 9/9 audit awaits criterion 8.

Saved pet reactions/movement commit: `474188a` — `feat: add pet reactions and desktop drag return`.
No tests, builds, probes, launches, captures, installed configuration or credentials were accessed.
No company code/internal library/proprietary snippet was imported. Primary interface reading was limited
to repository source/records and public macOS SDK declarations.

Saved custom pack commit: `4904db4` — `feat: import and select bounded asset-only pet packs`.
All behavior remains unverified. The full goal remains active; criterion 8 and final criterion 9 are unfinished.

## Turn 7 source audit

1. **Implemented in source, unverified — setup.** Existing provider setup/guarded three-scope transaction remains unchanged. Local customization starts no provider process and changes no provider settings.
2. **Implemented in source, unverified — sessions.** Existing SessionStore/event bounds/cards remain. PNG/sheet conversion does not read, clear or synthesize session/request state.
3. **Implemented in source, unverified — quotas.** Existing concrete Codex reads and Claude forwarding/receiver/store/strip remain. Neither new input adds quota or provider work.
4. **Implemented in source, unverified — actions.** Existing exact request/turn validation, explicit controls, separate helper and receipts remain. No AI SDK, prompt, paid turn or terminal input is introduced.
5. **Implemented in source, unverified — reactions.** Existing app adapter still selects pet-owned moods and bounded once-per-response cues. Generated animations supply art for the same pose names; text preserves unknown/attention even when supplied rows fall back to idle.
6. **Implemented in source, unverified — movement.** Native drag/hide/overlap/menu return and normalized placement remain. New packs flow through setArtwork to refresh the existing alpha hit image; no replacement Notch or session surface is created.
7. **Implemented in source, unverified — customization.** PetLibraryView exposes Animate PNG, Import Sprite Sheet and folder import. PetLibraryModel uses one native chooser and one cancellable detached worker. PetPackLibrary.importPNG/importSpriteSheet read bounded no-follow source files and normalize into the same private staging/validate/exclusive-rename/preference path. PetLocalAnimation fits visible subject pixels into 256px cells and emits six affine frames per pose. PetSpriteSheet validates seven-row square-cell geometry, exhaustively scans alpha, rejects gaps/empty idle, and maps empty optional rows to idle fallback. Shared PetPNGRaster checks encoded/header/source-depth memory bounds before decode and uses canonical RGBA for deterministic alpha reads. No source image, generated pack or captured runtime data enters Git. Failure/cancellation preserves current selection; committed unselected copies remain possible as documented.
8. **Partial — navigation/desktop.** Pet recovery exists; exact-pane/application/manual navigation and full Notch recovery remain. The full goal was paused for customization questions and has now been explicitly resumed.
9. **Incomplete — final handoff.** Current pet/source specs, contract, README, architecture and STATUS record local-only scope/provenance and source paths. Deferred acceptance boxes are preserved. Final 9/9 audit still waits for criterion 8.

Verification: source reads/rg/nl and git diff whitespace inspection only. Tests, builds, type checks,
app/helper launches, probes, captures, installed configuration and credential/transcript access NOT RUN.
No company code, scripts or assets were copied; no image-generation tool or external model was invoked.

Saved local-only customization commit: `d2cb963` — `feat: add offline PNG animation and sprite-sheet import`.
The full goal remains active; navigation and final handoff remain incomplete. All runtime acceptance is unverified.

## Turn 8 source audit

1. **Implemented in source, unverified — providers.** ProviderSetupService.check/execute binds documented support; ProviderHookTransaction.run locks shared ownership, recovers all Claude scopes and writes only planned fields. ProviderMonitoringModel retains independent provider/action consent. No terminal dependency was added.
2. **Implemented in source, unverified — sessions.** SessionStore.reduce preserves typed provider/session/turn identity, 30-second delivery bounds, duplicate/conflict/ended rules and unknown expiry. AgentServices generation/cutoff checks reject stale queued observations. NotchSessionView retains selection while geometry changes through NotchWindowState.
3. **Implemented in source, unverified — quotas.** AgentServices starts Claude UsageReceiver/UsageInbox independently of windows; AgentUsageController owns Codex reads/retry. Existing forwarding helper and UsageStore retain source/account/freshness handling. Navigation cannot start quota or provider work.
4. **Implemented in source, unverified — actions.** ClaudeHookActionAdapter.providerOutput has concrete permission, structured-answer and Stop-feedback encodings. LocalActionController.send refreshes session evidence before ActionStore.prepare and one transport dispatch. Existing guarded setup, consent, drafts and uncertain receipts remain. Codex action channels are unsupported; Claude follow-up is the bounded existing Stop hook, not arbitrary later input.
5. **Implemented in source, unverified — reactions.** PetSessionAdapter.update derives moods from authoritative snapshots and bounds once-per-response identity to 4096 entries. Pet contains no agent dependency; hidden/asleep response cues do not replay.
6. **Implemented in source, unverified — movement.** PetPanelController retains alpha hit/drag, suppression/overlap/menu return and screen-relative recovery. The retained Notch host preserves selection and drafts while hidden or moved.
7. **Implemented in source, unverified — customization.** PetPackLibrary installs validated data through staged private writes, exact revalidation and exclusive rename. Existing PNG transforms/sheet import, cancellation/rollback, image bounds and own preferences remain unchanged; no AI or company code.
8. **Implemented in source, unverified — navigation/desktop.** TerminalNavigation chooses a bounded application identity/path and activates only one matching running instance. Optional ITermPaneAdapter uses only public get/select Apple Events addressed to a validated PID, bounded by 3 seconds/64 KiB reply/512 panes. Explicit user linking records exact session key, pane ID/tty and process lifetime, rejects duplicates and confirms resulting focus; it is not inferred agent mapping. No launch/create/write event or terminal-input injection. Other terminals retain application/manual return. NotchPanelController subscribes to screen/Space/sleep changes, updates shared geometry without replacing the hosting view, gates visibility, restores explicit keyboard focus and implements corner pass-through/Reduce Motion. PetSettingsController clamps visible Settings after screen/wake changes; Open Sessions is available from menu and Settings. All native/Automation behavior is unrun.
9. **Incomplete — final handoff.** Feature specs, terminal-independence decision, README, architecture and STATUS reflect this milestone; final consolidated nine-area audit remains next. Original acceptance stays unrun/unticked.

Source inspection only: rg/nl/file reads and git diff whitespace inspection. Two initial lookups used obsolete/nonexistent filenames and were corrected using the source file list. Public Apple SDK declarations and iTerm2 documentation/scripting dictionary establish interface identifiers only; no vendor implementation or company code was copied. Tests/builds/type checks, probes, launches, Apple Events, captures and installed configuration/credential/transcript access NOT RUN.

## Turn 9 final source audit

Completion means source implementation only under the user's explicit verification waiver. The original
nine criteria, not the larger future roadmap, define this finish line. Current production sources were
inspected again after the navigation commit; no required source path remains missing.

1. **Implemented / unverified — both provider setups.** ProviderSetupController.start connects native Check/Connect/Repair/Remove/Disconnect controls to ProviderSetupService.check/execute. Its `.documented` support path is concrete, visibly unqualified; disabled/managed policy still blocks it. ProviderHookTransaction.run locks, recovers known journals, preserves unrelated fields and rejects ownership conflicts. Claude lifecycle/quota/actions share the lock but have separate owned records. Disconnect pauses first and reports partial removal. ProviderMonitoringModel.setEnabled independently gates providers; AgentServices uses generation and receipt cutoffs on pause/resume. Neither setup nor monitoring needs terminal metadata. Contracts: provider-setup and monitoring-controls.
2. **Implemented / unverified — shared sessions/Notch.** SessionStore.reduce validates canonical envelopes, delivery age, typed UTF-8 identities, duplicate/conflicting/retired turns and bounded request/session capacity. Response-ready requires the current observed turn; silence expires to unknown. Pending requests survive suspension unconfirmed. AgentServices batches through SessionEventInbox and rejects prior-generation/cutoff delivery. NotchPresentation and NotchSessionView share those snapshots; selected keys survive display/hide changes, request cards retain tool identity, and observed-turn timers tick only while visible/expanded/awake. No terminal liveness becomes session evidence.
3. **Implemented / unverified — both quotas.** CodexUsageConnection launches read-only `codex app-server` and implements initialization/account limit exchange with deadline/output/cancellation bounds; AgentUsageController owns active-provider refresh and bounded retry. StatusLineForwarder.run pumps the original stdin/command streams, exit and cancellation, then ClaudeUsageProvider projects metadata-only windows to private datagrams. UsageDelivery/Receiver request 16 KiB send/128 KiB receive buffers; lease recovery only removes proven refused owned endpoints. Claude-only validated ingress enters bounded UsageInbox; UsageStore keeps source/account replacement, sparse windows, receipt versus measurement time, stale/reset/failure and intake/receiver state distinct. NotchAllowanceStrip renders shared snapshots without owning I/O. Contract: usage-intake.
4. **Implemented / unverified — concrete actions.** Separate ActionTransport/ActionInbox/NotchPetActionHook receive bounded transient offers. ClaudeHookActionAdapter.providerOutput encodes PermissionRequest allow-once/deny, AskUserQuestion PreToolUse updated answers and Stop feedback. ActionStore.matching requires exact provider/session/current turn and one confirmed request/tool identity; prepare reserves one dispatch, acknowledgement attests only helper stdout completion, and interruption becomes uncertain without replay. LocalActionController.send reconciles immediately before transport.respond. Native LocalActionView composers exist in Settings and Notch, guarded by independent default-off consent and separately owned hooks. Drafts remain memory-only. Claude Stop waits at most 60 seconds in the same existing prompt; arbitrary-time replies and Codex action channels are unsupported, with manual/navigation guidance. Contract: local-actions-v1.
5. **Implemented / unverified — reactions.** PetSessionAdapter observes authoritative snapshots and maps working/confirmed attention/unknown/response-ready/ended into PetMood; it never writes SessionStore. ReadyIdentity deduplication is bounded to 4096 app-lifetime entries. PetPanelController.setReaction consumes cues while hidden/asleep/unavailable, uses a bounded two-second presentation and optional default-off sound, and never claims task success. Missing art falls back to idle while native state text stays distinct. Package.swift keeps Pet free of agent modules.
6. **Implemented / unverified — movement.** PetDragView uses rendered alpha and native mouse drag. PetPanelController suppresses the retained Notch during drag; overlap return, menu and Settings Return Pet restore/clamp without rebuilding selection/drafts or resolving notices. Pet-only works without Agents/Notch; overlap has no target when Notch is absent. PetPreferences stores normalized display placement and size/sound outside Git; screen/Space/wake recovery clamps against connected displays.
7. **Implemented / unverified — custom pets/preferences.** PetLibraryView -> PetLibraryModel.perform -> PetPackLibrary imports manifest/frame folders, local PNG transforms or seven-row sheets. PetPackDirectory rejects links/nonregular/unsafe private storage, bounds reads and stages private writes. Manifest/PNG header/decode/frame/memory limits precede playback; install revalidates exact staged assets and commits by exclusive rename. Selection changes only after successful validation/preference readback; errors/cancellation preserve the current pet. Missing saved packs temporarily use bundled art without erasing saved identity; explicit built-in recovery works without pack storage. Immutable bytes/bounded image cache drive visible/awake playback and Reduce Motion. No AI calls, executable plugins, copied artwork or generated packs enter Git. Contract: pet-workflows.
8. **Implemented / unverified — navigation/desktop.** TerminalNavigation.activateApplication verifies bundle identity/path and one running instance. Explicit linkCurrentPane stores exact SessionKey/ID/tty/PID/launch date; duplicate mappings are refused and stale/ended keys cleared. ITermPaneAdapter uses PID-addressed public get/select events only, bounded collection/reply/deadline; focus rechecks unique identity and actual current pane. No replacement app/pane/session or terminal input is created. Other terminals retain application/manual return; legacy Otty hints stay untrusted. NotchPanelController recovers retained geometry/visibility on display/Space/sleep changes, uses native fullscreen auxiliary behavior and explicit Open Sessions/Respond focus only, returns prior focus on owned Escape/Done, implements rounded-corner pass-through and Reduce Motion. Settings clamps on screen/wake. Hidden/asleep presentation timers stop. Specs: pane-navigation, desktop-recovery, accessible-controls.
9. **Implemented / unverified — handoff.** Current provider/quota/action/pet contracts, feature records, terminal-independence decision, README, architecture, STATUS and this nine-item audit now describe production call paths and limits. Old logs and original acceptance boxes remain untouched. Unrelated FM7/editor/CI drafts remain outside all scoped commits. No test/build/runtime result is inferred from names, old evidence or documentation.

Inspection evidence: current files, targeted rg and nl excerpts, git status/diff/stat/whitespace review.
A mistaken ProviderHookBinding filename lookup was corrected through the actual source list; no hidden
implementation was assumed. No tests/builds/type checks, providers/helpers, native app, Apple Events,
probes/injections/captures, installed config, credentials or transcripts were accessed during this run.
No company source, internal dependency, proprietary snippet or artwork was added. Historical reference
notes remain behavioral records, not build inputs. No remote changes were made.

Saved navigation/native recovery milestone: `708db53`.

## Final result

All nine source criteria are implemented under the user's explicit implementation-only scope. The full
local MVP goal is complete in source; all changed behavior remains UNVERIFIED. Runtime qualification
registry is empty. Tests, compiler/type checks, live provider/action/terminal compatibility, stream
preservation, imports, focus, displays/Spaces/fullscreen/sleep and resource measurements are NOT RUN.
Original acceptance and deferred broader roadmap (including FM7, CI, telemetry, login/language,
attention preferences/haptics, SSH/cloud and additional agents) are not completed by this goal.
The unsupported provider/terminal combinations above remain explicit product limits, not stubbed
required paths. No push, PR, extra branch or worktree was created.


## Post-handoff hosted compiler failure

The user authorized pushing, then merging PR #16 and closing the included PR #15. Reading existing
hosted run 42189628912 (build job 127798174265) revealed actual compiler errors at b8feffe, superseding
only the earlier statement that compiler behavior was entirely unverified. No local build/test was run.
Darwin SDK declarations confirm acl_free takes a raw pointer and acl_get_entry takes Int32, while the
constants import as a C enum. Explicit pointer/raw-value conversions correct both production callers.
The status-line helper needs scoped withCString conversions for strdup and the explicit Darwin.crt_externs
module for _NSGetEnviron. No ACL policy, input stream, child environment or test assertion is changed.
The changes await hosted CI; PRs remain open until merge is permitted. Unrelated drafts are excluded.

Hosted run 42190555585 confirms the Darwin interop errors cleared (NotchPetStatusLine linked).
Its full build artifact identifies circular type inference at PetAppController.localActions and
providerMonitoring; downstream member-resolution/menu type-check errors follow those declarations.
Explicit concrete property annotations break inference recursion without changing lazy runtime ownership.
The changed declarations alone are staged from HEAD so existing FM7 additions remain local.

Run 42191161959 (7168af5) cleared the prior source diagnostics but crashed swift-frontend during IRGen
for PetLibraryView, signal 6 / SmallVector capacity overflow, Swift 6.3.2. The earlier assumption that
remaining failures were ordinary source diagnostics is disproved by the full build artifact. The failing
compiler-generated String/actor function conversion maps to the picker's actor-isolated method reference.
Hypothesis: spelling Binding's setter as an explicit closure avoids that conversion thunk. This one-line,
behavior-equivalent workaround is the third scoped correction; no toolchain/CI gate or test is changed.
Hosted CI is the observation for this hypothesis; no local build/test is authorized or run.

Run 42191575948 (2bef0a9) passes Build, packaged Helper, Contract and Workflow. The setter workaround
avoids the Swift IRGen crash. Hosted Tests execute 194 functions: 189 pass, five fail (16 assertions).
Full tests artifact identifies stale fixtures/expectations: pre-start session timestamps fail the new
intake cutoff, quota fixture IDs fail the documented Claude source prefix/hash shape, receiver failure
is expected to disable now-independent usage, and the repaired buffer produces an unexpected success
inside an old withKnownIssue annotation. Existing tests are aligned with the accepted contracts only:
post-start fictional event clocks, valid fictional source IDs, explicit independent-service teardown,
and ordinary required oversize-datagram delivery. Negative inputs, old-generation rejection, notice
retention and callback/receipt assertions are retained. No new tests or local test invocation added.

Run 42192147776 (b64427b) confirms all 194 test functions pass with zero skipped/failed. The Tests job
then fails in coverage.py: missing production file coverage. Its source exporter includes only the
old NotchPetHook object, omitting the two new helper executables. The narrow integration correction
adds NotchPetStatusLine and NotchPetActionHook objects to both LLVM exports and fingerprints their
actual binaries. Every-file normalization and all evidence gates remain intact; no minimum percentage
is introduced or removed. This is package-target alignment, not a CI overhaul. Hosted confirmation
is pending; no local suite, helper, app or provider was run. PR #16/#15 remain open until merge succeeds.
