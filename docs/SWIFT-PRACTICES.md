# Swift practices

Follow these rules when you write or review Swift code in this repository.
Each rule gives an example that follows it, or the task that will make the code follow it.
A rule marked **Not yet** describes the target. Do not copy the code that breaks it.

Sources: the [2026-10-30 review](reports/2026-10-30-session-state-and-architecture-review.md), [D3](DECISIONS.md#d3-add-view-models-only-where-a-view-owns-state),
and rules adapted from two MIT-licensed agent skills, [swift-architecture-skill](https://github.com/efremidze/swift-architecture-skill) and [swift-patterns-skill](https://github.com/efremidze/swift-patterns-skill).
Those skills assume iOS 17, MVVM, and XCTest. This project uses none of those, so only the rules below apply.

## Structure

- Stores own shared state. Mark them `@MainActor` and publish `Equatable`, `Sendable` value snapshots.
  Example: `SessionStore` publishes `SessionSnapshot`.
- Put domain rules in pure functions or static enums, with no AppKit and no I/O, so tests can reach them.
  Example: `NotchPresentation`, `NotchPlacement`, `PetPlaybackPolicy`.
- AppKit controllers own windows, and actions that have their own state.
  Example: `NotchPanelController`, `PetSettingsController`.
- Add a view model only where a view owns state ([D3](DECISIONS.md#d3-add-view-models-only-where-a-view-owns-state)). Read-only views observe stores directly.
- Give each module one concern.
  **Not yet:** `SessionState` holds sessions, usage, and integration health. R2 splits it.
- Write each rule once.
  **Not yet:** the executable search exists twice with different fallbacks (review M2, fixed by R2). Other copies are listed in review L1.
- Keep verification instrumentation in one type with one entry point.
  **Not yet:** it is spread over `ServiceStartLedger`, `PetPanelController`, and `PetAppController`. R5 collects it.
- Add no package dependency without a recorded decision. The package has none.

## State and observation

- Use `@Observable` for stores and controllers ([D4](DECISIONS.md#d4-target-macos-14-so-stores-and-controllers-can-use-observable)).
  Example: `SessionStore`, `AgentUsageController`.
- Observe a store from a controller with `ObservationLoop`, not a hand-written `withObservationTracking` call ([D5](DECISIONS.md#d5-observe-stores-from-controllers-with-withobservationtracking)).
  Example: `AgentUsageController.start()`.
- Mark `@State` as `private`. Never declare a value passed in by the parent as `@State`, because `@State` keeps only the first value.
- Keep one source of truth. Compute derived values instead of storing a copy that must be kept in step.

## Views

- Keep `body` free of side effects. Start async work that belongs to a view's lifetime with `.task(id:)`, which cancels and restarts it when the id changes.
  Example: `PetView` drives playback with `.task(id:)`.
- Give `ForEach` a stable identity from the data. Never use indices for data that can change.

## Concurrency

- Change interface state only on the main actor.
- Keep one task handle for each repeatable action. Cancel the old task before you start a new one, and capture `self` weakly.
  Example: `AgentUsageController.start()`.
- Treat `CancellationError` as a normal exit, not a failure. Do not show it to the user.
- When an owner stops, cancel its tasks and drop its queued work.
  **Not yet:** after `AgentServices.stop()`, a batch already queued in the inbox can still reach the store (review L2).

## Input and errors

- Bound every external input with a named constant.
- Report failures as small enums. Never include raw content, such as configuration, commands, or event text, in messages, logs, or diagnostics.
- Keep agent and hook identity typed. Decode wire strings once, at the boundary.
  **Not yet:** agent and hook names are plain strings in several modules. R3 adds `Agent` and `HookEvent`.

## Code style

- Use no force unwraps outside tests. Use `guard let` and return a bounded result instead.
  **Not yet:** eight remain, in `SessionStore`, `EventBridgeServer`, `HookEnvelopeV1`, `SocketSupport`, and `CodexUsageConnection`.
  R3 removes the ones that typed hook events make unnecessary (review M7). Remove the others when you next change their code.
- Write one statement per line.
  **Not yet:** see review L5 for the known exceptions.
- Comment the reason for a rule, not what the code does.
- Use toolchain swift-format and selected SwiftLint rules under [0015](decisions/0015-adopt-swift-format-and-selected-swiftlint-rules.md).
  **Not yet:** neither tool is configured. automation/quality-gates owns rule review and a separate formatting migration.
  Keep existing code style until that task is approved. CI checks must not change source files.

## Tests

- Use Swift Testing, not XCTest. Use parameterized tests for per-agent cases.
  Example: `CodexEventAdapterTests`, `SessionStoreTests`.
- Use fictional data only. Never use real sessions, configuration, or credentials.
- For each repeatable async action, test success, failure, and cancellation or a stale result.

## Not used now

- No architecture framework such as TCA. It would add the package's first dependency for little gain at this size.
