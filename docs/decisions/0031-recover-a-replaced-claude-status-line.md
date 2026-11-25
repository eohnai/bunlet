# 0031: Recover when another app replaces Bunlet's Claude status line

- Status: accepted
- Date: 2026-11-25
- Amends: [0024](0024-repair-hooks-and-connect-quota-at-launch.md)

## Context

Claude quota forwarding wraps the user's `statusLine` command and saves a record of the exact value it installed.
On this Mac, Bunlet wrapped another app's status-line wrapper on 2026-11-24. Later, `statusLine` was set back to that
other wrapper, most likely by the other app reinstalling it at launch. From then on the record no longer matched the
file, and every path treated the mismatch as a conflict: launch repair skipped forwarding, and both manual **Connect quota**
and **Remove forwarding** failed. No Claude reading arrived, so the island showed `5h unavailable`, and nothing in the app
could clear the stale record. The user approved the fix on 2026-11-25.

## Decision

When Bunlet's quota record is valid for this configuration and helper, but `statusLine` no longer holds the recorded
wrapper and does not name Bunlet's status-line helper, the status line was **replaced outside Bunlet**:

- **Setup shows it.** **Owned forwarding** reads **Replaced outside Bunlet**, with a message that explains Connect and Remove.
- **Launch repair leaves it alone.** A replacement counts as a removal by hand under 0024, so Bunlet does not add
  forwarding back automatically. Otherwise two apps that both wrap the status line would rewrite it on every launch.
- **Connect quota wraps the replacement.** The current value becomes the new original, its output is preserved, and the
  record is replaced.
- **Remove forwarding clears only the record.** The status line is left exactly as the other app or the user wrote it.

A value that still names Bunlet's helper but differs from the record, such as an edited copy of the wrapper, stays a
conflict. Lifecycle hooks are unchanged; this applies only to quota forwarding.

## Consequences

Users with another status-line wrapper must press **Connect quota** again after that app replaces Bunlet's wrapper.
Bunlet does not detect the replacement until the next check or launch. If both apps keep reinstalling their wrappers,
the last writer wins until the user chooses. Planner and service tests cover the replacement, a reconnect, a removal and
an edited lookalike. The behavior has not been run against a live Claude Code installation.
