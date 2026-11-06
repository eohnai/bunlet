# Notch companion for terminal coding agents

Record migration approved on 2026-10-29: [decision 0011](../decisions/0011-organize-records-by-feature.md) replaces the single-spec layout.
The area indexes are [sessions](sessions/area.md), [notch](notch/area.md), [usage](usage/area.md), [actions](actions/area.md), and [pets](pets/area.md).
This file remains the source for unmigrated tasks and evidence.
[Observation bridge](sessions/observation-bridge.md) now owns its seven completed tasks and copied historical evidence.
Five retrospective specs now own the tasks of features that already have code: [session-state](sessions/session-state.md), [integration-health](sessions/integration-health.md), [session-island](notch/session-island.md), [codex-allowance](usage/codex-allowance.md), and [claude-allowance](usage/claude-allowance.md).
[Built-in pet](pets/built-in-pet.md) plans standalone use under accepted [decision 0013](../decisions/0013-separate-standalone-pet-scope.md).
Its new tasks are proposals. Original P0–P8 task lines and historical evidence stay here unchanged.
Historical evidence below remains intact during migration. Do not count moved tasks twice.
Its earlier single-spec instructions are historical and superseded. Do not drop tasks or treat implementation as verified completion during migration.

## Merged MVP handoff, 2026-11-06

