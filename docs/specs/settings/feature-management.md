# Install and uninstall optional features

Status: in progress

## Goal

Let people keep only the parts they use in one native app: Desktop Pet, Notch and Agents.
Pet works without either other feature. Settings owns feature availability; each feature retains its own behavior and services.
The user approved FM1–FM7 and continued execution on 2026-11-02, excluding VoiceOver testing for every feature.
FM1–FM7 are linked by the [modular-features goal](../../goals/modular-features.md). The user has paused it and deferred FM7; older goals remain separate.

## Done when

- Settings has a Features destination with an icon, name, one-line purpose, installation state and Install/Uninstall action for each feature.
- A fresh installation starts with Pet only. It starts no session/usage receiver, agent process, configuration probe or refresh loop.
- Existing explicit monitoring preferences migrate without installing hooks, inspecting provider configuration or silently changing the user's opt-in.
- Pet-only use creates no Notch controller and supports useful desktop placement without a physical notch. Pet preferences survive reinstall.
- Notch can be added or removed without starting or stopping agent monitoring. Agents can run while either visual surface is absent.
- Installing Agents makes its controls available; connection/setup remains an explicit provider action under its existing contract.
- Uninstalled features have no ordinary settings page, surface, shortcut or active owned work. Their Features rows remain available for reinstall.
- Removing the last optional feature leaves Settings, Features and Quit reachable from the menu bar.
- Runtime removal cancels owned work and prevents callbacks from a retired instance from changing current state. Repeated removal is safe.
- Feature removal preserves unrelated preferences/configuration and cannot resolve an outstanding request as approved, answered or successful.
- Every combination survives relaunch. Reinstall restores saved choices without silently reconnecting a removed provider or replaying requests.
- A failure leaves a truthful, recoverable state. The UI distinguishes feature availability, runtime pause, provider setup and health evidence.

## Scope and ownership

This feature owns the catalog, persistent installation choices, app lifecycle coordination and Features actions.
The shared settings-window roadmap owns native window/navigation mechanics and hosting the existing pet controls.
The work should reuse that shell; it must not create another competing settings window.
FM1 and the lifecycle work can be reviewed independently of that shell. FM4 cannot ship until the shell's task list is approved.

Existing owners remain:

- [Built-in pet](../pets/built-in-pet.md): artwork, size, playback and its deferred acceptance.
- [Pets area](../pets/area.md): desktop placement, later dragging/return and optional reactions. FM3 provides only the placement needed for Pet without Notch.
- [Codex setup](../sessions/codex-setup.md): verified Connect, configuration ownership, installation/removal and provider qualification.
- [Session island](../notch/session-island.md): selection, focus, alerts and remaining physical-notch acceptance.
- [Usage](../usage/area.md): provider reads, account/freshness meanings and refresh ownership.

