# Notch Pet

A macOS companion for Codex CLI and Claude Code, under development, with terminal-independent operation as an accepted requirement.
The source implements independently selectable Pet, Notch and Agents features, shared native Settings,
session cards, provider limits and a silent observation helper. Agents owns optional receiver and quota work.
The Codex MVP includes setup/check/removal controls and owned-hook transactions, with runtime qualification still pending.
Pet reactions, dragging/return and custom packs remain planned.
Local approval/deny controls, question answers, and follow-up replies are also planned, subject to verified agent/version support.
SSH and cloud-agent integrations are optional future work.

The working name is `notch-pet`; the user has not chosen a product name.

## Planned local telemetry

The user confirmed an optional background collector, local SQLite history, and telemetry for next-task, debug-issue, and checkpoint.
Collection will continue while the interface is closed, with no hosted backend or cross-device sync.
Pet-only use will require no collector. Battery and resource requirements apply to all owned processes.
See the [telemetry plan](docs/specs/telemetry/area.md) and [resource requirements](docs/specs/notch/resource-efficiency.md).
The three feature task lists are proposed; no collector service or history database is implemented or installed by this plan.

## Run locally

Use macOS 14 or later with Swift 6 tools. Install Apple's Command Line Tools if `swift --version` is unavailable.
The first build was verified on macOS 26.3.1 with Swift 6.2.3 on the M2 MacBook Air.
Older supported macOS versions have not been tested yet.

From the repository root, run:

```bash
bash scripts/run.sh
```

Click the paw icon in the menu bar. Settings manages feature availability; installed surfaces have recovery actions.
When Agents is installed, the Codex submenu opens Connect, Check and Remove hooks controls.
Select **Quit Notch Pet** to close the app. Command-Q also quits while its menu is open.
The app has no Dock icon. Pet, Notch and Settings windows follow the selected features and explicit actions.

The script builds a Swift package and creates `Notch Pet.app` under `${TMPDIR:-/private/tmp}/notch-pet-dev`.
Build products stay there too. The app uses no external package dependencies.
Starting the app or opening Settings does not install provider hooks.
Quit the running app before rebuilding. Repeating the launch command reuses the same app bundle.
Temporary files can be removed by macOS; rerun the command to rebuild them.

Build the bundle without launching it:

```bash
bash scripts/run.sh --build-only
```

On success, the command prints the app bundle's absolute path. Build messages go to stderr.
This is a development bundle; distribution packaging and signing are a later task.

## Local event bridge

With Agents installed and monitoring enabled, the app listens at `/private/tmp/notch-pet-<uid>/events-v1.sock`.
The directory has mode `0700`. The socket has mode `0600`.
Both endpoints check the connected user's numeric ID.
The receiver validates [version-1 envelopes](docs/contracts/agent-events-v1.md) before calling its consumer.
The app retains validated observations in a shared session store with bounded ordering and freshness rules.
The notch reads the shared store; setup, configured hooks and observed delivery remain separate evidence.

The bundle includes `Contents/MacOS/NotchPetHook`.
Run it with `--agent codex` or `--agent claude`, with one raw hook JSON object on stdin.
It forwards only the contract's allowed fields, including an optional unverified `OTTY_PANE_ID` hint.
It never opens transcripts or forwards prompt text, commands, or raw tool input.
Handled errors return exit `0` with empty stdout and stderr.
There is no acknowledgement, retry, queue, or saved activity.

The helper limits stdin, connection, and writing to 50 ms each.
It also enforces a shared 250 ms deadline after executable entry.
Process launch time is additional. The setup planner specifies a three-second synchronous handler timeout;
agent enforcement remains a release-qualification requirement.
The receiver allows 100 ms to finish one frame, including fragmented reads.
A successful write does not prove that an observation reached session state.

The app holds `listener.lock` while it owns the endpoint.
It recovers an owned stale socket only after a refused connection and an unchanged file identity.
It leaves active listeners, symlinks, and unrelated files intact.
Normal shutdown removes only its own socket. The lock file and directory remain for later launches.
These checks separate users and coordinate app instances. They do not authenticate an agent running as the same user.

## Codex event adapter

`CodexEventAdapter.project(rawHook:paneSelector:)` selects Codex fields for the existing version-1 envelope.
The helper uses this adapter when invoked with `--agent codex`.
It accepts `SessionStart`, `UserPromptSubmit`, `PreToolUse`, `PermissionRequest`, `PostToolUse`, `Stop`, and `SessionEnd`.
It preserves source session, turn, and tool-call identities when supplied. It does not invent missing identities.
The shared store classifies `request_user_input` as a question and other permission requests as approval requests.
A stop means response ready, including when assistant prose contains a question. It does not prove task success.

