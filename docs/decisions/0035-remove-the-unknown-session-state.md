# 0035: Remove the Unknown session state; the latest event decides

- Status: accepted
- Date: 2026-11-28
- Amends: [0008](0008-define-event-ordering.md), [0034](0034-keep-the-last-session-state.md)

## Context

After 0034, a session still became Unknown when its events conflicted, after a wake or clock change, or at a
capacity limit. Unknown kept the session's open requests, and a new prompt was refused while any request was open.
An interrupted turn sends no `Stop`, so its request never closed. On 2026-11-28 a Claude Code session and a Codex
session stayed Unknown through every later prompt. The island showed "Unknown" and the pet showed "State unknown".

## Options

- **Keep Unknown for conflicts only, and let a new prompt always recover**: fixes the freeze. The island still shows
  a state that tells the user nothing.
- **Remove Unknown from the display, but keep a hidden "unconfirmed" flag**: the flag would only turn off Bunlet's
  own reply buttons. A reply already goes back on the live connection of the exact waiting hook, and must match the
  session, turn, tool and one request ([local actions](../contracts/local-actions-v1.md)), so the flag adds little.
- **Remove Unknown completely; the latest event decides**: a listed session is always working, waiting for the user,
  or response ready. A wrong state lasts until the next event.

## Decision

Remove the Unknown state and the confirmed/unconfirmed request flag. The latest event decides a session's state.
A new prompt always starts a new turn. A stop always shows response ready and closes open requests. A start or
prompt after an end reopens the session. A wake or clock change keeps every state. A failed turn shows red.

## Reasoning

The user decided: "i don't want state unknown, i think it makes it too ambiguous", and "i don't think there should
even be an unconfirmed reason". The user named the states to show: working (blue hare), requires response (orange
hare), response ready (green hare), and red for a failed turn. Keeping Unknown for conflicts lost because any
Unknown is ambiguous to the user. The hidden flag lost because reply routing already prevents a wrong answer.

## Consequences

The island, the pet panel and the pet's mood never show Unknown. Events that 0008 treated as conflicts now apply, so
a session can show a wrong state until its next event. An older event than the latest applied one is still dropped,
and late events from a retired turn or an ended session still change nothing. A full session forgets old event and
turn IDs instead of refusing events. Turning session tracking off removes the sessions instead of freezing them.
