# Show Codex allowance in the notch

Needs: notch/session-island

## Goal

Read the real Codex 5-hour and weekly allowance through the read-only App Server, and show it next to active Codex sessions in the notch.
This spec also delivers the shared usage store and the provider-aware usage sections that Claude allowance reuses.
See the [usage area](area.md) for shared context.

This is a retrospective spec. It moves the usage-source investigation, U1, U3a, U3b1, U3b2, and U5 out of the [source specification](../notch-companion.md).
Some of this code has live evidence, but actual-app acceptance is incomplete.

## Done when

Display scope update, 2026-11-02: [0014](../../decisions/0014-omit-usage-limit-tooltips.md) removes hover details
from the [compact notch strip](../notch/allowance-strip.md). It shows one selected window and a reset countdown.
Both windows together, exact reset timestamps, and detailed source messages are omitted from that surface.
The original task wording and evidence below remain for data/integration coverage; those obligations are unchanged.

These checks come from "Feature 2: see the limits of agents in use" in the source spec, approved on 2026-10-29.

- Only providers with an observed active session appear under [0015](../../decisions/0015-show-limits-only-for-active-providers.md). Unknown and Ended sessions do not count. Codex-only hides Claude, both active shows both, and no active sessions shows an empty state.
  Cached allowance alone never makes an inactive provider appear.
- Real Codex allowance reaches the actual notch through the read-only App Server.
- Percentages are labelled used. Each window shows its reset time when supplied, plus freshness and source/account confidence. (replaced 2026-10-31: the notch shows percent left under D6; reset time, freshness, and confidence move to the [allowance strip](../notch/allowance-strip.md) and its tooltip)
- Window labels follow the reported duration: 300 minutes is 5-hour and 10080 minutes is weekly. Other durations keep honest labels.
- Either window can be missing on its own. A missing window shows unavailable with a bounded reason, not a made-up percentage.
- Stale, disconnected, and signed-out states explain missing values. A passed reset never shows zero usage.
- Several sessions never duplicate allowance. Providers are never combined into a total.
- Codex reads never start a thread or turn, and never send login, logout, credit, or email requests.
- The usage store keeps provider and window identity, account confidence, full bucket maps, and receipt, source, and reset times. It creates no session events.

## Out of scope

- Claude status-line forwarding: [claude-allowance](claude-allowance.md).
- Rate-limit notifications, bounded retry, reconnect, and account switching (U3c, U4, and the failure parts of U6): `refresh-recovery`.
- Private endpoints, credentials, token-based estimates, and agent turns for quota refresh.
- Agents other than Codex and Claude Code.

## Constraints

- Use only the read-only App Server quota read accepted in [decision 0007](../../decisions/0007-read-supported-usage-data.md).
- Keep quota in its own store and transport. Do not widen the lifecycle envelope to carry account data.
- Bound process lifetime, output bytes, and each frame. Stop only the owned process on cancellation or timeout.
- Views render snapshots. Provider services do the I/O, under [decision 0002](../../decisions/0002-use-mvvm-with-services.md).
- Supported allowance reads must work without Otty or navigation metadata, under [decision 0012](../../decisions/0012-support-terminal-independent-operation.md).

## Verify

- Seam: `CodexUsageConnection.read` into `UsageStore`, shown by `NotchUsageView` in the running app.
- Code: `Sources/SessionState/UsageStore.swift`, `CodexUsageProvider.swift`, `CodexUsageProtocol.swift`, `CodexUsageConnection.swift`, and `Sources/NotchPet/NotchUsageView.swift`.
- Build: `bash scripts/run.sh --build-only`.
- Swift checks: `env DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --scratch-path /private/tmp/notch-pet-dev/build`.
- Real app: `bash scripts/run.sh` with fictional Codex sessions, then a sanitized live managed-provider read. Keep no raw quota or account IDs in the repository.

These are reproduction commands. This retrospective spec ran documentation checks only.

## Decisions