The adapter uses the existing bounded parser, field validation, and helper deadline.
An inherited pane selector remains an unverified hint until the terminal adapter validates it.
The fictional checks cover projection, session meanings, and actual socket delivery through the bounded inbox.
They do not establish installed Codex compatibility in interactive Otty sessions.
The earlier controlled hook investigation covered Codex `0.163.0`. The CLI now reports `0.164.0`.
Partial interactive checks used isolated configuration and a mock provider.
The remaining Codex interactive checks are deferred to immediately before final workflow verification under decision 0009.
No hooks were installed during development of this implementation.
See the [compatibility record](docs/notes/agent-event-compatibility.md) for evidence boundaries and known limits.

## Codex MVP: implementation, not live acceptance

The Codex submenu and Agents settings expose explicit Connect, read-only Check and Remove hooks actions.
The source includes lossless seven-hook planning, unchanged reinstall, targeted removal, bounded guarded writes
and install/remove journal recovery. Configuration, ownership and recovery data are bounded to 256 KiB each.
Existing settings and the normal Codex trust flow are preserved under the accepted concurrent-editor limitation.
Finish other configuration edits before applying setup changes.

**No Codex installer release is qualified yet. Automatic Connect therefore remains unavailable.**
The production path behind that gate is implemented; the qualified release registry is intentionally empty.
Historical compatibility, a candidate version, configured hooks or a delivery receipt cannot qualify installation.
Check reports the available evidence and removal does not require a working CLI.
No user preference or environment flag bypasses the qualification gate.

Successful supported setup enables monitoring explicitly. If Notch is absent, the app offers Features rather than
installing it silently. Real observations use the existing helper, receiver, inbox and shared session store.
Active Codex sessions drive read-only quota reads into the shared usage store; quota reads cannot start turns.
Pet-only use starts no agent services.

The user requested implementation without testing: **no tests, builds, app launches, live probes or installed
configuration changes were performed for this MVP goal**. Compiler correctness, real setup/delivery and native
interaction acceptance are unverified. See the [source audit and log](docs/goals/codex-mvp-implementation.md)
and [Codex setup specification](docs/specs/sessions/codex-setup.md).

## Verify the bridge

Quit Notch Pet before running the process checks. They refuse to replace an existing socket.
The Swift tests use isolated temporary directories. The process checks use the standard endpoint and fictional input.
Neither command installs hooks or changes agent settings.

Build the bundle and helper first:

```bash
bash scripts/run.sh --build-only
```

Run the Swift tests with full Xcode selected for this command only:

```bash
env DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  swift test --scratch-path /private/tmp/notch-pet-dev/build
```

The tested Command Line Tools installation cannot import the test frameworks.
The app and helper still build with Command Line Tools.
The Swift tests also use `/usr/bin/python3` to serialize the existing fictional contract cases.
They check the production Swift decoder, rather than the Python reference validator.

Run the helper process checks and contract reference checks:

```bash
python3 scripts/check-event-bridge.py
python3 scripts/check-event-contract.py
git diff --check
```

Success means all Swift tests pass and the process checker prints `Bridge process checks passed`.
The contract checker prints four `PASS` lines. The diff check prints nothing.
Process timings include launch time. They are observations on this Mac, not a real-time scheduling guarantee.

## Start here

- [Project status](docs/STATUS.md)
- [First-version specification and tasks](docs/specs/notch-companion.md)
- [Architecture](docs/ARCHITECTURE.md)
- [Decision records](docs/decisions/)

## Confirmed requirements

- Use SwiftUI and AppKit on the user's M2 MacBook Air.
- Support Codex CLI and Claude Code without requiring Otty. Verify terminal combinations before claiming compatibility.
- Show input requests and response completion through the notch interface.
- Let the user detach, customize, and return a desktop pet.
- Include reported usage limits where supported.
- Keep terminal navigation optional and allow later integrations with other coding apps.
- Retain SwiftUI/AppKit and independently adapt selected Flux Island setup, session-navigation, window/pet, and quota-refresh behaviors.
- Keep conservative session evidence, bounded one-way observation delivery, optional terminal navigation adapters, and supported provider usage sources.
- Include local approvals, structured-question answers, and explicit follow-up replies through verified agent-specific response channels, with available terminal navigation or manual-return guidance for unavailable actions.
- Keep SSH and cloud-agent support as optional future work outside first-release acceptance.
- Do not depend on Flux Island or reuse its code or internal assets. Sprite-sheet input compatibility remains a proposal.

The original task list and architecture decisions 0001–0009 have recorded approvals; decision 0010 records the subsequently accepted local-interaction scope.
[Decision 0012](docs/decisions/0012-support-terminal-independent-operation.md) accepts terminal-independent operation; live verification beyond Otty remains open.
[Standalone pet use and packaging](docs/decisions/0013-separate-standalone-pet-scope.md) are accepted:
one app with an independent Pet module and optional agent services, extended by D7's feature availability.
The user requested the 2026-10-28 Flux-informed plan update; its revised remaining tasks are proposed for review.
See the specification and [reference findings](docs/notes/flux-island-adoption.md) for selected behaviors,
open choices, and the distinction between planned features and implemented code.

