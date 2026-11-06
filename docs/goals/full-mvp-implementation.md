# Full local MVP implementation

Status: active since 2026-11-06. Full scope: nine source criteria, four milestones.

## Goal block

```text
GOAL: Implement the FULL local Codex+Claude MVP in SwiftUI/AppKit: nine source criteria. Tests/build/runtime/qualification remain UNVERIFIED. Codex-only work cannot finish.

ENTRY: Current checkout, feat/codex-mvp, base 8707bdf. Read AGENTS.md, docs/{STATUS,ARCHITECTURE,SWIFT-PRACTICES}.md, source/area specs, contracts/decisions and this goal/log. Preserve FM7/editor/CI drafts; reuse existing code.

DONE WHEN all nine have source excerpts tracing real adapters, services and UI:
1. Both agents: optional Connect/Check/Repair/Remove, owned install/reinstall/recovery, independent pause/resume/disconnect and truthful health. Preserve unrelated hooks, Otty, Claude statusLine, trust and permission policies.
2. Shared sessions/notch: same-folder identity, requests, unknown/ended states, selection and observed-turn timers; bounded delivery, duplicate/freshness rules and capacity feedback. Silence cannot mean success.
3. Both quotas: Codex reads and Claude status-line forwarding into the shared store/strip. Preserve stdin/output/cancellation/exit behavior. Fix socket buffers, provider/source isolation, stale-socket recovery, receiver health, freshness, sparse/account updates and bounded retry.
4. Actions: separate channels, approve-once/deny, structured answers and explicit follow-ups. Exact existing session/request/turn targeting, duplicate/stale rejection, draft ownership, acknowledgement, cancellation and uncertain delivery. At least one concrete documented provider adapter per action; unsupported-only controls fail.
5. Pet reactions: optional app-owned adapter for working, attention, response-ready and unknown/ended cues; no agent imports in Pet, invented success or repeated completion cues. Retain idle fallbacks.
6. Pet movement: desktop drag, island hide, overlap return and menu Return Pet, preserving selection/notices. Pet needs neither Notch nor Agents; overlap return requires installed Notch.
7. Custom pets: bounded asset-only manifest/PNG validation/import/selection/settings, invalid-import rollback and animation fallbacks. Persist selection, size, sound and screen-relative placement outside Git.
8. Navigation/desktop: validated exact-pane/application/manual-return capabilities; native settings/recovery, keyboard, focus/click-through, Reduce Motion, sleep/Spaces/fullscreen/display recovery and placement clamping. Never create replacement sessions.
9. Handoff: update specs/contracts/architecture/README/STATUS; 9/9 source audit, zero missing paths. Preserve history/unrun acceptance; no tested/release-ready claims.

EVERY TURN: `git status --short --branch`, `git diff --stat`, `git diff --check` (exit 0 to finish); inspect with `rg -n` and `nl -ba`. Print nine implemented/incomplete statuses with source excerpts; names/stubs are insufficient. Append numbered timestamped rows to docs/goals/full-mvp-implementation-log.md. Tests/build/runtime/qualification: NOT RUN.

CONSTRAINTS: Scope: Package.swift, Sources, native resources/packaging, relevant docs; tests only compatibility edits, never weakened assertions/new verification work. No tests/builds/probes/launches/injections/captures, installed-config/credential/transcript access, paid turns, new dependencies, pushes/PRs, branches/worktrees. Commit coherent milestones; log hashes and unverified status. Primary-doc research allowed. Implement documented provider bindings; label unverified support, never invent qualification or bypass trust. No keystroke/clipboard injection, auto-approval, private APIs or transcript/liveness heuristics. No SSH/cloud, extra agents, statistics/telemetry, branding or CI overhaul.

STOP: 60 turns; same blocker three turns with no new approach; missing access/provider contract/product decision after independent work is exhausted. Never shrink the nine criteria or count a blocked integration as delivered.

ON FINISH/STOP: checkpoint/log all nine statuses and unverified behavior; commit coherent scoped work; report hashes and remaining gaps.
```

## Scope confirmed by the user

The user originally requested a full native Flux-inspired port, then clarified that the full MVP was intended.
The Codex-focused goal saved in commit 8707bdf is a foundation slice, not completion of this deliverable.
On 2026-11-06 the user invoked make-goal for the full scope, then confirmed:
"don't need to test first, just leave it unverified. i just want the code implementation".

That instruction changes verification, not feature coverage. Implement all nine areas before claiming full
implementation completion. Do not silently substitute a first milestone, one provider or disabled UI shells.
The result may be "full MVP implementation complete; unverified", never "tested" or "release ready".

This is one bounded local first-release product outcome, with four internal milestones. It excludes the
larger project's SSH/cloud integrations, additional agents, statistics, telemetry, branding and CI program.
No milestone alone can close the full goal.

## Read before execution

