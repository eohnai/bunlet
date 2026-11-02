# Deliver independently selectable companion features

Status: prepared, not activated
Created: 2026-11-02
Spec: [settings/feature-management](../specs/settings/feature-management.md)
Log: [modular-features-log](modular-features-log.md)

The user requested one goal linking FM1–FM7 while FM1 planning was in progress.
This is the proposed execution contract. Starting it would approve the named task sequence and verification;
the current request prepares the goal and does not start implementation or a conversation goal.

## Goal block for approval

```text
GOAL: Complete FM1-FM7 in docs/specs/settings/feature-management.md so one native app offers Pet, Notch and Agents install/uninstall in Settings. Pet works without either other feature; preferences survive reinstall and uninstalled features perform no owned work.

DONE WHEN all are proven with evidence printed in the conversation:
1. All seven FM tasks are checked against their actual acceptance evidence. Settings remains reachable with no optional features. All eight feature combinations work; installation, enablement, provider connection and health remain distinct. The independent Pet module imports no agent types.
2. Focused tests cover FM1 defaults/legacy migration, all eight saved sets, invalid/future data preservation, reopen and retained preferences; lifecycle tests prove zero absent-feature factories, idempotent teardown and rejection of late callbacks. No real preferences, sessions, credentials or installed agent configuration are used.
3. `env DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --scratch-path /private/tmp/notch-pet-features/build` exits 0 with at least the baseline 172 tests plus the new contract coverage, zero unexpected failures and the pre-existing usage-datagram issue explicitly retained.
4. `env TMPDIR=/private/tmp/notch-pet-features DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer bash scripts/run.sh --build-only` and `git diff --check` exit 0. The packaged app preserves its existing helper/resource checks.
5. One bounded noncapture native pass on the actual app proves feature install/remove/reinstall, Pet without Notch/Agents, eight combinations, keyboard access, clear control labels, retained settings, focus and menu recovery. Record missing required evidence as incomplete. Full VoiceOver testing is deferred to accessibility follow-up, with no screen-reader acceptance claimed. Existing unrelated deferred acceptance stays open. A unit test or ledger is not native acceptance.

ORDER: FM1 catalog/preferences; FM2 independent service/surface lifetime; FM3 selected startup and minimal desktop pet placement; FM4 shared Settings shell plus Features; FM5 removal/reinstall/recovery; FM6 contract matrix; FM7 native acceptance. Record bounded file/function/test plans before FM2-FM5 edits, including the necessary settings-window slice. Routine choices within the approved spec need no repeated permission; ask before changing scope or unresolved product semantics.

EVERY TURN: run `git diff --check`, print new relevant proof and FM status, and append one row to docs/goals/modular-features-log.md. Continue its numbering. Run focused tests only after relevant changes; run the full final checks once stable rather than repeating unchanged tests.

CONSTRAINTS: Only touch feature-management app composition/settings/preferences, necessary Pet/Notch/Agent lifecycle seams, related tests, packaging if needed and their records. Preserve shared session meaning, provider opt-in/configuration, privacy, no-tooltip choice and pending notices. No new dependencies, providers, action channel, collector or downloadable plugins. No screen capture/recording, global permission changes, real hook installation/removal, commits, pushes, PRs or older-goal resumption. Never weaken checks to pass. FM1: at most 3 implementation/test files, 4 handwritten production functions/accessors and 5 parameterized test cases.

STOP AND REPORT incomplete after 30 work turns, after the same failing criterion for 3 turns without a new approach, or when blocked on access, a product decision or a prohibited operation. Do not bypass native acceptance or invent approval. On finish/stop, record evidence and remaining gaps in the log/spec/STATUS; mark complete only if all five criteria are actually proven.
```

## Checkpoints and task links

One goal owns the complete outcome; checkpoints are not separate goals or separate definitions of done.
FM1 is planned in [the first-slice section](../specs/settings/feature-management.md#first-implementation-slice-for-review).
FM2/FM3 build on that state model, FM4 integrates the minimal settings-window slice, and FM5 adds removal/reinstallation.
FM6 verifies their combined contract. FM7 remains required before claiming this modular-feature milestone complete.
Full VoiceOver screen-reader testing is a later accessibility pass; keyboard access, labels and focus remain in this milestone.

| Checkpoint | Tasks | Evidence needed before proceeding |
| --- | --- | --- |
| Stored choices | FM1 | Focused isolated preference tests; invalid data preserved; no runtime wiring |
| Independent runtime | FM2–FM3 | Deferred factories, zero absent-feature work, safe stop/restart, useful Pet-only placement |
| User controls | FM4–FM5 | Reachable shared Settings, truthful progress/recovery, no silent dependency installs, preferences retained |
| Contract verification | FM6 | All eight combinations plus transitions and late callbacks, full suite and packaged build |
| Native acceptance | FM7 | Actual noncapture controls/keyboard/labels/focus evidence; required gaps stay incomplete; full VoiceOver pass deferred |

The runtime goal is still unarmed. Goal approval must also settle the spec's proposed combinations and migration behavior.
Missing automation access can leave the required native checks incomplete. VoiceOver deferral alone does not block this milestone,
and neither case permits requesting Screen Recording or claiming unperformed checks passed.
No token budget is proposed. The 30-turn stop is a proposed work limit, not a deadline.
