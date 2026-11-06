# Optional terminal navigation

Status: implementation merged in PR #16; feature acceptance remains deferred.

The user reaffirmed terminal-independent use on 2026-11-06. Monitoring, quota, provider actions, pet
reactions and session identity require no terminal executable or metadata. Navigation is a separate
app-owned capability, with exact-pane, application-only and manual-return results. No terminal is a
prerequisite; no foreground app, folder, transcript or process activity establishes session identity.


Merged evidence: [full MVP handoff](../notch-companion.md#merged-mvp-handoff-2026-11-06). Hosted build/package, existing tests and
coverage checks passed at `ab2ae13`. This is not feature-specific native/provider acceptance;
historical results and unrun acceptance checkboxes retain their original meaning.

## Implementation policy

Users may choose any native application as their preferred terminal. Save its bundle identity/path in
our own preferences; activation requires exactly one matching already-running instance. Never launch
an application or create a pane as fallback. Make clear that app activation does not select a session.

Exact-pane support is adapter-specific. The initial documented binding uses iTerm2's public AppleScript
session `unique id`/`tty` and session/tab/window `select` verbs. Linking is an explicit user action:
select the intended pane in iTerm2, return here and Link current pane to this observed session. This is
a user-owned association, not an automatically verified agent-to-pane mapping. Store it only in memory
under the exact provider/session key, with terminal PID and launch date. Session end/removal drops it.
Before focus, revalidate the same terminal instance and require one unique matching ID/tty; select its
existing objects only and inspect the resulting current session. Conflicting/stale/missing identity
fails closed. A timeout/partial command sequence is uncertain; no automatic retry or app fallback.
Normal macOS Automation consent may be required. Never read terminal content, history or process state.
AppleScript is documented but deprecated by iTerm2; capability remains unverified for installed versions.

Other terminals retain application activation/manual return until a supported adapter exists. Existing
version-1 Otty hints stay untrusted and compatible; they do not authorize navigation by themselves.
The public Otty docs establish focus verbs and closed-selector behavior but do not establish a complete
current machine-readable agent/pane field mapping. No guessed mapping or private bundle/source inspection
is used. Original Otty N1/N2/N6 checks remain unrun and its automatic exact-pane mapping is unsupported.

Bounds: 128 transient bindings, one cancellable navigation worker, 3s worker deadline and 64 KiB per-reply limit,
256-byte ID/tty strings, at most 64 windows/128 tabs or panes per collection/512 panes total.
Direct public Apple Events target the already-validated PID, never a bundle/name launch address.
Only get/select events are sent; no executable scripts or terminal input are constructed. Only explicit native controls
perform lookup/link/focus. Errors are small categories; raw process output is never logged.

Primary interfaces: [iTerm2 scripting](https://iterm2.com/documentation-scripting.html) and its
[public scripting dictionary](https://github.com/gnachman/iTerm2/blob/master/iTerm2.sdef)
(four-character interface identifiers only; no vendor implementation copied).
Terminal independence: decision 0012. No change to the version-1 event wire format.

- [ ] Inspect exact user-linked pane focus, duplicates, close/restart/reused identity, permission denial and uncertain timeout.
- [ ] Inspect application-only/manual return in other local terminals with both providers.
- [ ] Inspect no replacement panes, no terminal input, no transcript reads and preserved selection/notices.


Native cross-application focus is not a transaction with agent lifecycle. The adapter checks before and
after selection, but terminal/user changes during dispatch can produce an uncertain outcome. No
operation is replayed automatically. Sleep cancels the active worker. The package declares the normal
Apple Events usage description; this run did not send Apple Events, request Automation access, inspect
installed terminal configuration or qualify the deprecated scripting interface. No launch/create/write
verb is sent. Open Sessions and Settings remain available without a terminal adapter.
