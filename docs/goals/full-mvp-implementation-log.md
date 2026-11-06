# Goal log: Implement the full local Codex and Claude MVP

- Goal file: goals/full-mvp-implementation.md
- Created: 2026-11-06 11:47 +08
- Turn limit: 60
- Status: active since 2026-11-06; execution turn 2
- Scope: all nine source criteria; four milestones are not separate completion goals
- Verification: tests, builds, runtime checks and provider qualification NOT RUN by user instruction
- Branch/base: feat/codex-mvp / 8707bdf; current checkout only
- Local commits: authorized at coherent milestones; record hashes and NOT RUN verification; no push/PR

## Turns

| Turn | Time | Criteria passing | What changed / evidence |
|---|---|---|---|
| 1 | 2026-11-06 12:11 +08 | Source 2 implemented; 1, 3–9 incomplete. Acceptance unverified. | Started the full goal. Added bounded Claude forwarding executable and packaging; session-hashed source projection; per-socket buffers; private receiver lease/refused-socket recovery; Claude-only validation; bounded inbox/app receipt; source expiry and loss/health feedback; Codex retry; session capacity/overflow UI. See source audit below. Coherent local source commit being saved; hash recorded after creation. Tests/builds/runtime/qualification NOT RUN. |
| 2 | 2026-11-06 13:20 +08 | Sources 1–3 implemented; 4–9 incomplete. Acceptance unverified. | Previous turn classified as progress (`299d021`). Generalized guarded provider setup/recovery; concrete documented release/policy bindings; native controls for both agents; independent consent/cutoffs/cancellation; separate owned Claude status-line wrapping/restoration and cross-scope recovery. Corrected Codex launch arguments against official stdio documentation without executing a probe. Relevant source audit below. Preparing a scoped local milestone commit. Tests/builds/runtime/qualification NOT RUN. |

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

## Final result

_Active. On finish/stop, list all nine source statuses and evidence, remaining implementation gaps,
unsupported provider contracts and every unrun verification/qualification item. Mark done only when all
nine source criteria are implemented; do not claim runtime or release readiness._
