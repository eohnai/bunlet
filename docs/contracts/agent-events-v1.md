# Agent event contract, version 1

Accepted with [decision 0008](../decisions/0008-define-event-ordering.md).

When Claude requests command approval, the app must identify the session and distinguish that request from an old message.
This contract defines the helper's message and the receiver's handling rules.

## Scope and boundaries

The helper reads one hook payload and projects only the fields listed below.
The app's agent adapter translates that projection into a shared session event.
The shared store applies the ordering rules.
Usage snapshots use a separate future contract.

Version 1 supports the seven hook names exercised in the [event investigation](../notes/agent-event-compatibility.md).
Controlled hook dispatch does not establish normal interactive Otty behavior.
`Interrupt`, `StopFailure`, notifications, MCP elicitation, and subagent lifecycle messages are outside this version.
They need coverage checks and a contract revision before acceptance.
A response stop means response ready. It does not mean task success.

## Wire message: HookEnvelopeV1

Send one UTF-8 JSON object followed by one LF byte (`0x0a`).
An envelope is a message with identity and timing fields around the projected hook data.
There is no acknowledgement or reply body.

```json
{
  "version": 1,
  "event_id": "00000000-0000-4000-8000-000000000001",
  "agent": "claude",
  "session_id": "fictional-session",
  "hook_event_name": "PermissionRequest",
  "observed_at_ms": 1000000,
  "turn_id": "fictional-turn",
  "tool_name": "Write",
  "cwd": "/example/project",
  "terminal": {"kind": "otty", "pane_selector": "fictional-selector"}
}
```

The timestamp above is fictional. Actual timestamps use milliseconds since the Unix epoch.
The helper creates `event_id` once per invocation, using a random UUID.
Repeated delivery of the same message must preserve that ID and every field.
Two invocations for the same source hook can have different IDs. The store must also merge matching request identities.

| Field | Required | Rule |
|---|---|---|
| `version` | yes | Integer `1`; booleans are not integers |
| `event_id` | yes | Lowercase canonical UUID text, 36 ASCII bytes |
| `agent` | yes | `codex` or `claude` |
| `session_id` | yes | Source session ID; 1–256 UTF-8 bytes |
| `hook_event_name` | yes | One hook name from the mapping table below |
| `observed_at_ms` | yes | Integer from 0 through 9007199254740991 |
| `turn_id` | no | Source turn identity; 1–256 UTF-8 bytes |
| `tool_use_id` | no | Source tool-call identity; 1–256 UTF-8 bytes |
| `tool_name` | for tool hooks | Source tool name; 1–128 UTF-8 bytes |
| `cwd` | no | Absolute source project path; 1–4096 UTF-8 bytes |
| `terminal` | no | `kind` and `pane_selector`, plus `socket` and `app` where the kind allows them (decisions 0025, 0026): `otty` (1–256-byte selector); `tmux` (`%N`, absolute `socket`, optional outer `app`); `apple_terminal` (`/dev/ttysN`); `iterm` (session UUID); `wezterm` (pane number); `kitty` (window number, absolute `socket`); `editor` and `app` (bundle identifier) |
| `prompt_preview` | no | `UserPromptSubmit` only; display preview of the prompt, 1–1024 UTF-8 bytes |
| `reply_preview` | no | `Stop` only; display preview of the last assistant message, 1–1024 UTF-8 bytes |

Reject unknown fields, explicit nulls, duplicate object keys, invalid UTF-8, and non-finite JSON numbers.
All strings must exclude Unicode control characters and unpaired surrogates.
Count encoded UTF-8 bytes, rather than characters.
Reject oversized fields. Never truncate an identity or path.
The only nested object allowed is `terminal`; arrays are not allowed.
There is no free-form payload field.

For Claude, project `prompt_id` into `turn_id`. For Codex, project `turn_id` unchanged.
Project `tool_use_id` only when the source supplies it.
Do not invent missing source identities or a source sequence number.
`tool_name` is required for `PreToolUse`, `PermissionRequest`, and `PostToolUse`.
It is forbidden for the other hooks. `tool_use_id` is also forbidden for non-tool hooks.

Omit commands, file contents, question text, answers, transcript paths, credentials, and raw tool input.
Do not open a transcript to fill a missing field.

