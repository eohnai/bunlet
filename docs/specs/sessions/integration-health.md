# Report integration health

Needs: observation-bridge

## Goal

Show, for each agent, separate evidence about version support, hook configuration, the helper, the receiver, and the last delivery.
A user can then tell "not set up" apart from "set up but quiet" without the app guessing.
Later setup controls (I6) use this evidence. See the [sessions area](area.md) for shared context.

This is a retrospective spec. It moves I2a–I2c and their evidence out of the [source specification](../notch-companion.md).
The I2 code exists, but its verification is incomplete. All three tasks stay unchecked.

## Done when

- For each agent, health reports agent-version support, managed-hook configuration, helper availability, receiver state, and last observed delivery as separate values.
  No single connected/disconnected flag combines them.
- A running receiver or a successful helper write is not reported as proof of end-to-end receipt.
  Delivery is reported only after an observation reaches the app.
- No recent event alone is not reported as a broken integration. An empty session list is not described as a disconnected agent.
- Delivery receipt times stay after session state becomes unknown or ended. They come from the inbox, not from current sessions.
- Version, configuration, and helper probes are read-only and bounded. They do not change configuration, invoke the helper, or expose file contents.
- Diagnostics include versions, bounded error categories, and receipt time. They include no prompts, tool input, transcripts, or credentials.
- The full Swift suite and the app build pass with the I2 code. The real app updates receiver and delivery evidence from actual bridge start, stop, and receipt.

## Out of scope

- Installing and removing hooks: `codex-setup` and `claude-setup` (I3–I5).
- Setup, check, and removal controls in the interface: I6 in the source spec.
- Health of the separate usage receiver. It is an open decision in [usage/claude-allowance](../usage/claude-allowance.md).
- Action-channel capability. Lifecycle hooks do not prove approval or reply support.
- Terminal navigation capability. Missing navigation is not a health failure, under [decision 0012](../../decisions/0012-support-terminal-independent-operation.md).

## Constraints

- Do not read or print credentials. Read only the bounded hook structure and the expected version shape.
- Do not run probes at startup or in the background. `refresh(agent:)` is an explicit action boundary.
- A probe result replaces only version, configuration, and helper values. It must not overwrite receiver or delivery evidence that arrived during the probe.
- Preserve existing Codex, Claude Code, and Otty configuration.

## Verify

- Seam: `IntegrationHealthController` in `Sources/NotchPet/NotchPetApp.swift`, fed by the bridge lifecycle and the inbox.
  The model and probe are in `Sources/SessionState/IntegrationHealth.swift`.
- Build: `bash scripts/run.sh --build-only`.
- Swift checks: `env DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --scratch-path /private/tmp/notch-pet-dev/build`.
  The ten I2 tests are in `Tests/SessionStateTests/IntegrationHealthTests.swift`.
- Real app: `bash scripts/run.sh`, then check receiver and delivery evidence with fictional helper events.

These are reproduction commands. This retrospective spec ran documentation checks only.

## Decisions

- [0002: Use services and shared stores](../../decisions/0002-use-mvvm-with-services.md).
- [0004: Receive events through agent hooks](../../decisions/0004-receive-agent-hook-events.md).
- [0011: Organize records by area and feature](../../decisions/0011-organize-records-by-feature.md).
- [0012: Support terminal-independent operation](../../decisions/0012-support-terminal-independent-operation.md).
- **Serialize independent fictional process cases, 2026-10-31.** The user approved suite serialization after the controlled comparison passed. Keep the two-second production timeout and all assertions. This avoids an execution-fixture/API redesign and accepts a longer suite duration; increasing the product timeout would change its intended deadline.

## My calls

- I2a–I2c move here, as the area file's `integration-health` entry describes. Their wording and unchecked states are unchanged.
- The older source-spec paragraph that says I2 "has not started" is marked superseded there. The I2 evidence below shows that the code exists.
- The retrospective migration added no tasks. I2c already includes the full suite, build, and checkpoint that the code still needs. The later I2d task records the separately approved probe-fixture scheduling repair.

## Open questions

- Later test runs passed with the I2 code. The source spec records 59 tests across seven suites. The paused goal log records 94 tests across 14 suites, at turn 21.
  These runs are not I2c's app-wiring acceptance. Review this evidence before you tick any I2 task.
- Turn 20 of the [paused goal log](../../goals/notch-agent-limits-log.md) records `IntegrationHealthTests:103` failing in full runs (`timedOut` instead of `unverified`).
  Turn 21 serialized the new fake-process suites and the full suite then passed. The exact OS cause is not established.

## Tasks

- [ ] I2a: Define independent integration-health evidence and classification for both providers; verify five model tests. Implementation written; verification deferred at the user's request.
- [ ] I2b: Add bounded read-only version, hook-configuration and helper checks; verify five isolated probe tests without changing configuration. Implementation written; verification deferred at the user's request.
- [ ] I2c: Feed actual receiver lifecycle and recorded delivery times into health independently of session state; verify the full suite/build and checkpoint I2 completion. Implementation written; verification deferred at the user's request.
- [x] I2d: Serialize the independent fictional process cases in IntegrationHealthProbeTests without changing assertions or the production timeout; verify the isolated probe suite and the complete coverage-enabled Swift suite.

