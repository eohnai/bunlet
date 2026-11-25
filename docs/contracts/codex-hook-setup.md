# Codex lifecycle hook setup contract

How Bunlet adds, repairs and removes its own Codex hooks. The [provider setup contract](provider-setup.md) extends the
same rules to Claude Code and Cursor CLI. Known disabled or managed-only hook policy blocks setup, and unknown policy is
labelled unverified. Bunlet grants no trust or permissions. The [Codex setup spec](../specs/sessions/codex-setup.md)
describes the user-facing behavior.

## Existing requirements

The [Codex setup spec](../specs/sessions/codex-setup.md) requires reversible,
idempotent setup that preserves unrelated settings and hook trust review.
[Decision 0004](../decisions/0004-receive-agent-hook-events.md) accepts lifecycle hooks;
[decision 0005](../decisions/0005-use-a-local-unix-socket.md) accepts the silent observer helper.
The [version-1 event contract](agent-events-v1.md) remains unchanged.
Approval decisions, question answers, and follow-up submissions belong to A1–A2's separate action contract.

I3 will provide setup services. I5 will implement removal, and I6 will expose user actions and
verify isolated agent-to-menu delivery. This proposal describes the removal guarantees that
installation must make possible; it does not move I5 or I6 into I3.

## Version, path, and configuration gates

- Use the versions and limitations in the [compatibility record](../notes/agent-event-compatibility.md).
  Its recorded Codex versions are evidence, not a supported version range or proof of complete
  interactive behavior. Unknown, missing, or failed version evidence prevents installation until
  the relevant version and configuration shape are verified and accepted.
- Installation must establish that lifecycle hooks can be enabled through a supported mechanism.
  Recognized `hooks.json` structure does not establish feature enablement. This proposal does not
  authorize edits to `config.toml`, enabling unrelated features, or guessing a configuration API.
  If a separate enablement step is required, report it for review before writing hook entries.
- Use the effective Codex configuration directory, respecting the existing bounded absolute-path
  handling of `CODEX_HOME`; do not silently fall back from an invalid override to another directory.
  Resolve only the intended hook file and app-owned setup records. Do not inspect auth files,
  credentials, transcripts, or unrelated configuration values for diagnostics.
- Use the bundled helper through an explicit absolute path. Validate executable availability;
  a directory, unresolved location, or missing helper prevents installation.
- Accept only a verified hook JSON shape. Reject malformed input, duplicate object keys,
  ambiguous ownership, unsupported managed-entry shapes, and resource-limit violations without
  modifying configuration. Unknown unrelated fields must be preserved; if safe preservation
  cannot be established, return an unsupported-shape result.
- Bound input and candidate output to 262144 bytes each, matching I2's hook-read limit.
  Refuse symlink or nonregular file targets and unsafe directory paths before writes. The
  installer must define and verify its path checks, concurrent-update protection, and file
  permission handling before implementation; checking a pathname once is insufficient.

These are proposed installation gates, not new claims about the unverified I2 probe implementation.

## Managed entries and preservation

Install only the seven event names implemented by `CodexEventAdapter`:
`SessionStart`, `UserPromptSubmit`, `PreToolUse`, `PermissionRequest`, `PostToolUse`, `Stop`, and `SessionEnd`.
Keep app entries separate from existing groups and handlers. Do not replace a whole event's array,
merge an existing user handler into an app-owned group, or infer ownership from array position.

Each managed invocation must call the helper with exactly `--agent codex`, preserving stdin
and the inherited pane hint. Paths containing spaces or shell metacharacters must remain one
executable path; verify command construction without running user-supplied commands.
Any ownership marker must use verified configuration syntax or reviewed command construction,
not unsupported helper arguments. Do not add unverified provider fields to label entries.

Specify an agent-enforced execution timeout using the verified version's supported syntax.
The exact value and provider representation remain open pending review of that syntax and the
existing process-launch evidence. The helper's internal 250 ms shared deadline remains unchanged;
process launch adds time, so that deadline alone cannot bound the complete hook invocation.
No wrapper may print an approval response, convert failure into a grant, or wait indefinitely.

