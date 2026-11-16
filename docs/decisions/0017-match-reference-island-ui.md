# 0017: Match the reference island's visible UI, keep Bunlet's behavior

- Status: accepted
- Date: 2026-11-12
- Supersedes: the 2026-11-02 "use both references as inspiration, do not copy either app's complete UI" choice in
  [companion UI direction](../notes/companion-ui-direction.md#accepted-product-choices)

## Context

Bunlet already has a native Swift core: event bridge, session store, usage, local actions and pet runtime.
Its island, settings and pet panel were designed as an original interface that borrowed the reference island's hierarchy only.
On 2026-11-12 the user asked for Bunlet to be a Swift version of the reference island with their own decisions,
preferably with the same UI. The reference's source repository is not readable by the user's account; the installed
The reference island 0.1.25 bundle is readable and records the layout, sizes, colors and timings.

## Options

- **Keep an original UI:** retains the 2026-11-02 direction; does not give the user the reference look they want.
- **Match the reference's visible UI on the existing Swift core:** gives the requested look; keeps tested behavior and storage.
- **Rewrite the whole app after the reference's architecture:** discards a tested native core for no visible gain.

## Decision

Match the reference island's visible UI for the island (pill and panel), the Settings window, and the pet with its session panel.
Keep the existing Swift core and replace the presentation layer.
Use the installed 0.1.25 build as the reference; do not request access to the source repository.
Describe the reference UI in [the UI notes](../notes/reference-ui.md) so work does not depend on the installed app.

Bunlet keeps these behaviors where the reference differs:

- The pet remains a separately installable feature ([D7](../DECISIONS.md#d7-install-and-uninstall-features-from-settings),
  [0013](0013-separate-standalone-pet-scope.md)). Settings keeps a Features page for Pet, Notch and Agents.
- Silence, process exit or a timeout never marks a session complete. Unknown stays visible.
- Follow-ups are never typed into a terminal. Only verified local reply channels get buttons.
- Supported agents remain Claude Code and Codex.
- Sessions with a confirmed pending request sort first.
- The reference UI that has no Bunlet data behind it (subagents, cloud agents, token counts, update tags) is omitted.

## Reasoning

The user explicitly prefers the reference's UI and their own product decisions. Reusing the core keeps 194 passing tests
and the accepted storage, pet and integration decisions intact.

## Consequences

The reference's artwork, agent logo images, ByteSans font and sounds are internal ByteDance assets and are not copied into this repository.
Bunlet uses SF Symbols, the system font and its own artwork, so the result matches layout and behavior rather than pixels.
Prompt/reply text in rows is decided separately in [0019](0019-show-prompt-and-reply-previews.md);
usage hover details in [0018](0018-restore-usage-hover-details.md).
Screen captures remain prohibited, so visual comparison is done by the user.
