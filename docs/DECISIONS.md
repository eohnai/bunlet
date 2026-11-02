# Decisions

Earlier accepted decisions remain in [decisions/](decisions/0013-separate-standalone-pet-scope.md). No records are moved.

## D1: Make low idle energy use a release requirement

- Status: accepted
- Date: 2026-10-30

**Context.** The user wants telemetry and companion features to remain practical on an M2 MacBook Air with 16 GB RAM.
They requested battery-efficient operation after discussing a native UI and a local collector.

**Options.**
- **Event-driven native components with bounded work:** minimize idle activity; require lifecycle coordination and profiling.
- **Frequent polling and continuously updated surfaces:** simpler periodic updates; cause unnecessary work while idle.

**Decision.** Require low idle activity, bounded storage and memory, paused unnecessary rendering, and adaptive provider refresh.
Measure the actual app and any collector or child processes on the target Mac before claiming efficiency.

**Reasoning.** The user explicitly prioritizes battery and resource efficiency for their existing Mac.

**Consequences.** [Resource efficiency](specs/notch/resource-efficiency.md) defines proposed implementation tasks and initial measurement targets.
The user wants collection to continue when the interface closes. Collector installation, persistence, lifecycle, and IPC need a separate reviewed design.
This decision does not install a service, add a database, change the hook contract, or supersede existing storage and pet decisions.

## D2: Collect and inspect telemetry locally with an optional background process

- Status: accepted
- Date: 2026-10-30

**Context.** The user confirmed a telemetry plan separate from battery work, including collection while the interface is closed.
They confirmed local-only history and the next-task, debug-issue, and checkpoint pilots.

**Options.**
- **App-owned collection and file-only state:** one process and simple lifecycle; loses collection when the interface quits and lacks history queries.
- **Optional collector with local SQLite history:** works without the interface and supports queries; adds IPC, lifecycle, migrations, and retention.
- **Hosted telemetry or separate projects:** can support sharing and independent releases; adds infrastructure and coordination outside the confirmed scope.

**Decision.** Use one native app and one optional local collector in the notch-pet repository and release.
Add bounded, deduplicated local SQLite history and instrument the three pilots in agent-skills.
Usage refresh and interactive actions retain their existing owners. Keep the pet independent and require no collector for pet-only use.

**Reasoning.** The user wants useful skill history when the interface is closed, with low battery cost on their M2 Air.
They confirmed this first-release scope instead of hosted ingestion or cross-device synchronization.

**Consequences.** The [telemetry area](specs/telemetry/area.md) defines three feature specs with proposed task lists.
This updates decision 0013's app-owned service boundary for telemetry and decision 0003's no-database scope for history only.
Their independent pet, preferences/assets, and fresh live-evidence requirements remain intact. Earlier implementation evidence is not rewritten.
D1's measured resource requirements apply to every new process. Exact registration, IPC, schemas, and limits receive task-level review.
This accepts scope and storage direction, not implementation tasks, service installation, hook edits, or goal resumption.

## D3: Add view models only where a view owns state

- Status: accepted (its `ObservableObject` line is replaced by D4)
- Date: 2026-10-30

**Context.** Decision 0002 and `ARCHITECTURE.md` describe MVVM, but the code has no view models.
Read-only views observe stores directly. Pure functions such as `NotchPresentation` and `PetPresentation` prepare their state.
`AgentUsageController` and `PetSettingsController` already publish status and handle actions.
The [2026-10-30 review](reports/2026-10-30-session-state-and-architecture-review.md) (M4) raised the mismatch.

**Options.**
- **A view model for every view:** one uniform structure; most would pass store properties through, and cached derived state can become a stale copy of session truth.
- **No view models:** least code now; async action state would move into views or AppKit controllers once Codex setup actions and Settings arrive.
- **View models only where a view owns state:** read-only views stay thin and testable through pure functions; needs a stated rule for when to add one.

**Decision.** Read-only views observe stores directly and use pure presentation functions.
A view gets a view model when it owns state the store does not hold: actions with async results, in-progress flags, drafts, or validation.
Use `ObservableObject`, because `@Observable` needs macOS 14 and the package targets macOS 13.

**Reasoning.** The user accepted this on 2026-10-30. Pure functions already do the view-model job for read-only views and are easier to test.
The views that need action state either already have a controller for it or are still planned.

**Consequences.** This updates the view-model consequence of decision 0002. Services, shared stores, and explicit dependencies remain as accepted.
Codex setup menu actions (I6a), the Settings window, and the reply composer are expected to get view models.
Existing `…Controller` types that act as view models keep their names until a task touches them.
Revisit if read-only views start to duplicate derivation logic, or when the deployment target reaches macOS 14.

## D4: Target macOS 14 so stores and controllers can use `@Observable`

- Status: accepted
- Date: 2026-10-31

**Context.** The package targeted macOS 13, and no record explains why.
D3 kept `ObservableObject` because `@Observable` needs macOS 14.
The R1 review of two external Swift skills found that both assume `@Observable`. `docs/SWIFT-PRACTICES.md` adopts it as the rule.

**Options.**
- **Stay on macOS 13 with `ObservableObject`:** supports one more macOS release, but the practices guide and both skills would describe a model the code cannot use.
- **Raise the target to macOS 14 and move to `@Observable`:** code matches the practices guide; drops macOS 13 users and replaces APIs deprecated in macOS 14.

**Decision.** Target macOS 14 in `Package.swift` and `Info.plist`. Move the five `ObservableObject` classes to `@Observable` in codex-setup R8.
This replaces D3's `ObservableObject` line. The rest of D3 stands.

