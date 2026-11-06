# Goal log: Implement the full local Codex and Claude MVP

- Goal file: goals/full-mvp-implementation.md
- Created: 2026-11-06 11:47 +08
- Turn limit: 60
- Status: active since 2026-11-06; execution turn 1
- Scope: all nine source criteria; four milestones are not separate completion goals
- Verification: tests, builds, runtime checks and provider qualification NOT RUN by user instruction
- Branch/base: feat/codex-mvp / 8707bdf; current checkout only
- Local commits: authorized at coherent milestones; record hashes and NOT RUN verification; no push/PR

## Turns

| Turn | Time | Criteria passing | What changed / evidence |
|---|---|---|---|
| 1 | 2026-11-06 12:11 +08 | Source 2 implemented; 1, 3–9 incomplete. Acceptance unverified. | Started the full goal. Added bounded Claude forwarding executable and packaging; session-hashed source projection; per-socket buffers; private receiver lease/refused-socket recovery; Claude-only validation; bounded inbox/app receipt; source expiry and loss/health feedback; Codex retry; session capacity/overflow UI. See source audit below. Coherent local source commit being saved; hash recorded after creation. Tests/builds/runtime/qualification NOT RUN. |

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

## Final result

_Active. On finish/stop, list all nine source statuses and evidence, remaining implementation gaps,
unsupported provider contracts and every unrun verification/qualification item. Mark done only when all
nine source criteria are implemented; do not claim runtime or release readiness._