[PR #16](https://github.com/eohnai/notch-pet/pull/16) merged as
`fa691f47be6fef39445c3d37d434c1c12c76c78b`; it includes PR #15's independent feature-management
commits. [Hosted run 42194558749](https://github.com/eohnai/notch-pet/actions/runs/42194558749)
passed at PR head `ab2ae13`: 194 existing tests, packaged Build and Helper, Contract, Workflow,
coverage export/inventory and Required. This is recorded hosted evidence, not a new local run.
Earlier failed runs and process/socket timeouts remain in the [implementation log](../goals/full-mvp-implementation-log.md).

The full nine-area implementation-only MVP is merged. The broader release checklist below is not
complete: installed-provider setup/actions, stream preservation, real terminal focus, physical-notch
interaction, imports/restart recovery and resource measurements still require their own acceptance.
Hosted test coverage does not establish end-to-end coverage of every new feature. No local builds,
tests, app/provider launches, installed configuration access or captures were run for this docs update.

| Area | Merged production path | Remaining limits/acceptance |
|---|---|---|
| Provider setup | ProviderSetupController/View → ProviderSetupService → ProviderHookTransaction/HookFileDirectory; separate lifecycle/quota/actions ownership | Codex 0.164.0 and Claude 2.1.306 are documented bindings; runtime-qualified registry is empty. Real trust, policy, preservation and recovery acceptance is deferred. |
| Sessions and Notch | AgentServices → SessionEventInbox → SessionStore → NotchPresentation/NotchSessionView; menu contains recovery/setup controls, no session list | Native panel/focus/hit-testing and live event delivery acceptance remain open. |
| Quota | CodexUsageConnection/AgentUsageController; NotchPetStatusLine → ClaudeUsageProvider → UsageReceiver/UsageInbox → UsageStore → NotchAllowanceStrip | Claude-only hashed-source ingress and owned socket recovery are implemented. Live Claude stream preservation and account/reconnect acceptance remain open. |
| Local actions | NotchPetActionHook/ClaudeHookActionAdapter → ActionTransport/ActionStore → LocalActionController/View in Notch and Settings | Claude approve-once/deny, structured answers and ≤60-second Stop feedback; Codex actions and arbitrary-time replies are unsupported. Helper receipt does not prove provider acceptance. |
| Pet reactions | App-owned PetSessionAdapter → independent Pet moods/poses and bounded cues | Response ready does not mean success; native animation/sound acceptance remains deferred. |
| Pet movement | PetDragView/PetPanelController → retained Notch hide/return and saved display-relative placement | Pet works without Agents/Notch; real drag/overlap/display acceptance remains open. |
| Custom pets | PetLibraryModel/View → PetPackLibrary/PetPackDirectory → validated private staged assets → playback/preferences | Manifest packs, offline PNG transforms and seven-row sheets are implemented; no AI workflow or company code. Native import/rollback/restart acceptance remains open. |
| Navigation/desktop | TerminalNavigation + optional ITermPaneAdapter; NotchWindowState/NotchPanelController and Settings recovery | Any chosen running terminal supports application/manual return. Exact pane focus is explicit user-linked iTerm2 only, not automatic agent mapping. Legacy Otty hints stay untrusted. Native/Automation qualification is deferred. |
| Handoff | [Nine-area source audit](../goals/full-mvp-implementation-log.md#turn-9-final-source-audit), contracts, feature specs and this reconciliation | Implementation completion is separate from feature/release acceptance. Original verification-bearing checkboxes remain open. |

The local-only sprite-sheet conversion choice is accepted and implemented under the full MVP;
its earlier P5 proposal is superseded. P5/P6 native acceptance is not established by that source finding.
Unimplemented broader roadmap work (login/language preferences, automatic attention/haptics,
telemetry/statistics, additional agents and SSH/cloud) is not delivered by this merge.
The user chose Bunlet on 2026-11-06 to emphasize the pet, including desktop use.
[Decision 0016](../decisions/0016-use-bunlet-name.md) and the
[product-name spec](settings/product-name.md) own the approved visible app and bundle rename.

## Goal

Show when Codex CLI or Claude Code needs attention on the user's M2 MacBook Air, without requiring Otty.
Let a customizable pet move between the notch and desktop while sharing the same session state.
Show reported usage limits and reset times so the user can monitor available allowance.
Let the user approve or deny local agent requests, answer structured questions, and send follow-up replies from the app through verified agent-specific channels.

On 2026-10-28 the user requested a specification update that adapts useful Flux Island behavior
while retaining this app's native implementation and conservative session evidence.
Prioritize a usable path from hook setup to visible session state and the correct terminal pane.
The user subsequently included local approvals and replies in the release and designated SSH/cloud integrations as optional future work.
The [reference findings](../notes/flux-island-adoption.md) separate observed Flux behavior from recommendations.

## Done when

- A local SwiftUI/AppKit app launches with a menu-bar control and notch interface on the user's Mac.
- An approval request from each supported agent appears with the correct agent, project, and session.
- Each agent's finished response produces a response-ready notice without claiming the task succeeded.
- Dedicated input events are shown where verified; uncovered question types have documented limitations.
- Alerts from two concurrent sessions remain distinct, including sessions in the same project.
- Terminal navigation reports exact-pane, application-only, or unavailable capability separately from agent monitoring.
- A verified adapter focuses the exact recorded pane. Otherwise offer verified application activation or explain manual return.
- Both supported agents deliver live events and visible alerts in at least one local terminal other than Otty.
- Missing terminal metadata or navigation support does not block monitoring, pet reactions, or supported allowance reads.
- Closing a pane or restarting the app cannot present an unverified session as still working.
- The user can drag the pet onto the desktop and return it to the notch.
- A valid custom pet imports and responds to working, attention, response-ready, and idle states.
- A missing optional animation falls back safely; an invalid pet pack leaves the selected pet intact.
- Pet selection, size, sound preference, and valid placement survive an app restart.
- Both providers show real usage percentages and reset times for verified supported account modes.
- The compatibility record identifies modes without usage data; those modes show unavailable with a reason.
- Usage windows show freshness and used/remaining labels, and are not double-counted across sessions.
- Setup and removal preserve existing Otty hooks, unrelated agent settings, and Claude Code status-line output.
- App unavailability cannot auto-approve a tool or leave the terminal waiting indefinitely for this app.
- Documented checks cover sleep, wake, fullscreen, Space changes, external-display removal, and Reduce Motion.
- A five-minute idle profile and an animated-pet profile record CPU and memory measurements on the target Mac.
- The notch is the primary session interface. The menu bar contains basic app controls and no session list.
- Setup reports agent-version support, managed-hook configuration, helper availability, receiver state, and last observed delivery separately.
- Repeating setup does not duplicate managed hooks; removal preserves unrelated configuration and reports conflicting user edits.
- A stale or ambiguous terminal target never focuses another pane or creates a replacement session; the interface explains the unavailable action.
- Inactive transparent areas pass clicks through, and the notch and pet do not steal keyboard focus merely to show an alert.
- Unknown or ended session state is distinguishable from working and response ready in both surfaces; retained requests remain visibly unconfirmed.
- Dragging the pet over the notch returns it; a menu-bar Return Pet action remains available when dragging is impractical.
- Usage refresh failures produce stale or unavailable states with bounded retry backoff; restoring a connection does not duplicate account allowance.
- The user can approve once or deny a confirmed local permission request, with the decision delivered to that exact pending request and acknowledged by the supported agent channel.
- The user can answer a structured question or explicitly send a follow-up reply to the selected local agent session; these are separate capabilities with per-agent/version availability.
- Switching sessions, duplicate clicks, expired/cancelled requests, disconnects, and app restart cannot send an action to a different request or silently replay a reply.
- Controls show pending, confirmed, rejected, and unavailable outcomes; sending an action alone does not establish that the agent accepted it or resumed work.
- At least one verified local provider path works in the actual app for each of approval/denial, structured answers, and follow-up replies. Any missing path remains a release blocker rather than marking all integrations unavailable and calling the feature complete.
- Unsupported agent/version actions show a reason and the available terminal navigation or manual-return guidance.
- The release compatibility record identifies verified agent, version, terminal, and action combinations without promising universal support.

The historical sprite-sheet proposal below retains its acceptance checks. The later local-only conversion decision and merged implementation are recorded in the handoff above; decision 0006's asset-only runtime remains intact.

## Out of scope

- Simulated terminal keystrokes or clipboard submission as an automatic approval/reply fallback, unattended approvals, or broad permission-policy changes.
- Codex desktop and other coding apps in the first release.
- Guaranteed exact-pane navigation in every terminal, IDE, multiplexer, or remote environment.
- SSH hosts, remote computers, and cloud-agent integrations in the first release; these remain optional future work below.
- A cloud backend, user accounts, synchronization, searchable session history, or a pet marketplace.
- In-app artwork generation, a pet drawing editor, three-dimensional pets, and scripted pet plugins.
- Reading private usage endpoints, copying provider tokens, or estimating subscription quota from tokens.
- Guaranteed notification of arbitrary questions without a verified event source.
- Reuse of Flux Island code or internal assets, a Flux runtime dependency, or migration to Electron/React.
- Transcript or terminal-output parsing and process-liveness heuristics that infer task completion.

## Constraints

- Retain SwiftUI/AppKit, shared stores, and separate agent, terminal, usage, and window responsibilities.
- Do not require Otty, its executable, or its pane metadata for agent monitoring or pet reactions.
- Keep navigation capabilities separate from provider action capabilities and integration-health failures.
- Retain the version-1 observation contract, bounded one-way observation delivery, silent observer-helper failures, and explicit unknown state. Define a separate action contract before introducing request/response behavior.
- Do not change payload limits, the helper deadline, freshness, or recovery semantics merely to make a check pass.
- Preserve agent hook trust review, existing Otty and agent configuration, and existing Claude status-line output.
- Keep active sessions in memory; new evidence is required after restart. Preferences and imported assets remain outside the repository.
- Preserve all completed work and the existing single-spec layout requested by the user. Do not migrate specs or decision records into new folders. Superseded on 2026-10-29 by decision 0011: specs now live in area folders. Preserving completed work still applies.
- Reimplement selected reference behavior through supported native APIs. Reference inspection is evidence of packaged code, not runtime verification or a performance benchmark.

## Terminal independence and standalone pet review, 2026-10-30

[Decision 0012](../decisions/0012-support-terminal-independent-operation.md) accepts terminal-independent operation.
Otty becomes one optional navigation adapter. Missing navigation must not disable otherwise supported agent features.
This updates current release requirements, not historical evidence or completed task wording.
N1–N2 and N6 retain their Otty adapter checks. N7–N8 add the general capability boundary and checks without Otty.
Preserve all seven deferred Codex checks in R6–R7 under decision 0009.

The version-1 observation contract still accepts only Otty in its optional terminal object.
Observations without that object remain valid. This update does not widen the contract or verify another terminal.
Any new navigation metadata needs a separately reviewed contract plan.

The user also raised pet-only users and asked about a separate service or project.
[Decision 0013](../decisions/0013-separate-standalone-pet-scope.md) records that choice as proposed.
One app with a separate pet module and optional agent features is the assistant's recommendation, not accepted scope.
P0 must settle standalone behavior, packaging, and dependency changes before pet implementation.
The existing pet dependency remains pending that choice. No separate process, repository, or app target is authorized.
This documentation update does not resume the paused goal or authorize runtime checks.

### Accepted pet direction, 2026-10-30

The user subsequently accepted one app with an independent pet module and optional agent services in decision 0013.
This replaces the proposed status and retained integrated-pet dependency described above.
Set up the pet first without agent services. Connect agents through optional approved setup, then react to received session events automatically.
Silence does not prove an observed session ended. Preserve unknown state and unresolved notices.
The user approved separate standalone built-in-pet and agent-reactions features. Only built-in-pet has a detailed plan so far.
The [pets area](pets/area.md) defines the revised boundaries. Approval of the direction does not approve implementation tasks.

## Notch and allowance plan update, 2026-10-29

The user approved the prior notch direction and requested adding 5-hour and weekly limits.
This update changes records only. No goal is active after the user cleared the old goal.
Keep the existing single specification as previously requested; N and U are separate feature slices. (Superseded on 2026-10-29 by decision 0011. N and U tasks now live in area specs.)
Completed tasks and historical evidence remain intact. Open task wording reflects the new direction.

### Feature 1: access sessions in the notch

Goal: inspect sessions through a compact, expandable island around the physical notch.
Collapsed content shows activity and session count. Explicit expansion reveals all sessions and details.
The old menu session list is removed only when the notch can replace it. Quit remains available.
Settings and Return Pet appear when their implementations exist, without dead controls.

Done when N3–N5 and the I1 retirement check pass: correct notch placement; expand/collapse without
unsolicited focus; both providers and same-folder sessions remain distinct; all observed state and
retained-notice meanings survive; selection survives updates; menu contains no session list.
The real-app check uses fictional helper events, not a second mock interface. Limit visual QA to
one batched pass and one correction pass. Do not require repeated user screenshots.
N1–N2 exact-pane navigation and N6 live-agent acceptance remain separate follow-ups.

### Feature 2: see the limits of agents in use

Goal: see Claude Code and Codex 5-hour and weekly allowance next to their sessions in the notch.
Show only providers with active observed sessions: Codex alone shows only Codex; Claude alone shows only Claude; both active shows both. Cached allowance alone must not make an inactive provider appear. Percentages are labelled used;
show a reset time/countdown when supplied, plus freshness and source/account confidence.
Do not multiply allowance by session count or combine providers into a total.

Accepted provider visibility: only agents in use appear. Implementation assumption for review:
a provider is in use when it has a non-ended observed session. Unknown sessions remain visible with uncertainty. With no observed sessions, show an
empty state rather than claiming that no agent process exists. Multiple anonymous Claude sources
remain separate, labelled account unverified; provider grouping does not establish shared account identity.

Done when U1–U6 pass: Claude-only, Codex-only, both-provider and empty cases render correctly;
real supported sources supply values to the actual notch; either window can independently be absent;
stale/disconnected/signed-out states explain missing values; a reset never fabricates zero usage;
reconnect and multiple sessions do not duplicate allowance or start agent work.
Fictional values are test fixtures only. Unavailable states do not substitute for required live-source verification.

Claude uses the accepted status-line forwarding source. Codex uses read-only App Server quota reads.
The provider contracts must preserve Claude terminal output and bound cancellation/waits.
Quota has its own store/transport; do not widen the existing lifecycle envelope to carry account data.
Codex window labels follow reported duration: 300 minutes maps to 5-hour, 10080 to weekly.
Other or unknown durations keep honest labels; never relabel every primary/secondary pair as 5h/week.
Missing windows show unavailable with a bounded reason rather than a made-up percentage.

Out of scope for these slices: additional agents, animated/custom pets, approval/reply dispatch,
SSH/cloud, private endpoints, credentials, token-based estimates and automatic paid prompts.
The existing I3 setup design remains separate and is not an entry gate for notch/usage development.
Installed configuration changes require an explicit reversible plan and user approval; isolated fixtures do not.

Execution order: N3, N4, N5, U1, U2, U3, U4, U5, U6. Each implementation task still needs a
concrete size check: it must be finished and verified in one session.
Split a task before coding when it cannot fit.
The initial goal groups these into eight reviewable stages; their source-of-truth checkboxes stay here.

## Behavior to adapt

All behavior in this section is planned unless the coverage record below identifies implemented code.

### Setup and connection health

Offer a per-agent check, setup, and removal flow from the menu-bar interface.
Check supported versions and configuration shapes before changing files. Unsupported or malformed configuration must remain untouched.
Track only app-owned entries and restore or remove those entries without overwriting later user edits.
Setup must be idempotent, and conflicts must leave a recoverable configuration rather than a partial installation.
Do not preapprove Codex hook trust. Keep Claude lifecycle hooks separate from the later quota-forwarding wrapper.

Show configuration health separately from observed activity. A running receiver or successful helper write is not proof of end-to-end receipt.
Report delivery only after an observation actually reaches the app; no recent event alone does not prove the integration is broken.
An empty session list must not be described as a disconnected agent without additional evidence.
Routine diagnostics include versions, bounded error categories, and receipt time, with no prompts, tool input, transcripts, or credentials.
Action-channel setup is a separately reported capability; successful lifecycle hooks do not prove approval or reply support.
Install or remove any additional action integration with the same ownership, conflict, and trust rules.

### Session selection and terminal navigation

Present real session snapshots directly in the notch. Retain the existing menu implementation only until the notch replaces it; remove session rows when that replacement ships.
Show agent, project, session identity sufficient to distinguish same-folder sessions, attention state, and evidence freshness.
Derive priority once for both surfaces: confirmed unresolved input first, then response-ready notices, with every session still reachable.
Retain unconfirmed requests visibly when the store becomes unknown; dismissing a presentation notice must not resolve the underlying request.

Treat navigation as optional. Monitoring uses agent and source session identity without requiring terminal identity.
Each terminal adapter reports exact-pane navigation, application activation, or unavailable navigation.
Validate a target against current live identity before enabling an exact-pane jump.
For Otty, retain inherited-selector validation and closed, reused, stale, and ambiguous target checks.
Offer application activation only when the application is identified. Otherwise explain how to return manually.
Missing navigation support is not evidence that agent monitoring is broken.
Never create a pane, launch a replacement agent session, approve a command, or send terminal input as a navigation fallback.

### Local approvals and replies

Local interaction is accepted release scope under [decision 0010](../decisions/0010-add-local-agent-actions.md).
Expose three separate capabilities per agent/version: permission decisions, structured-question answers, and follow-up text submission.
Verify actual response mechanisms first; lifecycle event coverage and Flux's adapter support do not establish that our installed agents expose the same channels.
Record unsupported combinations explicitly and show available terminal navigation or manual-return guidance.
Provider action channels must not require a terminal adapter merely because navigation is unavailable.

An approval card identifies the agent, project, session, and exact live request and shows bounded request details needed to understand the action.
Start with approve once and deny. Do not silently convert these into remembered or account-wide grants.
Structured answers preserve the source question/options and validate any required answer shape.
A follow-up composer targets a confirmed session; text is sent only after the user selects Send.
Switching sessions must not carry a draft or pending action into a different target without explicit user action.
The editor may acquire keyboard focus when explicitly opened; incoming alerts remain nonactivating.

Bind every action to a verified agent/session/request or conversation/turn target and an action identity.
Revalidate that target at dispatch, disable controls on stale/unconfirmed or resolved requests, and reject duplicate actions.
Show submission separately from provider acknowledgement and observed lifecycle progression.
Timeout, disconnect, cancellation, or unknown delivery must not grant permission, claim a successful reply, or retry blindly.
Bound interactive waits and outstanding actions independently from the existing 250 ms observer helper.
Never turn an unavailable app or dismissed card into an allow decision; specify the provider's terminal fallback/cancellation behavior in the action contract.
Keep necessary request details and user replies in memory only and out of routine diagnostics; the version-1 observation allowlist remains unchanged.
Quota refresh, setup checks, and reconnection never submit user messages or start agent work.

The action-channel structure remains open until A1–A2 establish compatibility:

- **Dedicated interactive helper/endpoint:** response-capable hooks can carry decisions to a pending request; needs its own bounded waiting and shutdown lifecycle.
- **App-owned provider control channel:** supported provider APIs can carry actions directly; needs proven attachment to the existing local agent session and ownership of connection/reconnect state.

Choose per verified provider capability rather than forcing every action through one unverified interface.
Both structures keep action state in a service/store shared by the notch and pet, with provider translation outside the views.

### Native notch and detachable pet

Use supported AppKit panel/window behavior for display geometry, focus, Spaces, fullscreen, and transparent-area hit testing.
Keep basic menu-bar controls for Quit, implemented settings, and Return Pet when available. Do not duplicate the session list there. Provide a basic Show Notch recovery action when the overlay is inaccessible.
The notch and detached pet observe the same session/presentation state; switching surfaces cannot lose or resolve an alert.
Drag-out creates the desktop presentation; overlap with the notch and the explicit return action restore the notch presentation.

Animation expresses the current evidence; it never invents lifecycle events.
Working, attention, response ready, unknown, and ended remain distinguishable.
Idle, play, sleep, and drag are presentation states, and must not override unresolved attention or imply confirmed completion.
Pause unnecessary animation while hidden or asleep and provide a Reduce Motion presentation.
Prototype alert timings and placement tolerances on the target Mac instead of copying Flux constants.

### Pet import compatibility proposal

Update 2026-11-06: the user requested the compatible custom-pet workflow, accepted local PNG animation
and sprite-sheet import, then explicitly excluded the AI workflow. Import-time conversion into the
existing runtime is selected and implemented in source; see [sheet import](pets/sprite-sheet-import.md)
and [local PNG animation](pets/local-png-animation.md). The older options below record the proposal
that led to this choice. P5/P6/P8 acceptance remains unchecked because tests/builds/native checks were
not run. No company source, scripts or artwork is reused.

Decision 0006 remains the accepted runtime format: a versioned JSON manifest and transparent PNG frame sequences.
The proposed addition is an optional importer for user-supplied seven-row PNG sheets in Flux-compatible row order:
`idle`, `play`, `sleep`, `running`, `attention`, `complete`, `drag`.
Supporting an input layout does not include distributing Flux artwork.

- **Convert during import — recommended, proposed:** validate and normalize a sheet into the existing pack format. One runtime representation is retained; conversion and resource validation add import work.
- **Add a second runtime loader:** retain a sheet and slice frames during playback. Import does less work; both validation and playback must handle two asset representations.

If conversion is approved, its checks must establish square cells from seven equal-height rows, whole-cell width,
bounded encoded and decoded sizes, bounded frame counts, alpha handling, and deterministic row lengths and timing.
Review the first-empty-cell rule against real user artwork; do not blindly inherit Flux's sampled-alpha detector.
Reject interior gaps or ambiguous layouts with a useful error. Transparent trailing cells are padding; define missing optional-row fallbacks explicitly.
Map visual `complete` to response ready, never to verified task success. Preserve source artwork and the selected pet on failed import.
Use independently created fixtures to check every row and invalid geometry; no installed Flux assets become test fixtures.

### Usage refresh and presentation

Keep usage separate from session lifecycle and show only allowance windows supplied by verified supported interfaces.
Adapt Flux's independent provider refresh, cancellation, reconnect, and retry-backoff patterns.
Prefer the full Codex bucket map, merge sparse updates or reread a full snapshot, and never flatten every account into fixed daily/weekly slots.
Keep Claude's existing status-line output intact when forwarding quota; repeated forwarding is not evidence of a new provider measurement.
Keep local receipt time, source time when supplied, reset time, and account confidence separate.
Do not add transcript fallbacks, private endpoints, token-based allowance estimates, or agent turns for quota refresh.

## Decisions

- [0012: Support terminal-independent operation](../decisions/0012-support-terminal-independent-operation.md) — accepted. Replaces Otty as a release prerequisite while retaining its adapter checks.
- **Earlier open question: should the pet support standalone use, and how should it be packaged?** Replaced on 2026-10-30 by accepted [decision 0013](../decisions/0013-separate-standalone-pet-scope.md).
- **Show provider-specific 5-hour and weekly limits in the notch, 2026-10-29.** The user requested limits for the agents being used and chose Claude Code and Codex for the first version. Other agents are deferred. This brings usage alongside the notch instead of waiting for the pet; accepted provider sources in decision 0007 remain unchanged.
- **Use the notch as the session interface, 2026-10-29.** The user explicitly chose session access in the notch and rejected a menu-bar session list as unnecessary. This replaces the earlier duplicate-session presentation recommendation. Keep basic app controls in the menu bar. Prioritize the notch plan next; removal of existing menu session rows and notch implementation require a concrete task-list review. Preserve existing event handling and partial verification evidence.
- [0001: Use SwiftUI and AppKit](../decisions/0001-use-swiftui-and-appkit.md) — accepted.
- [0002: Use MVVM with services and shared stores](../decisions/0002-use-mvvm-with-services.md) — accepted.
- [0003: Store local state without a database](../decisions/0003-store-state-without-a-database.md) — accepted.
- [0004: Receive events through agent hooks](../decisions/0004-receive-agent-hook-events.md) — accepted.
- [0005: Deliver events through a Unix socket](../decisions/0005-use-a-local-unix-socket.md) — accepted.
- [0006: Import asset-only pet packs](../decisions/0006-import-asset-only-pet-packs.md) — accepted.
- [0007: Read usage through supported interfaces](../decisions/0007-read-supported-usage-data.md) — accepted.
- [0008: Use conservative event ordering](../decisions/0008-define-event-ordering.md) — accepted.
- [0009: Defer remaining Codex interactive checks](../decisions/0009-defer-remaining-codex-interactive-checks.md) — accepted.
- [0010: Include local approvals and replies](../decisions/0010-add-local-agent-actions.md) — accepted scope; action-channel structure and provider support remain to be verified.
- **Retain SwiftUI/AppKit after considering Electron/React.** The user accepted the native recommendation on 2026-10-28 for this macOS companion; decision 0001 remains in force. Flux's implementation progress is not evidence of measured runtime superiority.
- **Open: normalize compatible sprite sheets at import or add a second runtime loader?** Import conversion is recommended to retain decision 0006's runtime format. Resolve in P5 before implementing P6; the options and consequences are above.
- **Open: which supported response channel can target each existing local agent session?** Compare a dedicated interactive hook path with an app-owned provider control channel in A1–A2; do not alter the version-1 observer protocol to assume the answer.
- **Use a separate ownership file for Codex hook setup.** The user accepted this option on 2026-10-28 after reviewing entry markers. Exact managed-entry records support safe removal and edit detection; markers alone lack verified compatibility and edit detection. The separate file requires recovery across configuration and ownership updates. The recovery design and implementation plan remain proposed. See the [setup contract](../contracts/codex-hook-setup.md#ownership-alternatives-requiring-a-decision).

## My calls

- Use `notch-pet` as a working name and a separate local Git repository.
- Keep project records in `docs/` because this is a single repository.
- Initial planning used `planning/initial-scope`; current implementation is on `feat/notch-companion` with a private origin. This planning update creates no branch, commit, or remote.
- Include limits after the notification and pet foundations; retain both providers in the planned first release.
- Start with one selected pet, with custom artwork supplied through imports.
- Use response ready as the default completion label.
- Treat detailed colors, animation timings, usage layout, and performance budgets as prototype decisions.
- Track no deadline or assigned owner because the user supplied neither.
- Treat the 2026-10-28 request as authorization to revise the documented plan, with revised implementation tasks presented for review.
- Keep independent acceptance groups as delivery slices inside this existing spec, honoring the user's single-spec preference rather than applying the skill's default area migration. Superseded on 2026-10-29 by decision 0011.
- Recommend sprite-sheet normalization as an optional input adapter; keep the choice open instead of replacing the accepted pet format.

## Tasks

The user approved this scope and task list on 2026-10-22.
The user approved architecture recommendations 0002–0007 and proceeding directly to the app shell on 2026-10-22.
Each task should fit one work session; split it if the investigation shows otherwise.
The user approved splitting Codex implementation from interactive Otty verification on 2026-10-23.
The user approved moving the unchecked Codex interactive task immediately before final workflow verification on 2026-10-24.
The user requested the Flux-informed planning update on 2026-10-28 and retained the native stack.
The user accepted adding local approvals and replies, with SSH/cloud support recorded as optional future work, on 2026-10-28.
The revised remaining tasks below are proposed for review; the earlier approval is not approval of every added task or open design choice.
The user activated the bounded G1/G2 goal on 2026-10-28, approving those two tasks and their parser/verification plan only; other revised tasks remain subject to review.
The user approved I1's three-file implementation plan on 2026-10-28, initially deferred testing, subsequently authorized verification, then requested skipping the remaining checks. A later renewed verification passed the isolated build and 48-test Swift suite; the user then stopped further checks and explicitly requested committing and pushing the current work. Do not run further builds, tests, or UI checks without a renewed request. I1 remains unchecked because running-menu verification is incomplete. I2 is the agreed next goal candidate after I1; its goal is prepared but inactive, and its implementation has not started. (Superseded: I2 code was written later, with verification deferred. See [integration-health](sessions/integration-health.md).) The user authorized separate task commits and pushing the current work; incomplete verification must remain documented.
Each task includes its relevant configuration, documentation, and verification. Each implementation task must be finished and verified in one session. Split it before starting if that cannot fit. The user removed the earlier three-file, three-function and five-test limits on 2026-10-31.
The user subsequently approved starting I2, deferring I1 verification, and keeping all checks paused. This authorizes the prepared I2a/I2b/I2c implementation split and separate implementation commits under the earlier per-task commit instruction. Write tests but do not run tests, builds, probes, helper injections, or UI checks. Implementation commits do not complete the unchecked verification requirements.
The user approved splitting I3 into documentation, configuration planning, and installation tasks, and starting only I3a's three-file documentation plan on 2026-10-28. The setup contract remains proposed; this approval selects neither an ownership mechanism nor an interruption-recovery algorithm. I3b/I3c implementation, runtime verification, commits, and pushes are not authorized by this documentation approval. The recorded I2 goal remains incomplete; no new goal is active in this chat.
Completed tasks and their evidence remain intact. Historical task numbers in the coverage record refer to the pre-2026-10-28 list.
New tasks use stable IDs, so later refinements do not renumber that evidence.
The 2026-10-30 documentation request adds P0 and N7–N8 for planning. Their implementation still requires a concrete approved task list.

### Completed foundation

Completed historical tasks 1, 4, 5, 6, and 8 moved to [observation-bridge](sessions/observation-bridge.md#tasks), with their checked states unchanged.
The shared architecture task remains below. The usage investigation and session-store tasks moved on 2026-10-30.

- [x] Settle proposed architecture records using the compatibility findings and user review.

The completed usage-source investigation moved to [codex-allowance](usage/codex-allowance.md#tasks).
The completed session-store task moved to [session-state](sessions/session-state.md#tasks). Both keep their checked states.

### G: Finish bridge verification

Completed G1 and G2 moved to [observation-bridge](sessions/observation-bridge.md#tasks).
Their full [verification record](sessions/observation-bridge.md#g1g2-verification-2026-10-28) is preserved there and below.


### I: See sessions and manage agent setup

Start after G1–G2. Establish a visible integration before building the notch and pet.

I1 moved to [session-island](notch/session-island.md#tasks). I2a–I2c moved to [integration-health](sessions/integration-health.md#tasks). Their checkbox states are unchanged.

- [x] I3a: Document the proposed Codex hook ownership and reversible installation contract, retaining open design choices; review fictional install/reinstall/user-edit/malformed-input cases and verify documentation.
- [ ] I3b: Settle Codex hook ownership and interruption recovery, then add a pure configuration planner with idempotent app-owned entries, version/shape gates, preservation checks, and at most five isolated tests; review its implementation plan before coding.
- [ ] I3c: Add the bounded Codex hook installer using the accepted planner and recovery design, guarded file updates, helper and supported-version checks, and preserved hook trust review; review and split the file-operation checks as needed before implementation.
- [ ] I4: Add reversible Claude lifecycle hook setup that preserves unrelated hooks and leaves the existing status line intact.
- [ ] I5: Remove only app-owned setup entries, preserving subsequent user edits and leaving conflicting or malformed configuration untouched with a useful error.
- [ ] I6: Expose setup, check, and removal actions with actionable health messages; verify both agents reach the visible notch in disposable Otty sessions and cleanup restores isolated configuration.

### N: Reach the correct session from the notch

Build N3–N5 next using the implemented receiver/store; hook installation is not a prerequisite for fictional-event UI checks. Add N1–N2 navigation afterward. Full remaining Codex interactive acceptance stays in R6–R7 under decision 0009.
N1–N2 and N6 retain their original Otty-specific wording as adapter acceptance, not a universal monitoring prerequisite.
Plan N7 before implementing navigation adapters. N8 verifies operation without Otty before release.

- [ ] N1: Validate Otty pane selectors against current live identity and report closed, reused, stale, and ambiguous matches without creating panes.
- [ ] N2: Connect session selection to exact-pane navigation, with an explicit activate-Otty fallback and checks that another same-folder pane is never selected.
N3–N5 moved to [session-island](notch/session-island.md#tasks), unchecked.
- [ ] N6: Verify live approval, structured-question, response-ready, and unknown presentations through the notch and correct Otty pane jumps using isolated agent sessions.
- [ ] N7: Specify terminal navigation capabilities separately from monitoring and provider actions; review exact-pane, application-only, unavailable, and missing-metadata cases before implementation. Plan any new wire metadata separately.
- [ ] N8: Verify both supported agents through the real helper, store, and visible app in at least one local terminal other than Otty, with no Otty executable or pane metadata required; check concurrent same-folder sessions and honest unavailable navigation, then record the tested matrix.

### A: Act on local requests and send replies

Use the visible session selection and verified identity from I/N. Complete this local interaction slice before release; SSH/cloud work is not a prerequisite.
The scope is accepted, while implementation tasks and the response-channel choice remain subject to review.
A7's original Otty fallback is one adapter option. Apply decision 0012's capability-based fallback to current implementation plans.
Verify A1/A8 provider channels independently of navigation support. Do not use terminal keystrokes as an action fallback.

- [ ] A1: Verify installed Codex and Claude permission-decision, structured-answer, and follow-up submission capabilities in disposable local sessions; record supported targets, trust, cancellation, and terminal fallback behavior with sanitized evidence.
- [ ] A2: Settle provider action-channel structure and specify its contract for target identity, bounded content/waits, acknowledgement, duplicates, cancellation, and uncertain delivery while preserving the version-1 observation path.
- [ ] A3: Add a shared local-action service with capability reporting, current-target validation, duplicate prevention, and dispatch/acknowledgement states checked with concurrent same-folder sessions.
- [ ] A4: Deliver approve-once and deny decisions through each verified provider adapter, with isolated checks for exact-request targeting, expiration, cancellation, disconnect, and no implicit grants.
- [ ] A5: Deliver structured-question answers through verified adapters, preserving option identity and validating the response shape while handling replaced or cancelled questions.
- [ ] A6: Submit explicit follow-up text to the verified existing local conversation, preserving draft/target identity and preventing replay or silent creation of a replacement session.
- [ ] A7: Add capability-aware approval cards, answer controls, and a reply composer to shared notch/pet presentation, with explicit editing focus, outcome messages, and unavailable-action Otty navigation.
- [ ] A8: Verify each supported local action in the actual app, including concurrent-session targeting and failure recovery; document per-provider/version gaps and leave any missing release-required path explicitly blocked.

### P: Detach and customize the pet

Use shared presentation from N for optional agent reactions. The standalone pet uses an independent pet module under decision 0013.
P5–P6 remain the open sprite-sheet proposal.
Do not implement P6 before its format choice is accepted.
P0's scope and packaging direction is accepted. Its unchecked task remains pending final planning review.
P1 maps to future agent-reactions. Standalone work is proposed in [built-in-pet](pets/built-in-pet.md).
Terminal navigation is optional under decision 0012, including for the integrated pet.

- [ ] P0: Settle standalone pet behavior and packaging for users without coding agents; compare one app with a separate module, shared-module apps, a separate project, and a background service, then update pet dependencies and acceptance only after approval.
- [ ] P1: Render an independently supplied built-in pet from shared presentation state, including distinct unknown/ended behavior and fallbacks that preserve attention.
- [ ] P2: Add the native detached pet panel with drag-out, overlap return to the notch, and an explicit Return Pet action that preserves session selection and notices.
- [ ] P3: Specify and validate versioned manifest/frame packs with bounded image resources, safe paths, single-frame idle support, and optional-animation fallbacks.
- [ ] P4: Import validated packs into Application Support and switch selection only after successful import; invalid input must preserve the existing selected pet and assets.
- [ ] P5: Settle the proposed sprite-sheet input choice with its row, alpha, gap, timing, and resource rules; record whether conversion or a second runtime loader is accepted.
- [ ] P6: Implement the approved optional sprite-sheet importer using independently created fixtures and verify row mapping, padding, invalid geometry, and rollback. (blocked: native sprite-sheet acceptance remains deferred by the user)
- [ ] P7: Persist pet selection, size, sound preference, and screen-relative placement using the accepted preferences/file boundaries, with safe defaults for missing assets and displays.
- [ ] P8: Verify detach/return, custom artwork, unknown and attention states, invalid-import preservation, and preference restoration in the actual app with isolated assets.

### U: Show provider-reported allowance

Build alongside the notch; do not wait for the pet, action channels or hook installer. First support Claude Code and Codex. Preserve account-mode limits from the usage compatibility record.

U1, U3a, U3b1, and U3b2 moved to [codex-allowance](usage/codex-allowance.md#tasks).
U2a, U2b, U2c1, U2c2, and U2c3 moved to [claude-allowance](usage/claude-allowance.md#tasks). Their checkbox states are unchanged.

- [ ] U3c: Handle rate-limit notifications by rereading full snapshots, account changes and source failures; verify cancellation and reconnect without stale-account leakage.
- [ ] U4: Add bounded refresh, cancellation, reconnect, and retry backoff; provider failures and passed reset times must retain honest stale/unavailable status.
- [ ] U6: Verify live Claude forwarding/output preservation and Codex coexistence, reconnect, sparse updates, and account changes; document unavailable account modes without private-endpoint fallbacks.

U5 moved to [codex-allowance](usage/codex-allowance.md#tasks), unchecked. It covers both providers.
U6 stays here until `refresh-recovery` is written, because it spans three usage specs.

### R: Verify desktop behavior and the release workflow

Use the implemented surfaces and usage providers. R6–R7 retain all seven deferred Codex checks and run immediately before R8.
R8 also includes the terminal-independent acceptance in N8 and unavailable-navigation guidance.
Retain Otty evidence without presenting it as verification of other terminals.

- [ ] R1: Recover notch and pet placement after display changes and external-display removal, clamping saved positions to a connected display.
- [ ] R2: Verify and correct fullscreen/Spaces visibility and transparent-area hit testing with a menu-bar recovery route and no unsolicited focus changes.
- [ ] R3: Verify physical sleep/wake recovery preserves unknown session semantics and restores accessible window placement without reviving stale working state.
- [ ] R4: Pause unnecessary hidden/asleep animation and implement Reduce Motion and keyboard-accessible session/return controls; verify that attention remains perceivable.
- [ ] R5: Record five-minute idle and animated-pet CPU/memory profiles on the M2 Air; address measured issues without claiming an unmeasured advantage over Flux.
- [ ] R6: Verify installed Codex hook trust, default-mode structured-question dispatch, and explicit denial in isolated interactive Otty sessions.
- [ ] R7: Verify installed Codex graceful end, controlled abrupt loss, prose-question classification, and unavailable-receiver behavior in isolated interactive Otty sessions.
- [ ] R8: Verify the actual first-use install/check/alert/jump/action/reply/quit/removal workflow and update local packaging, supported versions, removal instructions, and documented limitations.

## Optional future work

These are roadmap possibilities, not first-release tasks or acceptance gates. They have no committed deadline or automatic implementation authorization.

- **SSH sessions:** optionally observe and interact with agents on remote hosts through an explicitly configured remote bridge. Plan host/session identity, encrypted forwarding, disconnect/reconnect, remote helper compatibility, and cleanup before implementation; local-only use remains complete without this feature.
- **Cloud agents:** optionally add selected provider integrations for remote task status, navigation, and supported actions/replies. Select providers and verify official APIs, existing authentication, account boundaries, and remote request semantics in a later plan; no provider is promised by this release.

Future adapters should reuse shared session/action interfaces where compatible. Their absence must not produce a setup warning or incomplete-release status for a local-only user.

## Coverage check

### Historical implementation evidence

Task numbers in this subsection refer to the original list. Task 9 is now G2; task 21 is now R6–R7.
Recorded passing checks below are historical results, not checks rerun during this planning update.

Task 1 evidence: [compatibility matrix](../notes/agent-event-compatibility.md) and
[fictional payload examples](../notes/agent-event-examples.json).
Installed-agent runtime checks used a local mock provider. Full interactive Otty verification remains part of adapter and final workflow checks.

Task 2 evidence: [usage-source compatibility](../notes/usage-source-compatibility.md).
Codex account reads returned real quota windows without agent turns.
Claude field support and account eligibility were checked; live quota forwarding remains unverified until the forwarding task.

Task 3 evidence: decisions 0002–0007 are accepted after user review on 2026-10-22.
The architecture preserves the investigations' coverage limits and distinguishes unknown account identity from confirmed account grouping.

Task 4 implementation: `Package.swift`, `Sources/NotchPet/NotchPetApp.swift`, `Resources/Info.plist`, and `scripts/run.sh`.
The build and launch succeeded. The user's screenshot confirms the menu, and the user confirmed that selecting Quit closes the app.

Task 5 evidence: [version-1 event contract](../contracts/agent-events-v1.md),
[fictional validation and state cases](../contracts/agent-events-v1-cases.json), and
[accepted ordering decision 0008](../decisions/0008-define-event-ordering.md).
`python3 scripts/check-event-contract.py` passes 68 message cases, 37 state sequences with 122 steps, and four memory-capacity checks.
The checker also verifies the document policy values and local links.
The checker remains a reference model. Task 6 supplies real transport and deadline checks.
At that checkpoint, adapters and shared-store behavior remained unimplemented.

Task 6 implementation: the shared `Sources/EventBridge/` target, `Sources/NotchPetHook/main.swift`,
app lifecycle ownership, and the bundled helper in `scripts/run.sh`.
The receiver validates one bounded envelope per connection and checks peer user IDs, endpoint ownership,
permissions, delivery age, framing, and deadlines.
The helper projects allowed fields, has one delivery attempt, and returns silently on handled failures.
It neither installs hooks nor retains messages. At that checkpoint, the app discarded validated observations.

`env DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --scratch-path /private/tmp/notch-pet-dev/build`
passes 15 tests, including all 68 existing contract message cases through the production Swift decoder.
`python3 scripts/check-event-bridge.py` passes unavailable-app, 15 fictional hook projections,
exact raw-input capacity, invalid-input, open-stdin, and busy-socket checks through actual helper processes.
`bash scripts/run.sh --build-only` builds both bundled executables with Command Line Tools.
A local smoke check also verified app startup, silent helper invocation, and owned-socket removal on Quit.
Full Xcode is needed for tests on this Mac; the selected Command Line Tools cannot import test frameworks.

The shared-store task can consume `EventBridgeServer.start(onEnvelope:)` and call `stop()` at shutdown.
The callback runs on the bridge worker and must return promptly.
`ReceivedHookEnvelope` contains `envelope`, `receiptWallMs`, and `receiptMonotonicNs`.
`HookEnvelopeV1.decode(frame:)` and `EventBridgeClient.send(_:)` are the common wire interfaces.
At that checkpoint, adapters, ordering, freshness expiry, and live session presentation remained later tasks.

Task 7 implementation: `Sources/SessionState/` contains the contract mapping, observable shared store, and bounded bridge inbox.
`NotchPetApp` owns the store and connects the bridge callback through the inbox.
The store enforces ordering, request identity, retained unconfirmed notices, terminal restrictions, freshness, and memory limits.
Snapshots keep source session identity separate from project paths and unverified pane hints.
The app invalidates observations on sleep, wake, and clock notifications.
Its expiry timer runs only while fresh observations exist.
Provider compatibility, hook setup, terminal navigation, and live session presentation remain later tasks.

`Tests/SessionStateTests/SessionStoreTests.swift` checks all 37 existing state sequences with 122 steps.
It also checks four memory limits, concurrent delivery, inbox overflow, delayed publication, byte-distinct Unicode identities,
clock changes, recovery with unseen turns, and a real bridge callback reaching the store.
The Python reference model still permits recovery with a previously conflicting turn ID.
The production store follows the accepted contract's stricter unseen-turn rule, covered by a separate Swift regression.
The reference-model correction is a proposed follow-up, outside this implementation task.

`env DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --scratch-path /private/tmp/notch-pet-dev/build`
passes 31 tests across three suites, including 16 shared-store tests.
The contract checker, helper process checks, and development app bundle build also pass.
An earlier full run exposed a timing assumption in the existing `invalidFramesNeverReachCallback` test.
Its maximum-size valid frame and final extra byte require separate writes on this Mac.
A temporary diagnostic confirmed acceptance when that extra byte arrives after the receiver checks buffered bytes.
This matches the contract's buffered-extra-byte rule.
The final full run passed. The bridge and existing test remain unchanged, with the diagnostic removed.
Physical sleep/wake and live provider behavior remain later verification work.

Task 8 implementation: `Sources/EventBridge/CodexEventAdapter.swift` owns Codex raw payload projection.
`HookEnvelopeV1.project` routes Codex input through the adapter while retaining common parser bounds and helper deadlines.
The adapter accepts only the seven investigated version-1 hook shapes and preserves supplied source identities.
It does not copy conversation content, read transcripts, infer missing identities, or install hooks.
`SessionObservationV1`, `SessionEventInbox`, and `SessionStore` retain shared meanings, ordering, and freshness rules.
At that checkpoint, the existing Claude projection remained in place for its separate adapter task.

`Tests/EventBridgeTests/CodexEventAdapterTests.swift` checks all seven fictional Codex examples,
ten unsupported hook names, metadata and content omission, missing identities, input bounds, and parser deadlines.
`Tests/SessionStateTests/SessionStoreTests.swift` checks projected Codex session meanings and uncorrelated requests.
Its real socket check now projects through `CodexEventAdapter` before delivery to the inbox and store.
At that checkpoint, the full Swift suite passed 41 tests across four suites, including eight adapter tests and 18 store tests.
The app bundle build, helper process checks, and contract checker also passed at that checkpoint.
These checks establish implementation behavior with fictional inputs.
Task 21 must verify installed Codex in interactive Otty sessions using isolated configuration.
The planning version check found `0.164.0`; the earlier controlled runtime evidence covers `0.163.0`.

Task 9 implementation, 2026-10-24: `Sources/EventBridge/ClaudeEventAdapter.swift` owns Claude raw payload projection.
`HookEnvelopeV1.project` routes Claude input through this adapter with the existing parser bounds and helper deadline.
The adapter accepts the seven investigated hook shapes and maps `prompt_id` to the common `turn_id`.
Missing source identities remain missing. The shared store still owns question classification, ordering, and freshness.
The adapter omits conversation content and does not install hooks or read transcripts.

`Tests/EventBridgeTests/ClaudeEventAdapterTests.swift` checks all eight fictional Claude examples,
ten unsupported hook names, field omission, missing identities, invalid input, byte bounds, and parser deadlines.
The shared-store tests now cover both providers' approval, structured-question, resolution, response-ready,
end, and uncorrelated-request behavior. Real socket checks deliver both providers through the inbox to the store.
The full Swift suite passed 48 tests across five suites. Both the app and helper built with Command Line Tools and Xcode.
The contract checker passed its existing cases. No live Claude or Otty verification was performed this session.

At the 2026-10-24 checkpoint, the task remained unchecked because `python3 scripts/check-event-bridge.py` failed its existing 262144-byte raw-input boundary check.
All 15 fictional payloads passed through the actual helper before that failure, including eight Claude examples.
The check failed twice with the Command Line Tools build and once with the Xcode build.
A temporary diagnostic measured about 3 ms to read that input and about 315 ms total after projection with Command Line Tools.
The existing parser consumed the 250 ms helper budget before delivery. This diagnostic did not measure the Xcode parser separately.
The process check also timed out launching the Xcode helper during a separate comparison attempt.
No parser or deadline change was made. The later invalid-input, open-stdin, and busy-socket process assertions were not reached.
The user-invoked next-task workflow requires stopping after the same failure three times.
See the [implementation findings](../notes/agent-event-compatibility.md#claude-adapter-implementation-2026-10-24).

Task 21 partial evidence, 2026-10-23 (originally task 9): Codex `0.164.0` ran interactively in two isolated Otty panes with a loopback mock provider.
Actual helper events reached the production bridge, inbox, and store through a temporary receiver.
Observed paths include text turns, command approval and cancellation, an accepted marker write, structured-question selection,
concurrent same-folder sessions, freshness expiry, and an unsupported `Interrupt` event.
Interruption left an unresolved approval notice and prevented later same-session activity from restoring known state.
This follows the accepted contract and remains a documented usability limit.
The user questioned further probing, so cleanup restored configuration and closed only disposable panes.
The task remains unchecked because controlled trust, default-mode question dispatch, explicit denial,
graceful end, controlled abrupt loss, prose questions, and interactive unavailable-receiver checks remain incomplete.
See the [partial interactive findings](../notes/agent-event-compatibility.md#partial-interactive-codex-verification-2026-10-23).
The user approved deferring these remaining checks to task 21 on 2026-10-24, under decision 0009.
Deferral does not complete the task or remove any acceptance requirement.

### G1/G2 verification, 2026-10-28

The user activated the [bounded bridge-verification goal](../goals/finish-bridge-verification.md), approving G1/G2 only.
The historical full 250 ms timeout did not reproduce before changes with the current Xcode 6.2 and Command Line Tools 6.3.2 Swift compilers.
Both unchanged builds passed the helper process suite. This does not establish why the historical runs were slower.

A temporary Command Line Tools debug diagnostic isolated the padding scan in `StrictJSON.whitespace()`.
The original scan took roughly 75–98 ms for 262144 whitespace bytes; full maximum-size projection took about 72–77 ms.
Replacing only the per-byte array membership expression with a byte switch in a temporary copy reduced projection to about 7–15 ms.
The original loop also lacked deadline checks. A separate fictional maximum-size projection with 5 ms remaining
returned success after 94.7 ms, failing the diagnostic assertion.

`Sources/EventBridge/HookEnvelopeV1.swift` now scans the same four JSON whitespace bytes directly,
checks the existing deadline every 1024 bytes of padding, and checks it again before returning from parsing.
Private parser calls propagate timeout errors. Public APIs, strict validation, the 262144-byte raw limit,
16384-byte frame limit, 250 ms helper deadline, silent failure behavior, and one-attempt transport remain unchanged.
No adapter, test, fixture, check script, dependency, or agent/Otty configuration changed.

The same deadline diagnostic now throws timeout at 5.1 ms. A diagnostic compiled from the corrected production sources
projects the maximum-size fictional input for each provider in 3.6–4.4 ms across three invocations per provider.
These are local parser measurements excluding process launch, not a general latency guarantee.
Temporary diagnostic sources and executables remain outside Git in `/private/tmp/notch-pet-g1-i1rtavd8/`.

Verification performed after the parser correction:

- `bash scripts/run.sh --build-only` exits 0 with both bundled executables and a valid Info.plist.
- `env DEVELOPER_DIR=/Library/Developer/CommandLineTools bash scripts/run.sh --build-only` also exits 0.
- `python3 scripts/check-event-bridge.py` exits 0 with `Bridge process checks passed` for freshly built helpers from both toolchains.
  All 15 fictional projections, exact raw-input capacity, invalid-input rejection, unavailable-app, open-stdin, and busy-socket assertions pass.
  Recorded helper process ranges are 5–397 ms for Xcode and 7–493 ms for Command Line Tools, including launch.
  These process ranges are separate from the unchanged internal deadline.
- `env DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --scratch-path /private/tmp/notch-pet-dev/build`
  exits 0: 48 tests in five suites, zero failures, including both adapters and actual socket-to-store delivery.
- `python3 scripts/check-event-contract.py` exits 0: document policy/links, 68 message cases,
  37 state sequences with 122 steps, and four memory-capacity boundaries.
- `git diff --check` exits 0 with no output.

G1 and G2 are complete on this implementation evidence. Live Claude/Otty verification remains later release work;
the seven deferred Codex checks remain R6/R7 under decision 0009. The previously documented reference-model discrepancy
and socket-test timing assumption remain separate proposed follow-ups. No later task or action-channel choice is approved by this goal.

### I1 implementation awaiting verification, 2026-10-28

`Sources/NotchPet/NotchPetApp.swift` now reads the existing observable `SessionStore` in `CompanionMenu`
and renders each snapshot through `SessionMenuEntry(snapshot:)` in the existing native menu.
Entries include agent, project, source session identity, and the shared-store status.
Each submenu exposes the full project path and session identity, the recorded state-refresh time when available,
plain-language unknown reasons, and unresolved requests marked according to `isConfirmed`.
Same-folder sessions remain separate through `SessionKey`; response stops use the label "Response ready".
The empty state says "No sessions observed yet" without claiming configuration or connection failure.

Runtime behavior remained unverified at the initial checkpoint. The existing 48-test Swift suite had passed before this source change;
that baseline result did not verify I1. After the user first authorized verification,
`bash scripts/run.sh --build-only` failed because the default scratch directory contained Swift 6.3.2 modules
that the selected Swift 6.2 compiler could not import. No source change was needed for that cache mismatch.
The isolated build command
`env TMPDIR=/private/tmp/notch-pet-i1-20261028 DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer bash scripts/run.sh --build-only`
completed with exit 0, both executables, and a valid Info.plist before the pending build could be stopped.
Its artifacts are outside the repository in `/private/tmp/notch-pet-i1-20261028/notch-pet-dev/`.

The accessibility probe
`osascript -e 'tell application "System Events" to tell process "NotchPet" to get {name, count of menu bars}'`
was denied with `osascript is not allowed assistive access. (-25211)`.
No changed-source Swift test run, fictional helper injection, or visible-menu inspection was completed at that initial checkpoint.
The user then requested skipping checks. The task checkbox remained open.

The user subsequently authorized resuming I1 verification and committing it when verified. The same isolated build command above
completed with exit 0 and a valid Info.plist. The changed-source check
`env DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --scratch-path /private/tmp/notch-pet-i1-20261028/notch-pet-dev/build`
completed with exit 0: 48 tests in five suites, zero failures. Both commands required running outside the filesystem sandbox;
the initial sandboxed build could not write the compiler module cache (`Operation not permitted`). No source correction was needed.

The same accessibility probe now returned `NotchPet, 2`. Inspection of the already-running older app showed
the previous "Agent connections are not set up." placeholder, not I1's rebuilt session menu.
A temporary harness was prepared at `/private/tmp/notch-pet-i1-verify/verify_menu.py` to restart the rebuilt app and check fictional
observations through its bundled helper. Its execution was interrupted; no completed helper-to-visible-menu evidence was obtained.
The user then instructed "don't run the tests now", "just commit", and "and push". Further checks are paused;
the explicit commit/push instruction permits saving the implementation and records without claiming I1 is verified.
I1 remains unchecked, and I2's prepared goal remains inactive behind its I1 verification gate.

When the user authorizes verification, use the existing build and Swift commands in **Verify**, then launch
with `bash scripts/run.sh` and exercise fictional observations through the bundled helper.
Check both providers, concurrent same-folder sessions, idle/working/question/approval/response-ready/ended labels,
unknown state with retained unconfirmed notices, the recorded evidence time, and empty state after restart.
Include long project paths and source session identities in the native-menu inspection.
Keep temporary fixtures and any captures outside the repository. I6 retains installed-agent/Otty acceptance.

### I1 verification resumed by combined goal, 2026-10-28

The user activated `docs/goals/codex-setup.md`, authorizing the combined task list and its checks.
I3's separate design approval gate remains. No commit, push, or production configuration update is authorized.

`env TMPDIR=/private/tmp/notch-pet-codex-setup DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer bash scripts/run.sh --build-only`
exited 0 with app/helper executables and a valid Info.plist after creating the temporary root and allowing compiler-cache access.
The same environment with `bash scripts/run.sh` exited 0 and launched the rebuilt app.
A read-only process check confirmed PID 56750 running the executable from that exact app bundle.

`env DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --scratch-path /private/tmp/notch-pet-codex-setup/notch-pet-dev/build`
initially exited 1: 59 tests, with two issues in the provider cases of
`IntegrationHealthProbeTests.diagnosticsDiscardUnrelatedFictionalValues` at line 206.
The probe returned `timedOut` instead of expected `invalidOutput`.
The unchanged command with `--filter diagnosticsDiscardUnrelatedFictionalValues` then exited 0
with one parameterized test passing for both agents. The unchanged full suite then exited 0:
59 tests across seven suites, zero failures. No source or tests changed; the initial timeout's cause is not established.
These executions do not complete I2's separate app-wiring acceptance.

Computer Use could not obtain the app UI: bundle-ID and exact-bundle-path connections each returned
`Computer Use server error -10005: timeoutReached`; display-name connection returned `Invalid app: Notch Pet`.
The earlier temporary verification harness no longer exists. No fictional observations were injected,
and none of I1's ten visible-menu cases has fresh evidence. I1 remains unchecked.
The [I3 design review](../contracts/codex-hook-setup.md#i3-design-review-for-the-activated-goal)
records proposed schema, recovery states, concurrency limitation, interfaces and required size review.
These proposals are not implementation approval.

### Guided I1 evidence, 2026-10-29

The user resumed the goal. Computer Use still timed out, but user-supplied screenshots verified
actual bundled-helper-to-menu delivery. The running rebuilt bundle was confirmed as PID 15730.
The temporary sender `/private/tmp/notch-pet-codex-setup/verify-menu-events.py` sent three basic
and three request observations; each invocation exited 0 silently. Visible delivery is established
by the screenshots, not those exit codes.

Verified: initial empty menu; Codex observed idle and Claude working; distinct sessions in the
same shared-project folder; Codex approval and Claude question labels; Codex submenu agent,
session, full project path, approval status, refresh timestamp, Bash request and i1-approval tool ID.
Screenshots supplied in this conversation end in 7668801, 7714634, 7780684 and 7831284.
Captures and sender remain outside the repository.

Response-ready, ended, unknown with retained unconfirmed notice, long identity/path handling,
and empty state after restart remain unverified. I1 stays unchecked. The user questioned the
manual screenshot burden; no further screenshots are requested. I3 design approval remains pending.

### I2 implementation with verification deferred, 2026-10-28

The user explicitly selected starting I2 with I1 verification deferred and all checks paused. The earlier I1 entry gate
in the prepared goal is superseded by that instruction. I2 is split into I2a/I2b/I2c without removing its original
version/configuration, helper, receiver, delivery, and inactivity requirements. Separate implementation commits are authorized;
they are not evidence of passing checks, and all three task checkboxes remain open until their verification is resumed and passes.

I2a adds `Sources/SessionState/IntegrationHealth.swift` with independent typed evidence and snapshots.
`IntegrationHealth.evaluate(_:)` classifies recorded version compatibility without combining configuration, helper,
receiver or delivery observations into a connected/disconnected flag. Recorded compatibility retains the existing
per-version/event limitations; unfamiliar versions stay unverified. Hook counts do not establish app ownership or trust.
App-owned receiver and receipt values can be replaced in a value snapshot without rereading configuration or consulting sessions.

Five model tests were written in `Tests/SessionStateTests/IntegrationHealthTests.swift` before the model implementation.
They cover evidence independence, no receipt without false disconnection, retained receipt after session expiry/store replacement,
and no promotion of version support by configuration or delivery. No failing baseline, Swift test, build, provider/configuration probe,
helper injection or UI check was run for I2. This source is not yet compiler- or runtime-verified.

I2b adds `IntegrationHealthProbe.inspect(agent:executableURL:configurationURL:helperURL:)` in the same service file.
Version execution runs off the main actor with a two-second process deadline and 65536-byte combined-output cap;
only the expected version shape is retained. Launch time and OS scheduling are not a hard wall-clock guarantee.
The probe kills only its own process on timeout/overflow and does not wait indefinitely on exit or inherited pipe writers.
Hook JSON reads require a regular non-symlink file, are capped at 262144 bytes including growth during the read,
and inspect only hook structure/counts. Other fields, command contents and decoder errors are not exposed as diagnostics.
Unsupported handler shapes are reported explicitly. Helper availability checks metadata and executability without invoking it.
The five additional probe tests use disposable fake executables/configuration outside the repository; they have not run.
No installed CLI, user configuration, helper or receiver was probed during this implementation.

I2c adds the app-owned observable `IntegrationHealthController` in `NotchPetApp.swift` and supplies it through the
existing menu's environment for later I6 controls. The bridge's actual start success, categorized failure, and stop
update receiver evidence. Validated inbox observations update per-agent receipt times before the session clock cutoff;
delivery is not inferred from current sessions and does not expire when session state becomes unknown or ended.
Publication is batched, and asynchronous probe results replace only version/configuration/helper fields so they cannot
overwrite receiver or delivery evidence received while awaiting the probe. Duplicate per-agent refreshes are coalesced.

`refresh(agent:)` is an explicit action boundary, not a startup/background probe. It resolves only bounded absolute PATH
entries and the supported agent configuration-directory variables, locates the bundled helper, and delegates I/O to the
background probe service. No Check UI is introduced before I6, and no refresh was called during this task.
The ten new tests, app build, receiver wiring and all I2 behavior remain unverified. All I2 checkboxes remain open.

### I3a documentation, 2026-10-28

The user approved the three-file documentation plan and the I3a/I3b/I3c split.
The [Codex setup proposal](../contracts/codex-hook-setup.md) records required preservation,
version/helper gates, separate planning/application boundaries, unchanged observer behavior,
normal trust review, idempotency, and the ownership guarantees needed by I5 removal.
Its fictional review cases cover first installation, repetition, Otty/unrelated hooks, user edits,
malformed input, interrupted updates, and absent trust/delivery evidence. They were reviewed as
documentation requirements, not executed as configuration or runtime tests.

An inline local-document check using Python's standard library exited 0: all relative Markdown
links and heading anchors in the three changed files resolve, the ten previously completed tasks
are preserved, and I1/I2a/I2b/I2c remain unchecked. `git diff --check` exited 0.
I3a is complete as documentation only; the contract remains proposed. Ownership representation,
interruption recovery, external-writer guarantees, and exact timeout/enablement details require
review before the corresponding I3b/I3c implementation. No new goal, production code, agent
configuration access, runtime check, commit, push, or pull request was performed in this task.

### Revised acceptance coverage

- Native launch and bounded delivery: [observation-bridge](sessions/observation-bridge.md), plus final release verification in R8.
- Both agents, concurrent sessions, questions, honest completion and uncertainty: I1, N4–N6, P1, R3, R6–R8.
- Reversible setup, trustworthy health messages, and correct-pane navigation: I2–I6, N1–N2, R8.
- Terminal-independent monitoring and optional navigation capabilities: N7–N8, A1/A8, R8. Otty-specific checks remain I6, N1–N2, N6, and R6–R7.
- Notch geometry, focus, click-through behavior, and recovery access: N3, R1–R4.
- Local approvals, structured answers, follow-up replies, capability boundaries, and action delivery failures: A1–A8, R8.
- Pet detach/return, validated imports, preference restoration, and animation fallbacks: P1–P4, P7–P8, R1–R4.
- Standalone pet scope and packaging remain proposed: P0 must resolve them before changing P1–P8 dependencies or acceptance.
- Optional compatible sprite-sheet input, if accepted: P5–P6, P8.
- Provider windows, account confidence, freshness, reset times, and refresh failures: U1–U6.
- Physical desktop recovery, Reduce Motion, accessibility, and measured resource use: R1–R5.
- Final first-use and installed-agent acceptance: I6 and N6 provide early real-app checks; R6–R8 complete release verification.

The existing reference-model and socket-test corrections remain separate proposed follow-ups in STATUS.md.
This plan does not silently approve those changes or modify the version-1 contract.

## Verify

- Seam: actual bundled helper to app receiver, shared store, and visible notch/pet without required terminal metadata; navigation and provider actions are verified separately against their exact targets.
- Build: `bash scripts/run.sh --build-only`.
- Swift checks: `env DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --scratch-path /private/tmp/notch-pet-dev/build`.
- Helper process checks: `python3 scripts/check-event-bridge.py`, with the app stopped; keep launch time separate from the helper's internal deadline.
- Contract reference checks: `python3 scripts/check-event-contract.py`; retain the documented unseen-turn model discrepancy until its separate correction is approved.
- Real app: `bash scripts/run.sh`, using disposable local agent sessions and isolated configuration. Include N8 without Otty and retain Otty adapter/deferred checks separately. Keep independently supplied pet assets outside the repository.
- Real provider allowance checks: U6, restricted to verified supported interfaces, with no credentials or captured session content in records.
- Real local actions: A1/A8 use disposable sessions and harmless requests; verify approve-once/deny, structured answers, explicit follow-up text, acknowledgement, duplicate clicks, stale targets, cancellation, and unavailable receivers. Record capability limits without capturing real prompts or credentials.
- Physical desktop and resource checks: R1–R5; injected clock checks alone do not establish those behaviors.
- Final interactive Codex checks: R6–R7 immediately before R8, preserving all requirements of decision 0009.
- Documentation checks: local links resolve, completed checkboxes are preserved, and `git diff --check` is clean.


### N3 placement foundation, 2026-10-29

NotchPlacement.frame(screen:safeTop:notchWidth:expanded:) now computes compact/expanded panel
frames without AppKit. Five frozen NotchPresentationTests cover physical cutout room, negative
screen origins, narrow/short screens, displays without a cutout and invalid dimensions.
The initial test baseline failed because the type was missing. The first implementation needed
an explicit CoreGraphics import; assertions were unchanged. The isolated Swift command with
`--filter NotchPresentationTests` exited 0: five tests, zero failures.
This is N3's placement foundation only; no panel is rendered yet, and N3 remains unchecked.

### U2a quota parser verification, 2026-10-29

ClaudeUsageProvider.parse(_:sourceID:receivedAtMs:) extracts five_hour/seven_day only, converting
Unix seconds to milliseconds and preserving independently missing windows/reset times. Account
and provider measurement identity remain absent. No raw status-line content is retained.
Five ClaudeUsageProviderTests first failed the missing-type baseline, then passed with the
implementation using the isolated Swift test command and --filter ClaudeUsageProviderTests.
This verifies parsing only, not forwarding, terminal output preservation or live quota.

### U3a quota parser verification, 2026-10-29

CodexUsageProvider.parse(_:sourceID:receivedAtMs:) accepts a full account/rateLimits/read result.
Five frozen tests first failed the missing-type baseline, then passed. Full bucket maps take
precedence over the compatibility view, identities remain separate, and missing/nonstandard
window durations remain unchanged. Reset seconds convert safely to milliseconds.
This is parsing evidence only. No App Server process was launched and no live quota was read.

### U3b next-task interface sketch

Proposed implementation detail within accepted read-only quota scope:
`CodexUsageConnection.read(executableURL:sourceID:) async -> UsageObservation`.
The connection launches only the explicit Codex executable, initializes App Server over stdio,
then issues account/rateLimits/read with reset-credit details excluded. It must wait for the
initialization response before quota requests and match response IDs rather than the next line.
Ignore unrelated notifications. Never issue thread/turn, login/logout, credit-consumption or email requests.
Bound process lifetime, stdout bytes and each frame; stderr is not a user diagnostic.
Stop the owned process on cancellation/timeout and return a bounded failure category.
Verify five isolated process cases: valid handshake/quota; interleaved notifications and wrong IDs;
server error/malformed frame; timeout/cancellation; oversized output. Fake servers must assert
that no thread or turn methods were sent. Actual managed-provider reads follow only after those checks.

### U3b1 protocol verification, 2026-10-29

CodexUsageProtocol has three methods (init/start/receive). Five frozen tests first failed the
missing-type baseline then passed: initialization ordering, quota-only outbound methods, unrelated
notifications/wrong IDs, bounded server errors, malformed/oversized input and terminal completion.
Frames are bounded to 256 KiB and cumulative received bytes to 1 MiB per one-shot connection.
No process or real provider was contacted. U3b2 owns deadlines, OS cancellation and cleanup.

U3b2 process plan: expose `CodexUsageConnection.read(executableURL:sourceID:) async -> UsageObservation`.
Run the explicit executable on a cancellable worker. Maintain a small nonblocking stdin request
queue and newline-framed stdout buffer. Enforce the protocol frame/total-byte limits and a shared
post-launch deadline; process-launch time must be reported separately if the OS launch cannot be
interrupted. Polling must recheck cancellation frequently and never block on a full input pipe.
Suppress SIGPIPE on the pipe descriptor without changing the host process's global signal policy.
On completion/error/cancellation, close owned pipe ends and terminate only the owned process.
Do not print raw stdout/stderr or retain unrelated notification content. Five isolated process
tests must prove real handshake order, wrong-ID interleaving, error/EOF, timeout/cancellation and
output bounds, including child cleanup. No live read precedes these checks.

### U2c1 quota sender verification, 2026-10-29

UsageDelivery.send(_:endpointURL:) uses a separate Unix datagram endpoint at
/private/tmp/notch-pet-<uid>/usage-v1.sock. Each JSON observation is at most 8192 bytes.
The owned parent must be a real 0700 directory and endpoint an owned 0600 socket; symlinks
and regular files are rejected. Sending is nonblocking, with no spool, output or acknowledgement.
Five tests first failed the missing-type baseline then passed against real disposable sockets.
Datagrams keep each small quota message atomic without reusing lifecycle framing. The same-user
filesystem boundary is retained; receipt does not authenticate a provider or establish measurement freshness.
The app receiver and terminal wrapper remain unfinished. No installed configuration changed.

### U2c2 receiver verification, 2026-10-29

UsageReceiver has init/start/stop methods. Five tests first failed the missing-type baseline,
then passed against isolated Unix sockets: valid typed receipt, rejected malformed/invalid input,
private directory and existing-path preservation, second-receiver rejection/restart, and replacement
file preservation at stop. Each datagram is limited to 8192 bytes and a callback drain to 32 messages.
The receiver stamps local receipt time and never adopts an existing endpoint. Callers must stop
it at shutdown; app lifecycle integration and live Claude receipt remain U2c3 work.
