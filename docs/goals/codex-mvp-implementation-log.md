# Goal log: Finish the native Codex MVP implementation

- Goal file: goals/codex-mvp-implementation.md
- Created: 2026-11-06 10:38 +08
- Turn limit: 30
- Status: implementation complete; original feature acceptance remains open
- Completion scope: six production-source criteria; tests, build, qualification and native acceptance deferred by the user

## Turns

| Turn | Time | Criteria passing | What changed / evidence |
|---|---|---|---|
| 1 | 2026-11-06 11:01 +08 (recorded) | 1–2 source implemented; 3–5 written, review incomplete; 6 incomplete | Active on feat/codex-mvp at c760308. Reused 633b4d0 production refactor and existing test relocations/caller updates; ported 2925880 scanner/planner into Integration. Added owned removal, file/journal transactions, qualification-aware service, controller, Settings/menu controls and explicit optional-service wiring. Evidence: HookSetupModels.swift:24; HookGroupEdits.swift:12/84; CodexHookTransaction.swift:47; CodexSetupService.swift:51; CodexSetupController.swift:37; PetAppController.swift:92. git diff --check exited 0. Tests/build/runtime: NOT RUN. No qualification added. |
| 2 | 2026-11-06 11:11 +08 | 1–6 implemented at source level | Reviewed full paths and completed lexical number preservation, structural handler/ownership validation, safe temporary cleanup, private metadata handling, synchronized recovery, probe cancellation and visible native Check/confirmation feedback. Removal skips CLI lookup. Source evidence is recorded in the goal's six-item audit. Reconciled README/architecture/setup/health/usage records and checkpointed STATUS. Tests/build/runtime/qualification: NOT RUN. Branch remains feat/codex-mvp, base c760308; no commits, pushes, PRs or additional branches/worktrees. |

Preparation is not an execution turn. On activation, continue numbering from the latest execution row.
Record source evidence separately from tests/build/runtime, which must remain NOT RUN for this goal.

## Branch preparation

The user requested separate branches where necessary, then explicitly chose the current checkout
without worktrees. Created `feat/codex-mvp` at `c760308` and switched the existing checkout to it,
carrying all pre-existing changes. `feat/modular-features` is preserved. The newly created clean
`/private/tmp/notch-pet-codex-mvp` worktree was removed; no implementation was written there.
The user subsequently cancelled additional branches and activated the goal: all work stays on
`feat/codex-mvp` in this checkout. No tests/builds/runtime checks are authorized.
Existing upstream refactor test-file moves/import/type updates are reused for package coherence;
no new test cases or changed assertions are introduced to establish completion.

## Final result

Implementation complete for all six source criteria. The source audit in the goal maps each requirement to
production paths and line-numbered evidence. The accepted exact-release registry stays empty: automatic Connect
is unavailable until a Codex release and effective-policy probe qualify. The guarded transaction path is implemented
behind that gate. Check and ownership-based removal are separately wired and do not invent delivery or trust.

NOT RUN: tests, builds/type checks, app/helper launches, live provider/version/policy probes, installed configuration
changes, captures, live sessions, native focus/keyboard/desktop acceptance and qualification. Compiler correctness
and user-visible runtime behavior are unverified. Original spec checkboxes remain open where they require those checks.

Preserved: all pre-existing FM7/editor/CI drafts, original branch refs, independent Pet/Notch/Agents behavior,
bounded silent observer delivery, conservative session evidence and separate quota/action/navigation ownership.
No new dependencies, staging, commit, push, PR or other branch/worktree was introduced during execution.

Final bookkeeping: `git diff --check` exited 0; branch is `feat/codex-mvp`, HEAD remains `c760308`.
The progress board exited 0 with no due/overdue flags. Its feature-acceptance checklist states were not
changed to claim verification; its remaining counts are not an estimate of this source goal's completion.

## Optional staging and commit commands

### Subsequent local-save authorization, 2026-11-06

After the implementation-only handoff, the user asked "can commit first?". This authorizes one local
MVP commit on feat/codex-mvp, superseding the original no-commit restriction for saving this work only.
Exclude pre-existing FM7 instrumentation and editor/CI drafts, including their overlapping source hunks.
Keep those bytes in the working tree. No tests, builds, runtime checks, push or PR are authorized.
The implementation-stage no-commit statements above remain historical; this authorization is later.

These commands were not executed. Existing FM7 changes overlap several source files and STATUS; review hunks
and leave unrelated work unstaged. The intent-to-add list contains only the new MVP/refactor files, not the
pre-existing FeatureNativeCheck/FeatureControlFrames, CI drafts or editor files. Existing test changes are upstream
refactor moves/import/type updates only, not evidence that any test ran.

```bash
git add -N -- Sources/EventBridge/Agent.swift Sources/EventBridge/HookEvent.swift Sources/EventBridge/HookConfigurationJSON.swift Sources/Integration Sources/Usage Sources/NotchPet/CodexSetupController.swift Sources/NotchPet/CodexSetupView.swift Tests/IntegrationTests Tests/UsageTests docs/goals/codex-mvp-implementation.md docs/goals/codex-mvp-implementation-log.md
git add -p -- Package.swift Sources Tests README.md docs/ARCHITECTURE.md docs/SWIFT-PRACTICES.md docs/STATUS.md docs/specs/sessions/codex-setup.md docs/specs/sessions/integration-health.md docs/specs/usage/codex-allowance.md docs/specs/usage/area.md docs/goals/codex-mvp-implementation.md docs/goals/codex-mvp-implementation-log.md
git diff --cached
git commit -m "feat: implement Codex setup MVP"
```
