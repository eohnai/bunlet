# Architecture

## Accepted structure

Stores own shared state. Read-only SwiftUI views observe those stores and render their snapshots.
Pure presentation functions derive labels, ordering, selection and geometry without starting services or changing session meaning.
AppKit controllers own windows. Services own event delivery, provider I/O and their task lifetimes.

[D3](DECISIONS.md#d3-add-view-models-only-where-a-view-owns-state) refines decision 0002: add a view model only for state the store does not own.
Examples include drafts, validation, pending actions and async results. A view model for every view would add unnecessary forwarding and duplicated state.
`FeatureSettingsModel` owns feature actions and recovery state. Existing controller names remain where they describe the current owner.
[D4](DECISIONS.md#d4-target-macos-14-so-stores-and-controllers-can-use-observable) sets macOS 14 and `@Observable` for stores and observable controllers.
[D5](DECISIONS.md#d5-observe-stores-from-controllers-with-withobservationtracking) uses `ObservationLoop` for controller observation outside SwiftUI.
The loop re-arms observation on the main actor and suppresses unchanged values. Cancellation prevents queued callbacks from re-arming it.

Models describe sessions, alerts, usage limits and pets. Integration services do not belong to a view's lifetime.
The planned local-action service also returns explicit user decisions and replies through verified agent-specific channels.

The user accepted decisions 0002–0007 on 2026-10-22 after reviewing the compatibility findings.
SwiftUI and AppKit were already accepted in decision 0001.
Acceptance chooses the design; the compatibility records still define what has and has not been verified.

On 2026-10-28 the user retained SwiftUI/AppKit after considering Electron/React and requested a Flux-informed plan update.
The [reference findings](notes/flux-island-adoption.md) support the planned behavior below.
The [specification](specs/notch-companion.md) owns acceptance checks and proposed tasks; the native stack and decisions 0001–0009 remain in force for their existing responsibilities.
[Decision 0010](decisions/0010-add-local-agent-actions.md) adds accepted local-interaction scope without changing the existing observation protocol.
[Decision 0012](decisions/0012-support-terminal-independent-operation.md) removes Otty as a product prerequisite.
Agent monitoring and pet reactions use agent identity independently of optional terminal navigation.

## Boundaries

| Part | Responsibility | Does not own |
|---|---|---|
| SwiftUI views | Notch content, pet, settings, usage display | Hook parsing and account access |
| Pure presentation functions | Derived ordering, selection, labels, timers and geometry | I/O, service lifetime or session transitions |
| View models and action controllers | View-owned actions, drafts, validation and recovery state | Independent copies of session truth |
| Session store | Authoritative session state, freshness and pending requests | Window placement or presentation selection |
| Usage store | Provider/account observations and freshness | Session lifecycle events |
| App composition | Shared stores, feature availability and deferred runtime factories | Provider configuration ownership |
| Agent adapters | Translate Codex and Claude Code events | Terminal navigation |
| Local-action service and provider adapters | Verified capabilities, explicit user decisions/replies, request targeting, acknowledgements and cancellation | Inferring lifecycle progress or quota refresh |
| Terminal adapters | Report verified exact-pane, application-only, or unavailable navigation | Agent lifecycle detection and provider action availability |
| Usage providers | Read supported quota sources and report freshness | Estimating limits from token counts |
| AppKit controllers | Window creation, placement, focus and native window behavior | Agent business rules |
| Preferences and pet services | Save preferences and validate local assets | Session history queries |

`NotchSessionView` observes `SessionStore` and `UsageStore` directly. Its expansion and selected-session key are local view state.
`NotchPresentation`, `NotchAllowancePresentation`, `NotchPlacement`, `PetPresentation` and `PetPlaybackPolicy` provide reusable pure rules.
`PetView` receives pet presentation and playback inputs. It does not observe agent stores.
An eventual session-to-pet adapter must consume the same authoritative snapshots rather than create another session store.

## Current targets

`Package.swift` defines these production targets. Tests depend on the target whose contract they check.

| Target | Current responsibility | Dependencies |
|---|---|---|
| `EventBridge` | Shared agent/hook identities, bounded envelopes, adapters, lossless JSON scanning and Unix-socket delivery | None |
| `Integration` | Health/probes, path lookup, provider policies/planners, owned transactions and recovery | `EventBridge` |
| `Usage` | Usage store, providers, connection, sender/receiver and allowance presentation | `EventBridge` |
| `SessionState` | Session store/inbox, observation mapping and session presentation rules | `EventBridge` |
| `AgentActions` | Typed transient action state, Claude hook bindings and bounded interactive transport | `EventBridge`, `SessionState` |
| `Pet` | Artwork, preferences, rendering and playback rules | None |
| `NotchPet` | App composition, feature management, Settings, windows and optional services | `Pet`, `EventBridge`, `SessionState`, `Usage`, `Integration` |
| `NotchPetHook` | Silent one-way observation helper | `EventBridge` |
| `NotchPetStatusLine` | Bounded Claude status-line input forwarding and original-command execution | `Usage` |
| `NotchPetActionHook` | Separate interactive Claude callback projection and one explicit response | `AgentActions` |

[Codex setup R2a](specs/sessions/codex-setup.md#tasks) separates `Usage` and `Integration` from `SessionState`.
R3 replaces `IntegrationAgent` directly with `EventBridge.Agent`; no compatibility alias remains.
`HookEvent` defines the seven version-1 hook names. Envelope validation converts wire strings into these enums.
Session keys retain typed agent identity, and observation mapping handles every hook explicitly.
Usage transport retains its provider string and existing validation behavior through `Agent`.
R2b adds `AgentPathLocator` with explicit health/usage policies. It preserves their existing path rules and keeps environment reads in app callers.

## Feature availability and runtime ownership

[D7](DECISIONS.md#d7-install-and-uninstall-features-from-settings) keeps one app with independently selected Pet, Notch and Agents features.
`PetAppController` creates the shared session and usage stores, `FeatureSettingsModel`, and deferred factories in `FeatureRuntimeOwner`.
Listing the catalog does not construct optional controllers. No optional feature needs another optional surface to remain installed.

`FeaturePreferences` reads versioned availability from injected `UserDefaults`. Reads do not write or start services.
Absent records produce Pet-only defaults, except explicit legacy monitoring opt-in preserves all three features.
Malformed or unsupported records require recovery and remain untouched. An empty installed set is valid.
`FeatureSettingsModel.start()` explicitly saves usable defaults or migration before applying runtime choices.
Feature availability, monitoring consent, provider setup and integration-health evidence remain separate.

`FeatureRuntimeOwner.apply(_:)` starts each active runtime once and stops removed instances in reverse catalog order.
A failed factory is reported as unavailable. The Agents feature runs only when installed and monitoring is enabled.
`AgentServices` owns the receiver/inbox, usage controller, expiry timer and lifecycle observers independently of `NotchPanelController`.
`AgentUsageController` observes active Codex sessions and owns cancellable usage reads. Hiding or removing Notch does not stop monitoring.

Stopping Agents retires its generation before stopping intake, dropping its inbox and cancelling owned work.
Queued delivery, notification and expiry callbacks check that generation before changing current state.
`SessionStore.suspendMonitoring()` retains pending requests as unconfirmed. Removal does not report approval or completion.
Reinstalling Agents preserves preferences but disables monitoring until explicitly enabled. It does not install or remove provider hooks.

Settings and Quit remain reachable with no optional features. Features remains available for installation and recovery.
`PetSettingsController` hosts the shared `AppSettingsView`; feature pages follow availability while General and Features remain present.
Pet setup and size controls reuse that window. Opening Settings does not itself start monitoring.
FM1–FM6 implementation and automated evidence are recorded in [feature management](specs/settings/feature-management.md).
FM7 remains deferred: native focus, keyboard, removal and relaunch acceptance is incomplete.

## Data flow

An agent event reaches a small local helper through a configured hook.
The helper's agent adapter projects allowlisted metadata into the shared wire envelope.
The helper sends one bounded message to the app through the Unix-domain socket.
The receiver validates the envelope. `SessionEventInbox` queues normalized observations for main-actor delivery.
The session store applies the event once and publishes updated presentation state.
The notch reflects that state through pure presentation rules. PetSessionAdapter projects snapshots into optional pet moods and deduplicated response-ready cues.
Navigation uses an app-owned TerminalNavigation capability independently of provider services.
Missing terminal identity or navigation support does not block event receipt or session presentation.

Usage providers send source snapshots to a separate usage store.
They do not create agent lifecycle events or start agent turns.
`AgentServices` independently starts/stops `UsageReceiver` and Codex refresh. A bounded UsageInbox
batches Claude-only ingress onto the main actor, guarded by the service generation. UsageStore keeps
receiver state, receipt and intake/capacity loss separate from lifecycle health. Private socket leases,
refused-endpoint recovery and enlarged socket buffers implement the [quota intake contract](contracts/usage-intake.md).
`NotchPetStatusLine` retains bounded parse input while streaming original stdin to the original shell
command with inherited output/cwd/environment. Cancellation targets its process group; quota forwarding
is nonblocking and has no terminal output. Owned wrapper setup/restoration is implemented by the separate Claude quota scope. No new
source behavior is compiler- or runtime-verified.

The receiver, adapters, inbox, stores and visible session/allowance surfaces are implemented.
Both providers expose explicit Check/setup/repair/removal and independent monitoring controls.
Documented release bindings allow explicitly unverified installation; no release is runtime-qualified.
The Agents page reads snapshots without starting probes. Check explicitly calls the bounded service and updates
only version/configuration/helper fields, preserving live receiver/delivery evidence.
Remaining acceptance stays open in the [Sessions area](specs/sessions/area.md).
Health observations do not start sessions, grant hook trust, or make a successful socket write proof of receipt.

## Local-action flow: documented source implementation

The user accepted local approvals, structured answers and explicit follow-ups, then requested source
implementation with runtime qualification unrun. Documented Claude callback adapters, native controls,
transient ActionStore, bounded stream transport/inbox and app-owned LocalActionController now exist.
A separate Claude actions scope owns guarded interactive-hook setup/check/removal and cross-scope
recovery under the shared writer lock. Explicit response consent, Claude monitoring and the Agents
master switch gate intake. Settings exposes the same composers without requiring Notch. Disconnect
disables responses before removing actions, quota and lifecycle scopes, reporting partial removal.
[Local actions v1](contracts/local-actions-v1.md) defines the implemented identity, output and failure contract.
The action helper is separately packaged; the observer helper keeps its one-way deadline/allowlist.
A1 first verifies each installed agent/version's supported response mechanisms and ability to target an existing local agent session.
A2 chooses a dedicated interactive helper/endpoint or a provider control channel for each supported capability and records its contract.
The one-way version-1 observation helper keeps its existing 250 ms internal deadline and does not become a long-wait approval process.

Views submit explicit user actions to a shared local-action service rather than writing to hooks or terminals directly.
The service checks current session/request identity, action capability, expiry/cancellation, and duplicate action identity before dispatch.
Provider adapters encode decisions, structured answers, or follow-up text and report supported acknowledgements.
Submission, provider acknowledgement, and subsequent lifecycle evidence are distinct states; a click cannot itself mark the agent working or a request resolved.
Unknown outcomes are shown without blind replay. Unconfirmed or resolved requests have disabled action controls.
Offer verified terminal navigation or explain manual return. Missing navigation alone does not disable a verified provider action channel.
Timeout, app loss, or cancellation cannot imply approval; each supported provider path needs a documented bounded fallback.

Keep only bounded request details and draft/reply content necessary for the interaction in memory, outside routine diagnostics.
Do not widen the lifecycle envelope or read transcripts to obtain action content.
Explicitly opening a composer may acquire focus; incoming alerts remain nonactivating.
Only explicit Send can submit a follow-up; usage refresh and recovery cannot initiate turns.
The concrete initial follow-up path is feedback to a waiting Claude Stop hook in the existing prompt.
It is limited to a 60-second window and suppressed for stop_hook_active; it is not arbitrary-time new-turn
submission. PermissionRequest returns allow-once/deny without rules; AskUserQuestion uses original input
plus the answer map. Runtime/provider acceptance is not implied by helper stdout acknowledgement.
Unknown/ended/paused or ambiguous requests disable dispatch; prior dispatched notices cannot authorize
another callback. Drafts are offer-owned and memory-only. The app starts/stops action intake with Agents,
independently of Notch. Only an explicit Respond click acquires native keyboard focus.

SSH/cloud adapters remain optional future work, with no first-release requirement or promised provider coverage.
Later plans must define remote identity, connection/authentication ownership, and supported action semantics before adding them.

## Setup and presentation

Adapt Flux's reversible setup and visible session workflow through native services and views.
Provider setup owns only this app's entries, records ownership for removal, preserves unrelated settings
and user edits, and reports conflicts instead of overwriting unsupported configuration.

`ProviderSetupController` owns action/progress/confirmation state and one cancellable task per provider.
Menu commands open Agents settings; `ProviderSetupView` renders separate version, shape, helper, ownership,
policy, receiver, delivery and Claude quota evidence. Opening a view does not probe or install anything.
`PetAppController` owns both controllers only while Agents is installed and cancels them on removal.

`ProviderSetupService` distinguishes documented bindings from runtime qualification. Codex 0.164.0 and
Claude Code 2.1.306 have documented bindings under the user's explicit verification waiver. The qualified
registry remains empty. `CodexHookPolicyProbe` uses bounded initialize/config/read/configRequirements/read;
Claude user settings expose known disabled flags but cannot establish project/managed enablement.
Unknown policy stays unverified; known disabled/managed-only policy blocks installation. No policy,
permissions or trust are changed. Removal needs exact content ownership and file safety, without a CLI.
See [provider setup](contracts/provider-setup.md) for the contract and limitations.

`ProviderMonitoringModel` persists per-provider consent separately from the master Agents switch.
Pause filters queued lifecycle events and cancels the provider's quota work, preserving unconfirmed
requests and ended sessions. Resume installs new receipt/capture cutoffs. Claude quota callbacks have a
separate generation. `AgentServices` owns these gates independently of Notch visibility.
Disconnect pauses first and removes owned configuration; a failed/partial removal stays paused.

HookSetupPlanner consumes explicit evidence and bounded bytes. HookConfigurationJSON preserves source ranges,
duplicate-key rejection and numeric lexemes; the observer retains its separate finite-number and deadline boundary.
The planner adds seven independent groups, quotes the helper path, leaves unchanged reinstalls byte-identical and removes
only uniquely matching owned groups. Existing unrelated numbers, values, group ordering and later edits survive.

ProviderHookTransaction owns descriptor-relative no-follow file operations, cooperative locking, rechecks and the
install/remove journal. HookFileDirectory bounds reads, checks identities/permissions and synchronizes candidates,
hooks, records and directories. Existing safe mode/group/ACL metadata is preserved; unsupported extended metadata is rejected.
New private records/directories have restrictive modes and no inherited ACL. Journals hold digests and
scoped ownership records, never full configuration backups. Claude quota ownership also retains the
exact original statusLine value privately for restoration. Its planner changes only that field and
preserves the original command/field members. Lifecycle and quota use different ownership/journal names
under one writer lock; either known pending journal is recovered before further settings changes.
Known previous/candidate states can recover; other states require manual reconciliation.
Before journal publication cancellation may abandon the change. After publication the worker completes durable
finalization or retains recovery evidence, while cancelled UI observation drops late results.
The accepted independent-editor compare/replace window remains; locking and atomic rename do not eliminate it.

Records live under Application Support/NotchPet/Integrations/{Codex,Claude}/<configuration-path hash>, outside the repository.
Inactive unpublished temporary candidates are never adopted; unproven crash orphans are left inert.
No test, build, app launch, live probe or installed configuration mutation was performed for this source-only MVP.
The temporary menu session interface established partial delivery evidence. The current menu contains feature-dependent Show Pet/Show Notch, Settings and Quit.
Session content is in the notch. Remaining [session-island acceptance](specs/notch/session-island.md) is separate from that source finding.

`NotchPresentation` derives default selection and attention priority from session snapshots.
`NotchSessionView` retains its selected key across updates while that session exists. There is no shared cross-surface selection store yet.
Pet reactions preserve authoritative session meaning. A shared selection adapter remains future work.
Views do not maintain independent copies of lifecycle truth, and hiding or dismissing a visual notice cannot resolve a pending request.
TerminalNavigation saves a user-selected application identity/path and activates only one matching running instance.
The optional ITermPaneAdapter records an explicit user-linked ID/tty with terminal PID/launch date, revalidates unique live objects and confirms focus through process-addressed public Apple Events. It never launches a terminal or creates a pane.
Other terminals retain application activation/manual return; legacy Otty wire hints remain untrusted and do not authorize automatic focus.
See [pane navigation](specs/sessions/pane-navigation.md) for bounds, uncertainty and unrun compatibility.
Do not require Otty's executable or pane metadata for monitoring, pet reactions, or supported allowance reads.
The version-1 wire contract retains its optional Otty-only navigation object. Additional terminal metadata needs a separate contract review.

AppKit controllers own window geometry, focus and native behavior. Full dragging and display/Spaces recovery acceptance remains separate work.
Use supported native APIs to reproduce desired behavior rather than transplanting Electron helpers.
Pet returns through notch overlap or a menu-bar action without losing shared attention state. Native dragging hides the retained Notch window; return restores it without rebuilding session selection or drafts. Pet-only use restores a clamped desktop position.
Animation is presentation only: unknown state must not appear as confirmed working or response ready.

## Standalone pet boundary

[Decision 0013](decisions/0013-separate-standalone-pet-scope.md) accepts one app with an independent pet module and optional agent services.
The independent `Pet` target owns artwork, rendering, preferences and playback rules without importing agent session types.
The app's `PetPanelController` owns native placement, currently near the lower-right of the main display's visible frame.
`PetWindowPlayback` supplies visibility and sleep inputs. `PetView` schedules frames only when its playback policy permits animation.
The app owns optional service lifecycle. Pet-only startup starts no agent or usage services and needs no hook configuration.
PetSessionAdapter translates shared snapshots into PetMood, with visible text for working, attention, response ready, unknown and ended. A bounded app-lifetime identity set deduplicates response cues; existing, hidden and asleep states never replay a cue. PetPanelController owns native alpha hit testing, mouse-motion pass-through, dragging, overlap return and screen-relative preference restoration. The Pet target imports no agent module. Native interaction remains unverified.
Missing events will not prove that a session ended. Unknown state and unresolved notices will retain their existing meanings.
The [built-in pet](specs/pets/built-in-pet.md) is implemented in part, with native acceptance still open. Agent reactions remain a separate feature.
The independent pet remains accepted. [D2](DECISIONS.md#d2-collect-and-inspect-telemetry-locally-with-an-optional-background-process) now adds an optional collector and history; no second app or repository split is planned.

## Proposed compatible pet input

Decision 0006's versioned manifest and PNG frame sequences remain the runtime representation.
The user’s later local-only request selects import-time normalization of seven-row sprite sheets into this format; P5/P6 acceptance remains unrun.
The structural alternatives are normalization into that representation at import, or a second runtime loader.
Normalization is recommended but remains open; it would leave the renderer with one format and concentrate validation in the import service.
No runtime format changes, detector rules, or Flux artwork are accepted by this proposal.

## Resource efficiency and collection follow-up

Low idle energy use is an accepted release requirement: see [D1](DECISIONS.md#d1-make-low-idle-energy-use-a-release-requirement).
The [resource-efficiency spec](specs/notch/resource-efficiency.md) proposes concrete runtime checks, profiling tasks, and initial budgets.
Native implementation alone is not evidence of low CPU, memory, or battery cost.

The user confirmed one optional local collector, local SQLite history, and three pilot skills under [D2](DECISIONS.md#d2-collect-and-inspect-telemetry-locally-with-an-optional-background-process).
The [telemetry area](specs/telemetry/area.md) separates background collection, local history, and skill instrumentation.
The collector will own live session evidence; the app will consume bounded snapshots. Persistent history cannot establish live working state.
Usage refresh and interactive action channels retain their current owners. The independent pet does not import telemetry or start a collector.

Observation hooks retain bounded one-way delivery. Durable telemetry uses a separate reviewed acknowledgement/retry contract with stable record IDs.
Data stays on this Mac; no hosted backend, synchronization, transcripts, or credentials are included.
Existing app-owned collection remains the implemented foundation until the proposed extraction tasks are approved and verified.

## Data without a database

| Data | Storage | Reason |
|---|---|---|
| Active sessions and alerts | Memory | They describe live processes |
| Feature availability, master/per-provider monitoring consent, pet size/setup and selected Settings page | `UserDefaults` | Implemented small preference values with separate meanings |
| Selected pet UUID, sound and screen-relative placement | `UserDefaults` | Sound defaults off; missing assets/displays use explicit/clamped fallback |
| Imported pets and manifests | Private Application Support files | Validated asset-only bytes; staged exclusive rename; immutable playback data |
| Optional later usage cache | Small JSON file in Application Support | Must retain receipt time, source measurement time if supplied, and a stale label |
| Credentials | Existing provider-managed authentication | The app does not copy tokens |

Do not persist a session as still working after the app restarts without fresh evidence.
D2 now accepts SQLite for local telemetry history. The current memory/preferences/files layout remains the foundation until that feature is implemented.
Adding quota display alone does not require a database.
Keep runtime files, imported packs, and captured session data outside this repository.

## Accepted decisions

| Choice | Accepted approach | Alternative and tradeoff |
|---|---|---|
| Presentation structure | Shared stores, pure presentation and view models only for view-owned state (D3) | A view model for every view adds forwarding and risks duplicated state |
| Persistence | Memory, preferences, and files | SQLite supports history queries, but adds schemas and migrations |
| Event source | Official agent hooks | Transcript reading catches other details, but depends on changing formats |
| Local event delivery | Unix-domain socket and small helper | Localhost HTTP is easier to inspect, but needs port management |
| Custom pet format | JSON manifest and transparent PNG frame sequences | Sprite atlases reduce file count, but are harder to author |
| Usage source | Provider-supported interfaces | Private endpoints may expose more data, but add authentication and compatibility work |
| Local interactions | Accepted scope; response mechanisms and action contract require compatibility verification | Otty-only handling is simpler but requires switching away from the app for every decision or reply |

No dependency-injection framework, external event broker, hosted backend, or web account is needed. D2 adds one optional local collector.
Pass service dependencies explicitly. Keep the first version small.

The current app-owned delivery can lose events while the app is closed. The planned collector removes that UI dependency without making the one-way helper durable. Do not replay unverified activity as live state after restart.
The [version-1 event contract](contracts/agent-events-v1.md) defines message fields, bounds, and ordering before bridge implementation.
[Decision 0008](decisions/0008-define-event-ordering.md) records conservative ordering without persistent helper state.

## Local app shell

The first executable is a dependency-free Swift package targeting macOS 14 or later with Swift 6 tools.
`NotchPetApp` owns the SwiftUI `MenuBarExtra` scene and delegates app lifetime to `PetAppController`.
Its private `CompanionMenu` presents feature recovery, Settings and Quit, without duplicating the session list.
Quit calls AppKit's application termination action. The bundle's `LSUIElement` flag keeps it out of the Dock.
`bash scripts/run.sh` builds and launches a development app bundle under the user's temporary directory.
This keeps build products outside the repository and works with installed Command Line Tools.
This is a local development launch path; distribution packaging remains a later task.

## State and attention rules

- Identify sessions by agent and source session identifier, rather than project folder alone.
- Keep pane identity separate from session identity.
- Validate terminal targets against live state. The optional explicit iTerm2 binding requires unique ID/tty and the same process lifetime. Legacy Otty hints alone never authorize navigation; ambiguous targets remain unavailable.
- Include event identity, source ordering where available, and observation time in the event contract.
- Define rules for duplicate events, delayed events, and restarted sessions before integrating the UI.
- Distinguish working, approval needed, response ready, failed, interrupted, ended, and unknown states.
- Claim a dedicated question state only when a verified source identifies it.
- Treat a finished response containing a question as response ready when no dedicated signal exists.
- Do not claim task success from a stop event.
- Give unresolved input requests priority over response-ready notices.
- Keep every session accessible when several need attention.
- Mark stale sessions unknown when their state cannot be confirmed.
- A stale terminal target permits only verified application activation or manual return. Never create a replacement session automatically.

The version-1 contract specifies these requirements as provisional observations with a two-minute freshness limit.
Unknown state retains unresolved requests as unconfirmed notices.
It does not support working-state recovery after an observed end reuses the same source session ID.
The bridge is implemented in the shared `EventBridge` Swift target.
`NotchPetHook` projects raw hook input and makes one bounded delivery attempt.
The optional `AgentServices` instance starts and stops the receiver. `PetAppController` stops all feature runtimes during normal app termination.
The receiver hands validated envelopes and receipt times to a callback on its worker queue.
The app now owns one observable `SessionStore` in the `SessionState` target.
`SessionObservationV1.init(received:)` maps the seven accepted hooks into shared event meanings.
This mapping implements the version-1 contract. It does not verify provider compatibility or install agent hooks.
`CodexEventAdapter` owns Codex raw field selection. Both adapters use the shared seven-hook allowlist in `HookEvent`.
Adding a hook requires reviewing the wire contract and both providers' coverage. The enum alone does not qualify provider support.
`HookEnvelopeV1.project` routes Codex payloads through that adapter and preserves the helper's parser deadline.
The wire validator still enforces common field bounds. The store still owns ordering and freshness.
The adapter uses the investigation's payload shapes without inferring missing identities or reading transcripts.
Both Codex and Claude adapters are implemented and checked with fictional inputs.
Their fictional-input checks do not establish live provider compatibility or native acceptance.
Remaining interactive Codex verification stays separate under decision 0009 and the Sessions specifications.

`SessionEventInbox.receive(_:)` enqueues observations without waiting for the main actor.
The inbox retains at most 128 queued observations and schedules one drain at a time.
One active batch can coexist with the next queued batch.
Each batch preserves enqueue order. Receipt order does not prove source order.
An overflow drops excess observations and makes all nonterminal sessions unknown after applying the retained batch.
This avoids retaining an unbounded UI queue or claiming complete evidence after a local drop.

The main actor serializes store changes and publishes immutable `SessionSnapshot` values.
The store checks delivery age, duplicate identity, ordering, requests, freshness, and the accepted memory limits.
It retains SHA-256 digests for event comparisons instead of complete old envelopes.
Source identities compare UTF-8 bytes so distinct Unicode forms cannot merge sessions, turns, or requests.
Snapshots retain project paths and unverified pane hints only from compatible observations.
Unknown sessions expose pending requests as unconfirmed notices.
Recovery requires a different, previously unseen turn identity with no unresolved requests.
An observed end retains its terminal restriction for the app run.

`SessionStore.apply(_:)` applies one normalized observation.
`applyBatch(_:observationsLost:wallMs:monotonicNs:)` expires delayed observations before publishing the batch.
`advance(monotonicNs:)` checks expiry. `checkClocks(wallMs:monotonicNs:)` also checks clock continuity.
Backward clock samples and wall/monotonic elapsed-time differences above two seconds invalidate nonterminal observations.
New evidence after a monotonic reset uses deadlines in the new clock range.
The app checks clocks during receipt and schedules a timer while fresh observations exist.
The timer checks after one second or at the nearest expiry, whichever comes first.
An empty or entirely unknown store has no expiry timer.
Sleep, wake, and system clock notifications invalidate live observations and exclude earlier queued receipts.
`invalidateClocks()` retains unresolved notices and terminal restrictions.
These injected lifecycle checks do not establish physical sleep/wake or window recovery behavior on the target Mac.

The app holds a user-owned `listener.lock` file while it owns the socket.
It never removes the lock file, which prevents separate processes from locking different replacement files.
It recovers only an owned socket whose connection is refused and whose file identity remains unchanged.
Shutdown checks that identity before removing its socket.
These checks coordinate local instances within the accepted same-user boundary; they do not authenticate an agent.
Runtime files remain under `/private/tmp/notch-pet-<uid>/`.

## Limits display

The notch allowance strip supports Codex and Claude Code presentation for active providers only.
Codex-only sessions hide Claude, Claude-only sessions hide Codex, and both active providers show both entries.
Cached usage alone never makes an inactive provider visible. Unknown and ended sessions do not establish provider activity.
The store retains reported used percentages. Under [D6](DECISIONS.md#d6-show-allowance-as-percent-left-not-percent-used), presentation shows `100 − used`, rounded down.
The strip selects an unambiguous reported five-hour window, or a weekly fallback, and shows its reset countdown.
Missing or ambiguous data stays unavailable. Stale values use gray. A reset passing does not establish refreshed usage.
Other providers are deferred. Account grouping requires supported identity, and live Claude forwarding remains unverified.

- Keep context usage, token usage, subscription allowances, and API rate limits separate.
- Show only windows returned by the provider. Do not assume Codex always uses five-hour and weekly windows.
- Label percentages explicitly as used or remaining.
- Retain a source timestamp when supplied, local receipt time, and each window's reset timestamp; do not invent provider measurement time.
- Mark cached observations stale. A reset time passing does not prove a new allowance value.
- Account allowance is shared across sessions; never add the same allowance across panes.
- Keep snapshots isolated by provider and account when identity is available.
- Do not combine sessions into an account total when account identity cannot be established.
- Keep Claude observations separate and label them account unverified when supported identity is absent.
- Record local receipt time separately from provider measurement time, which the investigated quota shapes do not establish.
- Repeated status-line delivery does not prove a fresh provider measurement.
- Prefer Codex's full bucket map when present; do not count its compatibility view as another allowance.
- Merge sparse Codex updates into a full snapshot, or read a new full snapshot.
- Preserve the user's existing Claude Code status-line output when adding a forwarding wrapper.
- Use bounded refreshes with backoff; avoid frequent account requests while idle.
- Keep cancellation and reconnect behavior inside each usage provider; failed refreshes cannot leave an allowance labeled fresh indefinitely.
- Adapt independent refresh and status-line preservation patterns without adding transcript fallback or fixed daily/weekly buckets.

## Desktop implementation and deferred acceptance

- NotchWindowState retains geometry separately from view identity; NotchPanelController recovers on display/Space/sleep changes. Pet and Settings clamp placement on connected displays. Actual external-display recovery remains unrun.
- Define fullscreen and Space behavior through supported AppKit window behavior.
- Menu/Settings Open Sessions explicitly acquires keyboard focus; Escape/Done Editing restores the previous app only while focus is still owned. Automatic recovery never activates an app.
- Keep inactive transparent regions from intercepting normal clicks.
- Pause unnecessary animation when hidden or asleep, and support Reduce Motion.
- Clamp saved placement to a connected display after resolution changes.
- Treat pet packs as data. Reject invalid paths and oversized image sets.
- Keep routine logs bounded and exclude prompts, command contents, and credentials by default.
- Preserve unrelated hooks and status-line settings during setup and removal.
- Make overlay alerts nonactivating, and keep basic menu-bar recovery controls and Return Pet.
- Keep unknown and ended presentation distinguishable from working or response ready; animation does not change session state.
- Validate display recovery and resource use in the actual app; native implementation alone is not a performance measurement.

## Verified documentation and remaining checks

Checked on 2026-10-22. Documentation establishes interfaces; it does not prove this app's integration works.

- [Codex hooks](https://learn.chatgpt.com/docs/hooks) documents `PermissionRequest`, `Stop`, session identifiers, and hook trust.
- [Claude Code hooks](https://code.claude.com/docs/en/hooks) documents approvals, response stops, and notification types with different timing.
- [Otty pane links](https://docs.otty.sh/reference/url-scheme) documents `OTTY_PANE_ID` and `otty://pane/<id>` navigation.
- [Otty setup](https://docs.otty.sh/getting-started/first-launch) describes existing agent hook installation.
- [Claude Code status lines](https://code.claude.com/docs/en/statusline#rate-limit-usage) expose eligible accounts' usage percentages and reset timestamps.
- [Codex App Server](https://learn.chatgpt.com/docs/app-server) documents `account/rateLimits/read` and rate-limit update notifications.

The [event compatibility record](notes/agent-event-compatibility.md) verifies controlled hook dispatch and fresh Otty pane navigation.
It also records a stale inherited pane selector. Partial interactive Codex checks used a mock provider; remaining paths and real-provider behavior are unverified.
The [usage-source record](notes/usage-source-compatibility.md) verifies short read-only Codex quota reads without conversations.
Claude eligibility and installed fields were checked; live forwarding and output preservation remain unverified.
Later adapter tasks must check interactive behavior, abrupt process loss, and hook trust.
Later usage tasks must check long-running coexistence, account changes, and Claude forwarding behavior.
Unsupported account modes remain explicit limitations. Do not introduce private endpoint fallbacks.



## Custom pack flow

App-owned PetLibraryModel owns chooser/worker/cancellation and current selected presentation. PetPackLibrary
in the independent Pet module validates the manifest and every PNG, copies only bounded asset bytes into
private staging, revalidates content and commits with exclusive rename. The app saves selection only after
success; invalid import/cancellation preserves the active pet. Missing/invalid saved packs fall back to
built-in art without silently resetting preference. Explicit built-in recovery works with unavailable
pack storage. PetView plays immutable encoded bytes through a bounded decoded-image cache; no manifest
path is resolved during playback. See [pet workflows](contracts/pet-workflows.md) for exact bounds.


Local-only customization adds two inputs to the same app-owned serialized import worker. Animate PNG
uses PetLocalAnimation for bounded affine transforms of the supplied pixels; Import Sprite Sheet uses
PetSpriteSheet for seven-row slicing with exhaustive alpha detection and trailing padding rules.
PetPNGRaster centralizes header, source bit-depth, decode, canonical RGBA and output PNG bounds.
Neither path adds provider/model calls, prompts, authentication, imported executable code or a second
playback representation. Both use PetPackLibrary’s existing private transaction and selection rollback.


## Full local MVP source handoff, 2026-11-06

The nine source criteria in [the full implementation goal](goals/full-mvp-implementation.md) have
concrete production paths; its [final audit](goals/full-mvp-implementation-log.md#turn-9-final-source-audit)
traces adapters, services, ownership and native controls. This completes the implementation-only goal,
not broader roadmap or release acceptance. All changed code remains unbuilt and untested at the user's
request. Existing historical evidence does not qualify this checkout.

Documented provider candidates are Codex 0.164.0 and Claude Code 2.1.306; the runtime qualification
registry remains empty. Claude supplies approve-once/deny, structured answers and bounded Stop-hook
feedback; arbitrary-time input and Codex local actions are unsupported. Exact terminal pane focus is
optional, explicitly user-linked and currently limited to the iTerm2 adapter; application/manual return
remains available elsewhere. No monitoring path requires Otty. No AI artwork workflow or company code
was added. Original acceptance checkboxes, deferred FM7 and separate CI/telemetry work remain open.
