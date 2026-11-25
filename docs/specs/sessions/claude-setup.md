---
summary: Bunlet installs, repairs and removes its Claude Code lifecycle hooks and, separately, its quota status-line wrapper.
---

# Connect Claude Code

## How it works

Claude Code follows the same automatic setup as Codex: on by default, connected at launch when none of Bunlet's hooks
are present, repaired when its owned entries drift, and picked up when the Claude desktop runtime appears later.

**Lifecycle hooks.** Connect adds command groups to `~/.claude/settings.json`, each running the helper with
`--agent claude`: the seven core events, `SubagentStart` and `SubagentStop`
([0025](../../decisions/0025-adopt-more-reference-behavior.md)), and `StopFailure`
([0030](../../decisions/0030-keep-requests-visible-and-report-failures.md)). Older owned installs gain missing groups in
place. Other settings, other apps' hooks, trust and permissions are untouched. Bunlet never sets `disableAllHooks` or
`allowManagedHooksOnly`.

**Quota forwarding.** A separate operation wraps the existing `statusLine` command with `NotchPetStatusLine`, which
forwards quota readings and still runs the original command with its output. Bunlet stores the original value
privately and restores it on removal. If another app replaces the wrapper, Settings shows **Replaced outside Bunlet**.
Connect wraps the new value and Remove clears only Bunlet's record
([0031](../../decisions/0031-recover-a-replaced-claude-status-line.md)).

Lifecycle hooks, quota forwarding and local-response hooks share one writer lock and recover pending journals before
any change. Disconnect pauses intake first, then removes response hooks, quota wrapping and lifecycle hooks. A partial
failure stays paused and says what already happened.

## Requirements

- Edited, missing or duplicated owned entries conflict and are not rebuilt over the user's edits.
- Remove works from the ownership record even if the CLI or old helper is gone. A moved app may need Remove, then Connect.
- Setup never adopts an unowned entry that only looks like Bunlet's.
- Any Claude Code version connects. Version 2.1.306 is recorded as tested.

## Open work

- Check install, repeat install, interruption recovery and conflicts against a disposable real Claude Code setup.
- Check workspace trust and event coverage, including `StopFailure` and subagent payloads, in a real session.
- Check status-line output, cancellation and restoration in a disposable setup.

## Decisions

[Provider setup contract](../../contracts/provider-setup.md),
[0024](../../decisions/0024-repair-hooks-and-connect-quota-at-launch.md),
[0029](../../decisions/0029-automate-desktop-agent-setup.md),
[0031](../../decisions/0031-recover-a-replaced-claude-status-line.md).
