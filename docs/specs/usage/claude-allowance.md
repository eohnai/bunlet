# Forward Claude allowance to the notch

Needs: codex-allowance

## Goal

Forward the real Claude Code 5-hour and weekly allowance from the status line into the app, and show it next to active Claude sessions.
The forwarding must keep the user's status-line output and cancellation behavior unchanged.
It reuses the shared usage store and notch sections from [codex-allowance](codex-allowance.md). See the [usage area](area.md) for shared context.

This is a retrospective spec. It moves U2a, U2b, U2c1, U2c2, and U2c3 out of the [source specification](../notch-companion.md).
The parser, sender, receiver, forwarding executable and app wiring now have source implementations. Owned status-line installation/restoration and Settings health also have source paths. Live acceptance remains incomplete.

## Done when

- Claude `five_hour` and `seven_day` status-line fields become anonymous usage observations. Missing windows and reset times stay missing on their own.
- A forwarding wrapper keeps the original stdin, stdout, cancellation, and exit behavior of the status line.
  Repeated forwarding is not reported as a new provider measurement.
- Observations travel over a separate private datagram endpoint, not the lifecycle socket. Each message is at most 8192 bytes. Sending never blocks or spools.
- The running app receives these observations into the shared usage store, with the app's own receipt time.
- When the app is unavailable, the terminal still shows the original status line, with no delay beyond a fixed bound.
- Live Claude allowance appears in the actual notch beside Claude sessions, using the U5 presentation in codex-allowance.
- Several anonymous Claude sources stay separate and are labelled account unverified. Grouping by provider does not claim one shared account.
- Installed configuration changes happen only after a reviewed, reversible plan and the user's approval.

## Out of scope

- Codex allowance and the shared store's first delivery: [codex-allowance](codex-allowance.md).
- Retry, reconnect, account changes, and stale-source recovery beyond this spec's open decisions: `refresh-recovery`.
- Account identity for Claude sources. No supported source supplies it.
- Private endpoints, credentials, token-based estimates, and automatic paid prompts.

## Constraints

- Use only the status-line source accepted in [decision 0007](../../decisions/0007-read-supported-usage-data.md).
- Keep the existing Claude status-line output intact. Keep Claude lifecycle hooks separate from the quota wrapper.
- Keep quota on its own transport. Do not widen the lifecycle envelope.
- The same-user filesystem check does not authenticate a provider or prove that a measurement is fresh.
- Forwarding must work without Otty or navigation metadata, under [decision 0012](../../decisions/0012-support-terminal-independent-operation.md).

## Verify

- Seam: a fictional status-line payload through the forwarding wrapper and `UsageDelivery` to `UsageReceiver`, then `UsageStore` in the running app.
- Code: `Sources/Usage/{ClaudeUsageProvider,UsageDelivery,UsageReceiver,UsageStore,UsageInbox,UsageEndpointLease,UsageValidation}.swift`, `Sources/NotchPetStatusLine/main.swift`, and app wiring in `Sources/NotchPet/`.
- Build: `bash scripts/run.sh --build-only`.
- Swift checks: `env DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --scratch-path /private/tmp/notch-pet-dev/build`.
- Real app: `bash scripts/run.sh`, then a live Claude status line with the reviewed configuration plan. Compare terminal output with and without forwarding.

These are reproduction commands. This retrospective spec ran documentation checks only.

## Decisions

