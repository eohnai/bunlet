---
summary: Every pull request and push to main builds, tests and checks Bunlet on GitHub Actions, with one strict Required result.
---

# Continuous integration

## How it works

`.github/workflows/ci.yml` runs on pull requests to `main`, pushes to `main` and manual runs, with no path filters, so a
documentation-only change also gets a result. A newer run cancels an older one for the same pull request. Runs on
`main` always finish.

| Job | Runner | Limit | Work |
| --- | --- | --- | --- |
| Workflow | ubuntu-24.04 | 5 min | Validates workflow syntax with a pinned actionlint |
| Tests | macos-26, Xcode 26.5 | 20 min | Runs the full Swift suite, exports test results and production coverage |
| Build | macos-26, Xcode 26.5 | 15 min | Packages the app and helpers, checks the bundle, uploads one archive and manifest |
| Helper | macos-26, Xcode 26.5 | 10 min | Downloads that archive, checks its identity and checksums, runs fictional helper process checks |
| Contract | ubuntu-24.04 | 5 min | Runs `scripts/check-event-contract.py` |
| Required | ubuntu-24.04 | 2 min | Passes only if every job above succeeded |

The scripts in `scripts/ci/` record tool versions, run checks with bounded logs, build and verify the archive, export
coverage, read test results and compute the Required result. Build archives are kept for one day and reports for three.
`.github/workflows/release.yml` packages releases ([software updates](../settings/software-updates.md)).

## Requirements

- Required fails on any failed, cancelled, skipped, missing or malformed job result.
- No retries, test exclusions, `continue-on-error` or ignored exit codes hide a failure. Missing reports fail the run.
- The Helper job uses Build's exact archive and never rebuilds. A missing or altered archive fails before anything runs.
- Workflows use `pull_request`, read-only permissions and checkout without stored credentials. Remote actions and tools
  are pinned to verified versions. Pull request runs need no release secrets.
- Runs use fictional input only and never read installed agents, credentials or real sessions.
- If the pinned Xcode disappears from the runner image, the run fails rather than silently using another version.

## Out of scope

- Signing, notarization and publishing, apart from the release workflow.
- Branch protection and merge rules in repository settings.

## Open work

- Approved as directions in [0014](../../decisions/0014-use-comprehensive-github-actions-ci.md) but not built:
  formatting and selected SwiftLint rules ([0015](../../decisions/0015-adopt-swift-format-and-selected-swiftlint-rules.md)),
  coverage thresholds, an Intel and multi-version matrix, sanitizers and repeated tests, secret and dependency scanning,
  automated app startup checks, and merge gates.
- Three tests fail intermittently when the suite runs in parallel on a busy machine, and pass alone:
  `versionProbeBoundsItsProcessAndOutput(agent: .codex)`, `waitsForDesktopRuntimeAndHonorsPause` (seen with `.claude`
  and `.codex`, `pauseBeforeInstall: true`) and `connectsAndRemovesHooksFromCleanDesktopConfiguration(agent: .claude)`.

## Decisions

[0014](../../decisions/0014-use-comprehensive-github-actions-ci.md),
[0015](../../decisions/0015-adopt-swift-format-and-selected-swiftlint-rules.md).
