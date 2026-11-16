# Local provider setup implementation policy

Merged implementation and verification scope: [MVP handoff](../specs/notch-companion.md#merged-mvp-handoff-2026-11-06).
PR #16 has hosted build/test/package evidence; live provider/native qualification remains deferred.
Earlier implementation-run NOT RUN statements below describe that stage, not the subsequent CI result.

Selected under the approved full MVP goal, 2026-11-06. Tests, builds and runtime qualification are
explicitly deferred. This supersedes only the old qualification-before-installation gate; it does
not grant hook trust, change permissions, or call a documented integration runtime-qualified.

- Keep separate documented and runtime-qualified support. Documented setup initially covers the
  repository's inspected Codex 0.164.0 and Claude Code 2.1.306 release shapes. Other versions require
  a matching supported binding; a numeric version alone cannot claim compatibility.
- Check may run bounded read-only version/configuration inspection when explicitly invoked in the
  shipped app. This implementation run does not execute it or read installed configuration.
  Codex policy uses initialized app-server `config/read` and `configRequirements/read`, projecting
  only hook flags. Launch uses `codex app-server`'s documented default stdio transport; no `--stdio`
  flag is sent. Missing/malformed/unsupported policy fields are unknown. A known disabled or
  managed-only policy prevents installation; unknown policy permits an explicitly unverified
  installation, with clear guidance that hooks may not run. No settings are enabled automatically.
- Codex writes only hooks.json; Claude lifecycle writes only the hooks subtree in settings.json.
  Both use separately owned command groups, shell-quoted absolute helper paths and timeout 3s.
  The silent observer helper keeps its own 250ms deadline. Existing settings/statusLine are preserved
  byte for byte. No hook command is run during planning or setup.
- The same descriptor-relative guarded transaction owns locking, candidates, journal, digest and
  identity rechecks, recovery and removal for each provider. Ownership records include the provider;
  a record from another provider/configuration cannot be adopted. Recovery/removal needs no CLI.
  An unchanged owned setup is idempotent. Missing/edited/duplicated owned groups are conflicts;
  Repair runs recovery and reinstalls only after exact ownership validation, never overwriting edits.
- Hook install/repair/remove and quota wrapping are distinct operations. Claude lifecycle removal
  never removes or interprets statusLine. Quota setup retains its own exact original field bytes.
  `ClaudeStatusLinePlanner` owns that field only: at most 64 KiB, command at most 16 KiB, no NUL.
  It quotes the original command as a single wrapper argument and preserves other field members.
  The private quota ownership record/journal may contain that original value for exact restoration;
  it is never printed, logged, uploaded, or expanded into a full configuration backup.
  Lifecycle, quota and interactive-action journals use separate filenames under the same record directory/writer lock.
  A known pending operation in any scope recovers before another settings change. Unknown states
  stop all scopes. Disconnect pauses and disables responses, removes interactive actions, quota wrapping,
  then lifecycle entries; failure between
  scopes is reported as partial removal, never rolled back over edits or blindly replayed.
- Monitoring preferences are per-provider, with the existing global Agents monitoring master switch.
  Pause immediately drops that provider's queued events/refresh, retains unconfirmed requests and
  does not remove hooks. Resume starts a new receipt cutoff; queued old evidence cannot restore
  freshness. Disconnect pauses first, then explicitly removes only owned configuration. Failures
  remain paused, with a recoverable message. Removing Agents stops everything without changing hooks.
- Monitoring, allowance, hooks installed, policy, trust and actual delivery are separate evidence.
  No installed boolean means a provider session is connected. No silence means success.

Setup progress and verification, 2026-11-14:

- Connect reports checking, saving and verification stages in Settings beside the provider.
- Version and policy probes run once per Connect. Post-save verification rereads configuration,
  helper availability and ownership without relaunching the CLI. Version and policy evidence comes
  from that operation's preflight. An explicit Check always probes again.
- This removes duplicate process startup. It does not remove the pre-install policy gate or durable writes.
- Setup errors remain visible without opening the provider's details.

Primary interface links:
[Codex hooks](https://learn.chatgpt.com/docs/hooks),
[Codex app-server](https://learn.chatgpt.com/docs/app-server),
[Claude hooks](https://code.claude.com/docs/en/hooks),
[Claude settings](https://code.claude.com/docs/en/settings).

Documented support is an implementation choice under the user's verification waiver. Earlier exact
release qualification records stay historical; the runtime-qualified registry remains empty.
Repair never reconstructs edited/deleted owned groups from guesses. If the app/helper path moved,
remove the old owned entries first, then Connect from the new location. Removal uses the recorded path
and does not need that old helper or the provider executable to exist.

Interactive Claude setup owns PermissionRequest, Stop and an AskUserQuestion-only PreToolUse group,
using the separate action helper and 75-second provider timeout (60-second user window). Its exact
groups, ownership and journal never adopt lifecycle entries. Consent defaults off and enables only after
explicit opt-in; master/provider pause cancels response channels. Settings supports responses without
Notch. Resume alone does not install hooks. Action removal first disables responses; failure stays disabled.
See [local actions](local-actions-v1.md) for the exact provider and receipt limits.
