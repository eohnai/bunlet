---
summary: Bunlet installs, repairs and removes its own Codex lifecycle hooks without touching anything else in hooks.json.
---

# Connect Codex

## How it works

Codex is on by default. At launch, and whenever its switch is turned on, Bunlet checks Codex once. If Codex is
found and none of Bunlet's hooks are present, Bunlet connects it without asking. If Bunlet's hooks are present and
recorded as Bunlet's own, it repairs any drift. If the ChatGPT desktop runtime is not installed yet, Bunlet keeps
checking while it runs ([0023](../../decisions/0023-connect-agents-automatically.md),
[0024](../../decisions/0024-repair-hooks-and-connect-quota-at-launch.md),
[0029](../../decisions/0029-automate-desktop-agent-setup.md)).

Connect adds seven command groups to `hooks.json` in the effective `CODEX_HOME`, each running the bundled helper.
Bunlet records exactly what it added in a private ownership file under Application Support. Writes go through a
journal so an interrupted update can be recovered. **Check** is read-only. **Remove** deletes only entries that still
match the ownership record, and works even if Codex is no longer installed. Codex still asks the user to trust the
new hooks, and Bunlet never bypasses that review.

Any Codex version from 0.129.0 connects. Versions with recorded evidence (0.163.0, 0.164.0) show as tested, and others
show as untested ([0026](../../decisions/0026-any-agent-version-and-any-terminal.md)).

## Requirements

- Repeating Connect on matching entries changes nothing and adds no duplicates.
- Unrelated handlers, their order and all other JSON values are preserved byte for byte.
- Edited, missing, copied or ambiguous Bunlet entries are a conflict and are left untouched.
- Unsupported versions, disabled hooks, a missing helper, unsafe paths and invalid configuration produce a short
  message and no change.
- Inputs, outputs, ownership records and recovery data are each limited to 262,144 bytes. Duplicate JSON keys are rejected.
- Bunlet reads no credentials, authentication files or transcripts.
- Turning Codex off, Disconnect and Remove pause it, so the next launch does not add the hooks back.

## Out of scope

- Editing `config.toml` to enable hooks, or bypassing Codex's trust review.
- Coordinating with editors that change `hooks.json` at the same moment. The app lock covers only Bunlet's own writes.

## Open work

- Run Connect, repeat Connect, Check, a visible session in the island, Remove and a conflict case against a disposable
  real Codex installation.

## Decisions

The [setup contract](../../contracts/codex-hook-setup.md) holds the ownership schema, journal and limits.
[0023](../../decisions/0023-connect-agents-automatically.md),
[0024](../../decisions/0024-repair-hooks-and-connect-quota-at-launch.md),
[0026](../../decisions/0026-any-agent-version-and-any-terminal.md),
[0029](../../decisions/0029-automate-desktop-agent-setup.md).