Since [decision 0019](../decisions/0019-show-prompt-and-reply-previews.md), two display previews are the only conversation text:
the helper projects the source `prompt` into `prompt_preview` and `last_assistant_message` into `reply_preview`.
It collapses whitespace and control characters to single spaces, drops format characters, and cuts the text to
200 characters (ending with `…`), then to 1024 UTF-8 bytes. Unlike identities and paths, previews may be truncated.
A non-string or empty source value is omitted. The app keeps previews in memory for display only;
they are never logged, persisted, or used as lifecycle or health evidence.

### Hook mapping: SourceHookV1

| Hook | Shared meaning | Additional rule |
|---|---|---|
| `SessionStart` | Session observed idle | Not a heartbeat or a source sequence boundary |
| `UserPromptSubmit` | A turn started | Supplies the baseline for working state |
| `PreToolUse` | Tool observed | Does not itself clear any input request |
| `PermissionRequest` | Approval needed | Classify question tools before command approval |
| `PostToolUse` | Tool finished | Clears only a matching request |
| `Stop` | Response ready | Clears requests only for the matching current turn |
| `SessionEnd` | Session ended | Creates a terminal record for this app run |

Codex `request_user_input` and Claude `AskUserQuestion` identify structured questions.
A `PreToolUse` or `PermissionRequest` for either provider's matching tool means question needed.
Other `PermissionRequest` events mean approval needed.
Repeated question openings for the same tool call produce one request.
A permission event without a tool-call ID must not be guessed to match another opening.
Natural-language questions remain response ready when no dedicated source event identifies them.

## Identity and evidence

The session key is `(agent, session_id)`. A folder, process ID, or pane selector is not a session key.
Equal session IDs from different agents remain separate.
Two source session IDs in the same folder also remain separate.

The request key is `(current turn, tool_use_id)` when both identities are available.
Otherwise, retain an unidentified request keyed by `event_id`.
Different requests must not overwrite each other.
A repeated opening with the same request key merges into the existing request.
If its request kind or tool name changes, the latest opening replaces the request.
A matching `PostToolUse` has the same turn, tool-call ID, and tool name, and closes that request.
A `PostToolUse` with no exact match closes the oldest unidentified request with the same tool name.
Display needs no exact match. Local replies stay safe because each reply returns to the exact waiting hook
([local actions](local-actions-v1.md)).
Any `Stop` closes every open request, because the agent then waits for the user.

`terminal` is an unverified navigation hint.
It never proves activity, working state, account identity, or permission.
The future terminal adapter must validate it against live Otty state and this source session.
Absent, closed, stale, or ambiguous matches make navigation unavailable.
Never open a replacement pane automatically.

## Ordering and shared state: SessionObservationV1

Hooks do not supply a verified total source order.
The helper's timestamp records when it read the hook, not when the agent produced it.
Receipt order and UUID order cannot establish source order.
There is no unknown state. The latest event decides a session's state
([0035](../decisions/0035-remove-the-unknown-session-state.md)). A wrong state lasts only until the next event.

The store keeps a capture-time watermark, current turn, known retired turns, pending requests, and seen event IDs per session.
It also keeps receipt time.
A session keeps its last state until a new observation changes it. Elapsed time alone never changes it
([0034](../decisions/0034-keep-the-last-session-state.md)).

Apply these rules in order:

1. Reject invalid or expired messages before changing session state.
2. Ignore an identical previously seen event ID.
3. If that ID has different contents, ignore the second event.
4. A valid `SessionEnd` takes priority. Set ended, clear requests, and retain a terminal record.
5. After end, a `SessionStart` or `UserPromptSubmit` reopens the session, because agents resume with the same ID.
   Reopening retires the ended lifecycle's turn. Ignore any other event after end.
6. For any other unseen event, compare `observed_at_ms` with the watermark.
7. A lower timestamp is out of date. Ignore it. An equal timestamp applies in arrival order.
8. An event for a retired turn is delayed. Ignore it.
9. Apply the transition below, and advance the watermark when the state changes.

| Incoming event | Transition |
|---|---|
| First `SessionStart`, or a start that reopens the session | Idle; a later start in a live session changes nothing |
| `UserPromptSubmit` | Working with a new turn; retire the previous turn and close its requests |
| Repeated submit for the current turn | Leave state unchanged |
| Non-question `PreToolUse` | Working, unless a request is open; also after a stop |
| Question opening or approval request | Add or merge the request; question needed or approval needed; also after a stop |
| `PostToolUse` | Close its request as described above; working if no requests remain |
| `PostToolUse` after a stop | A late copy; leave state unchanged |
| `Stop`, for any turn or none | Response ready; close every request |