- **Show provider-specific 5-hour and weekly limits in the notch, 2026-10-29.** Recorded in [codex-allowance](codex-allowance.md#decisions).
- [0002: Use services and shared stores](../../decisions/0002-use-mvvm-with-services.md).
- [0007: Read usage through supported interfaces](../../decisions/0007-read-supported-usage-data.md).
- [0011: Organize records by area and feature](../../decisions/0011-organize-records-by-feature.md).
- [0012: Support terminal-independent operation](../../decisions/0012-support-terminal-independent-operation.md).

## Receiver implementation policy, 2026-11-06

The user's approved full MVP goal authorizes routine implementation choices. The earlier five
proposals are resolved for this implementation in [quota intake](../../contracts/usage-intake.md):
Claude-only socket ingress; refused-owned-socket recovery under a persistent private lock;
UsageStore-owned receiver health rendered by the notch; session-hashed anonymous sources with
24-hour expiry and visible refusal at capacity; app-owned receiver/store/Codex refresh.
These are implementation choices, not claims of tested compatibility or provider authentication.

Sources now trace the forwarding executable through `ClaudeUsageProvider.forward` and
`UsageDelivery` into `AgentServices`' generation-guarded `UsageInbox` and shared UsageStore.
Per-socket buffers address the historically unreachable 8192-byte limit. Full snapshots replace
independently missing windows. Codex refresh retries with bounded backoff; it does not start turns.
The notch exposes stale readings, receiver failure and intake/capacity loss. The old view-owned
receiver and ambiguous `sync(execute:)` build finding below are historical, not this code path.

Tests, builds, process launches, socket probes, installed configuration access and runtime
qualification were NOT RUN. Original verification-bearing checkboxes are preserved.
`ClaudeStatusLinePlanner` and `ProviderHookTransaction` now implement separate guarded quota
setup/removal/restoration, and `ProviderSetupView` exposes quota ownership/helper/receipt state.
See [Claude setup](../sessions/claude-setup.md). Live terminal preservation remains unverified.

## My calls

- U2a–U2c3 move here, as the usage area file says. Their wording and checkbox states are unchanged.
- The usage-source investigation evidence for Claude stays in codex-allowance with the rest of that task. This spec cites it.
- The five receiver choices were subsequently settled as implementation policy under the approved full MVP goal; their original task remains unticked because runtime acceptance was not run.
- The original five-gap review and paused-goal evidence remain historical. Current ownership and intake rules are in the linked contract.

## Tasks

- [x] U2a: Parse bounded Claude 5-hour/weekly status-line fields into anonymous usage observations; verify five parser tests, independent missing windows, reset units and bounded errors.
- [ ] U2b: Add a bounded Claude status-line forwarding wrapper that preserves original stdin/stdout, cancellation and exit behavior without changing installed configuration.
- [x] U2c1: Send typed quota observations through a separate bounded nonblocking Unix datagram endpoint; verify five socket/path/permission tests.
- [x] U2c2: Validate and receive bounded quota datagrams through a private receiver callback with app receipt time; verify five isolated delivery/lifecycle cases. App-store wiring remains in U2c3.
- [ ] Settle the five open usage receiver decisions (socket providers, stale socket recovery, receiver health, source lifetime, service ownership) and update U2c3's plan; proposed 2026-10-30, awaiting user approval.
- [ ] U2c3: Connect the forwarding helper and receiver, verify app-unavailable behavior and live Claude quota in the notch, and review reversible setup before any installed configuration changes.

## Evidence from the paused goal

The [paused goal log](../../goals/notch-agent-limits-log.md) adds the following. It is summarized here, not copied. None of it was rerun for this spec.

- U2a: turn 12 split U2 into parser, wrapper, and delivery tasks. Five parser tests failed first, then passed. Commit `738e0ee`.
- U2c1: turn 25 added the one-function datagram sender with five tests. Commit `ed07904`.
- U2c2: turn 26 added the three-method `UsageReceiver` with five isolated tests. Commit `ab773e6`.
- U2c3: the pause checkpoint records the uncommitted receiver wiring. Its build was interrupted, and the result was not captured.
- U2b: no wrapper existed at that checkpoint. The full MVP now adds source only; live Claude forwarding remains unverified.

## Historical evidence

The following records are copied from the [source specification](../notch-companion.md#u2a-quota-parser-verification-2026-10-29).
Only relative link paths changed. They were not rerun for this spec.
The source spec also keeps them.

### U2a quota parser verification, 2026-10-29

ClaudeUsageProvider.parse(_:sourceID:receivedAtMs:) extracts five_hour/seven_day only, converting
Unix seconds to milliseconds and preserving independently missing windows/reset times. Account
and provider measurement identity remain absent. No raw status-line content is retained.
Five ClaudeUsageProviderTests first failed the missing-type baseline, then passed with the
implementation using the isolated Swift test command and --filter ClaudeUsageProviderTests.
This verifies parsing only, not forwarding, terminal output preservation or live quota.

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