- AGENTS.md, docs/STATUS.md, docs/ARCHITECTURE.md, docs/SWIFT-PRACTICES.md.
- docs/specs/notch-companion.md, including its full Done when, constraints and unmigrated tasks.
- Sessions, Notch, Usage, Actions, Pets and Settings area indexes and relevant feature specs.
- docs/contracts/agent-events-v1.md and docs/contracts/codex-hook-setup.md.
- docs/DECISIONS.md and the relevant named decisions in docs/decisions/.
- docs/notes/flux-island-adoption.md and docs/notes/companion-ui-direction.md.
- docs/goals/codex-mvp-implementation.md and its log for the existing source slice and limits.
- Read older branch records via git show only. Reconcile their proposals and obsolete limits rather than
  overwriting newer decisions or duplicating previously completed work.

Production code and current accepted choices take precedence over stale historical ownership descriptions.
The source spec remains authoritative for requirements not migrated into feature files. Preserve its original
task/evidence history; migration is not implementation or acceptance.

## Four milestones; one finish line

1. **Both providers, sessions and quota — criteria 1–3.**
   Reuse existing bridge/store/cards/strip and the committed typed module split and Codex setup source.
   Complete concrete Codex version/effective-policy bindings and Claude-specific lifecycle policy,
   planner, guarded installation/recovery/removal, controls and independent provider monitoring.
   Claude lifecycle setup preserves statusLine as an uninterpreted value. Its quota forwarding is separate.
   Complete the forwarding helper, original command I/O/cancellation/exit preservation and app-owned
   UsageReceiver lifecycle/batching into UsageStore. Address the known datagram-buffer limit and
   stale endpoint/source handling without changing global OS limits or overwriting in-app Codex sources.
   Retain actual provider windows, source/account uncertainty, reset/receipt/measurement distinctions and
   active-provider filtering. Define sparse update/reconnect/account replacement behavior explicitly.
2. **Local actions and replies — criterion 4.**
   Use primary documentation/source evidence to define supported existing-session response channels,
   their identities, request details, content/wait bounds, acknowledgements, cancellation and uncertain results.
   Implement providers and shared service/state, not just protocols and unavailable buttons.
   Every required action has at least one concrete documented provider path; do not promise every provider
   supports every capability. Unsupported combinations need truthful capability/navigation guidance.
   Preserve approve-once/deny scope; never create persistent grants or inject terminal keys.
   Request details/drafts are transient action state outside ordinary observation logs.
3. **Pet interaction and customization — criteria 5–7.**
   Preserve the independent Pet target and existing original rabbit artwork. Add an app-owned adapter
   from authoritative session snapshots, distinct states/notices and response-ready cue deduplication.
   Implement native dragging/hide/overlap-return and recovery, without enabling Agents for pet-only use.
   Add bounded asset-only manifest/PNG validation, import/selection/settings, rollback and preference restoration.
   Preserve idle/visible fallback, hidden/asleep scheduling cancellation and Reduce Motion.
   Seven-row sprite-sheet import remains optional under open P5; accepted manifest/frame packs are required.
   No mascot/brand redesign, artwork generator or executable pet plugin is part of this goal.
4. **Navigation, desktop recovery and handoff — criteria 8–9.**
   Implement terminal capability adapters and current-target validation. Missing metadata never blocks
   monitoring, quota or supported provider actions. Do not launch a replacement pane/session.
   Native controls and recovery must be real code: keyboard routes, focus ownership, transparent regions,
   display changes/clamping, sleep/wake, fullscreen/Spaces and Return Pet.
   Reconcile current docs and feature ownership; audit all nine production call paths and report exact gaps.

These milestones are sequencing and commit boundaries, not separate completion goals or branches.
The user explicitly authorized local commits where appropriate; do not ask again for routine scoped saves.
Use normal implementation judgment for routine choices within accepted behavior. Record newly settled
interfaces/operational policies before coding against them; distinguish proposals from accepted decisions.

## Meaning of unverified

No tests, builds/type checks, benchmarks, fake or live process probes, app/helper launches, event injections,
captures, installed configuration reads/changes or paid turns are authorized during this run.
No verification-only instrumentation, check harnesses or new test cases are requested.
Necessary test caller/import compatibility edits may accompany real source changes; never weaken assertions.

Read-only repository inspection and primary provider documentation/source research are permitted.
Implement supported provider behavior from concrete interfaces; do not guess unsupported protocol fields,
fake effective policy or copy Flux's implementation/assets. Check/updater actions written into the app may
later perform bounded provider inspection when a person explicitly invokes them; do not invoke them here.

Keep documented/unverified support distinct from runtime-qualified support. The current Codex release
registry is empty; that fact is a deployment limitation, not proof that a concrete policy/driver exists.
The full source implementation needs actual provider producers/adapters and call paths, not only an
empty registry, injectable placeholder or a view that always returns unavailable.
Do not invent qualification or bypass normal trust/permission handling to improve completion counts.
If a required supported provider interface cannot be established from documentation/source, record that
precise missing contract, continue independent work, and report incomplete/blocked rather than fabricate it.

