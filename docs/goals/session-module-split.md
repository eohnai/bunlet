# Session module split

Status: done on 2026-11-04.
Prepared and activated on 2026-11-03. The user instructed: "start the goal".
Activation approves the R2a/R2b task list, locator interface, retained stack and specified Swift checks.
It does not authorize unrelated runtime acceptance or configuration changes.
The initial baseline failed on 2026-11-03. On 2026-11-04 the user approved investigating the compiler crash and then resuming R2.
A reduced reproduction isolated the direct main-actor method reference in the Monitoring binding. An explicit closure compiles.
The repaired baseline passes 194 tests in 31 suites with one existing known issue.

```text
GOAL: Complete R2a and R2b: separate session, usage and integration modules and extract path lookup without changing behavior.

ENTRY: Read AGENTS.md, docs/STATUS.md, docs/SWIFT-PRACTICES.md, docs/specs/sessions/codex-setup.md and docs/goals/session-module-split.md. Activating this block approves its R2a/R2b plan, checklist split and tests only. Stay on feat/sessions-codex-setup with its existing c760308 stack. Prerequisite acceptance stays open.

DONE WHEN all hold, with current command output and exit codes printed:
1. `env DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift package describe --type json` shows Integration with no target dependencies, Usage depending on Integration, SessionState depending on EventBridge and Integration, and NotchPet directly depending on Pet/EventBridge/SessionState/Usage/Integration. Matching UsageTests and IntegrationTests targets exist. `rg --files Sources/SessionState Sources/Usage Sources/Integration Tests/UsageTests Tests/IntegrationTests` shows eight usage source/test pairs and the health pair relocated; AgentPathLocator source/test added. Sessions stay in SessionState.
2. The full suite command below reports eight new AgentPathLocatorTests passing: missing PATH fallbacks; empty PATH; absolute candidate order; 64-component limit including empty-component differences; 16384-byte PATH bound; usage-only fallback directories; nil/empty configuration overrides; absolute 4096-byte override bound with no fallback for invalid nonempty overrides. Cover both agents where applicable. Preserve existing health/usage search differences, status messages and configuration filenames.
3. `env DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --scratch-path /private/tmp/notch-pet-dev/build` exits 0 after both tasks, with zero failures, all original cases retained and a test count at least the baseline count plus eight. Record the baseline before edits. Only fictional fixtures/processes in tests.
4. `git diff --check` exits 0. `bash /Users/ianhoe/.agents/skills/progress/scripts/progress.sh` reports verified R2a and R2b complete. Print a diff review: no search loops in app callers; no unrelated task completion.

EVERY TURN: run the check commands; print outputs/exits and each criterion status. Append a numbered timestamped row to docs/goals/session-module-split-log.md. Continue numbering; use current evidence only.

CONSTRAINTS:
- Only change Package.swift; Sources/{SessionState,Usage,Integration,NotchPet}/; Tests/{SessionStateTests,UsageTests,IntegrationTests,NotchPetTests}/; docs/ARCHITECTURE.md; docs/SWIFT-PRACTICES.md; docs/specs/{sessions,usage}/area.md; docs/specs/sessions/{codex-setup,integration-health}.md; docs/STATUS.md; these two goal files.
- Do R2a then R2b. Retain IntegrationAgent in Integration until R3. Existing APIs keep signatures. Locator accepts explicit inputs and an injectable executable predicate; separate health/usage policies retain current behavior. Environment reads stay at app boundaries and use only PATH/CODEX_HOME/CLAUDE_CONFIG_DIR.
- Existing tests may only move or change imports. Freeze eight new locator tests before implementing the locator. Never weaken/delete assertions, skip cases, modify check scripts or lower this rubric.
- No R3/R5/installer work, external dependencies, commits, pushes, PRs, app launches, captures, installed-provider probes/configuration edits or credential reads. Keep fixtures/build/runtime data outside the repo. Do not resume paused goals.

STOP AND REPORT: 30 turns; same failure on three consecutive turns; missing access or an unapproved design/scope change. Baseline compiler diagnosis/repair is authorized by the user on 2026-11-04; other unrelated fixes need review.

ON FINISH OR STOP: set log Status to done/stopped/blocked and fill Final result; use checkpoint; tick only verified tasks; report proof and gaps; give explicit-path git add and Conventional Commit commands for the user. Never run them.
```

