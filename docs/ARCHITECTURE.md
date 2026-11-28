# Architecture

Bunlet is one Swift package with a SwiftUI and AppKit app and three small helper executables. It needs macOS 14 on
Apple silicon. The only package dependency is Sparkle, linked only in update-enabled builds
([0028](decisions/0028-use-sparkle-for-app-updates.md)). Coding rules are in [SWIFT-PRACTICES.md](SWIFT-PRACTICES.md),
and feature behavior is in the [specs](specs/README.md).

## Processes

| Executable | Runs when | Does |
| --- | --- | --- |
| `NotchPet` (Bunlet.app) | The user opens Bunlet | Receives events and quota, holds all state, shows the island, pet and Settings |
| `NotchPetHook` | An agent fires a lifecycle hook | Sends one bounded event to the app, then exits silently |
| `NotchPetStatusLine` | Claude Code refreshes its status line | Forwards quota to the app and runs the user's original status line |
| `NotchPetActionHook` | An agent fires a hook that waits for a reply | Holds the request open and returns the user's one explicit answer |

The helpers live inside the app bundle. Agent configuration points at them by that path, so an in-place update keeps
working.

## Targets

| Target | Owns | Depends on |
| --- | --- | --- |
| `EventBridge` | Agent and hook identities, the version-1 envelope, per-agent adapters, terminal detection, lossless JSON scanning and the Unix socket | nothing |
| `SessionState` | `SessionStore`, its inbox, and pure presentation rules: ordering, listing, geometry and alerts | `EventBridge` |
| `Usage` | `UsageStore`, the Codex App Server reader, the Claude status-line parser, quota transport and `TokenLedger` | `EventBridge` |
| `Integration` | Health probes, agent path lookup, setup planners, owned transactions and recovery | `EventBridge` |
| `AgentActions` | Action requests and replies, per-agent reply formats and the interactive transport | `EventBridge`, `SessionState` |
| `Pet` | Artwork, packs, imports, preferences, placement and playback rules | nothing |
| `NotchPet` | App composition, windows, Settings, the menu and app-owned services | all of the above |

`Pet` imports no session or event types. The app translates session snapshots into pet moods.

## Ownership

`PetAppController` starts at launch and owns the shared `SessionStore`, `UsageStore` and `TokenLedger`.
`FeatureSettingsModel` starts every runtime and reports any that failed so Settings can offer a retry
([0020](decisions/0020-one-app-with-pet-mode.md)). `ProviderMonitoringModel` saves one on or off choice per agent.

`AgentServices` owns the event receiver and inbox, the quota receiver and inbox, `AgentUsageController` for Codex reads,
and the sleep, wake and clock-change observers. Each start gets a new generation, and queued callbacks from an older
generation are dropped. `ProviderSetupController` runs Connect, Check, Remove and automatic setup per agent.
`LocalActionController` owns reply channels.

`NotchPanelController` owns the island window, its geometry, focus and hit testing. `PetPanelController` owns the pet
window. `PetSettingsController` hosts the Settings window. Views observe stores directly and render their snapshots
through pure functions such as `NotchPresentation`, `NotchAllowancePresentation`, `IslandGeometry` and
`PetPresentation`. A view model exists only where a view owns state, such as drafts and pending actions
([D3](DECISIONS.md#d3-add-view-models-only-where-a-view-owns-state)). Controllers observe stores through
`ObservationLoop` ([D5](DECISIONS.md#d5-observe-stores-from-controllers-with-withobservationtracking)).

## Data flow

**Events.** An agent hook runs `NotchPetHook`, whose adapter keeps only the fields the
[contract](contracts/agent-events-v1.md) allows, plus short prompt and reply previews. It writes one frame to
`/private/tmp/notch-pet-<uid>/events-v1.sock`. The app validates the frame, drops it if that agent is paused, queues it
in `SessionEventInbox` and applies it once to `SessionStore` on the main actor. The latest event decides each session's
state, and there is no unknown state ([0035](decisions/0035-remove-the-unknown-session-state.md)). The island, pet and
sounds react to the new snapshot.

**Quota.** For Codex, `AgentUsageController` reads the App Server once when agent services start, then every 120
seconds while a Codex session is active. For Claude,
`NotchPetStatusLine` sends each reading over a separate private datagram socket to `UsageInbox`
([quota intake](contracts/usage-intake.md)). Both end in `UsageStore`, which never creates session events. Claude
readings also feed `TokenLedger`. The badge shows the last reading with no stale state, and a failed read keeps it
([0036](decisions/0036-keep-the-last-quota-reading.md)).

**Replies.** `NotchPetActionHook` streams a held request to the app over its own socket
([local actions](contracts/local-actions-v1.md)). `LocalActionController` shows it, rechecks it against
`SessionStore` on Send, and writes one reply back.

**Navigation.** Clicking a session uses the terminal identity the hook reported. `TerminalTargets` focuses the exact
pane or activates the app. Navigation never affects monitoring.

## Storage

| Data | Where | Why |
| --- | --- | --- |
| Sessions, requests, quota readings | Memory | They describe live processes. A restart needs fresh evidence. |
| Preferences, monitoring choices, pet size and placement, daily token totals (90 days) | `UserDefaults` | Small values |
| Imported pets | `~/Library/Application Support/NotchPet/Pets/` | Validated data files |
| Hook ownership records and journals | `~/Library/Application Support/NotchPet/Integrations/<agent>/` | Lets Bunlet remove only what it added |
| Credentials | The agents' own storage | Bunlet never reads or copies them |

There is no database ([0003](decisions/0003-store-state-without-a-database.md)). Runtime files, imported packs and
captured session data stay outside the repository.

## Decisions

Decision records are in [`decisions/`](decisions/), and the early project-wide ones (D1 to D6) are in
[DECISIONS.md](DECISIONS.md). [0033](decisions/0033-docs-describe-the-present.md) explains why the docs describe only
the present.
