# 0027: Support local desktop coding sessions

- Status: accepted
- Date: 2026-11-24
- Amends: [0026](0026-any-agent-version-and-any-terminal.md) and the desktop exclusion in the [companion spec](../specs/notch-companion.md)

The user wants to use Bunlet on their personal MacBook with ChatGPT and Claude desktop. Requiring standalone terminal installations would make those desktop workflows dependent on extra setup.

Bunlet falls back to the coding runtimes installed by ChatGPT and Claude and uses the same local hooks as terminal sessions. A reported Codex desktop session with a UUID can open its thread in ChatGPT. A reported local Claude Code desktop session brings Claude forward. Fresh installation includes starting a new local coding session in each app and checking that Bunlet shows its activity and routes back to the host.

See [desktop coding sessions](../specs/sessions/desktop-coding-sessions.md) for acceptance evidence.