**Reasoning.** The user chose this on 2026-10-31, so the code can follow the practices guide and the Swift skills it is reviewed against.
The development Mac runs macOS 26, and no record names a macOS 13 user. ^[inferred]

**Consequences.** R7 replaced two `onChange(of:perform:)` calls and `activate(ignoringOtherApps:)` with their macOS 14 forms.
`activate()` asks for focus instead of forcing it. Pet Settings opens from a menu click, so it should still come to the front, but this is unverified in the running app.
R8 can now move the stores and controllers to `@Observable`. Revisit if a supported user needs macOS 13.

## D5: Observe stores from controllers with `withObservationTracking`

- Status: accepted
- Date: 2026-10-31

**Context.** R8 moves stores and controllers to `@Observable`, which has no Combine publisher.
`AgentUsageController` subscribed to `SessionStore.$sessions` to start and stop Codex usage polling, and one store test counted publications through `$sessions`.

**Options.**
- **`withObservationTracking`, wrapped in one helper:** no store API change and no behavior change; the one-shot callback must be re-armed, and Swift 6 needs a main-actor hop that delays the reaction by one turn.
- **A stream or callback on `SessionStore`:** exact values in order; adds public API and a second observation path to a module R2 is about to split.
- **`.task(id:)` in the view:** least code; polling would follow what is on screen instead of whether a Codex session is active.
- **`Observations`:** Apple's async sequence without re-arming; the SDK marks it macOS 26, above the D4 target.

**Decision.** Controllers observe stores with `withObservationTracking`. `ObservationLoop` in the app target holds the re-arm logic, so it is written and tested once.

**Reasoning.** The user chose this on 2026-10-31 as Apple's documented way to observe `@Observable` outside SwiftUI on macOS 14.
It is the only option that changes neither behavior nor the store's public API.

**Consequences.** Observers see only the final value of each main-actor turn, so tests can no longer count assignments within one call.
The user accepted replacing the store's publication-count check with a check of the first value observers read.
Revisit when the target reaches macOS 26, where `Observations` can replace `ObservationLoop`.

## D6: Show allowance as percent left, not percent used

- Status: accepted
- Date: 2026-10-31

**Context.** The usage area and [codex-allowance](specs/usage/codex-allowance.md) label allowance percentages as used, copied from the source spec approved on 2026-10-29.
The notch layout reference the user supplied on 2026-10-31 shows a compact allowance strip, planned in [allowance-strip](specs/notch/allowance-strip.md).

**Options.**
- **Percent used:** matches the providers' reported `usedPercent`; the reader must subtract to see what remains.
- **Percent left (`100 − used`):** shows directly how much work remains before the limit; the app derives the number instead of showing the reported one.

**Decision.** The notch shows percent left for both Codex and Claude Code. The usage store keeps the reported used value unchanged.

**Reasoning.** The user chose percent left on 2026-10-31 while answering layout questions.
It shows what remains before the limit without arithmetic. ^[inferred]

**Consequences.** codex-allowance's "Percentages are labelled used" check is replaced for the notch. Its other U5 checks stand.
Percent left is rounded down, so the notch never shows more allowance than is reported.

## D7: Install and uninstall features from Settings

- Status: accepted
- Date: 2026-11-02

**Context.** The user prefers Vorssaint's modular feature selection. They want Pet without Notch,
and want people who do not use agent features to leave those features uninstalled.
After distinguishing a feature hub from separate downloads, the user chose installing and uninstalling features in Settings.

**Options.**
- **One app with installable features in Settings:** one release; feature availability owns surfaces and service lifecycle.
- **Separate pet-only download:** a smaller dedicated distribution; adds packaging and update paths.
- **Presentation switches alone:** can hide controls while leaving their services available; insufficient for the requested feature removal.

**Decision.** Retain one native app and let users install/uninstall Pet, Notch and Agents through Settings.
Pet must work without Notch or Agents. An uninstalled feature disappears from ordinary feature navigation and starts no owned work;
its entry remains available in the feature manager for reinstallation. Preserve preferences for reinstall.

**Reasoning.** The user explicitly chose in-app feature installation so people can keep only the functionality they want.

**Consequences.** This extends decision 0013's independent pet and optional services into a user-visible feature lifecycle.
“Installed,” “enabled,” “connected” and “healthy” remain distinct. Installing Agents does not automatically authorize hook edits;
provider Connect/setup retains its reviewed contract. Uninstall must stop owned tasks and surfaces, preserve unrelated configuration,
and handle pending notices without inventing completion. Loaded code may remain resident until restart; separate downloadable binaries
are not required by this decision. Dependency/removal rules, standalone desktop pet placement and bounded implementation tasks need planning.
This records product behavior, not implementation approval, a new goal, resumed acceptance or a claim that current packaging implements it.

## D8: Exclude VoiceOver testing from feature acceptance

- Status: accepted
- Date: 2026-11-02

**Context.** The initial modular-feature plan included VoiceOver acceptance, then proposed deferring it.
The user explicitly instructed: “skip voiceover. remove voiceover for all features. then continue”.

**Options.** Require a screen-reader pass, defer it as mandatory follow-up, or exclude it from feature acceptance.

**Decision.** Exclude VoiceOver/screen-reader testing from every feature's required work and completion gates.
Retain ordinary native labels, keyboard controls, Reduce Motion and focus behavior. Do not claim excluded checks passed.

**Reasoning.** The user explicitly selected this scope and asked to continue the modular-feature work.

**Consequences.** Update active specifications, goal requirements and blockers. Historical evidence remains historical;
an old unperformed VoiceOver check is no longer a pending acceptance requirement. This does not remove native controls or their labels,
authorize captures or global permission changes, or complete unrelated keyboard/focus acceptance.