- **Show provider-specific 5-hour and weekly limits in the notch, 2026-10-29.** The user asked for limits for the agents in use and chose Claude Code and Codex for the first version. Copied from the source spec.
- [0002: Use services and shared stores](../../decisions/0002-use-mvvm-with-services.md).
- [0007: Read usage through supported interfaces](../../decisions/0007-read-supported-usage-data.md).
- [0011: Organize records by area and feature](../../decisions/0011-organize-records-by-feature.md).
- [0012: Support terminal-independent operation](../../decisions/0012-support-terminal-independent-operation.md).
- [D6: Show allowance as percent left, not percent used](../../DECISIONS.md#d6-show-allowance-as-percent-left-not-percent-used), 2026-10-31. The notch's allowance display moves to [notch/allowance-strip](../notch/allowance-strip.md). U5 keeps its provider filtering, duration, missing-window, and live-data checks.
- [0014: Omit usage-limit tooltips](../../decisions/0014-omit-usage-limit-tooltips.md), accepted 2026-11-02. This supersedes the detailed hover display portion of U5, preserving its data and integration obligations.
- [0015: Show usage limits only for active providers](../../decisions/0015-show-limits-only-for-active-providers.md), accepted 2026-11-02. This replaces the earlier non-ended-session visibility rule.

## Code that differs from a decision

`NotchUsageView` runs the Codex refresh loop itself. Its `.task` calls `CodexUsageConnection.read` and then sleeps 120 seconds.
Decision 0002 puts I/O in services, with views that only render snapshots.
The goal plan also made the app the owner of the usage store, but `NotchPanelController` creates it.
This spec records the difference and does not choose a fix. It is part of the open "Usage service ownership" decision in [claude-allowance](claude-allowance.md#open-decisions).

## My calls

- The completed usage-source investigation moves here, as the first usage spec. It covers both providers, and claude-allowance cites it.
- U1 and U5 move here. The area file says codex-allowance delivers the shared usage store. U5 is one task line for both providers, so it cannot be split.
- U6 stays in the source spec. It covers Claude, Codex, and recovery checks, which belong to three specs.
- No new tasks are added. U1, U3b2, and U5 already require the remaining verification.

## Open questions

- U3b2 stays unchecked. Turn 19 of the [paused goal log](../../goals/notch-agent-limits-log.md) records five passing fake-process tests and a sanitized live read.
  That evidence appears to meet the task. Review it before you tick U3b2. `docs/STATUS.md` also records this.
- U1 stays unchecked. The store replaces a source's whole observation. Check whether this meets U1's "sparse-update behavior" before you tick it.
- U5 stays unchecked. Turn 24 verified Codex values and provider filtering in the actual notch. Live Claude values are still missing.

## Tasks

- [x] Verify both providers' usage sources and account-mode limitations without exposing credentials or starting agent turns.
- [ ] U1: Add a shared usage store that preserves provider/window identity, account confidence, full bucket maps, receipt/source/reset timestamps, and sparse-update behavior without creating session events.
- [x] U3a: Normalize bounded full Codex quota snapshots, preserving buckets, account identity and actual durations; verify five parser tests without compatibility double-counting.
- [x] U3b1: Sequence read-only Codex quota protocol initialization and response-ID matching; verify five isolated protocol tests without thread/turn methods.
- [ ] U3b2: Run the quota protocol over bounded Codex App Server process I/O; verify timeout, cancellation, framing, oversized output and cleanup with isolated fake executables, then perform a sanitized managed-provider read.
- [ ] U5: Show agent-aware 5-hour and weekly allowance sections in the notch for Claude Code and Codex in use, with used percentages, reset times, freshness and account confidence; preserve other returned Codex durations and avoid double-counting.

## Evidence from the paused goal

The source spec does not record this work. It comes from the [paused goal log](../../goals/notch-agent-limits-log.md). It is summarized here, not copied.
None of it was rerun for this spec.

- U1: turn 11 added a three-function bounded usage store with five tests. They cover active-only filtering, separate anonymous sources, replacement, rejection of malformed or old input, missing and nonstandard windows, and no reset-to-zero. The full suite passed 74 tests in ten suites. Commit `d6d211b`.
- U3b2: turn 19 added the cancellable `CodexUsageConnection` with nonblocking pipes, SIGPIPE protection on the descriptor, bounded frames, output, and deadline, and owned-process cleanup. Five fake-process tests passed. A temporary sanitized harness read real quota: no failure, two windows, durations 300 and 10080, account known. No thread, turn, or configuration change happened. Commit `1c537aa`.
- U5: turn 22 added active-provider quota sections to the expanded notch. Turn 23 added bounded Codex executable lookup. Turn 24 showed live Codex 5-hour and weekly values in the actual notch. It also showed Codex-only, both-provider, and ended-provider filtering. Commit `80b9351`.
- Full-suite evidence: turn 21 passed 94 tests in 14 suites. The pause checkpoint records 104 tests in 16 suites as the latest full run.

## Historical evidence

The following records are copied from the [source specification](../notch-companion.md#historical-implementation-evidence).
Only relative link paths changed. They were not rerun for this spec.
The source spec also keeps them.

Task 2 evidence: [usage-source compatibility](../../notes/usage-source-compatibility.md).
Codex account reads returned real quota windows without agent turns.
Claude field support and account eligibility were checked; live quota forwarding remains unverified until the forwarding task.

### U3a quota parser verification, 2026-10-29

CodexUsageProvider.parse(_:sourceID:receivedAtMs:) accepts a full account/rateLimits/read result.
Five frozen tests first failed the missing-type baseline, then passed. Full bucket maps take
precedence over the compatibility view, identities remain separate, and missing/nonstandard
window durations remain unchanged. Reset seconds convert safely to milliseconds.
This is parsing evidence only. No App Server process was launched and no live quota was read.

### U3b next-task interface sketch

Proposed implementation detail within accepted read-only quota scope:
`CodexUsageConnection.read(executableURL:sourceID:) async -> UsageObservation`.
The connection launches only the explicit Codex executable, initializes App Server over stdio,
then issues account/rateLimits/read with reset-credit details excluded. It must wait for the
initialization response before quota requests and match response IDs rather than the next line.
Ignore unrelated notifications. Never issue thread/turn, login/logout, credit-consumption or email requests.
Bound process lifetime, stdout bytes and each frame; stderr is not a user diagnostic.
Stop the owned process on cancellation/timeout and return a bounded failure category.
Verify five isolated process cases: valid handshake/quota; interleaved notifications and wrong IDs;
server error/malformed frame; timeout/cancellation; oversized output. Fake servers must assert
that no thread or turn methods were sent. Actual managed-provider reads follow only after those checks.

### U3b1 protocol verification, 2026-10-29

CodexUsageProtocol has three methods (init/start/receive). Five frozen tests first failed the
missing-type baseline then passed: initialization ordering, quota-only outbound methods, unrelated
notifications/wrong IDs, bounded server errors, malformed/oversized input and terminal completion.
Frames are bounded to 256 KiB and cumulative received bytes to 1 MiB per one-shot connection.
No process or real provider was contacted. U3b2 owns deadlines, OS cancellation and cleanup.

U3b2 process plan: expose `CodexUsageConnection.read(executableURL:sourceID:) async -> UsageObservation`.
Run the explicit executable on a cancellable worker. Maintain a small nonblocking stdin request
queue and newline-framed stdout buffer. Enforce the protocol frame/total-byte limits and a shared
post-launch deadline; process-launch time must be reported separately if the OS launch cannot be
interrupted. Polling must recheck cancellation frequently and never block on a full input pipe.
Suppress SIGPIPE on the pipe descriptor without changing the host process's global signal policy.
On completion/error/cancellation, close owned pipe ends and terminate only the owned process.
Do not print raw stdout/stderr or retain unrelated notification content. Five isolated process
tests must prove real handshake order, wrong-ID interleaving, error/EOF, timeout/cancellation and
output bounds, including child cleanup. No live read precedes these checks.
