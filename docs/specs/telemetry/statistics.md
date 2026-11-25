---
summary: Settings → Statistics shows daily Claude Code token totals from the status line. The counting is known to undercount.
---

# Token statistics

## How it works

Each Claude status-line reading that Bunlet's [quota wrapper](../usage/claude-allowance.md) forwards carries the
session's `context_window` input and output totals. `TokenLedger` adds the growth since that session's previous
reading to the local calendar day it was received. Daily totals are kept in preferences for 90 days. No transcripts are
read ([0025](../../decisions/0025-adopt-more-reference-behavior.md)).

**Settings → Statistics** shows Claude Code tokens for today, the last 7 days and the last 30 days, a bar chart of the
last 14 days, and a button that clears the totals without changing anything in Claude Code. When **Display → Today's
tokens** is on, the island's top row shows today's total.

## Requirements

- Tokens are never inferred from quota percentages, and quota is never estimated from tokens.
- Missing coverage stays missing, never zero.
- Totals contain counts only, no prompts, commands or transcript text.

## Open work

- **The totals undercount.** Claude documents `context_window` totals as counts from the most recent API response, not
  running session totals, so subtracting one reading from the next misses tokens. The proposed fix counts each call's
  `current_usage` once and ignores repeated deliveries of the same call. It needs a decision record, because reading
  transcripts instead would conflict with 0019.
- Codex reports no token totals through hooks or the App Server, so Codex shows none.
- Proposed but not planned: a background collector that keeps observing with the app closed, local SQLite history,
  and skill-run telemetry ([D2](../../DECISIONS.md#d2-collect-and-inspect-telemetry-locally-with-an-optional-background-process)).

## Decisions

[0025](../../decisions/0025-adopt-more-reference-behavior.md),
[D2](../../DECISIONS.md#d2-collect-and-inspect-telemetry-locally-with-an-optional-background-process).