## Context to read

- `AGENTS.md`, `docs/STATUS.md`, `docs/SWIFT-PRACTICES.md`.
- `docs/specs/sessions/codex-setup.md`, including its prerequisite limits.
- `docs/reports/2026-10-30-session-state-and-architecture-review.md`, H2/M1/M2 and its accepted outcome.
- Decisions 0002 and 0011, plus D3–D5 in `docs/DECISIONS.md`.
- `Package.swift`, `Sources/SessionState/`, `Sources/NotchPet/NotchPetApp.swift`, and `Sources/NotchPet/AgentUsageController.swift`.

## Approved task list

Activation replaces the existing R2 checkbox with these two checkboxes. Preserve its original wording in an explanatory note.
Do not change other task states. The original R2 is complete only when both parts pass.

- [x] R2a: Split SessionState into SessionState, Usage and Integration targets; move existing source/tests and update imports, dependencies and ownership notes; preserve behavior and pass the full suite.
- [x] R2b: Extract executable and configuration-directory lookup into Integration with explicit health/usage policies; preserve existing behavior, pass eight new locator checks and the full suite.

Use the existing branch `feat/sessions-codex-setup`. It contains R4 at `6d7b87e` above modular-feature baseline `c760308`.
Retaining this stack does not close integration-health/session-island prerequisites or establish that PR #15 has merged.
Do not fetch, switch branches, merge or restore deferred work as part of this goal.

### R2a: target extraction

1. Run the baseline full suite and record its count. The user authorized diagnosing and repairing the compiler crash on 2026-11-04. This supersedes the original stop-at-baseline rule for that crash only.
2. Move existing tests and change their imports first. Confirm compilation fails until the source targets exist.
3. Move the matching sources, update the package graph and imports, then run the full suite.
4. Update current ownership descriptions. Keep historical evidence and old verification paths explicitly historical.

Move these eight files from `Sources/SessionState/` to `Sources/Usage/`:

- `UsageStore.swift`
- `CodexUsageProvider.swift`
- `ClaudeUsageProvider.swift`
- `CodexUsageProtocol.swift`
- `CodexUsageConnection.swift`
- `UsageDelivery.swift`
- `UsageReceiver.swift`
- `NotchAllowancePresentation.swift`

Move their same-named `*Tests.swift` files from `Tests/SessionStateTests/` to `Tests/UsageTests/`.
Move `IntegrationHealth.swift` and `IntegrationHealthTests.swift` into `Sources/Integration/` and `Tests/IntegrationTests/`.
Keep `IntegrationAgent` in the moved health file. R3 owns typed identity changes.
`SessionState/NotchPresentation.swift` and affected tests import `Integration` for the existing provider enum.

Update imports in these app files as needed, with no other implementation edits during R2a:

- `AgentUsageController.swift`
- `AppSettingsView.swift`
- `NotchAllowanceStrip.swift`
- `NotchPanelController.swift`
- `NotchPetApp.swift`
- `NotchSessionView.swift`
- `PetAppController.swift`
- `PetSettingsController.swift`
- `ProviderLogo.swift`

Update `Tests/NotchPetTests/ProviderLogoTests.swift` and `Tests/SessionStateTests/NotchSelectionTests.swift` imports as needed.
Declare direct test dependencies where a test imports a module. Do not rely on transitive imports or add compatibility re-exports.
Update `docs/ARCHITECTURE.md`, current module ownership in the sessions/usage area files, the relevant practices rule,
and current verification paths in integration-health. Preserve historical paths/results as historical.
Do not reconcile unrelated stale records.

Package sketch:

```swift
.target(name: "Integration"),
.target(name: "Usage", dependencies: ["Integration"]),
.target(name: "SessionState", dependencies: ["EventBridge", "Integration"]),
.executableTarget(
    name: "NotchPet",
    dependencies: ["Pet", "EventBridge", "SessionState", "Usage", "Integration"],
    resources: [.process("Resources")]
)
```

Existing public names and function signatures stay unchanged. A caller adds imports:

