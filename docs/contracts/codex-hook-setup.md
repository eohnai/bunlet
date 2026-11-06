# Codex lifecycle hook setup contract

2026-11-06 implementation addendum: the user explicitly requested the full code implementation with
runtime qualification left unverified. [Provider setup](provider-setup.md) replaces the historical
qualification-before-installation gate with separate documented and runtime-qualified support.
Known disabled/managed-only policy still blocks setup; unknown policy is labelled unverified. No
trust or permissions are granted. The ownership/recovery and concurrent-editor guarantees below
remain in force. Earlier acceptance history and checkboxes are unchanged.

Status: design accepted, 2026-10-30. The user accepted the separate ownership file and the I3b1 design choices.
The [accepted I3b1 review](#i3b1-review-2026-10-30) governs where it refines the historical proposals below.
Task-level implementation plans, prerequisite closure, and runtime qualification remain separate gates.
No hook installation, configuration access, or runtime verification is established by this document.

## Existing requirements

The [specification](../specs/notch-companion.md#setup-and-connection-health) requires reversible,
idempotent setup that preserves unrelated settings and hook trust review.
[Decision 0004](../decisions/0004-receive-agent-hook-events.md) accepts lifecycle hooks;
[decision 0005](../decisions/0005-use-a-local-unix-socket.md) accepts the silent observer helper.
The [version-1 event contract](agent-events-v1.md) remains unchanged.
Approval decisions, question answers, and follow-up submissions belong to A1–A2's separate action contract.

I3 will provide setup services. I5 will implement removal, and I6 will expose user actions and
verify isolated agent-to-menu delivery. This proposal describes the removal guarantees that
installation must make possible; it does not move I5 or I6 into I3.

## Planning and application boundaries

The proposed configuration planner accepts explicit inputs: current hook bytes or a missing-file
state, version evidence, helper location, and any ownership evidence required by the chosen design.
It returns a complete candidate update, an unchanged result, or a bounded failure category.
It performs no file I/O, starts no process, and makes no trust or delivery claim.
Concrete Swift types and signatures will be reviewed with the I3b implementation plan.

A separate installer resolves and validates paths, obtains fresh evidence, reads bounded files,
applies a plan only to the inspected state, and records ownership using the approved recovery design.
It does not overwrite a changed configuration by applying an earlier plan.
User-visible setup belongs to I6, so adding a service does not authorize automatic startup installation.

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

## Ownership alternatives requiring a decision

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

## Fictional review cases and later checks

I3a reviews these cases against this document without accessing real configuration:

| Case | Required outcome |
|---|---|
| Missing hook file, accepted version/shape, available helper | Plan seven isolated managed entries; application waits for an approved installer design. |
| Repeated installation with unchanged owned entries | No new entries and no hook-file byte changes. |
| Existing Otty hooks, unrelated handlers, and unrelated settings | Preserve values and handler order while adding separate app entries. |
| User edits, copies, deletes, or duplicates a managed entry | Conflict/reconciliation; no broad match, automatic adoption, or destructive cleanup. |
| Malformed/oversized JSON, duplicate keys, unsafe path, unknown version, or unavailable helper | No configuration writes; bounded failure reason. |
| User edit during planning or interruption between file updates | Reject stale plan or expose uncertain state; never silently overwrite or duplicate. |
| Installed hooks still awaiting trust or with no delivered observation | Report configuration separately; do not claim connected, working, or action-capable. |
| Removal after unrelated user edits | I5 removes only proven unchanged app entries and preserves the user's later data. |

I3b will define at most five isolated planner tests before implementation, covering the relevant
cases above and the chosen ownership mechanism. I3c will review file-operation checks and split
further if required by the specification's file/function/test limits. Fixtures, records, and captures
remain outside the repository; tests must never load the user's agent configuration.

Runtime verification was paused during I3a. The combined goal subsequently renewed its specified checks.
Use the spec's isolated Xcode Swift checks and build; I6's setup/delivery/cleanup remains later work. No I3a prose
review counts as passing those checks, completing I3b/I3c/I5/I6, or completing the existing I2 goal.

## I3 design review for the activated goal

Status: proposed, 2026-10-28. Activating the combined goal authorizes I1 checks and planning.
Only the separate ownership file is accepted. This section needs approval before production code.

### Record schema and matching

Propose schema version 1 with installation UUID, absolute configuration path, parent directory
device/inode identity, helper path, and seven event/group descriptions. Each group description
contains only its event name and exact app-created group/handler values, including command and timeout.
Do not record array indices as identity. Do not retain unrelated configuration or commands.
Bound each record and journal to 262144 bytes. Reject unknown schema versions and duplicate keys.
Store records in an app-private directory with mode 0700; record/journal files use mode 0600.

The planner must find exactly one unchanged owned group for each recorded event. Reordering unrelated
groups is allowed. Missing, edited or duplicated owned groups are conflicts. Without an ownership
record, any lookalike managed invocation is a collision, never proof of ownership.
Helper-path changes require a later reviewed migration; do not silently treat them as first installation.

### Preservation and interfaces

Use bounded, lossless JSON scanning. Reject duplicate keys at every object depth.
Preserve unrelated token bytes, including numeric lexemes, and array order by inserting groups
at validated byte ranges. Do not round-trip arbitrary user values through floating-point JSON objects.
Validate the complete candidate before returning it. Unchanged installation returns original bytes.
The planner reads no files and launches no processes.

Proposed concrete entry points:

```swift
CodexHookSetupPlanner.plan(_ input: CodexHookPlanInput) -> CodexHookPlan
CodexHookInstaller.install(_ request: CodexHookInstallRequest) -> CodexHookInstallResult
```

`CodexHookPlanInput` carries optional current bytes and ownership, installation UUID, helper path,
target identity, and explicit verified version/enablement evidence. The result carries a candidate
and new ownership, unchanged, or a bounded unavailable/conflict category. It never carries raw errors.
`CodexHookInstallRequest` supplies explicit configuration, ownership-directory and helper URLs plus
version/enablement evidence. Tests supply disposable URLs only. The installer rereads current state
and replans; a caller cannot apply an unchecked saved candidate.

### File updates and recovery

Propose a process-shared exclusive advisory lock in the app-owned record directory, acquired without
unbounded waiting. Validate directory components and open files without following symlinks.
Require same-user ownership, regular files, no unexpected hard links, and safe directory permissions.
Preserve existing configuration mode; new configuration uses mode 0600. Validate the helper without executing it.
Use descriptor-based reads and target/parent identity checks, with bounded data and operation loops.

Write and synchronize a pending journal before configuration replacement. It contains installation
identity, previous and candidate configuration SHA-256 digests, previous ownership digest or absence,
and the new app-only ownership record. It contains no whole-configuration backup or candidate copy.
Prepare the candidate in a private same-filesystem temporary file, synchronize it, recheck the inspected
target identity and digest, then replace configuration atomically. Synchronize the parent directory.
Persist and synchronize ownership next, then remove the journal and synchronize its directory.
Keep file descriptors and the lock until completion. Bound filesystem errors into useful categories.

| Interruption/restart state | Proposed action |
|---|---|
| Before durable journal | No installation claim; configuration remains unchanged. |
| Valid pending journal; configuration matches previous digest and previous ownership still matches | Clear pending intent only; leave configuration unchanged and allow a fresh retry. |
| Valid pending journal; configuration matches candidate digest and ownership is still previous/absent | Verify all recorded groups and identities, then finalize ownership from journal. Do not rewrite configuration. |
| Valid pending journal; candidate configuration and new ownership both match | Clear pending intent; report installed without adding groups. |
| Journal malformed, identities differ, ownership changed, or configuration matches neither digest | Conflict; leave configuration and ownership untouched, retain recovery evidence. |
| No pending journal; valid ownership and unique unchanged entries | Unchanged even if unrelated groups moved. |
| No pending journal; missing ownership but lookalike entries exist | Conflict; never adopt the entries. |

Recovery never restores a whole-file backup, removes a user edit, or guesses which duplicate is ours.
Recovery checks must exercise every table row and every durable write boundary.

### Concurrent-writer limit requiring explicit approval

The advisory lock coordinates this app's installers only. It cannot force an editor or Codex to lock.
Rechecking inode/metadata/digest detects observed stale state, but comparison followed by rename has
a race window. Atomic rename alone does not provide compare-and-swap against a noncooperating writer.
Therefore this proposal cannot promise preservation of an external write made in that final window.
Approve this documented limitation or choose a different write strategy before implementation.
Do not describe a cooperative lock as a transaction across independent configuration writers.

### Provider settings and evidence boundary

Current [official hook documentation](https://learn.chatgpt.com/docs/hooks) specifies `timeout` in seconds,
with a three-second maximum for `SessionEnd`. It documents `[features].hooks` and the deprecated
`codex_hooks` alias. The [configuration reference](https://learn.chatgpt.com/docs/config-file/config-reference)
also identifies `features.hooks`. These are current documentation findings, not proof for every recorded CLI version.
Propose `timeout: 3` for all seven managed command hooks, using the quoted absolute helper path
and exactly `--agent codex`. Preserve synchronous behavior and hook trust review.
Verify timeout parsing and hook enablement against the selected CLI version before implementing gates.
If hooks are disabled or evidence is unavailable, return unavailable with instructions; never edit config.toml.

Read-only package-path inspection found `standalone/current` points to release
`0.164.0-aarch64-apple-darwin`. No hook/version schema ships as a separately discoverable
schema file in that package. This metadata does not prove timeout parsing or effective feature
enablement. No agent process, configuration probe, or schema-generation command was run.

### Historical size review, 2026-10-28

Lossless parsing, ownership comparison, durable file updates and recovery need separate steps.
Propose retaining I3b/I3c as parent tasks, with reviewed implementation steps for JSON scanning,
planning/matching, guarded file operations, and recovery. Each step must be finished and
verified in one session. Keep the five frozen planner tests and five frozen
installer tests parameterized across the required cases. No task-list split is accepted yet.
The eight-task split in [codex-setup](../specs/sessions/codex-setup.md#tasks) was subsequently approved on 2026-10-30.

## I3b1 review, 2026-10-30

Status: accepted, 2026-10-30. The user accepted writer option A after its limits were explained.
The user then accepted the remaining version policy, timeout, ownership schema, recovery table, and identical-replacement limit.
This section refines the earlier proposals. Acceptance settles the design, not implementation or runtime qualification.

### Prerequisite evidence reviewed

| Requirement | Checked evidence | Conclusion |
|---|---|---|
| Integration health | `IntegrationHealth.swift` separates version, shape, helper, receiver, and delivery. Goal-log turn 21 records 94 passing tests after fake-process suite serialization. | Historical suite evidence exists. App-wiring acceptance remains open, so I2a–I2c stay unchecked. |
| Session presentation | `AgentServices` feeds the inbox/store and creates the notch panel. Goal-log turns 3 and 24 record panel expansion and partial session/usage delivery. | Focus, click-through, keyboard, retained notices, and full state acceptance remain open. I1/N3–N5 stay unchecked. |
| Session state | The session-state spec records the completed store task but has no `Status: done`. | Closure requires a separate decision. This review does not close it. |
| Optional services and menu | `AgentServiceOwner` requires explicit opt-in. Health is private in `AgentServices`; the menu exposes Show Pet, Pet Settings, and Quit. | Reuse these owners in later tasks. Historical menu-environment wiring is stale. |
| Provider version | Compatibility notes record partial Codex 0.164.0 interactive evidence, with normal trust verification incomplete. | A historical event/version match is not an installer support gate. |

Sources: [integration-health](../specs/sessions/integration-health.md), [session-island](../specs/notch/session-island.md),
[session-state](../specs/sessions/session-state.md), [goal log](../goals/notch-agent-limits-log.md),
and [compatibility notes](../notes/agent-event-compatibility.md).
No historical command was rerun. Dependent implementation remains gated on prerequisite closure.

### Accepted provider policy

Current [official hooks documentation](https://learn.chatgpt.com/docs/hooks) describes command-handler `timeout` in seconds,
with a three-second maximum for `SessionEnd`. Hooks normally run synchronously and receive JSON through stdin.
User hooks require review of their exact definition. Hooks are enabled by default, but effective settings can disable them.
The [configuration reference](https://learn.chatgpt.com/docs/config-file/config-reference) identifies `features.hooks`,
the deprecated `features.codex_hooks` alias, and `allow_managed_hooks_only`, which excludes user hooks.
The [official changelog](https://learn.chatgpt.com/docs/changelog) dates CLI 0.164.0 to 2026-10-23.
These pages were fetched on 2026-10-30. They are not a version-pinned parser or runtime proof.

Use exact-version qualification, starting with **0.164.0 as a candidate**, without a minimum-version range.
The qualified set stays empty until explicitly authorized isolated checks establish its shape, timeout enforcement,
effective enablement/policy signal, helper invocation, and normal trust flow. No such checks ran in this review.
Newer, older, unknown, and prerelease versions remain unavailable until separately qualified.
This costs additional qualification for each release, but avoids extrapolating incomplete compatibility evidence.

Use `timeout: 3` for all seven synchronous command handlers. Keep the helper's 250 ms shared deadline unchanged.
This allows process-launch overhead while keeping the selected timeout within the documented SessionEnd limit.
Do not claim a hard wall-clock bound from configuration alone. Qualify enforcement with the chosen release.
Use POSIX single-quote escaping for the absolute helper path, including embedded apostrophes, then exactly `--agent codex`.
Omit `matcher` to cover every supported event. Add no async setting, ownership field, shell wrapper, or trust bypass.
This command construction remains subject to version-specific verification before installation becomes available.

Installation requires fresh evidence from the same executable and effective configuration context.
`recordedCompatibility`, hook counts, default enablement, and a prior delivery are insufficient individually.
Until a bounded supported way to obtain effective enablement and policy is qualified, return `enablementUnverified` without writes.
Disabled or policy-blocked hooks return unavailable with guidance to review Codex settings or contact the administrator.
Unsupported versions return guidance to use a qualified release. None of these outcomes authorizes editing `config.toml`.
Check, trust review, actual receipt, and current session state remain separate outcomes.
Removal relies on ownership and current file safety, so an unavailable CLI must not prevent safe targeted removal.

### Accepted ownership and collision policy

Use schema version 1: installation UUID, absolute hooks path, parent device/inode identity,
absolute helper path, and exactly seven records containing event name and the complete app-created group object.
Each group contains one command handler with only `type`, `command`, and integer `timeout: 3`.
The record stores no unrelated groups, original configuration, array indices, or credentials.
Retain the existing 262144-byte bounds, duplicate-key rejection, 0700 record directory, and 0600 record/journal files.

Require exactly one structurally unchanged group per event. Ignore JSON whitespace and object-key order when matching.
Extra fields, changed values, missing groups, and duplicate candidates conflict. Unrelated group reordering is allowed.
On first installation, a recognizable invocation of the helper is a collision even without matching ownership.
Do not adopt it. Do not execute or semantically interpret arbitrary shell commands to identify ownership.
Equivalent commands hidden in wrappers or other hook sources cannot be exhaustively detected.
Helper relocation requires a separately reviewed migration. Removal can still use the recorded old path without executing it.

These are content checks, not proof of edit history. Copying a group and deleting its original can leave one identical group.
No snapshot-based comparison can detect that history. Multiple visible copies conflict, but an identical replacement is indistinguishable.
The user accepted this limit on 2026-10-30. Markers alone do not solve identical copying.

### Accepted durable updates and recovery

Use a journal for both **install** and **remove**. A journal is a durable record of one pending operation.
Include schema version, operation, transaction UUID, target/parent identity, previous and candidate configuration state,
and previous/next ownership states. A configuration state is `missing` or a SHA-256 digest, never file contents.
Ownership states contain only the bounded app-created record or explicit absence, with a digest for comparison.
Reject no-op transitions before journaling. An unchanged reinstall returns the original hook bytes.
Removal leaves a valid hooks file, even when no handlers remain. It never deletes that file or restores an old backup.

Under the app lock, validate paths and descriptor identities, same-user ownership, regular files, links, and permissions.
Reject metadata that cannot be preserved safely. Preserve existing safe mode and use 0600 for a newly created hooks file.
Prepare a private same-filesystem candidate temporary file and synchronize it before publishing a synchronized journal.
Record its app-generated basename for bounded cleanup. It is transient candidate storage, not a recovery backup.
Recheck the inspected target identity/digest, atomically replace hooks, then synchronize its parent directory.
Atomically persist/synchronize the next ownership record, or unlink/synchronize ownership for removal.
Finally unlink the journal and synchronize the record directory. Keep the lock through completion.
Report completion only after synchronization succeeds. A synchronization error leaves the operation uncertain.

| Durable boundary or restart observation | Required recovery action |
|---|---|
| Candidate prepared, no published journal | No hooks/ownership update was authorized. Discard only proven app-created temporary storage under the app lock. |
| Journal publication interrupted, malformed, or not safely readable | Stop with recovery guidance. Do not infer completion from hook appearance. |
| Valid journal; hooks equal previous state; ownership equals previous state | Abort pending intent and synchronize journal removal. Leave hooks/ownership unchanged before a fresh plan. |
| Hook replacement or directory synchronization interrupted | Read current state. Continue only through one of the exact previous/candidate rows; unreadable or different state conflicts. |
| Hooks equal candidate; ownership equals previous state | Verify identities and operation-specific entries. Finalize next ownership without rewriting hooks. |
| Ownership replacement/deletion interrupted | Compare against the exact previous/next ownership states. Candidate hooks plus either known state can follow its matching row. |
| Hooks equal candidate; ownership equals next state | Synchronize the known state, clear/synchronize the journal, and report the operation complete. Add no entries. |
| Journal removal interrupted | If the journal remains, use the preceding row. If absent, use normal owned/unowned validation. |
| Hooks equal neither state; ownership is unexpected; identity changed; unsafe path; or missing required evidence | Conflict. Leave hooks/ownership and valid recovery evidence untouched. Require manual reconciliation. |

For install finalization, all seven new groups must match uniquely. For removal finalization, the candidate has none of the recorded groups.
A configuration inode change is expected after replacement. Recovery binds the parent identity and safe current contents,
not the pre-replacement file inode. Missing and empty files are distinct states.
Unrelated edits after a pending operation change its digest and stop automatic recovery, even if groups still look plausible.
Without a journal, normal owned-entry matching allows unrelated edits. Missing ownership plus lookalikes remains a conflict.
Manual reconciliation must not automatically discard ownership, adopt entries, restore a configuration backup, or retry over uncertainty.

This is preferred over writing ownership first, which can claim entries never installed, and configuration first without a journal,
which can leave entries without ownership. Stopping on every interruption is simpler but gives users avoidable manual repair.
The journal permits recovery only for exact known states. It does not provide a transaction against external editors.

### Concurrent writers: option A accepted

**A — Recommend bounded cooperative protection.** Serialize this app's writers with an advisory lock, recheck before replacement,
and reject observed stale state. Ask users to finish other configuration edits before Connect or Remove hooks.
An independent writer can still change the file between the last comparison and replacement, losing that write.
Directory synchronization and atomic replacement do not eliminate this window. Recovery cannot undo an overwritten external edit.
The guarantee therefore covers app writers and detected external edits only, not arbitrary concurrent writers.

**B — Decline automatic shared-file writes.** Keep setup unavailable until a supported independent source or coordinated update mechanism is qualified.
This avoids the shared-file replacement race, but delays the approved Connect behavior and needs a scope/design change.
Manual editing is not an implemented substitute for Connect. In-place rewriting was considered and rejected because it adds partial-file failures
without solving independent-writer coordination.

The user selected A on 2026-10-30 after reviewing the example of an independent edit lost during replacement.
This keeps the planned Connect path with explicitly limited protection. B was not selected because it defers automatic writes.
Acceptance of A does not accept the other proposals or authorize file-operation implementation before its remaining gates.
The user subsequently accepted the other I3b1 choices on 2026-10-30. The implementation and verification gates remain in force.

### Fictional-case review and task outcome

| Fictional case | Reviewed result under the accepted design |
|---|---|
| Missing hooks, qualified version, enabled policy, available helper | Plan seven separate groups and ownership. With today's unqualified evidence, return unavailable before writes. |
| Repeat unchanged installation | Return original bytes, no duplicate groups, and no journal. |
| Otty/unrelated handlers and numeric values | Insert at validated JSON ranges. Preserve unrelated tokens and handler order without numeric conversion. |
| Edited, missing, copied, or ambiguous entries | Conflict for detectable changes/duplicates. Identical replacement history has the explicit limit above. |
| Invalid input, duplicate keys, oversized candidate/record, unsafe path, invalid override, unknown version, or missing helper | Bounded failure with unchanged configuration. Do not fall back from an invalid CODEX_HOME override. |
| Edit during planning or between durable writes | Reject observed staleness. Use the recovery table after interruption. The final external-writer window remains under choice A. |
| Awaiting trust or no received event | Report installation evidence separately. Never infer delivery or a broken connection from silence. |
| Remove after unrelated edits | Match all owned groups first, then remove only those groups. Journal removal separately and preserve later unrelated tokens. |

No code, new interfaces, probes, tests, builds, app launches, captures, or installed configuration access occurred.
The existing planner/installer signatures remain proposals for their implementation tasks.
The user accepted the gate policy, timeout, schema, recovery table, identity limit, and writer choice A on 2026-10-30.
I3b1's documentation review is complete. `git diff --check` and the progress script exited 0.
The board resolved both prerequisites and retained all eight tasks. I3b2–I6b remain separate tasks.
Documentation checks establish consistency only. They do not qualify a release or close prerequisites.
