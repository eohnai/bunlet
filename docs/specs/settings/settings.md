---
summary: One native Settings window with General, Agents, Display, Sound, Shortcuts, Statistics and About pages.
---

# Settings

## How it works

**Settings** in the menu bar menu opens one native window with a sidebar. Opening it takes focus, as an explicit
request. It never runs Check, changes hooks or starts monitoring.

- **General:** launch at login, the preferred terminal app, and **Remove all hook configuration**. Behavior: expand
  when a session ends or when action is needed, focus-aware suppression, open on hover, haptic feedback, collapse when
  the pointer leaves, and reminder duration (3, 5, 10 or 30 seconds). Visibility: always hidden, hide in fullscreen and
  hide when there are no sessions. Sessions: **Clear quiet sessions after** and maximum panel height.
- **Agents:** one switch per agent, with setup status. Advanced holds Connect, Check, Remove, quota forwarding,
  local responses, **Approve in** for Codex and the evidence described in
  [integration health](../sessions/integration-health.md).
- **Display:** which display shows the island, pet size from 50% to 150%, pet artwork imports, and the top row's
  items: Claude Code and Codex usage limits, today's tokens, and whether usage shows percent left or used.
- **Sound:** sound on or off, volume, and one switch per event: app launch, session start, task complete, task fails
  and action needed. Sounds are macOS system sounds.
- **Shortcuts:** seven rebindable shortcuts: toggle the island, collapse, approve, always allow, deny, jump and switch
  session.
- **Statistics:** [token statistics](../telemetry/statistics.md).
- **About:** version and **Check for Updates** ([software updates](software-updates.md)).

If part of Bunlet fails to start, Settings shows it with a Retry button. Preferences live in `UserDefaults`.

**Name.** The app is called Bunlet ([0016](../../decisions/0016-use-bunlet-name.md)). Internal names stay as they were:
the bundle identifier `local.notchpet.dev`, the `NotchPet` executables, resource names, preference keys and the
`NotchPet` folder in Application Support.

## Open work

- Check on screen: Settings focus, keyboard use and each page's controls.
- Launch at login may be refused for a development build run from a temporary folder. Settings shows the reason.

## Decisions

[0016](../../decisions/0016-use-bunlet-name.md),
[0021](../../decisions/0021-settings-scope.md),
[0022](../../decisions/0022-close-reference-settings-gaps.md).
