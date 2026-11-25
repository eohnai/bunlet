---
summary: Claude Code's status line forwards its 5-hour and weekly limits to Bunlet through a wrapper that keeps the original output.
---

# Claude allowance

## How it works

Claude Code passes `rate_limits` to the `statusLine` command on stdin. It does so only for Pro, Max and Ultra
subscribers, or behind a gateway with a spend limit, and only after the session's first response. Bunlet's
[setup](../sessions/claude-setup.md) wraps the user's status line with `NotchPetStatusLine`. The wrapper streams the
original input to the original command, so its output, working directory and environment stay the same.

The wrapper parses only `rate_limits.five_hour` and `rate_limits.seven_day`, each with `used_percentage` and
`resets_at` in Unix seconds. It sends one reading to the app over a separate private datagram socket. A reading with no
windows still counts as a receipt, marked as awaiting its source. The app stamps its own receipt time and stores the
reading in the shared `UsageStore`.

Each Claude session is a separate anonymous source, named by a hash of its session ID. Sources expire after 24 hours,
and new ones are refused visibly when the store is full. Settings shows the quota receiver's state, forwarding
ownership and the last receipt.

## Requirements

- The wrapper keeps the original stdin, stdout, cancellation and exit behavior. If the app is not running, the
  original status line still prints, with no delay beyond a fixed bound.
- Each message is at most 8,192 bytes. Sending never blocks and never queues to disk.
- Missing windows and reset times stay missing. A value outside 0 to 100 is rejected.
- Claude sources are labelled account unverified. Grouping by agent never claims one shared account.
- Quota uses its own socket and never adds data to session events.

## Out of scope

- Installing and restoring the wrapper: [claude-setup](../sessions/claude-setup.md).
- Account identity. No supported source provides it.

## Open work

- Check live forwarding, output preservation and cancellation in a disposable setup.
- Check that a Claude reading reaches the badge after a real reply.

## Decisions

[0007](../../decisions/0007-read-supported-usage-data.md),
[0031](../../decisions/0031-recover-a-replaced-claude-status-line.md),
[quota intake contract](../../contracts/usage-intake.md).