## Historical evidence

The following records are copied from the [source specification](../notch-companion.md#i2-implementation-with-verification-deferred-2026-10-28).
Only relative link paths changed. They were not rerun for this spec.
The source spec also keeps them.

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

## Probe timeout diagnosis, 2026-10-31

The user authorized a separate diagnosis after the ci-foundation F1 baseline failed.
No repository source or test code changed during this diagnosis. Production behavior remains unmodified.

### Reproduction and isolation

The original coverage-enabled full suite failed with 132 tests in 24 suites and four issues.
Both provider cases of `versionProbeBoundsItsProcessAndOutput(agent:)` and
`diagnosticsDiscardUnrelatedFictionalValues(agent:)` returned `.unavailable(.timedOut)` unexpectedly.

```bash
env DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --scratch-path /private/tmp/notch-pet-dev/build --enable-code-coverage
env DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --scratch-path /private/tmp/notch-pet-dev/build --enable-code-coverage --filter IntegrationHealthProbeTests
```

The isolated command exited 0: five tests in one suite, 5.055 seconds.
This does not erase the full-suite failure.
Git shows no uncommitted changes to the probe, its tests or Package.swift.
The probe implementation and tests originate in `5b0aa5e`.

### Boundary measurements

A temporary copy of committed source was extracted with `git archive HEAD` under
`/private/tmp/notch-pet-ci/diagnosis/source`.
Only its probe was instrumented with elapsed launch, first-read and exit-loop measurements.
Fictional executable bodies, credentials and real agent data were not logged.

```bash
env DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --package-path /private/tmp/notch-pet-ci/diagnosis/source --scratch-path /private/tmp/notch-pet-ci/diagnosis/full-build --enable-code-coverage
```

The temporary full suite reproduced four issues in the same two parameterized tests.
`Process.run()` returned in 0–1 ms.
Three unexpected timeout traces reached 2000 ms with no output and a running child.
Another received its first output at 1966 ms, then reached the deadline while observing exit.
The evidence locates the delay before output or exit, rather than in version parsing.
It does not identify which macOS subsystem causes the execution delay.

A separate four-case comparison changed only the invocation form for equivalent fictional scripts:

| Invocation | First output | Result |
|---|---|---|
| Execute each new shebang script directly | 228–1024 ms | 4/4 reported the expected version |
| Execute `/bin/sh` with each script path | 5–6 ms | 4/4 reported the expected version |

These diagnostic invocation changes are outside the repository and are not a proposed product change.
The measurements support concurrent fresh-script execution as the source of deadline pressure.
Attributing that delay to a particular OS security service remains unproven.

### Proposed repair experiment

The temporary source copy then added only `@Suite(.serialized)` to `IntegrationHealthProbeTests`.
The diagnostic instrumentation remained identical to the failing comparison.
All test bodies, assertions and the production two-second timeout remained unchanged.
The same full-suite command exited 0: 132 tests in 24 suites, 10.694 seconds.
The failing instrumented run took 8.365 seconds.
This is one successful controlled comparison, not proof of reliability on every runner.

The user approved this separate repair task and resuming CI after it passes:

1. Add the suite trait and a short reason comment in `Tests/SessionStateTests/IntegrationHealthTests.swift`.
2. Record the scheduling choice and verification evidence here, in STATUS and in the CI goal log.
3. Run the isolated probe command above, then the original coverage-enabled full-suite command.
   Both must exit 0. The full run must report 132 tests and zero issues.
4. If verified, prepare a separate repair commit and resume ci-foundation F1.

The approved repair adds no API, production timeout change, assertion removal or test exclusion.
No new test is needed: the existing failing cases exercise the actual process boundary.
The original failure remains the regression evidence.
The I2 acceptance checkboxes stay open because this task does not establish app wiring or GUI acceptance.

### Repository repair verification

Applied the suite trait and reason comment to the repository after the user approved the task list.
No other test or product code changed.
The isolated probe command exited 0: five tests in one suite, 6.045 seconds.
The original full coverage-enabled command exited 0: 132 tests in 24 suites, 6.319 seconds, zero issues.
Logs: `/private/tmp/notch-pet-ci/reports/repair-probe-suite.log` and
`/private/tmp/notch-pet-ci/reports/repair-full-suite.log`.
I2d is verified. I2a–I2c remain open for their separate acceptance requirements.

### Evidence paths

All logs and diagnostic code remain outside the repository:

- `/private/tmp/notch-pet-ci/reports/f1-swift-test.log`
- `/private/tmp/notch-pet-ci/reports/diagnosis-probe-suite.log`
- `/private/tmp/notch-pet-ci/reports/diagnosis-full-trace.log`
- `/private/tmp/notch-pet-ci/reports/diagnosis-full-serialized.log`
- `/private/tmp/notch-pet-ci/reports/diagnosis-invocation-shebang.log`
- `/private/tmp/notch-pet-ci/reports/diagnosis-invocation-direct-shell.log`
- `/private/tmp/notch-pet-ci/diagnosis/IntegrationHealthTrace.swift`
- `/private/tmp/notch-pet-ci/diagnosis/IntegrationHealthInvocationTrace.swift`
- `/private/tmp/notch-pet-ci/diagnosis/Main.swift`
