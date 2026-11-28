# 0034: Keep a session's last state instead of expiring it to Unknown

- Status: accepted
- Date: 2026-11-28
- Amends: [0008](0008-define-event-ordering.md)

## Context

Under 0008, every hook event reset a 120-second deadline. A session with no new event before the deadline became
Unknown with the reason `expired`. That covered idle, working, waiting and response-ready sessions alike. A session that
has finished, or waits for the user, sends no events, so it always turned Unknown after 2 minutes. A working session in
a long tool run also turned Unknown. Unknown is sticky: the turn's `Stop` did not bring back response ready, so the
session stayed Unknown until its next prompt. On 2026-11-28 the island showed both of the user's sessions as Unknown
after they had finished replying.

## Options

- **Keep the 2-minute expiry**: no session claims a state the hooks have not recently confirmed. Most sessions show
  Unknown most of the time.
- **Remove the expiry and keep the last state**: a session shows waiting, response ready or working until a new event
  changes it. A session whose agent exits without `SessionEnd` keeps its last state.
- **Remove the Unknown state completely**, as the reference island does. This would also drop Unknown for conflicting
  events. Conflicting events would then show as a current request or state.

## Decision

Remove the expiry. A session keeps its last state until a new event changes it. Unknown remains only for conflicting
events, capacity limits, paused monitoring, and clock changes or wake.

## Reasoning

The user decided: "it should show either the fact that its awaiting a response or if not its completed, or running.
there's no need for unknown after 2 mins." A quiet session is normal, not evidence of a problem. Removing Unknown
completely lost because Unknown also withdraws answering a request from Bunlet when the session's events conflict
([local actions contract](../contracts/local-actions-v1.md)), and conflicts are rare.^[inferred]

## Consequences

The island and the pet show waiting, response ready and working without a timer. A session whose agent crashes keeps
its last state until the quiet-session clean-up from [0032](0032-list-sessions-like-the-reference.md) removes it, or the
user removes it. Local actions keep their own reply deadline, so a stale request still cannot be answered. Waking the Mac
still makes every open session Unknown. Revisit that if it shows up as often as the 2-minute expiry did.
