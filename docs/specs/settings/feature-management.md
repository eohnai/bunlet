# Install and uninstall optional features

Status: proposed

## Goal

Let people keep only the parts they use in one native app: Desktop Pet, Notch and Agents.
Pet works without either other feature. Settings owns feature availability; each feature retains its own behavior and services.
The user approved planning and publishing this specification on 2026-11-02. Its implementation task list remains proposed.
FM1–FM7 are linked by the prepared [modular-features goal](../../goals/modular-features.md).
The goal is not activated; preparing it does not approve implementation or resume any older goal.

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
Full VoiceOver screen-reader acceptance is proposed as follow-up accessibility work, outside this first modular-feature milestone.
Retain meaningful control labels, keyboard access, Reduce Motion and focus behavior here; a deferred VoiceOver check is not a passed check.

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

These choices make D7 implementable. They are proposals, not additional accepted decisions.

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

## Tasks proposed for approval

No task is approved for implementation by approving this planning work. Keep these tasks separate from existing source checkboxes.

- [ ] FM1: Add the pure feature catalog and versioned availability preferences, including fresh defaults, legacy opt-in migration and recovery for invalid records. No app wiring or I/O beyond isolated preferences. First reviewable implementation slice.
- [ ] FM2: Separate app-owned agent/usage lifetime from the Notch controller; add independent surface ownership and stop-generation guards. Verify that callbacks from stopped instances cannot reach the current store. Preserve the existing shared session authority.
- [ ] FM3: Wire selected-feature startup and minimal independent pet placement, menu/Features recovery, and absent-feature factories. Coordinate the placement change with Pets without adding full drag/Spaces recovery scope.
- [ ] FM4: Integrate the native Settings shell and three Features rows with catalog-driven navigation, operation states and Install actions. Review the settings-window task list first; reuse pet controls rather than duplicating the window.
- [ ] FM5: Implement Uninstall/Reinstall coordination with immediate teardown, retained preferences, pending-notice semantics and explicit provider reconnection/cleanup handling. Review partial failure and owned-hook behavior before coding this slice.
- [ ] FM6: Verify the eight combinations and transitions using fictional sessions and isolated preferences/factories, including all features absent, repeated operations, relaunch migration and late callbacks. Add only meaningful contract checks, then run the appropriate existing suites/build.
- [ ] FM7: Perform one approved native acceptance pass covering Features keyboard access and clear control labels, pet-only placement, absent surfaces, saved preferences, focus and recovery. Defer a full VoiceOver pass to accessibility follow-up; do not claim screen-reader acceptance. No captures or installed-provider edits unless separately authorized. Preserve unrelated deferred pet/notch acceptance.

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

The user requested FM1 planning, not implementation. Approval of FM1 alone would cover this focused run only.
Approval to start the umbrella goal can cover FM1–FM7 and the goal's specified verification together; later slices still need their bounded plans recorded
before edits. Neither kind of approval authorizes captures, installed-provider changes, additional dependencies or unrelated cleanup.

## Decisions and questions

- Accepted: [D7](../../DECISIONS.md#d7-install-and-uninstall-features-from-settings), [0013](../../decisions/0013-separate-standalone-pet-scope.md),
  [terminal independence](../../decisions/0012-support-terminal-independent-operation.md), and [native UI](../../decisions/0001-use-swiftui-and-appkit.md).
- Proposed: the eight-combination semantics, availability migration, zero-feature recovery, placement default, lifecycle generation boundary
  and partial-removal behavior above. Confirm these with the task list before implementation.
- Proposed scope refinement, 2026-11-02: after the user questioned whether VoiceOver testing was necessary, defer that full screen-reader pass
  from the initial goal while retaining keyboard access, labels, focus and existing accessibility requirements. This does not complete deferred accessibility acceptance.
- Confirm the desktop pet's first position while Notch is absent. A safe visible desktop default is sufficient for FM3; persistent dragging stays with Pets.
- Confirm whether the proposed calm Notch-without-Agents state is useful enough to ship, or should be labelled as awaiting optional monitoring.
- Resolve a future owned-hook cleanup failure's displayed state before FM5. Feature removal cannot bypass codex-setup qualification or ownership checks.
- No owner or deadline was supplied. No new goal is created.
