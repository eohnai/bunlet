---
summary: Bunlet tracks Codex in the ChatGPT app and Claude Code in the Claude app, and clicks return to that app.
---

# Desktop coding sessions

## How it works

Bunlet finds the coding runtimes bundled with the ChatGPT and Claude desktop apps, even with no standalone CLI, and
sets up the same owned hooks as for the CLIs. If Claude's runtime is not downloaded yet, opening Claude's Code tab once
downloads it, and Bunlet picks it up while running ([0029](../../decisions/0029-automate-desktop-agent-setup.md)).
Codex still asks the user to review the new hooks. After that, a fresh thread, or an existing one after a config
reload, sends events.

Clicking a desktop session opens the observed Codex thread through the `codex` URL scheme, falling back to activating
the ChatGPT app when macOS rejects the URL. A Claude desktop session brings the Claude app forward.

## Requirements

- Setup preserves other settings and the normal hook review, as for the CLIs.
- Bunlet runs from /Applications on Apple silicon, macOS 14 or later. Release builds have an ad-hoc code signature and
  are not notarized.

## Open work

- Check on screen: permission notifications, completion alerts and return navigation for both desktop apps.

## Decisions

[0027](../../decisions/0027-support-local-desktop-coding-sessions.md),
[0029](../../decisions/0029-automate-desktop-agent-setup.md).