```swift
import Integration
import Usage

let store = UsageStore()
let providers: Set<IntegrationAgent> = [.codex]
let snapshots = store.snapshots(activeProviders: providers, nowMs: 1_000)
```

### R2b: shared lookup with explicit policies

Create `Sources/Integration/AgentPathLocator.swift` and `Tests/IntegrationTests/AgentPathLocatorTests.swift`.
Use this interface sketch. Empty bodies show signatures, not valid production implementations.

```swift
public enum AgentPathLocator {
    public enum ExecutablePolicy: Sendable {
        case health
        case usage
    }

    public enum ExecutableLookup: Equatable, Sendable {
        case found(URL)
        case notFound
        case invalidSearchPath
    }

    public static func executable(
        agent: IntegrationAgent,
        policy: ExecutablePolicy,
        searchPath: String?,
        homeDirectory: URL,
        isExecutable: (String) -> Bool = {
            FileManager.default.isExecutableFile(atPath: $0)
        }
    ) -> ExecutableLookup { }

    public static func configurationDirectory(
        agent: IntegrationAgent,
        override: String?,
        homeDirectory: URL
    ) -> URL? { }
}
```

Caller sketch:

```swift
let executable = AgentPathLocator.executable(
    agent: .codex,
    policy: .usage,
    searchPath: path,
    homeDirectory: FileManager.default.homeDirectoryForCurrentUser
)
switch executable {
case .found(let url):
    // Existing CodexUsageConnection.read caller uses url.
    break
case .notFound:
    status = "Codex executable unavailable."
case .invalidSearchPath:
    status = "Executable search path unavailable."
}
```

Health maps either unavailable result to its existing nil executable input.
Keep helper discovery and configuration filenames in the app caller.
The locator computes paths and tests executability through its predicate. It does not read configuration or launch processes.
Environment reads remain in the app. Tests supply explicit fictional values and predicates.

The accepted call preserves distinct policies because the task requires no behavior change.
Unifying user-visible search rules was considered and deferred. It would require a separate behavior decision.
The user approved this implementation choice by activating the goal. It changes no product behavior.

Freeze eight named test functions before implementing the locator:

| Test | Required evidence |
|---|---|
| missingPathUsesPolicyFallbacks | Health: /usr/bin:/bin:/usr/sbin:/sbin. Usage: /usr/local/bin:/opt/homebrew/bin:/usr/bin:/bin, then usage extras. |
| emptyPathPreservesPolicyBehavior | Explicit empty PATH does not use either missing-PATH default. Usage still appends extras. |
| absoluteCandidatesKeepOrder | Ignore relative candidates; return the first executable absolute candidate for each agent. |
| componentLimitPreservesEmptyHandling | Health counts empty components within its first 64. Usage omits empties before taking 64. |
| searchPathUsesUTF8ByteBound | Accept 16384 UTF-8 bytes. Reject 16385, with invalidSearchPath and no executable predicate calls. Include multibyte text. |
| usageAppendsFallbackDirectories | After PATH candidates, usage tries home/.local/bin, /opt/homebrew/bin, /usr/local/bin in that order. Health adds none. |
| missingOrEmptyOverrideUsesAgentDefault | nil/empty overrides use home/.codex or home/.claude. |
| invalidNonemptyOverrideNeverFallsBack | Absolute override up to 4096 UTF-8 bytes is accepted; relative or longer nonempty override returns nil. Include multibyte text. |

Use loops inside these eight tests for applicable provider/policy cases so the final count increases by eight.
Do not change existing process, deadline, socket or usage tests beyond moves/imports.
The current path rules are health/usage behavior, not a newly qualified installer safety gate.

## Verification and handoff

Preparation ran documentation checks only. Goal execution on 2026-11-04 completed the specified Swift checks.
The results, compiler repair and one-off socket failure are recorded in the matching log and codex-setup specification.
The Swift suite includes existing fictional process/socket tests. It does not authorize installed-provider probes.
Print the original and final full-suite counts and the new locator test results.
Inspect both caller diffs to confirm all search/directory logic moved while status messages, cancellation and polling remain intact.
Checkpoint each verified part in the specification and keep unverified parts open.
At the end provide explicit-path commit commands. Do not stage, commit, push or open a PR.

