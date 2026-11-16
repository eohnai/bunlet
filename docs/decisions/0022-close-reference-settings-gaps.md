# 0022: Add the reference island's missing Claude Code and Codex settings

- Status: accepted
- Date: 2026-11-16

## Context

A comparison with the installed reference island (0.1.25) found settings Bunlet lacked for its two supported agents.
The user approved closing those gaps and tidying the Settings pages. Decision 0021 had left out idle-session clean-up and key choice.

## Decision

Amend [0021](0021-settings-scope.md) with:

- **Always allow** for Claude Code permission requests, with its own shortcut. The button and shortcut appear only when
  the request carries Claude's `permission_suggestions`; Bunlet sends that list back unchanged as `updatedPermissions`.
  Codex has no local actions, so it gets no such button.
- **Rebindable shortcuts:** one shared modifier (Control, Option or Command) and a key picker per shortcut, with a per-shortcut
  switch, a conflict warning and Restore Defaults. Esc never uses the modifier. Adds always allow and switch session.
  The jump key stays ⌃↩ by default. There is no key-recording field.
- **Visibility:** always hidden, hide in fullscreen (default on), hide with no sessions, and open on hover (default on).
  An open island is never hidden by these options.
- **Sessions:** idle and ended sessions leave the list after 30 minutes to 7 days (default 7 days). Working sessions and
  sessions that need attention always stay. The store's evidence is unchanged; only the list is shorter.
- **Usage display:** percent left (default) or percent used. Level colors still follow percent left.
- **Sound:** a launch sound joins the existing three events.
- **Settings layout:** one file per page, shared rows for menus, sliders and footnotes, agent messages shown as row subtitles,
  and pet customization and per-agent setup collapsed by default.

## Not built

Task-error and context-limit sounds (Bunlet has no such events), a token-count pill item (no token data), a preferred-provider
setting (the two limit switches cover it), a separate auto-collapse delay (the reminder duration covers it), and the reference's
other agents, Feishu, SSH and cloud features.

## Consequences

Fullscreen detection reads window bounds only, as display following already does. Hot keys are registered from a clean slate
whenever a key, modifier, switch or request changes. Nothing here was run on screen.