A full source audit does not establish compiler correctness, compatibility with installed CLI versions,
actual approval delivery, terminal preservation, native focus behavior or measured efficiency.
Keep source implementation status separate from all deferred acceptance checkboxes and historical results.
D8 excludes screen-reader testing; retain native labels, keyboard controls, Reduce Motion and focus behavior.

## Existing task map

- Criterion 1: Codex setup I3b/I3c/I5/I6 plus Claude I4 and shared I5/I6; provider monitoring controls.
  The older workflow branch has CL1–CL5 and CN1–CN6 planning to reconcile, not fresh implemented Claude drivers.
- Criterion 2: observation-bridge/session-state and session-island; preserve completed cards/allowance behavior.
- Criterion 3: U1–U6, Claude U2b/U2c3, usage/refresh-recovery and recorded receiver decisions.
  App/store ownership is already implemented; the old panel/view-owned I/O description is historical.
- Criterion 4: A1–A8 and actions/verified-channels, permission-decisions, structured-answers, follow-up-replies.
- Criteria 5–7: pet source P1–P4/P7/P8 and pets/agent-reactions, detachable-pet, custom-packs;
  reuse existing built-in-pet work and preserve its deferred acceptance.
- Criterion 8: N1–N8 and R1–R4/R8 implementation responsibilities, relevant Settings and recovery features.
  Physical checks, R5 profiling and native/live acceptance remain not run.
- Criterion 9: record reconciliation and complete source audit. Do not turn duplicated/migrated checkbox
  counts into a project percentage or treat the earlier Codex goal's closure as full MVP closure.

Some area entries still lack detailed specs. Write those necessary contracts/task plans before implementing
their behavior, preserving the source obligations. This goal is the full implementation task list; do not
stop merely because a feature file is absent or an old verification-first gate contradicts the user's waiver.

## Branch, change and storage boundaries

Use only the existing checkout on feat/codex-mvp, starting at commit 8707bdf. No extra branches/worktrees.
Preserve current unstaged FM7 instrumentation, editor configuration, CI drafts and STATUS's unrelated CI notes.
Do not stash/reset/discard those changes. Adapt shared files around them and keep changes attributable.
Do not rewrite the saved Codex commit or automatically resume earlier paused goals.

Work may touch Package.swift, Sources, native resources and packaging, README, and relevant docs.
Native packaging includes script changes needed to bundle implemented helpers, not CI/check-script overhaul.
No package dependencies or global settings/registrations are authorized. Runtime files, imported packs,
owned configuration records, drafts and captured session data remain outside the repository.
Current original rabbit art can be reused; imported artwork is data, never code.

On 2026-11-06 the user added: "commit where it's good to do so". This authorizes coherent local milestone
commits throughout this full goal on feat/codex-mvp, superseding the earlier no-commit restriction.
Commit when a bounded implementation unit has real callers/UI wiring and a reviewable source diff.
Include directly relevant documentation and record the hash, scope and NOT RUN verification in the log.
Do not commit half-written code, placeholders or unrelated FM7/editor/CI drafts merely to create a checkpoint.
Review staged content and git diff --cached --check; stage explicit paths/hunks rather than all changes.
Tests/builds remain skipped. A local commit is not acceptance or full MVP completion.
No push, publishing, PR, other branch or worktree is authorized.

## Log and stop rules

Use docs/goals/full-mvp-implementation-log.md. Preparation is not execution turn 1.
Record branch/base, nine per-item source statuses, evidence paths/lines, changed behavior, missing work and
NOT RUN verification each execution turn. Reuse prior source work, but re-inspect the current state before
claiming it satisfies a criterion. Freeze the nine criteria; do not edit them to fit partial output.

Default large-goal limit: 60 execution turns. Stop at the limit with incomplete items listed.
A repeated blocker counts toward the three-turn stop only when no new approach or independent authorized
work can make progress. If a genuine product decision/access/provider contract is needed, state it precisely.
Do not create endless retry loops or silently deliver unsupported-only controls.

Only after all nine source criteria are complete may the implementation log be marked done.
If stopped or blocked, keep the missing criteria visibly incomplete. Update STATUS using checkpoint,
preserve unrun feature acceptance, save coherent scoped work under the user authorization and report commit hashes.
Leave incomplete or unrelated work uncommitted and identify it in the handoff.

## Preparation record

Prepared on 2026-11-06 from the conversation, current status/specs, existing commit and make-goal instructions.
The user confirmed full code implementation with verification left unverified. No implementation, build,
test, runtime probe, installed configuration access, commit, branch/worktree change or goal activation
occurred during the initial goal preparation. The user subsequently authorized saving this plan and coherent
implementation milestones locally; that does not activate the goal or authorize runtime checks.