No second app, downloadable code plugin, installer package split, new collector, agent response channel, new provider or pet artwork is added.
This plan does not resume a goal, captures, deferred native acceptance or installed-agent configuration changes.
VoiceOver/screen-reader testing is excluded from feature acceptance under [D8](../../DECISIONS.md#d8-exclude-voiceover-testing-from-feature-acceptance).
Retain meaningful control labels, keyboard access, Reduce Motion and focus behavior.

## Current code and gaps

Baseline: main `e856686`, after PR #13. These are source findings rather than new runtime acceptance:

- `PetAppController.applicationDidFinishLaunching` always creates/shows the pet and creates its settings controller.
  It reads `agentMonitoringEnabled` to opt into a single `AgentServiceOwner`.
- `PetPanelController` is independent of agent models, but initially places the pet under the built-in notch area.
  Independent desktop placement and menu recovery require an explicit small change.
- `AgentServiceOwner` defers service creation until enabled. It has no installation catalog and retains its created service for reuse.
- `AgentServices.start()` creates/shows the Notch controller; `NotchPanelController.show()` starts usage reads.
  Presentation, monitoring and usage ownership must be separated before they can follow independent feature choices.
- `AgentServices.stop()` does not establish that already queued inbox callbacks are discarded. Lifecycle generation checks need verification.
- `PetSettingsController` and `PetSettingsView` provide pet preview, size and completion controls. The general settings shell and Features page do not exist.

## Proposed behavior for review

These choices implement D7 and were approved with the goal on 2026-11-02. Later slice plans must preserve these boundaries.

### Installation and migration

Use a versioned feature-availability record in the existing UserDefaults domain. Keep it outside the Pet module.
The catalog contains stable IDs for `pet`, `notch` and `agents`; views render this catalog and current operation state.
Factories must remain deferred: listing a feature never constructs its controller or starts its services.

When no availability record exists, preserve an explicitly enabled legacy `agentMonitoringEnabled` preference by installing Pet,
Notch and Agents and retaining that opt-in. Otherwise use Pet only. FM1 only computes and stores choices; it starts no runtime work.
Malformed/unsupported stored values need a visible recovery state and must never enable Agents by guesswork or destroy the original value.
Keep feature availability separate from existing runtime monitoring consent. A provider executable on disk is not consent.

### Supported combinations

| Selected features | Expected behavior |
| --- | --- |
| None | Menu, Settings, Features and Quit remain; no optional surfaces or agent work |
| Pet | Ordinary desktop companion; no Notch or agent services |
| Notch | Optional island surface with a calm explanation that monitoring is not installed; no agent probes |
| Agents | App-owned monitoring/health controls available in Settings; no automatic pet/island creation |
| Pet + Notch | Both presentation features; no agent work |
| Pet + Agents | Pet plus monitoring; no Notch. Agent reactions remain a separately planned adapter |
| Notch + Agents | Existing session/allowance presentation without creating the pet |
| All three | Shared session authority; each surface and its service lifecycle still follows its own feature choice |

Notch without Agents offers Open Features rather than silently installing monitoring.
Agents without a visual surface keeps evidence in app-owned state while the app runs. It does not introduce collection after Quit,
new notifications, a menu-bar session list or automatic reactions. Settings remains the recovery/control surface.

### Install, uninstall and recovery

An Install action makes the selected feature available and applies its own permitted runtime state. Installing Agents starts no provider
configuration edit or new connection. Existing verified session/usage consent is required before optional provider work can start.

Uninstalling Pet closes its panel/preview work and removes pet commands while retaining size/artwork preferences.
Uninstalling Notch closes that panel and its presentation timers; it leaves installed agent monitoring and retained notices intact.
Monitoring and usage work belong to the installed Agents feature and their provider-specific opt-ins, not window visibility.

Uninstalling Agents first gates new input and retires the current lifecycle generation, then cancels receivers, observers, expiry tasks,
usage processes and refresh loops. Late callbacks are ignored. Pending notices become unconfirmed; no artificial completion is emitted.
Pet returns to ordinary presentation and an installed Notch reflects unavailable monitoring. Reinstall requires fresh live evidence;
old snapshots cannot be revived as current sessions or requests, and no uncertain action is replayed.

Feature removal and hook removal are different operations. Current unowned/externally installed hooks are left untouched.
If a future provider setup records owned hooks, uninstall must explain and use that reviewed removal contract. On an ownership conflict,
stop monitoring, report cleanup pending and retain the ownership record rather than pretending removal succeeded or deleting unrelated settings.
Keep that recovery reachable in Features. The exact UI wording and partial-removal state must be reviewed before FM5.

Preserve preferences on reinstall, but do not silently reactivate disconnected providers. Loaded object/code memory may remain until restart;
the contract is zero ongoing owned work, not runtime unloading of compiled Swift code. No restart should be needed merely to stop a feature.

### Proposed UI

Use the portable [UI direction](../../notes/companion-ui-direction.md), especially the small Vorssaint-inspired feature manager.
General and Features remain available. Feature-specific pages appear only for installed features.
Keep the feature row itself after removal, with Install and a short explanation. An installed row can open its settings separately from Uninstall.
Show operation progress and bounded errors on the affected row; avoid duplicate requests while that operation is in flight.
Use an explicit confirmation only when removing a feature affects retained notices, owned integration configuration or another selected feature.
The app does not automatically cascade-uninstall Pet, Notch or Agents.

Opening Settings is an explicit focus request. Incoming observations and restoring a visual surface must preserve the existing nonactivating rules.
Use native controls, text alongside state colors, clear accessibility labels and keyboard access. Do not restore the removed allowance tooltips.

## Approved tasks

FM1–FM7 were approved with the goal on 2026-11-02. Keep their evidence and checkboxes separate from older source tasks.

- [x] FM1: Add the pure feature catalog and versioned availability preferences, including fresh defaults, legacy opt-in migration and recovery for invalid records. No app wiring or I/O beyond isolated preferences. Verified 2026-11-02: five focused Swift tests, including eight parameterized feature sets; zero failures.
- [x] FM2: Separate app-owned agent/usage lifetime from the Notch controller; add independent surface ownership and stop-generation guards. Verified 2026-11-02: five new runtime tests plus six existing service/observation checks passed. Old-generation events are rejected; retained requests become unconfirmed without synthetic completion.
- [x] FM3: Wire selected-feature startup and minimal independent pet placement, menu/Features recovery, and absent-feature factories. Shared Settings recovery is now present. Focused startup/placement and all eight selected-set checks passed; native placement remains with FM7.
- [x] FM4: Integrate the native Settings shell and three Features rows with catalog-driven navigation, operation states and Install actions. The approved bounded shell slice reuses the Pet window and controls. Model checks pass; actual native controls remain with FM7.
- [x] FM5: Implement Uninstall/Reinstall coordination with immediate teardown, retained preferences, pending-notice semantics and explicit provider reconnection/cleanup handling. Pending confirmation, stopped-on-write-failure and no reconnect on reinstall are verified. No owned provider installer is introduced or installed configuration touched.
- [x] FM6: Verify the eight combinations and transitions using fictional sessions and isolated preferences/factories, including all features absent, repeated operations, relaunch migration and late callbacks. Verified 2026-11-02: all 64 ordered transitions; final full suite passed 194 tests with zero unexpected failures and the existing usage-datagram known issue retained; packaged build and diff check passed. Actual native evidence remains with FM7.
- [ ] FM7: Perform one approved native acceptance pass covering Features keyboard access and clear control labels, pet-only placement, absent surfaces, saved preferences, focus and recovery. VoiceOver testing is excluded by D8; do not claim screen-reader acceptance. No captures or installed-provider edits unless separately authorized. Preserve unrelated deferred pet/notch acceptance.

## First implementation slice for review

FM1 proposes at most three changed implementation/test files:
`Sources/NotchPet/AppFeature.swift`, `Sources/NotchPet/FeaturePreferences.swift`, and `Tests/NotchPetTests/FeaturePreferencesTests.swift`.
Documentation/checkpoint records are separate. Add no package dependency or target.

### FM1 catalog and types

`AppFeature.swift` defines an internal `AppFeature: String, CaseIterable, Codable, Sendable` enum with stable IDs
`pet`, `notch`, and `agents`, in that display order. It contains no service factories, window references or provider capability claims.
Keep these app-composition types outside the independent Pet module and outside SessionState.

`FeaturePreferences.swift` defines value results that distinguish a usable installed set from required recovery.
A usable read carries its origin: stored, fresh default or legacy opt-in. Recovery carries a small reason enum,
never raw saved bytes in an error description. Suggested reasons are invalid stored type, invalid record, unsupported version and invalid legacy value.
An empty installed set is a valid choice, distinct from a recovery result. No inferred installed set is returned on recovery.

### FM1 storage and migration

Proposed key: `features.availability`, containing JSON `Data` with an integer `version` of 1 and an `installed` array of stable IDs.
For example, a pet-only record represents `{"version":1,"installed":["pet"]}`. An empty array means no optional features installed.
Encode IDs in catalog order, reject duplicates/unknown IDs, and bound input to 4,096 bytes before decoding.
A non-Data value, malformed record, incompatible version or invalid IDs produces recovery and remains untouched.
Version 1 may ignore extra JSON fields; a future incompatible format must use a different version.

Reads are side-effect free. When the availability key is absent, inspect only `agentMonitoringEnabled` in the injected defaults:

| Availability record | Legacy value | Read result |
| --- | --- | --- |
| Valid version 1 | Any value | Stored set wins, including the empty set |
| Absent | Absent or boolean false | Fresh Pet-only set |
| Absent | Boolean true | Legacy Pet + Notch + Agents set, preserving the previous opt-in |
| Absent | Other stored type | Recovery; do not interpret a string/number as consent |
| Present but invalid/unsupported | Any value | Recovery; do not fall back to the legacy flag |

Only an explicit save writes the new record. Save must refuse to replace a recovery record; a future deliberate reset needs its own reviewed action.
It never removes or rewrites the legacy flag, pet settings, unrelated keys or provider configuration. Persisting feature availability does not
start services, grant consent, install hooks or reconnect providers. Later runtime tasks must still apply those separate rules.
UserDefaults acceptance/read-back is the persistence seam; do not promise disk-level transactions, cross-process compare-and-swap or forced synchronization.

### FM1 proposed API and limits

Use a `@MainActor` `FeaturePreferences` namespace with explicitly injected `UserDefaults`; no default argument may silently select `.standard`.
Proposed entry points are `read(from:) -> FeaturePreferenceRead` and `save(_:to:) -> FeaturePreferenceSaveResult`.
Save accepts a typed `Set<AppFeature>`, returns success/recovery/write-failure distinctly and checks the current record before replacing it.
Use a private record decoder shared by read/save; keep the total to four handwritten production functions/accessors maximum.
Synthesized Codable/value-type members do not justify extra handwritten wrappers. Add no observers, tasks, AppKit/SwiftUI imports or dependencies.

Read must not repair or persist migration automatically. Save canonicalizes the typed set and verifies the observed value after the write;
reporting failure does not claim rollback or protection against an unrelated writer. Use a new isolated defaults suite per test,
clean up only that suite, and never enumerate real preferences or provider environment/configuration.

### FM1 five proposed checks

Use at most five Swift Testing test cases, parameterized where appropriate:

1. **Defaults and legacy classification:** absent/false/true/malformed legacy values return the specified source and installed set;
   repeated reads do not add/change any preferences.
2. **All eight sets:** save/reload each subset, including none; verify stored choices override a conflicting legacy flag and have deterministic ID ordering.
3. **Invalid/future data:** parameterize malformed JSON, wrong stored type, oversized input, duplicate/unknown IDs and incompatible versions;
   reads report recovery and a subsequent save preserves the original value and unrelated keys.
4. **Migration across reopen:** read a legacy opt-in, explicitly save that set, create a fresh preferences handle and confirm the stored record
   takes precedence after the legacy flag changes. The legacy key itself must survive untouched.
5. **Remove/reinstall preferences:** change the selected set, reopen and restore it while preserving fictional pet size, setup state and unrelated preferences.
   This checks installation-choice persistence, not runtime service teardown or actual hook removal.

These are proposed checks, not test results. FM1 passes only when its focused tests and diff check pass and the diff stays within the three named files
plus planning/status records. Its test count may include parameterized cases; report the actual framework count rather than promising five invocations.

Proposed command after implementation approval:

```sh
env DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --scratch-path /private/tmp/notch-pet-fm1/build --filter FeaturePreferencesTests
git diff --check
```

The user approved the umbrella goal, FM1–FM7 and its specified verification on 2026-11-02. Later slices still need bounded plans recorded before edits. Neither kind of approval authorizes captures, installed-provider changes, additional dependencies or unrelated cleanup.

## Decisions and questions

- Accepted: [D7](../../DECISIONS.md#d7-install-and-uninstall-features-from-settings), [0013](../../decisions/0013-separate-standalone-pet-scope.md),
  [terminal independence](../../decisions/0012-support-terminal-independent-operation.md), and [native UI](../../decisions/0001-use-swiftui-and-appkit.md).
- Approved with goal execution on 2026-11-02: the eight-combination semantics, availability migration, zero-feature recovery and lifecycle boundaries above. Record detailed later slices before edits.
- [D8](../../DECISIONS.md#d8-exclude-voiceover-testing-from-feature-acceptance) removes VoiceOver testing from every feature, retaining keyboard access, labels, Reduce Motion and focus.
- Confirm the desktop pet's first position while Notch is absent. A safe visible desktop default is sufficient for FM3; persistent dragging stays with Pets.
- Confirm whether the proposed calm Notch-without-Agents state is useful enough to ship, or should be labelled as awaiting optional monitoring.
- Resolve a future owned-hook cleanup failure's displayed state before FM5. Feature removal cannot bypass codex-setup qualification or ownership checks.
- No owner or deadline was supplied. The modular-features conversation goal is active.

## Execution evidence

FM1, 2026-11-02: the three named files implement the catalog and preferences with three handwritten production functions
and five Swift Testing tests. `env DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --scratch-path /private/tmp/notch-pet-fm1/build --filter FeaturePreferencesTests`
passed five tests in one suite, including eight parameterized combinations, with zero failures. The initial sandboxed invocation failed to write
the compiler module cache (`Operation not permitted`); the authorized retry outside the sandbox passed. No app was launched or preference domain inspected.

## FM2 bounded implementation plan

Approved goal scope; recorded before FM2 production edits. Separate monitoring from both presentation surfaces and usage ownership.
Keep pet moods/rendering in Pet; a future app-owned session-to-pet adapter remains the agent-reactions integration seam and needs no installed Notch.

1. Let `AgentServices` own shared session/usage stores and usage refresh, with an injected bridge/refresh seam for isolated checks.
   It must never construct a Pet or Notch window. Keep default provider I/O behind explicit startup/consent.
2. Give `NotchPanelController` injected shared stores. Show/stop only affect its own panel and rendering; no usage service startup there.
3. Guard inbox and expiry callbacks by a lifecycle generation, retire that generation before stop, and make repeated starts/stops safe.
   Stop marks retained live notices unconfirmed with an explicit monitoring-stopped reason. Restart requires new session evidence.
4. Add deferred app feature runtime ownership, reusable by FM3/FM5: uninstalled surfaces start no factories and repeated desired-state updates are idempotent.

Budget: up to seven production files (`NotchPetApp`, `NotchPanelController`, `AgentServiceOwner`, a feature runtime owner,
and the necessary SessionStore/observation model seams) and two related test files; at most twelve new handwritten production functions
and eight focused contract tests. Existing methods can be revised in place. Split further if this budget cannot cover the seams clearly.
Focused evidence must cover queued old-generation events, repeat start/stop, unknown retained requests, and absent-feature factories.
Use fictional events and in-memory injected start/stop closures; never start the real bridge or provider process in these unit tests.

FM2 evidence, 2026-11-02: `env DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --scratch-path /private/tmp/notch-pet-fm1/build --filter 'FeatureRuntimeTests|AgentServiceOwnerTests|ObservationLoopTests'`
passed 11 tests in three suites, including the eight parameterized factory combinations. The first build rejected capture of a non-Sendable
Notification payload; the callback does not use that payload, so it now sends only the invalidation signal. The rerun passed.

## FM3 bounded implementation plan

Record before FM3 edits. Wire the approved availability model into app startup without adding Settings controls yet.
Pet, Notch and Agents share only app-owned stores and deferred factories. Factory failure must be visible, not reported as running.

- Update `PetAppController` to load/migrate choices, preserve recovery data, and create only selected runtimes. Monitoring still requires its
  separate stored opt-in. Do not automatically reconnect on feature reinstall. Menu/Settings/Quit remain available when no feature runs.
- Add Pet runtime start/stop and a visible default desktop location using the screen's visible frame, independent of notch geometry.
  Retain size; full dragging, persistent placement and desktop recovery stay with Pets. Use a lower-right default with an inset and supported AppKit geometry.
- Keep the menu's Show Pet/Show Notch actions conditional on installation. Settings remains a single entry; FM4 supplies the shared window.
- Let a deferred factory fail explicitly so missing pet assets cannot produce a false active state; cover this in the runtime contract checks.

Budget: four production files (`PetAppController`, `PetPanelController`, `NotchPetApp`, `FeatureRuntimeOwner`) and one existing runtime test file,
at most ten new handwritten production members and two new focused tests. Reuse existing controls and stores; no UI redesign, agent setup or artwork.
Verify focused preferences/runtime checks and build through those tests; native window behavior remains for FM7.

FM3 implementation checkpoint, 2026-11-02: selected startup, separate monitoring opt-in, conditional menu actions, optional factory failure
and safe lower-right desktop placement are written. The combined focused run passed 15 tests in three suites, including two new factory/placement checks.
FM3 stays open until FM4 provides the actual Features/recovery route with no Pet installed; native placement remains for FM7.
This run exposed FM1 JSON object key-order instability (six byte-equality failures); `.sortedKeys` fixes canonical serialization without changing the tests.
The rerun passed. No production state or real provider configuration was used.

## FM4 and FM5 bounded implementation plans

Recorded before their production edits under the approved goal. Reuse the existing Pet settings window as the single shared Settings window.
Preserve the native dark appearance and existing Pet preview/size/Done behavior; use a modest sidebar and grouped feature rows from the portable reference.
General and Features always remain reachable, with Pet/Notch/Agents pages only when installed. Restore a saved page only while it remains available.

FM4 adds a main-actor observable feature-settings model with injected defaults and runtime-application/notice-count closures. Merely constructing
or opening Settings must not start services. App launch explicitly loads/migrates then applies selected features. Install makes availability persistent;
installing Agents explicitly leaves monitoring off. Retain inline recovery/factory failure explanations and Retry; do not silently reset unreadable data.
Use one page per installed feature: existing Pet controls, a Notch show action, and Agents monitoring/observed receiver evidence with truthful setup gaps.
There is no dead Connect control or new configuration probe. Use existing supported native controls and keyboard navigation; respect Reduce Motion/focus.

FM5 implements removal through the same model. Agents removal requires confirmation when retained requests exist, disables monitoring before teardown,
and preserves notices as unconfirmed. A failed feature-preference write leaves Agents installed but stopped and reports that partial state.
Reinstall preserves feature-specific preferences and keeps monitoring off until explicitly enabled. Pet/Notch removal leaves the other runtimes intact.
Existing agent hook/configuration files are untouched; this goal adds no owned installer, so there is no newly owned hook cleanup to perform.
Unreadable/future feature data remains intact. Retry can reconcile externally restored compatible choices; no implicit data reset is added.

Budget across FM4/FM5: at most eight production files (new settings model, new shared settings view, AppFeature metadata, FeaturePreferences key constants,
PetSettingsController, PetAppController, NotchSessionView/NotchPanelController if needed for the monitoring-unavailable explanation) and one new test file.
At most 25 new handwritten production members across the two tasks; split another named slice if extra native verification instrumentation is required.
At most eight new meaningful model contract tests cover no-start-on-open, all combinations, installation versus consent, pending-removal confirmation,
last-feature recovery/navigation, malformed data preservation/retry, persisted-write failure and no automatic reconnect on reinstall.
Then run the focused new model tests plus the existing preferences/runtime suites. FM6 retains full-suite/build responsibility and FM7 retains actual native checks.

FM4/FM5 evidence, 2026-11-02: focused `FeatureSettingsModelTests|FeaturePreferencesTests|FeatureRuntimeTests` passed 20 tests in three suites,
including all eight settings-to-runtime combinations. Eight new settings tests cover constructor isolation, separate monitoring consent,
pending-removal confirmation/cancel, retained preferences and no reconnect on reinstall, independent surface removal, future-data recovery/retry,
failed persistent writes leaving monitoring stopped, typed consent and independent factory retry. No app was launched by these tests.

## FM6 bounded verification plan

Add one contract test file with at most two parameterized tests. Exercise all 64 ordered transitions between the eight valid feature sets through
the real preferences/settings model/runtime owner with fake service factories. Assert retained services are not restarted, removed services stop once,
new Agents installation stays off until explicit consent, empty selections remain valid, and reopened models restore the saved choices.
Then run the full Swift suite and packaged build on the stable final implementation. Additional native verification code belongs to a separately
bounded FM7 slice and must be included before the final full-suite/build evidence is frozen.

FM6 transition evidence, 2026-11-02: `FeatureTransitionTests` passed its one parameterized test with all 64 ordered feature-set transitions.
It exercises the actual preferences/model/runtime owner, including retained instances, one stop per removed instance, explicit consent for newly installed
Agents and reopen behavior. The test uses only isolated defaults and fake service implementations. Full suite/build remain pending until native support is stable.

FM6 final evidence, 2026-11-02: after native support, the prescribed full-suite command exited 0: 108 + 17 + 37 + 32 = 194 tests,
zero unexpected failures, one pre-existing known issue in UsageReceiverTests. Full output: `/private/tmp/notch-pet-features-final-tests.log`.
The prescribed packaged build exited 0; `/private/tmp/notch-pet-features-build.log` records the build and Info.plist check.
The app is `/private/tmp/notch-pet-features/notch-pet-dev/Notch Pet.app`. `git diff --check` passed. These checks do not prove FM7.

## FM7 bounded native acceptance plan

Use the packaged actual app, isolated preference suites and a private temporary bridge endpoint. No screen captures, screen recording, VoiceOver tests,
global permission/preferences changes, installed-provider configuration or other running app instances are accessed or modified.
An API feasibility probe found that direct SwiftUI accessibility enumeration is empty without enhanced accessibility, while ordinary NSEvents delivered to
the probe's own NSWindow execute its native button. Tab/Space is unavailable with this Mac's full-keyboard-access setting off; do not change that global setting.
The probe is method research, not acceptance evidence for Notch Pet.

Add opt-in control-layout metadata to the actual Settings views, guarded by a validated private temporary directory and dedicated test-suite prefix.
One verification owner records factory/I/O counts, native window state and control bounds, and sends events only to this process's windows.
Use actual native menu/keyboard routes (Settings command, sidebar navigation, Return/Escape) and real button events; do not call model install/uninstall
methods as a substitute for testing controls. Include pending-removal cancellation/confirmation with fictional Claude observations through the bundled helper.
Monitoring uses the private test endpoint; no Codex observation may trigger a real provider process or credential read.

Run one batched pass for all eight launch combinations, then install/remove/reinstall, retained preferences, explicit monitoring, pending notices, focus,
keyboard and recovery with the actual controls, followed by relaunch. Allow one correction/confirmation batch for observed defects; report remaining gaps.
Record window geometry/visibility and production resource selection, not screenshots or a claim of pixel-level appearance acceptance.
The normal app pays no layout-probe or runner work when the explicit test environment is absent.

Native-support budget: up to six app/support source files plus one script, at most fifteen new production/support members. Any additional packaging defect
that prevents resource isolation gets a separate bounded repair recorded before edits; preserve the existing resource/helper assertions.
After support is stable, run the full suite and packaged build once, then the native pass. Keep FM7 open for any missing required native evidence.

Packaging repair before the native pass: this Xcode toolchain emits resource bundles with `Contents/Resources`. Pet's generated accessor already searches
the app's resource directory, but `ProviderLogo.image` assumes a flat bundle. Add one structured-bundle regression to the existing logo tests and then
resolve the packaged resource bundle through Foundation if the regression fails. Budget: only ProviderLogo.swift and its existing test file, one new test,
no new production member, no assertion removed. Continue preserving missing/invalid-artwork text fallback and development-path isolation.

Packaging evidence, 2026-11-02: the new structured-bundle regression failed for both logos while the original flat/missing/invalid cases passed.
`ProviderLogo.image` now resolves the actual app-owned resource bundle via Foundation, supporting both layouts without a developer-path fallback.
After correcting optional-chain syntax, all five ProviderLogoTests passed, including the original assertions and new structured case.
Pet's generated resource accessor already searches `Bundle.main.resourceURL`; no speculative PetArtwork repair was made.

### Native-support implementation handoff

The feasibility probe completed and closed its own window/process. Its own-window mouse events execute SwiftUI buttons without captures or global
accessibility access; its Tab/Space check did not activate the button with full-keyboard-access off. Do not treat that probe as app acceptance.
Use public AppKit keyboard equivalents, sidebar/default-button/Cancel routes in the actual app and report any remaining required keyboard gap honestly.

Implement native support in bounded slices before final verification:

1. **Native command/window preparation:** at most three existing files (NotchPetApp, PetSettingsController, NotchPanelController), at most two new members.
   Add the standard Settings command, expose the owned Settings window internally for the check, and give the session panel a clear title.
2. **Actual-app runner and layout evidence:** six app/support files maximum (ServiceStartLedger, a same-type native-check extension, AppSettingsView,
   PetSettingsView, PetAppController and a control-frame preference/view modifier) plus one script; fifteen new support members maximum.
   Enable only with a validated `/private/tmp` directory and a dedicated `local.notchpet.features.native.` preference suite.
   Record only own control geometry/window state, feature factory counts and existing I/O counters. Send NSEvents to those owned windows and actual
   NSMenu/NSAlert controls; do not replace Install/Uninstall with model calls. Check eight launch combinations, all-feature removal/recovery,
   separate monitoring enablement, real pending-removal Cancel/Confirm, reinstall size preservation, keyboard/focus and relaunch.
3. **Private helper endpoint seam:** two files maximum (EventBridgeClient and NotchPetHook/main), one new helper API parameter and no new CLI option.
   HookHelper currently accepts only `--agent` and uses the standard endpoint. Add an injected endpoint parameter defaulting to `.standard`; main may
   select a private endpoint only for the same validated native-check directory/suite. Preserve silent bounded one-way delivery, input/identity/deadline
   checks and every existing assertion. The runner uses the actual bundled helper with fictional Claude `prompt_id` observations (not `turn_id`).
   Never start a real Codex quota process during native checks. Add at most two focused endpoint/unchanged-contract tests if needed.

Run the full suite and packaged build after these source seams stabilize, then one batched actual-app pass with at most one correction/confirmation batch.
Temporary probe: `/private/tmp/notch-pet-native-control-probe.swift`. Native results and scripts' runtime data remain outside the repository.

### Native evidence and remaining gap, 2026-11-02

Support is implemented in the recorded slices. The first isolated run timed out before the opt-in runner entered.
A bounded delegate trace proved normal launch reached the runner; a direct Foundation probe returned `/tmp` for `/private/tmp`.
Both app and helper now compare the canonical directory against the canonical temporary root, preserving the private-root/suite guards.
Temporary delegate/stage diagnostics were removed.

The next actual-app run produced `/private/tmp/np-features-native-pass2/matrix-0/result.json`:
no optional feature factories, zero agent I/O, nonactivating startup, no Pet/Notch windows and packaged logos passed.
It then failed `explicit Settings focus`. A single diagnostic reproduction at `/private/tmp/np-feature-focus-debug/matrix-0/`
logged `Settings action invoked` and `Settings visible=true key=false appActive=false`.
The action/menu route works; whether activation refusal is caused by synthetic input or product behavior is unresolved.
Apple's [activation contract](https://developer.apple.com/documentation/appkit/nsapplication/activate()) does not guarantee activation.
Do not force activation or weaken the assertion to turn that uncertainty into a pass.

FM7 remains incomplete: the batch stopped at matrix-0, so all-eight native combinations, native install/remove/reinstall, pending-removal controls,
Return/Escape, retained-size/relaunch and final focus acceptance are not proven. Unit/transition tests remain valid but do not replace them.
No capture, global settings/permissions change, real provider/configuration access or installed hook edit was used.

### Bounded focus correction, 2026-11-02

A disposable accessory-app window reproduced the same API refusal: `activate()` left `active=false, key=false` despite `canBecomeKey=true`;
`activate(ignoringOtherApps: true)` made that same window active and key. Probe: `/private/tmp/np-feature-activation-api-probe.swift`.
An isolated Launch Services comparison also failed the unchanged Settings focus assertion, ruling out direct-executable launch as the explanation.
Use the explicit activation API only inside the Settings controller's existing `activate` branch. Budget: one existing file/function, no new member;
startup and incoming session/surface paths remain nonactivating. This is a routine implementation choice for the approved explicit-focus contract.
Rebuild, then run the remaining bounded correction/confirmation batch with the original native assertions preserved.

The correction passed matrix-0's real Settings/focus check, then matrix-1 failed raw artwork-path containment.
Actual selected-path evidence at `/private/tmp/np-feature-resource-debug/matrix-1/result.json` proves `Bundle.main` uses `/private/tmp/...`
and its selected bundled PNG uses `/tmp/...`. Canonicalize both sides and retain strict app-directory containment (including the slash boundary).
No Pet loader or artwork change is needed. The native report now records selected resource URLs, owned-window geometry and its own PID.
On the user's continued execution instruction, finish one aggregate batch: preserve every case assertion and report all independent case failures
before the script's final assertion, avoiding repeated fail-fast batches. Budget: existing checker extension/script only, no new production member.

Aggregate result: nine of twelve cases passed; matrix-6 reported a startup focus mismatch, interaction did not execute last-feature removal,
and reopen consequently found the unchanged Pet-only selection. All failures remain in `/private/tmp/np-features-native-aggregate/summary.json`.
Continue a bounded diagnostic slice in the existing runner only: record before/after focus PIDs, own content bounds/flipping and control coordinates;
send the same real events and retain all assertions. Guard the root layout-preference callback so normal runs do no checker work.
Use one targeted interaction reproduction to identify the conversion error before changing it; do not replace UI actions with model calls.

The diagnostic found SwiftUI's split-view coordinates include the title/toolbar area while the hosting view's bounds exclude it.
Native sidebar/button frames differ by the same measured 52-point chrome height; named and global SwiftUI coordinates match.
Evidence: `/private/tmp/np-feature-view-frame-debug/interaction/app.log`. Convert the recorded top-left coordinate using the full window height,
with no hard-coded chrome offset. Retain actual mouse events and every behavioral assertion; remove temporary view-tree enumeration.
A separate startup diagnostic recorded focus changing from PID 4828 to 4827 while the tested app was PID 96273, so that run cannot prove unchanged
focus and is not treated as a pass or a confirmed app focus steal. Require a stable unchanged before/after observation in the remaining check.

The corrected point executed actual Pet removal and General selection, then native list tracking ignored the next direct-dispatched event.
Test the specific dispatch hypothesis by enqueueing the same window-number-bound NSEvents on this process's NSApplication event queue,
allowing native controls to use their ordinary tracking loop/current event. Do not post system-wide events or call settings model actions.
This changes only the existing click/key helpers; preserve all operation and navigation assertions.

With uninterrupted focus, local queued events executed the native removal, General/Features navigation, independent Notch/Agents installation and
monitoring switch. The next failure was the fixture: UserPromptSubmit incorrectly included tool-only fields, so the unchanged envelope validator
correctly rejected it and the later request lacked a confirmed turn. Limit tool fields to PermissionRequest and validate each fictional payload through
the real Claude adapter before invoking the bundled helper. Change only the existing runner fixture function; preserve the production wire contract.
Evidence: `/private/tmp/np-feature-quiet-interaction/interaction/` and HookEnvelopeV1's existing tool-hook validation.

Completion-audit addition within the same interaction function: while the fictional request is confirmed and Pet is absent, remove and reinstall Notch.
Require zero visible surfaces with monitoring/request continuity, then one Notch surface with the same single receiver start. This supplies direct native
evidence for Agents without either surface and for Notch lifetime independence. No new member, provider or action channel is introduced.

## FM1–FM6 commit checkpoint, 2026-11-02

The user deferred FM7 and authorized saving FM1–FM6 in separate commits. The goal remains paused and incomplete; no native test was launched for this checkpoint.
Shared wiring means these are dependency-based commits rather than one artificial commit per task:

- `7edb003`: feature catalog, versioned preferences and preference tests (FM1).
- `d9962db`: independent lifecycle primitives and monitoring-stopped semantics (FM2 foundation).
- `a6d9f62`: installation/removal state, monitoring consent and model tests (FM4–FM5 foundation).
- `6bf0133`: selected startup, independent service/surface lifetime, desktop placement and shared Settings UI (remaining FM2–FM5 integration).
- `1334165`: structured provider-logo bundle loading and regression (FM6 resource verification).
- Verification/records commit: runtime/generation tests, all 64 ordered transitions and this checkpoint (FM6).

Deferred FM7 files and shared-file probe hunks are excluded from those commits, preserving their working-tree contents for later review.
Unrelated editor/CI drafts are also excluded. The regular Settings menu/keyboard command and explicit-focus implementation belong to the finished app UI.

Verified the exact exported production/test tree `a8c4d6e81926549c34eb86a80094ac0f0d8d85a9`, without the FM7 checker:

```sh
env DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --package-path /private/tmp/np-feature-commit-check/source --scratch-path /private/tmp/np-feature-commit-check/build
env TMPDIR=/private/tmp/np-feature-commit-check/package DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer bash /private/tmp/np-feature-commit-check/source/scripts/run.sh --build-only
git diff --cached --check
git diff --check
```

The unit suite exited 0: 108 + 17 + 37 + 32 = 194 tests, zero unexpected failures, one existing UsageReceiverTests known issue retained.
The packaged build exited 0 and retained both helpers/resource bundles and the Info.plist check. Its temporary directory was created after an initial
`couldNotFindTmpDir` setup failure; no source repair was needed. Logs: `/private/tmp/np-feature-commit-check/tests.log` and `package-build.log`.
FM7 remains unchecked and deferred. No push or PR is authorized by this commit request.
