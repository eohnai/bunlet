# 0026: Accept any agent version and find any terminal

- Status: accepted
- Date: 2026-11-16
- Amends: [0025](0025-adopt-more-reference-behavior.md) and the exact-version setup bindings recorded in
  `docs/contracts/provider-setup.md` and `docs/specs/sessions/codex-setup.md`

## Context

Setup accepted exactly Codex 0.164.0, Claude Code 2.1.306 and Cursor CLI 2026.09.18-9a7762b. This Mac has Codex 0.169.0
and Claude Code 2.1.318, so every agent update stopped setup until a new binding was written. The reference island
(0.1.25) checks no versions for setup. Its only floor is Codex CLI 0.129.0 for hooks-only setup, and it can skip
individual Claude events on older versions (its only such rule is commented out).

Jumping back to a session worked only for Otty, tmux, Terminal and the Cursor/VS Code family. The reference walks the
agent's parent processes to the terminal app and matches about 20 known app names; for some terminals it then selects the
exact pane through the terminal's own command-line interface.

The user approved both changes on 2026-11-16.

## Decision

1. **Any agent version.** Setup accepts any version in the agent's own format, at or above a floor: Codex 0.129.0
   (the reference's hooks-only floor); no floor for Claude Code or Cursor CLI. Versions with recorded compatibility
   evidence (Codex 0.163.0 and 0.164.0, Claude Code 2.1.306) show as tested; others show as "untested" in Settings and
   still connect. Strict event validation is unchanged, so a changed hook payload is dropped, not misread.
   The runtime-qualified registry and the hook-policy checks (disabled hooks, managed-only hooks) are unchanged.
2. **Find the hosting app.** The observer hook walks up to 12 parent processes and reports the bundle identifier of the
   nearest one that runs from an application bundle (the outermost `.app` in its path). This needs no list of terminal
   names. If no parent is found it uses the inherited `__CFBundleIdentifier`. It is reported as terminal kind `app`.
3. **Jump order.** The exact pane or window the hook reported; else the user-linked iTerm2 pane, if there is one;
   else the reported terminal's app; else the application chosen in Settings.
4. **tmux.** After selecting the pane, Bunlet asks the tmux server for the clients showing that pane's session, walks
   each client's parent processes to its app and activates the most recently active one. The inherited app stays a fallback.
5. **More exact panes.** iTerm2 (`ITERM_SESSION_ID`, selected by session unique id with AppleScript), WezTerm
   (`WEZTERM_PANE`, `wezterm cli activate-pane`) and kitty (`KITTY_WINDOW_ID` with `KITTY_LISTEN_ON`,
   `kitten @ focus-window`; needs kitty's remote control, which the user turns on). None is installed on this Mac.
6. Typed follow-ups stay limited to Otty and tmux (0025). No terminal-independent way to type exists that cannot land in
   the wrong window.

## Consequences

An agent update can change hook payloads or the approval reply format without Bunlet noticing until events stop
appearing or a reply is ignored; Settings says "untested" for such versions. The observation envelope's `terminal`
object gains the kinds `iterm`, `wezterm`, `kitty` and `app`. iTerm2 jumps need macOS Automation approval, like Terminal.
The new exact-pane adapters and the tmux client lookup were checked only with fictional data, not against the real apps.
