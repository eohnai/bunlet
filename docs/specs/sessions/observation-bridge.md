---
summary: The bundled hook helper delivers allowed agent event fields to the running app over a private Unix socket.
---

# Observe local agent events

## How it works

Codex, Claude Code and Cursor CLI run Bunlet's bundled helper, `NotchPetHook`, from their lifecycle hooks. The helper
reads the hook's JSON from stdin, keeps only the fields the [version-1 contract](../../contracts/agent-events-v1.md)
allows, and makes one attempt to send them to the app. It always exits 0 with no output, so it never changes what the
agent decides.

The app listens on `/private/tmp/notch-pet-<uid>/events-v1.sock`. The directory is mode `0700` and the socket `0600`,
and the server checks that the peer is the same user. Each provider has its own adapter that maps hook payloads to
version-1 events, and Claude's `prompt_id` becomes the turn ID. Accepted events pass through an inbox to the session store.

## Requirements

- Raw hook input is limited to 262,144 bytes and a frame to 16,384 bytes. The helper's whole run has a 250 ms
  deadline after launch, with 50 ms each for reading stdin, connecting and writing. The receiver allows 100 ms per frame.
- Invalid, oversized, stale, future-dated, truncated, unsupported or extra frames never reach the store.
- A successful helper exit does not count as delivery. Only an event that reaches the app does.
- Quitting stops the receiver and removes only the socket it owns. Other files, symlinks and live listeners are left alone.
- The helper never forwards transcripts, commands or raw tool input. Prompt and reply previews are display-only
  ([0019](../../decisions/0019-show-prompt-and-reply-previews.md)).
- Missing terminal metadata is valid ([0012](../../decisions/0012-support-terminal-independent-operation.md)).

## Out of scope

- Session ordering, requests and unknown state: [session-state](session-state.md).
- Installing hooks: [codex-setup](codex-setup.md) and [claude-setup](claude-setup.md).
- Replies to agents: the [actions specs](../README.md#actions).
- Persistent history, retries, acknowledgements and disk spooling.

## Open work

- Check live operation in a terminal other than Otty with both providers and no Otty installed.

## Decisions

[0004](../../decisions/0004-receive-agent-hook-events.md) hooks,
[0005](../../decisions/0005-use-a-local-unix-socket.md) helper and socket,
[0008](../../decisions/0008-define-event-ordering.md) ordering,
[0012](../../decisions/0012-support-terminal-independent-operation.md) terminal independence.
