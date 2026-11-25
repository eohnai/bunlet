---
summary: Bunlet reads Codex's 5-hour and weekly limits from the read-only App Server while a Codex session is active.
---

# Codex allowance

## How it works

`PetAppController` owns the shared `UsageStore`. While Codex has an active session, `AgentUsageController` starts the
Codex App Server and asks for its rate limits through the read-only quota request. It reads again every 120 seconds
while Codex stays active. After a failure it retries after 5, 15, 30, 60 and 120 seconds. When Codex has no active
session, or Codex is turned off, the reads stop. The notch only renders store snapshots and does no reading itself.

The store keeps each reading whole: agent, window ID and duration, used percent, reset time, account confidence,
receipt time and source. A window of 300 minutes is the 5-hour window and 10,080 minutes is the weekly window. Other
durations keep their own labels.

## Requirements

- Reads never start a thread or turn, and never send login, logout, credit or email requests.
- The App Server process has a bounded lifetime, output size and frame size. Cancelling stops only the process Bunlet
  started.
- Either window can be missing on its own. A missing window shows unavailable, never a made-up number.
- A passed reset time or a failed read shows stale, never zero usage.
- Several sessions never duplicate an allowance.
- Quota has its own store and transport. It never adds account data to session events.

## Out of scope

- Showing the badges: [allowance-strip](../notch/allowance-strip.md).
- Private endpoints, credentials and token-based estimates ([0007](../../decisions/0007-read-supported-usage-data.md)).

## Open work

- Handle rate-limit update notifications by rereading the full snapshot, and handle account changes without showing
  another account's numbers.
- Check reconnect, sparse updates and account changes against a live Codex.

## Decisions

[0007](../../decisions/0007-read-supported-usage-data.md) supported sources only,
[0015](../../decisions/0015-show-limits-only-for-active-providers.md) active agents only.
