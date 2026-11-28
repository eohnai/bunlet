# 0036: Keep the last quota reading, with no stale state

- Status: accepted
- Date: 2026-11-28
- Amends: [0015](0015-show-limits-only-for-active-providers.md)

## Context

Claude Code sends its limits only when its status line redraws, and it redraws only when the conversation changes.
When the user stopped typing for 5 minutes, the Claude badge turned gray and read `5h 62% 58m stale`. The numbers were
usually still right. They are out of date only if the same account used Claude somewhere else since the reading. A
failed Codex read replaced the last good reading, so the badge read `5h unavailable`. A badge showed only while its
agent had a listed session, so it disappeared when the sessions left the list.

## Options

- **Keep "stale" after 5 minutes:** the badge says when it may be out of date. The user finds the word ambiguous, and
  it shows after every quiet 5 minutes.
- **Read fresh Claude limits before a prompt:** Claude Code sends no limits before a session's first reply. The only
  other source is Anthropic's private usage endpoint with the user's login token, which
  [0007](0007-read-supported-usage-data.md) rules out.
- **Show the last reading as it is:** no stale word and no gray. A wrong number lasts until the next reading.

## Decision

The badge shows the newest reading that has windows, in its level color, with no stale word. A source with no windows
does not hide an earlier reading. When a window's reset time passes, the badge shows that window as 100% left with no
countdown until the next reading. A failed or empty read keeps the last good reading, and the hover popup names the
failure. The popup also says how old the reading is. A badge shows while its agent has a listed session or a kept
reading, so it stays after the sessions leave the list. The Settings switches still hide it.

## Reasoning

The user decided: "i don't want stale in the readings", and "i would prefer not to hide limits like the codex ones,
just leave it on there". Keeping "stale" lost because it is ambiguous, as Unknown was in
[0035](0035-remove-the-unknown-session-state.md). Reading Claude earlier lost because it needs credentials. After a
reset, 100% left is the latest fact Bunlet knows. Showing "unavailable" instead lost because the user wants no
ambiguous states.

## Consequences

A reading made old by use on another device or app looks current until the next reading. After a reset, the badge
reads too high if the account was used elsewhere since. Quota readings stay in memory only, so after Bunlet restarts a
badge returns with the next reading or the next listed session. Codex reads still run only while Codex has a session
that has not ended. The user dropped the related proposal to list a session as idle before its first prompt, so
[0032](0032-list-sessions-like-the-reference.md) is unchanged.
