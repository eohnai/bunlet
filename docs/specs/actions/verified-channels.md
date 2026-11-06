# Local response channels

Status: source implementation complete to the documented contract; runtime unverified.

The approved full MVP goal permits documented channel implementation without running tests/builds or
runtime qualification. [Local actions v1](../../contracts/local-actions-v1.md) defines exact identities,
bounds, acknowledgements, cancellation and failure behavior before the implementation.

Implemented source: `AgentActions` protocol, Claude projection/response adapter, private stream receiver,
bounded inbox, transient action store and packaged `NotchPetActionHook`. App-owned
`LocalActionController` validates current SessionStore evidence before each native Send, cancelling on
pause/staleness. Notch controls use the same service. No lifecycle fields, settings/trust/permission flags,
terminal keystrokes or transcript reads are used to respond.

At most 32 sockets and 128 queued delivery events are retained. Overflow closes action channels rather
than dropping identity/acknowledgement state silently. Requests wait at most 60 seconds; runtime receipt
only proves helper stdout completion. Lost/partial delivery stays uncertain and cannot be replayed.

Guarded Connect/Check/Remove uses a separate Claude actions ownership/journal scope under the shared
writer lock. PermissionRequest and Stop use the interactive helper; PreToolUse matches AskUserQuestion.
Settings offers explicit consent, pause/resume and the same composers independently of Notch. Claude
Disconnect disables responses, then removes actions, quota and lifecycle scopes with partial-failure
reporting. Installation remains separate from runtime delivery. See the full-goal turn-4 source audit.

Codex remains unsupported for local actions. Claude callbacks are documented/unverified, scoped to the
exact live invocation. See the per-action specs for capability limits. All original A1–A8 acceptance and
native/runtime checks remain open. No test or build command ran for this source work.