Question requests take priority over approval requests when both are open.
A session first seen in the middle of a turn takes its state from that event.
A new prompt always starts a new turn, so an interrupted turn without a `Stop` can never block a session.

## Time and bounded memory

These are initial policy values, rather than measured transport performance.
Changing them requires updating this contract and its cases together.

| Bound | Value | Handling |
|---|---|---|
| Raw hook stdin | 262144 bytes | Drop oversized input before projection |
| Wire frame, including LF | 16384 bytes | Reject before allocating a larger frame |
| JSON object depth | 2 | Reject deeper input |
| Maximum delivery age | 30000 ms | Reject older helper observations |
| Allowed future clock difference | 2000 ms | Reject observations further ahead |
| Sessions per app run | 128 | Refuse new session keys; do not evict a live session or terminal record |
| Event IDs per session | 4096 | At capacity, forget old event and turn IDs and keep applying events |
| Distinct turn IDs per session | 256 | At capacity, forget old event and turn IDs and keep applying events |
| Pending requests per session | 64 | Refuse new requests; retain existing requests without evicting one |

At receipt, record local wall time and monotonic time separately.
Reject an observation older than 30000 ms or more than 2000 ms in the future.
A quiet session keeps its last state, because a finished or waiting session is quiet by nature. If an agent exits
without `SessionEnd`, its last state stays until the island's quiet-session clean-up removes it.

A wake, a backward wall-clock change or a discontinuous clock keeps every state. It clears each session's watermark,
because capture times from before and after the jump cannot be compared. Without this, every later event would look
out of date and the session would never change again.

At app launch, start with an empty live store. Never restore working state from disk.
On reconnect, do not replay stored activity. The helper keeps no spool or session history.
Known ended sessions remain ended until a start or prompt reopens them.
A new app process has no knowledge of earlier sessions. Each session takes its state from the first event it sees.

## Socket lifecycle and failure behavior

Use `/private/tmp/notch-pet-<uid>/events-v1.sock`, outside the repository.
`<uid>` is the current user's numeric ID.
The app owns the directory with mode `0700` and socket with mode `0600`.
Verify directory ownership and type; refuse a symlink or an unexpected owner.
Both endpoints check that the peer has the same user ID.
Same-user access does not authenticate the provider. The app must never authorize agent actions.

Only the app creates the listening socket.
Never unlink an arbitrary existing path. Recover only an owned socket after establishing that no listener is active.
Detailed socket race handling belongs to bridge implementation and verification.

Each connection carries one message. Read at most one bounded frame, then close the connection.
Reject extra bytes if they are already buffered after LF. Never process a second frame on that connection.
Bytes sent after closure cannot create another event.
The receiver handles fragmented reads until LF, its size limit, or its deadline.
A truncated frame, invalid object, unsupported version, or read timeout makes no store change.
There is no version fallback and no negotiation.

| Deadline | Limit |
|---|---|
| Helper stdin read | 50 ms |
| Helper connect | 50 ms |
| Helper write | 50 ms |
| Total helper operation after executable entry | 250 ms, including parsing and cleanup |
| Receiver frame read after accept | 100 ms total, not reset by each byte |

Enforce a single total helper deadline as well as the phase deadlines.
Process launch time is outside that executable deadline and still needs adapter measurement.
There is one connection attempt and no retry, acknowledgement, queue, or disk spool.
An absent app, busy socket, broken connection, parse error, or timeout drops the message.
A successful write does not prove that the app applied the message.

For every handled failure, the hook helper returns exit `0` with empty stdout.
It must never output an approval result, change an agent decision, or send terminal input.
Routine stderr is also empty. Optional diagnostics use fixed reason codes without payloads or source identifiers.
The future setup task must also bound execution through each agent's hook configuration.
These are implementation requirements; this documentation task does not test real process deadlines.

## Version changes and checks

Reject any version other than integer `1`, including boolean `true`.
Version 1 rejects new fields and hook names; coordinate any wire extension through a new version.
Keep the socket suffix aligned with the wire version.
Do not reinterpret old version-1 fields after deployment.

The [fictional cases](agent-events-v1-cases.json) contain no captured session data.
Run `python3 scripts/check-event-contract.py` from the repository root.
It checks message validation and a small reference state model against independent expected results.
The checker is a design aid, not the production parser, adapter, or store.
The next tasks must test their actual implementations against these same requirements.
