# Goal log: independently selectable companion features

- Goal file: [modular-features](modular-features.md)
- Created: 2026-11-02
- Turn limit: 30 work turns
- Status: paused; FM7 deferred by the user

## Turns

| Turn | Time | Criteria passing | What changed / evidence |
| --- | --- | --- | --- |
| 1 | 2026-11-02 03:53 UTC | FM1/FM2 verified; FM3 partial; final goal criteria open | Removed VoiceOver gates (D8); implemented three-file preferences slice, independent runtime/generation guards and selected startup/desktop placement. Focused final run: 15 tests / 3 suites passed, including both eight-combination matrices. Sandbox compiler-cache failure resolved by approved retry; Notification isolation and nondeterministic JSON key ordering fixed with unchanged checks. Full suite/build/native checks pending. |
| 2 | 2026-11-02 06:05 UTC | FM1–FM5 verified at focused/model level; FM6/7 open | Added shared Settings/Features and safe install/remove/reinstall model; 20 focused tests passed. All 64 ordered transitions passed. Structured-logo regression first failed, then all five logo tests passed with original assertions preserved. Temporary native API probe proved own-window mouse delivery; it is not app acceptance. Native helper/control support and final full/build/native evidence remain. |
| 3 | 2026-11-02 06:45 UTC | FM1–FM6 verified; FM7 open | Implemented bounded native support and private helper endpoint. Confirmed Foundation canonical-path gate defect and repaired app/helper validation with guards preserved. Full final suite exited 0: 194 tests, zero unexpected failures, existing usage known issue retained; packaged build/diff check passed. Actual matrix-0 proves no optional factories/I/O and packaged logos, then fails Settings focus. One diagnostic reproduction proves the real action runs and opens a visible window, but key/active state remains false; synthetic input versus product behavior unresolved. Evidence/spec/STATUS record the unperformed native checks. Clarified optional session-to-pet adapter; reactions stay separate future work. No commit/push/capture/provider changes. |
| 4 | 2026-11-02; before pause | FM1–FM6 verified; FM7 incomplete | Corrected explicit Settings activation, canonical resource containment, native coordinate conversion/local event dispatch and an invalid fictional prompt fixture. The last batch at `/private/tmp/np-features-native-final/` passed all eight startup sets and fresh setup, but recovery/interaction failed focus and reopen failed after interaction stopped. No complete native interaction/keyboard acceptance is claimed. User paused the goal, deferred FM7, and requested FM1–FM6 commits. All native test processes are stopped. |

Execution approved on 2026-11-02; the conversation goal was created once. Rows below record verified execution work.
FM1's detailed contract and execution evidence are in the specification. Its focused tests prove preferences behavior, not native feature installation.
Scope update, 2026-11-02: the user removed VoiceOver testing from all feature acceptance.
The goal still requires keyboard access, clear labels, focus and actual native control checks. No screen-reader acceptance is claimed.

## Final result

Paused at the user's request. FM1–FM6 are saved as separate dependency-based commits; FM7 is deferred and its checker remains uncommitted.
The umbrella goal remains incomplete. Commit-only verification uses an exported production tree without FM7 support and opens no app windows.

Commit-only checkpoint, 2026-11-02: the exported FM1–FM6 tree passed 194 tests with zero unexpected failures and the existing usage-datagram known issue.
The packaged build and diff checks passed. Verification logs are under `/private/tmp/np-feature-commit-check/`; no app was launched.
The six commit concerns are preferences, lifecycle primitives, settings state, app/UI integration, resource loading, and verification/records.
The backup is `refs/backup/pre-fm-commits-20261102T083633Z` plus `/private/tmp/notch-pet-pre-fm-commits-20261102T083633Z/worktree.tar`.
