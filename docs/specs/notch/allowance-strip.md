---
summary: Quota badges left of the notch show each active agent's 5-hour or weekly allowance, with details on hover.
---

# Quota badges

## How it works

When the island is open, the top row shows one badge per agent left of the notch:
`[logo] 5h 96% 3h45m | [logo] 7d 87% 3h37m`. A badge appears while that agent has a listed session that has not
ended, or while Bunlet keeps a reading for it, and only if its switch in Settings is on
([0036](../../decisions/0036-keep-the-last-quota-reading.md)). So a badge stays after its sessions leave the list.
Cursor CLI reports no limits.

- **Window:** the 5-hour window, or the weekly window (`7d`) when there is no 5-hour window.
- **Value:** percent left by default (`100 − used`, rounded down) or percent used, per Settings. Colors by percent
  left: green above 50, yellow from 20 to 50, red below 20.
- **Countdown:** `3h45m` or `4d22h`, updated every 30 seconds while the panel is open.
- **Last reading:** the badge shows the newest reading that has windows, however old, in its level color. There is no
  stale state. A source with no windows, such as a new Claude session before its first reply, does not hide an
  earlier reading. A failed read keeps the last good reading.
- **Reset:** when a window's reset time passes, the badge shows `5h 100%` with no countdown until the next reading.
- **Missing:** with no reading that has windows, the badge shows `5h unavailable` in gray. An unverified account shows a
  marker.
- **Hover:** a popup with every reported window and its reset time, how old the reading is ("Updated 12 min ago"), a
  failed read after it, and receiver problems for Claude ([0018](../../decisions/0018-restore-usage-hover-details.md)).

Each side of the notch gets a fixed width. When the full badges do not fit, they switch to a short form without the
countdown, and with "—" for missing data. Hover still shows everything. Today's token count sits on
the right with the panel buttons.

## Requirements

- The store keeps the reported used value. Percent left exists only in presentation ([D6](../../DECISIONS.md#d6-show-allowance-as-percent-left-not-percent-used)).
- Several sessions never duplicate an allowance, and agents are never added together.
- For Codex, the matching `codex/` bucket wins. With several other matches the badge shows unavailable.
- Missing data never reads as zero remaining. A passed reset reads as 100% left, because the window is new.

## Out of scope

- Reading quota: [Codex](../usage/codex-allowance.md), [Claude](../usage/claude-allowance.md).

## Open work

- If even the short form does not fit, the row still overflows, because nothing shortens it further.
- Check on screen: the short form, the token chip in its new place, a badge after its sessions leave the list, and a
  passed reset.

## Decisions

[D6](../../DECISIONS.md#d6-show-allowance-as-percent-left-not-percent-used),
[0015](../../decisions/0015-show-limits-only-for-active-providers.md),
[0018](../../decisions/0018-restore-usage-hover-details.md),
[0036](../../decisions/0036-keep-the-last-quota-reading.md).
Logos are the user-supplied LobeHub variants of the Claude and Codex marks.