Preserve unrelated hooks, their execution order, and all unrelated JSON values. A repeated install
with matching managed entries and helper location must leave the configuration bytes unchanged.
Formatting changes during a real edit are permissible only if unrelated values and handler order
remain intact; a serializer that changes numeric values or drops fields fails this requirement.
Do not restore a whole-file backup over subsequent user edits.

## Ownership design

I3a originally approved documenting alternatives only. The user subsequently selected a separate
ownership file. Its preservation rationale below comes from the reviewed recommendation.

**External ownership record with exact managed-entry descriptions — accepted representation, 2026-10-28.**
The user selected a separate ownership file. The detailed schema and recovery protocol remain proposed.
Keep a versioned record under the app's Application Support directory, outside the repository.
Bind it to the target configuration, installation identity, and exact app-created groups/handlers,
including command, matcher, and timeout fields. Store only app-created data, not unrelated
commands or a copy of the user's configuration. A digest can assist comparison but does not
replace the owned-entry description or prove uniqueness.

Compare the current owned entries with the record before reuse, update, or removal. Reordering
unrelated groups must not break ownership. Missing, changed, or duplicated candidates must produce
a conflict rather than broadening the match or adopting an existing command. This gives removal
a record of what installation actually added, but updating configuration and a separate record
requires an explicit interruption/recovery protocol.

**Markers in managed entries without a separate ownership record — alternative, proposed.**
A stable identifier in a verified entry field or reviewed command representation avoids a second
ownership file. Its provider compatibility must be established first. A copied marker or a later
edit cannot be treated as proof that the entire entry is still app-owned. The design must explain
how it detects such edits without deleting user work; marker presence or helper-name matching
alone is insufficient.

**Decision: separate ownership file accepted.** Entry markers were considered and rejected as the
sole ownership mechanism. I3b must settle the record schema, collision rules, and recovery protocol
before writing code. This choice authorizes neither trust bypasses nor whole-file replacement.

## Application, interruption, and removal requirements

Prepare and validate the full candidate before changing the hook file. Refuse an unsupported
version, invalid helper, malformed file, ownership conflict, or concurrent edit before replacing it.
Define protection against concurrent writers without claiming that a pre-write comparison alone
provides an atomic transaction. The supported guarantees and residual external-writer limitations
must be explicit in the approved installer design and its checks.

If the ownership design uses multiple files, enumerate interruption points before the first write,
between writes, and after completion. A journal, if chosen, may retain app-owned data and bounded
identity/digest metadata only. Restart or retry must distinguish a completed install, no install,
and uncertain partial state. Uncertainty must stop with recovery instructions; it must not adopt
lookalike hooks, add duplicates, or overwrite later user edits. Exact recovery states remain open.

I5 removal will validate current ownership and remove only uniquely matching, unchanged app entries.
Preserve unrelated groups and values, including edits made since installation. If any managed entry
or ownership record is conflicting, malformed, or ambiguous, leave configuration untouched and
report a useful bounded category. A missing owned entry also needs explicit reconciliation; it
must not trigger removal of another matching command. Never delete a configuration file that
now contains unrelated data, or restore original file contents as a substitute for targeted removal.

## Trust and health outcomes

Leave normal Codex hook review in place. Do not preapprove hooks, write trust acknowledgements,
use a trust-bypass option, or modify Otty setup. Configuration installation and trust review are
separate outcomes. Keep the seven deferred interactive checks in R6–R7 under
[decision 0009](../decisions/0009-defer-remaining-codex-interactive-checks.md).

Report setup as installed, unchanged, unavailable, or conflicting, with a bounded reason and
recovery action. Do not include raw configuration, commands, process output, or credential values
in diagnostics. I6 will present these messages. Installation does not establish hook execution,
delivery to the app, current session activity, or local-action support. Only a validated app receipt
updates delivery evidence, independently of configuration, helper availability, and receiver state.
