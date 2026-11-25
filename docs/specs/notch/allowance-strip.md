---
summary: Quota badges left of the notch show each active agent's 5-hour or weekly allowance, with details on hover.
---

# Quota badges

## How it works

When the island is open, the top row shows one badge per agent left of the notch:
`[logo] 5h 96% 3h45m | [logo] 7d 87% 3h37m`. A badge appears only while that agent has a listed session that is not
unknown or ended ([0015](../../decisions/0015-show-limits-only-for-active-providers.md)), and only if its switch in
Settings is on. Cursor CLI reports no limits.

- **Window:** the 5-hour window, or the weekly window (`7d`) when there is no 5-hour window.
- **Value:** percent left by default (`100 − used`, rounded down) or percent used, per Settings. Colors by percent
  left: green above 50, yellow from 20 to 50, red below 20.
- **Countdown:** `3h45m` or `4d22h`, updated every 30 seconds while the panel is open.
- **Missing or stale:** no reading shows `5h unavailable`. A reading over 5 minutes old, past its reset time or from a
  failed source is gray and marked **stale**. An unverified account shows a marker.
- **Hover:** a popup with every reported window, its reset time and freshness, plus receiver problems for Claude
  ([0018](../../decisions/0018-restore-usage-hover-details.md)).

Each side of the notch gets a fixed width. When the full badges do not fit, they switch to a short form without the
countdown or the stale word, and with "—" for missing data. Hover still shows everything. Today's token count sits on
the right with the panel buttons.

## Requirements

- The store keeps the reported used value. Percent left exists only in presentation ([D6](../../DECISIONS.md#d6-show-allowance-as-percent-left-not-percent-used)).
- Several sessions never duplicate an allowance, and agents are never added together.
- For Codex, the matching `codex/` bucket wins. With several other matches the badge shows unavailable.
- Missing data never reads as zero remaining.

## Out of scope

- Reading quota: [Codex](../usage/codex-allowance.md), [Claude](../usage/claude-allowance.md).

## Open work

- If even the short form does not fit, the row still overflows, because nothing shortens it further.
- Check on screen: the short form and the token chip in its new place.

## Decisions

[D6](../../DECISIONS.md#d6-show-allowance-as-percent-left-not-percent-used),
[0015](../../decisions/0015-show-limits-only-for-active-providers.md),
[0018](../../decisions/0018-restore-usage-hover-details.md).
Logos are the user-supplied LobeHub variants of the Claude and Codex marks.
