# Claude Code setup

Status: implementation merged in PR #16; feature acceptance remains deferred.

Needs: integration-health, notch/session-island


Merged evidence: [full MVP handoff](../notch-companion.md#merged-mvp-handoff-2026-11-06). Hosted build/package, existing tests and
coverage checks passed at `ab2ae13`. This is not feature-specific native/provider acceptance;
historical results and unrun acceptance checkboxes retain their original meaning.

## Scope and approval

The full MVP task list authorizes source implementation of Claude setup, independent monitoring,
quota wrapping and removal. This fulfills the Claude portion of source I4/I5/I6 without migrating
or ticking their historical verification tasks. Local checks and feature-specific native/provider qualification remain NOT RUN; hosted evidence is recorded above.

## Contract

Use [provider setup](../../contracts/provider-setup.md) and the existing descriptor-relative ownership
transaction. Lifecycle Connect adds seven separate command groups to settings.json, each invoking
the bounded observer as `--agent claude`. Other settings, Otty hooks, trust and permissions stay intact.
Check reports version, shape, bundled helper, owned entries, policy, receiver and observed delivery
separately. The documented 2.1.306 binding is unverified; user settings do not establish effective
project/managed policy. Never set disableAllHooks/allowManagedHooksOnly or change policy automatically.

Repair recovers known journal states and reinstalls unchanged owned configuration idempotently.
Edited/missing/duplicated owned entries conflict rather than being reconstructed over a user's edits.
Remove works from exact ownership when the CLI or old helper has disappeared. A moved app may need
Remove then Connect at its new location; setup never adopts an unowned lookalike.

Quota setup is a separate statusLine operation. It wraps the original shell command, preserves field
members and stores the exact original value privately for restoration. Absent original status lines
use silent forwarding. The original value is restored only while the complete owned field matches.
Lifecycle, quota and local-action scopes share a writer lock and recover known pending journals
before changing settings. Disconnect pauses intake and disables responses first, then removes owned
local-action hooks, quota wrapping and lifecycle hooks. A
partial failure leaves monitoring paused and reports what already happened.

## Source implementation

- CL1: documented release/policy, timeout/limits, ownership/recovery and removal contract above.
- CL2: `HookSetupPlanner` now accepts typed Claude input and preserves unrelated JSON bytes.
- CL3: `ProviderSetupService` → `ProviderHookTransaction` → `HookFileDirectory` guarded installation.
- CL4: scoped exact removal/journal recovery without provider execution or trust grants.
- CL5: `ProviderSetupController`/`ProviderSetupView`, app-owned controllers and both menu submenus.
- Separate quota planner: `ClaudeStatusLinePlanner`, with its own ownership and pending record names.

These are source findings. Hosted CI establishes compilation, packaging and the existing suite result. Installed configuration,
hook execution, terminal output/cancellation, native focus and real Claude session results remain unverified.

## Deferred acceptance

- [ ] Confirm guarded install, unchanged reinstall, interruption recovery and conflict preservation.
- [ ] Confirm normal workspace trust and event coverage with a real supported Claude session.
- [ ] Confirm exact status-line I/O, cancellation, exit and owned restoration in a disposable setup.
- [ ] Confirm both providers can pause/resume/disconnect independently with retained notices.

No acceptance command was run. Original I4/I5/I6 checks remain with the source specification.
