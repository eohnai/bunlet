---
summary: Bunlet reads Codex's 5-hour and weekly limits from the read-only App Server while a Codex session is active.
---

# Codex allowance

## How it works

`PetAppController` owns the shared `UsageStore`. When agent services start and Codex is on, `AgentUsageController`
starts the Codex App Server once and asks for its rate limits through the read-only quota request. So the badge shows
after Bunlet starts even when a Codex session is open but quiet. While Codex has an active session, it reads every 120
seconds. After a failure it retries after 5, 15, 30, 60 and 120 seconds. When Codex has no active session, or Codex is
turned off, the repeated reads stop. The notch only renders store snapshots and does no reading itself.

The store keeps each reading whole: agent, window ID and duration, used percent, reset time, account confidence,
receipt time and source. A window of 300 minutes is the 5-hour window and 10,080 minutes is the weekly window. Other
durations keep their own labels.

## Requirements

- Reads never start a thread or turn, and never send login, logout, credit or email requests.
- Only one read runs at a time. A session that becomes active cancels the start read.
- The App Server process has a bounded lifetime, output size and frame size. Cancelling stops only the process Bunlet
  started.
- Either window can be missing on its own. A missing window shows unavailable, never a made-up number.
- A failed read keeps the last good reading and never shows zero usage. A passed reset time shows the window as
  100% left ([0036](../../decisions/0036-keep-the-last-quota-reading.md)).
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
[0015](../../decisions/0015-show-limits-only-for-active-providers.md) active agents only,
[0036](../../decisions/0036-keep-the-last-quota-reading.md) keep the last reading.

- **Read Codex limits once at start, without a session.** A Codex session that is open and quiet sends no event after
  Bunlet starts, so its badge stayed hidden. Keeping the last reading on disk across restarts, for every agent, was
  considered and dropped by the user. The cost is one short App Server process each time agent services start.
  (2026-11-28)
