# Independent provider monitoring

Status: implementation merged in PR #16; feature acceptance remains deferred.

Needs: codex-setup, claude-setup


Merged evidence: [full MVP handoff](../notch-companion.md#merged-mvp-handoff-2026-11-06). Hosted build/package, existing tests and
coverage checks passed at `ab2ae13`. This is not feature-specific native/provider acceptance;
historical results and unrun acceptance checkboxes retain their original meaning.

## Behavior

The user approved source implementation in the full MVP goal. The master Agents monitoring switch
still controls the optional runtime. `ProviderMonitoringModel` adds separate app-owned consent keys
for Codex and Claude. Missing keys preserve an existing global consent; they do not establish a new
provider connection. Explicit provider changes save booleans and fail closed on malformed/failed writes.

Pause withdraws confirmation from only that provider's live sessions, retains requests, and preserves
ended sessions. It cancels Codex reads/retries or stops Claude quota receipt immediately. Lifecycle IPC
is shared; disabled providers are filtered before delivery enters SessionStore. Other providers continue.

Resume sets fresh monotonic receipt and wall capture cutoffs. Queued pre-pause/pre-sleep evidence cannot
restore a session. The existing reducer still requires a valid baseline/new turn and correlation;
resuming cannot imply working, completion, approval or request resolution. Quota receipt has an additional
generation so stopped/restarted receiver queues cannot leak through a surviving Agents runtime.

Disconnect pauses before owned removal, with separate confirmation. Claude restores owned quota wrapping
then removes lifecycle groups. An uncertain/partial removal remains paused and needs explicit Check/retry.
Uninstalling Agents stops all runtime services while leaving provider hooks/settings untouched. Reinstall
preserves preferences but the master monitoring switch stays off until explicitly enabled.

Settings and menu controls call the same models/controllers. Opening Settings reads snapshots; it does
not run Check, alter hooks, start provider processes or enable monitoring. Notch/Pet are optional surfaces.

## Source

`ProviderMonitoringModel.setEnabled` → `PetAppController` → `AgentServices.setEnabledProviders` →
provider filter/cutoffs + `SessionStore.suspendMonitoring(agent:)` + cancellable provider quota work.
`ProviderSetupController.start(.disconnect)` pauses first and uses the scoped ownership service.

## Deferred acceptance

- [ ] Real per-provider pause/resume and fresh-evidence restoration with concurrent sessions.
- [ ] Cancellation, queued delivery, sleep/clock boundaries and preference failure behavior.
- [ ] Disconnect with missing CLI, partial removals, conflicts and journal recovery.

No local checks or feature-specific native/provider qualification were run; hosted evidence is recorded above. These checks remain open; source implementation
does not replace the original shared I5/I6 or native feature acceptance requirements.
