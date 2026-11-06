# Local actions v1

Merged implementation and verification scope: [MVP handoff](../specs/notch-companion.md#merged-mvp-handoff-2026-11-06).
PR #16 has hosted build/test/package evidence; live provider/native qualification remains deferred.
Earlier implementation-run NOT RUN statements below describe that stage, not the subsequent CI result.

Implementation contract selected under the approved full MVP goal, 2026-11-06. Runtime qualification,
tests and builds are NOT RUN. This contract implements documented channels; it claims no tested support.
The one-way observation envelope/helper and its 250ms deadline remain unchanged.

## Concrete provider channels

Claude Code 2.1.306's documented hook shapes provide the initial concrete bindings:

- PermissionRequest: an explicit approve-once/deny returns the hook decision's behavior. Never emit
  updatedPermissions, permission-mode changes or persistent rules. Provider deny/ask policy still applies.
- PreToolUse for AskUserQuestion: return the original questions/input plus user answers in updatedInput,
  paired with allow. That allow answers this tool invocation; it is not a persistent permission grant.
- Stop: an explicitly submitted follow-up is returned as the blocking reason for this waiting Stop
  invocation. It continues the exact existing prompt as hook feedback, not as a new user-role turn.
  It is available only during the bounded Stop reply window; after that, return manually to the session.
  stop_hook_active=true never opens another window, preventing an automatic continuation loop.

These are [documented hook interfaces](https://code.claude.com/docs/en/hooks), not a transcript reader,
CLI resume/new-session launcher, terminal key injection or background automatic reply. Codex action
capabilities remain unavailable until a separate documented existing-session channel is implemented.
Missing terminal metadata never disables a valid held Claude callback.

## Identity and authority

NotchPetActionHook is separate from NotchPetHook. It projects one bounded actionable invocation into
an offer on a private actions-v1.sock stream. Each offer has version, provider, session ID, prompt/turn
ID, hook kind, tool identity where supplied, random request UUID and capture timestamp. The live socket
is the return route to that exact invocation; a folder/path is never used as routing identity.
Same-user IPC restricts peers but does not authenticate provider binaries.

The app requires fresh matching authoritative SessionStore evidence for the same provider/session/turn.
Permission/questions must match exactly one confirmed pending request; ambiguous matches and competing
offers for the same observed request are unavailable. Stop replies require that turn's response-ready
observation and no unresolved requests. Offers may briefly await observation delivery, never create a
session themselves. Unknown/ended/paused sessions withdraw capability. Request details and drafts live
only in action memory, outside observation data, diagnostics, telemetry and disk.

## Bounds and failure behavior

Wire frames: newline-delimited JSON objects, at most 65536 bytes, depth at most 64, no duplicate keys.
Raw hook input: at most 256 KiB with 250ms read deadline. Tool-input details: at most 16 KiB. At most four
questions, four options each; individual question/answer text at most 2000 UTF-8 bytes, labels 128 and
descriptions 1024. Follow-up text: at most 8192 bytes. No raw assistant text/transcript path is projected.
Only main-session callbacks are accepted; subagent callbacks remain unsupported.

At most 32 connections/offers at once. Initial connect/write/read waits are bounded; the user decision
window is at most 60 seconds, within a 75-second provider hook timeout. New channels after pause have
new generations; pending old sockets are cancelled. Incoming offers never activate a window or take focus.
Only explicit composer interaction may acquire keyboard focus.

Response identity includes offer UUID and a fresh decision UUID. A record dispatches at most once.
The helper validates the response against its original offer and encodes provider JSON itself. It writes
bounded stdout, then acknowledges that write on the socket. The app labels this helper acknowledgement,
never provider acceptance. Transport loss after Send is uncertain, without replay. Lifecycle resolution
still requires subsequent observation; sending cannot remove a pending request or mark working/success.

Cancel/timeout/app loss before a decision emits no provider JSON and exits quietly: the normal terminal
permission/question flow or Stop behavior remains available. Cancellation after dispatch cannot revoke
a possible write and is labelled uncertain. Unsupported/malformed/oversized input also yields no decision.
No automatic denial, approval, follow-up, spool or retry. Drafts belong to the exact offer UUID and cannot
carry across a different request/session. Completed/expired records are bounded and transient.

## Integration

The app owns the optional action receiver/store beside lifecycle/usage services. Native request controls
read both stores and submit through the action service. Actions are independently opt-in configuration:
three separately owned Claude groups invoke the interactive helper for PermissionRequest,
PreToolUse/AskUserQuestion and Stop. They must use the existing guarded writer, separate ownership/journal
scope and normal trust flow. Lifecycle and quota installation/removal remain separate. Disconnect must
remove all unchanged owned scopes while preserving unrelated settings/Otty configuration.

Source implementation and native controls must be audited before this criterion is called implemented.
Runtime hook dispatch, policy, output preservation and provider behavior remain unverified by request.

## Guarded setup and consent

Interactive actions use a third Claude setup scope with actions-ownership-v1.json and
actions-pending-v1.json under the existing private records directory/writer lock. Its exact three
groups have a 75-second command timeout; PreToolUse matches only AskUserQuestion. Any known pending
scope recovers before another Claude settings write. Unknown/edited entries remain conflicts.

Connect actions is explicit and separate from lifecycle/quota Connect. Its confirmation explains
that Stop can wait up to 60 seconds for follow-up feedback, including while the user opens Settings.
Settings offers the same pending response controls when Notch is absent. Installation never opens a
composer or sends an action. A separate app-owned local-response consent defaults off and persists
only after explicit Connect/Resume. The receiver starts only with that consent, Claude monitoring and
the Agents runtime. Pause responses closes pending callbacks while retaining normal monitoring/hooks.
Remove actions disables consent before owned removal; Claude Disconnect disables it and removes actions,
quota wrapping and lifecycle hooks in separate guarded operations. Partial removal remains paused.
