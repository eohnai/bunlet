---
summary: Approve or deny, answer questions and send follow-ups from the island, only through verified local channels.
---

# Local responses

## How it works

Bunlet answers an agent only through a hook that waits for a reply, defined in
[local actions v1](../../contracts/local-actions-v1.md). The packaged `NotchPetActionHook` holds the agent's request
open and streams it to the app. `LocalActionController` shows an action card, rechecks the session, turn and request
against current store state when the user presses Send, and writes one reply. Lifecycle events, terminal input and
transcripts are never used to respond.

**Permissions.** Claude's `PermissionRequest` and, when **Approve in** is set to Bunlet, Codex's `PermissionRequest`
show **Allow once** and **Deny** ([0025](../../decisions/0025-adopt-more-reference-behavior.md)). **Always allow**
appears only when Claude sends permission suggestions. The card shows bounded tool-input details first. The reply
never changes persistent permissions or modes, and other agent policy still applies.

**Questions.** Claude's `AskUserQuestion` is held at `PreToolUse`. The card shows up to four questions with their
options, single or multiple choice, and custom text. Send returns the original questions with the user's answers.
Cancel or expiry hands the question back to Claude's normal flow.

**Follow-ups.** After a finished Claude turn with no pending request, the Stop hook stays open for up to 60 seconds.
Text the user sends becomes feedback on that same turn, not a new turn. After the window, or for other agents, Bunlet
types the text as one line plus Return, but only into an Otty or tmux pane it can address without focus. It never types
into the front window.

## Requirements

- Nothing is sent without an explicit Send. Drafts live in memory, tied to one request.
- A request with a missing tool-use ID needs exactly one matching event. Competing or already-answered requests are
  unavailable.
- Helper receipt, agent acceptance and the request being resolved are reported separately. Uncertain delivery is never
  replayed.
- At most 32 open channels and 128 queued delivery events. Overflow closes channels rather than losing identity.
  Requests wait at most 60 seconds.
- Incoming requests never activate the app. Respond opens the composer.
- Response hooks are opt-in, with their own ownership record. Disconnect turns responses off before removing hooks.
- Cursor CLI has no local responses.

## Open work

- Check Allow once, Deny, Always allow, answers and follow-ups against real Claude Code and Codex, including
  concurrent sessions in one folder, expiry, cancellation and disconnect.
- The `PermissionRequest` reply format for Codex follows the reference app's code and is unverified.

## Decisions

[0010](../../decisions/0010-add-local-agent-actions.md) local actions,
[0025](../../decisions/0025-adopt-more-reference-behavior.md) Codex approvals and typed follow-ups.
