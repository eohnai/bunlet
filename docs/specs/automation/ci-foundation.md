# Build and test changes through GitHub Actions

## Goal

Give each pull request a reproducible build-and-test result, useful reports, and an identifiable native build.
Exercise the packaged helper from that build before reporting success.
This is the first feature in the approved [automation roadmap](area.md), ahead of session-cards C2.

The user approved the roadmap on 2026-10-31 and activated the F1–F7 local implementation goal later that day.
That activation authorizes those tasks and their bounded local checks. The user also permits per-task commits,
subject to AGENTS.md's commit-plan approval procedure. On 2026-11-01, the user approved splitting F8 and doing
F8a's read-only hosted inspection, focused local test, and disposable diagnostic probes. New hosted drills,
repairs, and repository settings changes still require their own approval. The user handles commits and pushes.
After PR #10's main run passed, the user approved F9's script extraction and its local fixture verification.

## Done when

- PRs targeting `main`, pushes to `main`, and manual runs execute the workflow without path filters.
  A documentation-only PR also receives a result.
- A newer run cancels an older run for the same PR. Runs for `main` finish independently.
- An explicit macOS image and Xcode selection build the package and app bundle, and run the complete existing Swift suite.
  Reports record the selected and actual macOS, architecture, Xcode, Swift, Python, and workflow-validator versions.
- The build verifies both executables, `Info.plist`, and the packaged Pet resource bundle before uploading one archive and manifest.
  The manifest identifies the commit, run, attempt, toolchain, configuration, and file checksums.
- A separate job downloads that run's archive, verifies its identity and checksums, and runs fictional process checks against its helper.
  It does not rebuild either executable. Missing or altered artifacts fail before execution.
- Contract reference checks run separately. Their known difference from SessionStore remains explicit pending its owning fix.
- Swift tests produce machine-readable test results, coverage JSON, and readable HTML coverage for production Swift sources.
  Coverage summaries identify modules. Missing or malformed expected reports fail after an otherwise successful test run.
- Available test, coverage, build, and process reports upload after failures, with a summary identifying failed jobs and missing evidence.
  Early setup failure or cancellation can leave no report. Neither condition establishes a passing run.
- `Required` runs after all required jobs and accepts only the exact expected set of successful results.
  Failure, cancellation, skipping, missing jobs, malformed input, and unknown states fail it.
- A hosted passing PR run, deliberate failure, documentation-only run, artifact rejection, and supersession check demonstrate the contracts above.
  Evidence identifies the tested commit and final result. A cancelled run cannot satisfy acceptance.
- Every check has a local reproduction command and a troubleshooting recipe in this spec.
  Remote actions/tools are pinned, permissions are minimal, job times are bounded, and no release secrets are needed.

## Out of scope

- Coverage thresholds and comparisons: coverage-gates. Formatting, linting, and broad script/document checks: quality-gates.
- Expanded architecture/OS/toolchain matrices: compatibility-matrix. Sanitizers and repeated/generated-input checks: robustness-checks.
- Secret scanning, tracked-runtime-data guards, dependency maintenance, and CodeQL: security-maintenance.
- App launches, GUI interactions, focus/capture checks, and live agents: native-acceptance and existing feature acceptance.
- Branch protection and merge enforcement: merge-gates. No repository settings are changed here.
- Signing, notarization, release publishing, paid services, and caching.
- Fixing unrelated product or test defects. Record a failure and propose its separate repair instead of weakening assertions.

## Constraints

- Preserve pet-first startup, optional integrations, module ownership, and existing Codex, Claude Code, and Otty configuration.
- Use fictional input and disposable runner state. Do not discover installed agents, inspect credentials, or read real session data.
- Store builds, reports, temporary fixtures, extracted artifacts, and runtime files outside the checkout.
  Never upload home directories, environment dumps, configuration files, or captured sessions.
- Use `pull_request`, not privileged execution of PR code. Default to `contents: read`, with checkout credentials disabled.
  Pin external actions by verified full commit SHA, and separately verify any downloaded tool binary.
- Use no retry, test exclusion, `continue-on-error`, or ignored exit code to hide a failure.
  Preserve the original exit status when collecting output. Missing data does not count as zero failures.
- Existing task-specific test/build authorization remains required. Hosted checks begin only after the user commits and pushes approved workflow changes.
  Do not dispatch workflows, open PRs, or push failure probes on the user's behalf without explicit instructions.
- Keep the eight implementation tasks within the plan-feature size limits, including spec/STATUS updates.
  Each task below changes at most one implementation file. Review signatures and any needed split in its next-task plan.
  F9 is an approved exception: extracting the blocks and changing their callers together touches six implementation files.
  F10 is another approved exception: the internal wait seam and its replacement test touch two implementation files.

## Workflow contract

| Job | Work | Time limit |
|---|---|---|
| Workflow | Validate workflow syntax with a pinned actionlint release | 5 minutes |
| Tests | Full Swift suite, machine-readable results, coverage export, report upload | 20 minutes |
| Build | Package the app/helper and validate the archive and manifest | 15 minutes |
| Contract | Run `scripts/check-event-contract.py`, preserving its known evidence limit | 5 minutes |
| Helper | Download and verify Build's artifact, then run actual helper process checks | 10 minutes |
| Required | Validate every expected upstream result, then summarize the outcome | 2 minutes |

Use Linux for Workflow, Contract, and Required. Tests, Build, and Helper use the qualified macOS image and Xcode.
Helper depends on Build. Required depends on all five other jobs and uses `always()`.
It cannot convert an interrupted workflow into success. Give job and workflow names stable, unique identities.

Run every required job for every eligible PR. Change-based skipping is deferred.
Group PR concurrency by workflow and PR number. Give default-branch runs distinct groups so they do not cancel each other.
Set matrix fail-fast off when compatibility-matrix later adds independent required combinations.

The initial macOS candidate is the explicit `macos-26` Apple Silicon image.
F1 qualifies its installed Xcode versions and pins one exact supported selection. Fail if that selection disappears.
Do not silently use another Xcode or substitute `macos-latest`. This foundation does not establish macOS 14 runtime compatibility.

## Artifact and report contract

- Build uses the existing `scripts/run.sh --build-only` packaging path without launching the app.
  Foundation validates the current debug bundle. Release configuration belongs to compatibility-matrix.
- Preserve executable modes and the resource bundle when archiving. Validate archive paths and reject escaping entries before extraction.
- Name the build artifact with commit, run ID, and run attempt. Use the same identity for upload and download.
  Verify platform/configuration identity and the manifest's checksums before running the downloaded helper.
  Checksums detect altered content. They do not constitute signed provenance.
- F2 adds an explicit helper-path option to the existing process checker while preserving its default local behavior.
  It must refuse existing runtime endpoints. The tests retain their deadlines, omission checks, and silent helper behavior.
- Store binaries for one day and reports for three days. Missing required build files fail upload.
  Report uploads run after earlier failure when the job is not cancelled. Missing expected reports are visible in the summary.
- Archive text logs with bounded output. Report publication cannot mask the original test, build, or process exit status.
- Coverage includes production sources, excluding generated/test code by a documented rule.
  Keep instrumented tests separate from the uninstrumented build artifact. Export only supported formats from the pinned toolchain.
  Normalize source paths for readable HTML and record tool failures. Do not invent coverage after a failed test execution.
- Use native Swift Testing output supported by the selected toolchain for machine-readable test results.
  A converter, if needed, must retain test identity, failure, and skipped status. Do not report a disabled test as passed.
- Keep a small allowlist for environment metadata. Store no raw environment or secrets in reports.

## Verify

Seam: the real GitHub Actions PR run, through uploaded build artifacts to the packaged helper process.
Local commands provide reproduction. They do not establish hosted scheduling, cancellation, permissions, or artifact acceptance.

Existing commands, only after task-specific authorization:

```bash
env DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --scratch-path /private/tmp/notch-pet-dev/build --enable-code-coverage
env TMPDIR=/private/tmp DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer bash scripts/run.sh --build-only
python3 scripts/check-event-bridge.py
python3 scripts/check-event-contract.py
```

The process checker requires the app to be quit and refuses an existing socket.
Do not quit another app instance or remove its socket to make the check run.
Passing means zero exit status, no failed Swift tests, and `Bridge process checks passed` from the process checker.
The contract reference checker must exit zero. Its own output is not proof that its model matches SessionStore.

Foundation CLI commands (see the finalized F7 recipe below for fresh paths and native result flags):

```bash
actionlint .github/workflows/ci.yml
python3 scripts/ci/bundle.py --app "/private/tmp/notch-pet-ci/package/notch-pet-dev/Notch Pet.app" --output /private/tmp/notch-pet-ci/bundle --identity /private/tmp/notch-pet-ci/identity.json
python3 scripts/ci/bundle.py --verify /private/tmp/notch-pet-ci/bundle --identity /private/tmp/notch-pet-ci/identity.json
python3 scripts/check-event-bridge.py --helper "/private/tmp/notch-pet-ci/extracted/Notch Pet.app/Contents/MacOS/NotchPetHook"
env DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer python3 scripts/ci/coverage.py --build-root /private/tmp/notch-pet-dev/build --output /private/tmp/notch-pet-ci/reports
python3 scripts/ci/required-result.py
git diff --check
```

The bundle verifier must reject missing resources, altered contents, mismatched identity, and escaping archive paths.
F3's task plan specifies extraction paths and manifest identity inputs before code is written.
The coverage exporter must reject missing/malformed input and produce HTML, JSON, and a module summary from real coverage.
`required-result.py` reads `CI_JOB_RESULTS` and succeeds only for Workflow, Tests, Build, Contract, and Helper's exact successful results.
F6's fixtures cover all-success, non-success states, missing/extra jobs, malformed input, and empty input in at most five grouped cases.
The script reports job names and bounded result labels, not raw input.

F8 records hosted URLs and commit IDs for the passing run and the failure drills.
Use disposable reviewed changes for drills, and restore them before the final passing run.
Verify that a deliberate test/build failure rejects Required, a modified artifact is rejected before execution,
and two pushes to one PR cancel only the older run. Inspect the downloaded archive and HTML coverage.
Record incomplete drills as incomplete. Do not mark F8 done from local checks or written configuration alone.

## Known evidence limits

- The full suite has a recorded intermittent `IntegrationHealthProbeTests.versionProbeBoundsItsProcessAndOutput` timeout.
  Keep it enabled. A recurrence blocks a passing baseline and needs a separately approved diagnosis or repair.
- `scripts/check-event-contract.py` permits a conflicting turn ID to restore working state, unlike SessionStore's accepted unseen-turn rule.
  Preserve this warning until its own repair is approved. CI running that checker does not resolve the mismatch.
- PR #10 repaired the maximum-frame fixture's buffering assumption and added explicitly queued-byte checks.
  Its passing main run records one known usage datagram issue. That production transport limit still needs a separate decision and repair.
- No captures or native GUI acceptance run here. Existing deferred feature checkboxes stay unchanged.

## Decisions

- [0014: Use comprehensive GitHub Actions CI](../../decisions/0014-use-comprehensive-github-actions-ci.md).
- [0015: Adopt formatting and selected lint rules later](../../decisions/0015-adopt-swift-format-and-selected-swiftlint-rules.md).
- **Cancel superseded PR runs and finish default-branch runs, 2026-10-31.** The user approved this SMRT pattern over cancelling every older branch run.
- **Report coverage before setting thresholds, 2026-10-31.** The user approved a measured baseline followed by enforcement in coverage-gates.
- **Extract inline CI logic into focused Python scripts, 2026-11-01.** The user approved a shorter workflow over retaining embedded Python.
  Keep orchestration in YAML, reuse the existing result predicate, and expose each extracted phase as a directly runnable CLI.
- **Use an internal wait hook for deterministic reader-deadline tests, 2026-11-01.** The user approved F10 with both reset mutations.
  Virtual time and recorded deadlines catch resets after the first read, which an already-expired-deadline-only check misses.
  Prefer this small seam to a wider clock abstraction. The removed server-level coverage is explicit in F10.

## My calls

- Implementation branch: `feat/automation-ci-foundation`, created from `origin/main` at `7735ec6` after the user's explicit branch-transfer approval.
  The six planning documents moved here without session-cards C1 (`1f30a3c`), which remains on its own branch.
- Keep lightweight Python CLI tooling in `scripts/ci/`, using the standard library initially.
  Keep process checks in the existing script to avoid duplicating their assertions.
- Keep the initial reproduction/troubleshooting guide here. merge-gates can create a broader operations guide when the remaining checks exist.
- Start without caches or external coverage services. Use the job limits and retention above as initial bounded settings.
- Each implementation task reserves two file changes for this spec and STATUS.md.
  A task that needs a second implementation file must be split and reviewed before coding.
  F9's approved multi-file exception is recorded above. Its branch starts at passing main `08cb137`.
  The former local branch is preserved as `archive/automation-ci-foundation-pr10` at `293a4dd`.

## Tasks

- [x] F1: Add `.github/workflows/ci.yml` with a qualified macOS/Xcode selection, existing Swift/build/contract checks, pinned workflow validation, bounded jobs, and PR supersession cancellation; validate syntax and the local baseline.
- [x] F2: Add an explicit packaged-helper path option to `scripts/check-event-bridge.py`, preserving the default path, socket protections, and existing assertions; verify both invocation modes with fictional input.
- [x] F3: Add `scripts/ci/bundle.py` to validate and archive the actual app bundle with its identity/checksum manifest; verify a valid bundle and bounded rejection cases.
- [x] F4: Wire Build and Helper in `.github/workflows/ci.yml` to upload, download, and verify the same build artifact, then run F2 against its helper without rebuilding; verify the local artifact round trip and workflow syntax.
- [x] F5: Add `scripts/ci/coverage.py` to export real Swift coverage as HTML, JSON, and per-module summaries; verify real output and missing/malformed-input rejection without adding thresholds.
- [x] F6: Add `scripts/ci/required-result.py` accepting exactly the expected successful job results; verify the five grouped success/failure fixture cases in the Verify section.
- [x] F7: Complete `.github/workflows/ci.yml` with machine-readable test results, coverage export, failure-report uploads, summaries, and the always-evaluated Required job; finalize this spec's reproduction/troubleshooting recipes and verify syntax plus local checks.
- [x] F8a: Diagnose the failed hosted baseline using saved reports, a focused local test, and a disposable scheduling probe; record confirmed findings and evidence limits without changing the receiver or repository tests.
- [x] F8r: Repair `receiverDeadlineDoesNotResetForEachByte()` so a paused sender retries instead of failing, while a per-byte deadline reset still fails; verify with disposable pause and reset probes and the full local suite.
- [ ] F8b: Verify hosted passing and deliberate-failure runs, a documentation-only PR, artifact rejection, and superseded-run cancellation after the user pushes; record commit-linked evidence and restore a final passing run. (blocked: establish a passing hosted baseline for F10, then authorize the remaining hosted drills)
- [x] F9: Extract inline CI metadata, bounded execution, native-result parsing, inventory, and Required reporting into Python scripts; preserve workflow behavior and verify old/new outputs with saved reports and fictional failure fixtures.
- [x] F10: Replace the retry-based deadline test with virtual waits that record the original deadline across reads; reject resets before every wait and after the first read, run EventBridge and full-suite checks, and document the lost server-level coverage.

## F1 partial evidence, 2026-10-31

- A four-job workflow draft exists. It is not accepted or verified.
- Selected Xcode 26.5 build 17F42 to match the local toolchain and an installed version in GitHub's
  [macOS 26 Apple Silicon image inventory](https://github.com/actions/runner-images/blob/main/images/macos/macos-26-arm64-Readme.md).
  Hosted availability and execution remain unverified. The candidate uses `/Applications/Xcode_26.5.app/Contents/Developer`.
- Verified checkout v7.0.1 as `3d3c42e5aac5ba805825da76410c181273ba90b1` using `git ls-remote`.
  Verified actionlint 1.7.12 asset digests against its release metadata:
  Darwin arm64 `aba9ced2dee8d27fecca3dc7feb1a7f9a52caefa1eb46f3271ea66b6e0e6953f`,
  Linux amd64 `8aca8db96f1b94770f1b0d72b6dddcb1ebb8123cb3712530b08cc387b349a3d8`.
- `python3 scripts/check-event-contract.py` exited 0: 68 message cases, 37 sequences/122 steps, four memory boundaries.
  Its existing SessionStore evidence limit remains unchanged.
- `env DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --scratch-path /private/tmp/notch-pet-dev/build --enable-code-coverage`
  exited 1: 132 tests in 24 suites, four issues in `IntegrationHealthProbeTests`.
  Both provider cases of `versionProbeBoundsItsProcessAndOutput(agent:)` and
  `diagnosticsDiscardUnrelatedFictionalValues(agent:)` returned `.unavailable(.timedOut)` instead of their expected results.
  Log: `/private/tmp/notch-pet-ci/reports/f1-swift-test.log`. This is an unrelated baseline failure, so the goal stopped.
- `/private/tmp/notch-pet-ci/tools/actionlint .github/workflows/ci.yml` exited 1:
  `.github/workflows/ci.yml:75:19: context "runner" is not allowed here`.
  The partial Build job uses `runner.temp` in job-level `env`, where that context is unavailable.
  This introduced syntax error remains pending with the unverified workflow draft.
- Packaging and all subsequent F2–F7 checks have not run. No tasks were ticked and no commits were made.
- The user then authorized a separate diagnosis, recorded in
  [integration-health](../sessions/integration-health.md#probe-timeout-diagnosis-2026-10-31).
  A temporary instrumented source copy reproduced four issues.
  Serializing only its probe suite passed all 132 tests without changing assertions or the production timeout.
  The user approved a separate repair task. The repository's probe suite now uses `@Suite(.serialized)`.
  Its isolated five-test suite and full 132-test coverage-enabled suite both passed without changing assertions or product code.
  The original failure remains recorded above. F1 can resume; its workflow syntax check and packaging remain pending.

## F1 verified local baseline, 2026-10-31

The separate I2d repair is committed as `7cb67f2`. F1's local requirements are now verified.
Hosted qualification remains F8 and is not established by the published image inventory or local checks.

- `/private/tmp/notch-pet-ci/tools/actionlint .github/workflows/ci.yml` exited 0 with actionlint 1.7.12.
  Build's `TMPDIR` now uses step-level `env`, where `runner.temp` is available.
- `env DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --scratch-path /private/tmp/notch-pet-dev/build --enable-code-coverage`
  exited 0 after I2d: 132 tests, 24 suites, zero issues.
- `env TMPDIR=/private/tmp/notch-pet-ci/package DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer bash scripts/run.sh --build-only`
  exited 0, yielding `/private/tmp/notch-pet-ci/package/notch-pet-dev/Notch Pet.app`.
  Both packaged executables are regular executable files. Info.plist parses and passes plutil.
  `Contents/Resources/NotchPet_Pet.bundle` contains packaged resource files.
- `python3 scripts/check-event-contract.py` exited 0: 68 messages, 37 sequences/122 steps, four memory boundaries.
- `git diff --check` exited 0.

Packaging uses a separate scratch root so it cannot replace the instrumented test build.
The workflow uses the same separation through runner-temporary `test-build` and `package` paths.
No app was launched. No cache, repository settings, or installed integration configuration changed.

The four stable F1 job names are Workflow, Tests, Build and Contract.
Every eligible PR, main push and manual run schedules all four without path filters.
Only PR runs share a cancelling concurrency group. Main and manual runs use their run ID.
All checkout calls use the verified immutable pin with persisted credentials disabled.
F4 will add Helper, and F7 will add Required and reports. This intermediate workflow is not full-spec acceptance.

Evidence: `/private/tmp/notch-pet-ci/reports/repair-full-suite.log` and
`/private/tmp/notch-pet-ci/reports/f1-build.log`.

## F2 CLI sketch

Keep `main() -> None` and all existing process assertions.
Add standard-library argparse parsing with one optional `--helper PATH` argument.
Without that argument, retain the existing single-helper lookup under `$TMPDIR/notch-pet-dev/build`.
With it, require an existing executable regular file and use its absolute path without searching the build directory.
Reject an invalid explicit path before creating or locking any runtime endpoint.

Caller examples:

```bash
env TMPDIR=/private/tmp python3 scripts/check-event-bridge.py
python3 scripts/check-event-bridge.py --helper "/private/tmp/notch-pet-ci/package/notch-pet-dev/Notch Pet.app/Contents/MacOS/NotchPetHook"
```

Verify both real invocation modes serially with fictional input.
Each must exit 0 with `Bridge process checks passed` and retain every original assertion.
Verify missing/non-executable explicit paths fail, and a pre-existing owned fictional listener is refused without replacement.
Do not remove or stop any pre-existing user endpoint or app to run these checks.

### F2 verification

Both invocation examples exited 0 with `Bridge process checks passed`.
Each retained all original assertions and verified 15 fictional hook projections, maximum input size,
invalid-input omission, silent zero exits, open-stdin deadlines and busy-socket behavior.
The final default mode measured 4–13 ms per invocation. Packaged mode measured 4–20 ms.
Open-stdin checks completed in 71–76 ms across both modes and providers.

`python3 /private/tmp/notch-pet-ci/diagnosis/check-f2-cli.py` exited 0.
It checked missing, non-executable, directory and symlink paths, each rejected with exit 2.
It created and owned a fictional listener at the normal endpoint, then verified both modes refused it with exit 1
and preserved its inode. The harness removed only its own listener after verifying identity.
No existing user endpoint or app was removed or stopped.

The initial sandboxed default run could not bind a Unix socket (`Operation not permitted`).
Running with approved socket access completed the actual checks. This was an environment permission failure.
Logs: `/private/tmp/notch-pet-ci/reports/f2-default-helper.log` and
`/private/tmp/notch-pet-ci/reports/f2-packaged-helper.log`.
`git diff --check` exited 0. No Swift source changed, so the full suite was not repeated.

The first default run used a coverage-instrumented local helper and created `default.profraw` in the checkout.
F2 now routes `LLVM_PROFILE_FILE` for every child into a checker-owned temporary directory and cleans it on exit.
The generated checkout file was removed. Both real invocation modes and all six rejection/preservation checks
passed again on the final script. No repository profile was created by those final checks.

## F3 CLI and manifest contract

Later tasks use this CLI surface, not an imported Python API:

```bash
python3 scripts/ci/bundle.py --app "/private/tmp/notch-pet-ci/package/notch-pet-dev/Notch Pet.app" --output /private/tmp/notch-pet-ci/bundle --identity /private/tmp/notch-pet-ci/identity.json
python3 scripts/ci/bundle.py --verify /private/tmp/notch-pet-ci/bundle --identity /private/tmp/notch-pet-ci/identity.json --extract-to /private/tmp/notch-pet-ci/extracted
```

The required `--identity` file is independently supplied to both jobs from trusted workflow context and selected toolchain metadata.
It has exactly these fields: `commit` (40 lowercase hex characters), `run_id` (bounded identifier),
`run_attempt` (positive integer), `platform` (`macos`), `architecture` (`arm64`), `configuration` (`debug`),
`xcode_build` (bounded identifier), and `swift_version` (bounded version output).
Creation checks actual host architecture and toolchain against that input.
Verification compares all identity fields before extraction. It never takes expected identity from the manifest itself.
The manifest also records actual macOS and Python versions through an explicit allowlist.

Implementation sketch:

```python
def create_bundle(app: Path, output: Path, identity: dict) -> None: ...
def verify_bundle(bundle: Path, identity: dict, extract_to: Path | None = None) -> None: ...
def main() -> int: ...
```

The output directory contains only `app.tar.gz` and `manifest.json`.
Manifest schema 1 stores identity, allowed version metadata, archive checksum/size and every entry's type/mode.
Regular files also have size and SHA-256. Entries live beneath the exact `Notch Pet.app` root.
Validate the two executable files, the app plist and its executable/package identity, and the Pet bundle's manifest/artwork.
Accept only normal directories and regular files. Reject links, special files, duplicate/escaping/noncanonical paths,
unsafe mode bits, oversized input, and any mismatch between archive entries and the manifest.
Limits: 4096 entries, 240 UTF-8 bytes per path, 4 MiB manifest, 64 MiB per file and 256 MiB total/archive.
These bounds comfortably contain the inspected five-file, 3.75 MB debug app.

Outputs and extraction destinations must be outside the checkout and must not exist already.
Validate the entire archive and payload before creating an extraction destination.
Extract manually into a new private temporary directory, preserve approved modes, then publish it at `--extract-to`.
Never execute either bundled binary from this tool. The Helper job runs F2 only after verification.
Checksums detect changes and do not provide signed provenance.

F3 verification will use the actual F1 bundle plus disposable missing-resource, modified-content,
independent-identity, unsafe-path/link, malformed-manifest and extraction-preservation cases outside the repository.

### F3 verification

The real F1 app produced a five-file archive of 1,955,809 bytes.
Its independently supplied identity names the original build commit `7cb67f2`, fictional run `local-f3`,
attempt 1, macOS/arm64/debug, Xcode build `17F42` and stdout from the explicitly selected Swift toolchain.
Creation validates actual host/toolchain values against that input. F4 will construct the same shape from workflow context.

Both CLI examples above exited 0. The verifier reproduced all source file bytes and permission modes after extraction.
`env DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer python3 /private/tmp/notch-pet-ci/f3/check-bundle.py`
exited 0: `F3 bundle acceptance passed: 28 checks; no bundled binary executed`.

The checks cover actual creation/extraction, source and archived missing artwork, changed archive bytes,
changed file content with an updated outer checksum, five independently expected identity mismatches,
boolean/integer identity confusion, malformed/duplicate/unknown-schema/oversized metadata,
an oversized file declaration, escaping/absolute/backslash paths, duplicate and case-colliding entries,
symbolic/hard links, FIFO, setuid mode, wrong binary architecture despite consistent checksums,
malformed plist despite consistent checksums, and preservation of existing output/extraction destinations.
Every invalid verification case failed before publishing an extraction destination.

The added malformed-plist fixture initially exposed an uncaught `xml.parsers.expat.ExpatError`.
The final tool categorizes that parser exception without a traceback or raw decoder details.
The same fixture then passed with the other checks. No requirement or assertion was weakened.

Python syntax validation and `git diff --check` exited 0.
No Swift source, app configuration, or existing test changed. Swift tests and packaging were not repeated.
Evidence: `/private/tmp/notch-pet-ci/reports/f3-bundle-checks.log`.
The independent input is `/private/tmp/notch-pet-ci/identity.json`, the archive is under
`/private/tmp/notch-pet-ci/bundle`, and verified extraction is under `/private/tmp/notch-pet-ci/extracted`.
The expected identity must come from outside the downloaded artifact. A missing `--identity` is a CLI error.

On creation failure, check the selected toolchain, source app layout/modes and resource references.
On verification failure, preserve the failed artifact and inspect the bounded error category before regenerating it.
Do not replace expected identity with the manifest's identity or execute its helper to diagnose a rejected archive.
On an existing destination error, select a new disposable destination instead of overwriting existing files.

## F4 workflow contract

Keep `build`/Build stable and add `helper`/Helper with `needs: build`.
Build exposes `artifact-id` from its upload step. Helper requires a nonempty decimal ID before downloading,
so an empty output cannot fall back to downloading every artifact.
Upload name: `notch-pet-<commit>-<run_id>-<run_attempt>`; retention: one day.
Download that single ID within the current run, with digest mismatch set to `error` and no cross-run token.
The uploaded directory contains F3's archive and manifest only.

Both jobs independently write `notch-pet-ci/identity.json` under runner temporary storage.
Use `GITHUB_SHA`, `GITHUB_RUN_ID`, integer `GITHUB_RUN_ATTEMPT`, fixed macOS/arm64/debug,
selected Xcode build `17F42`, and actual selected Swift stdout.
Build creates and verifies the bundle before upload.
Helper verifies and extracts it before running the unchanged F2 checker against the extracted executable.
Helper contains no build or test command and does not launch the app.

Use verified immutable pins: upload-artifact v7.0.2 at `cf430e030ddbb5b0abf93d22962f4752f3646cd9`,
download-artifact v8.0.2 at `9000827ccba6bdab643e8b6fd33ac0654aef8333`.
Both tag targets were verified with `git ls-remote`.
Their [upload inputs](https://github.com/actions/upload-artifact/blob/cf430e030ddbb5b0abf93d22962f4752f3646cd9/action.yml)
and [download inputs](https://github.com/actions/download-artifact/blob/9000827ccba6bdab643e8b6fd33ac0654aef8333/action.yml)
define these bindings. Hosted action execution remains F8.

Local verification: run the actual YAML shell steps with fictional workflow identity and separate Build/Helper roots,
copy the archive and manifest between them to model transfer, verify identical archive checksums,
and run the extracted helper. Confirm no build directory appears in Helper's root.
Reject missing/modified artifacts before invoking the helper. Run pinned actionlint and `git diff --check`.
The local copy does not establish GitHub service upload/download behavior.

### F4 verification

`python3 /private/tmp/notch-pet-ci/f4/check-roundtrip.py` exited 0:
`F4 local artifact round trip passed`.
The harness used installed PyYAML to select the actual YAML shell blocks; no project dependency was added.
It executed those blocks with separate temporary Build and Helper roots and fictional workflow context.
Local `DEVELOPER_DIR` used `/Applications/Xcode.app/Contents/Developer`, whose version/build matches the selected
hosted Xcode 26.5/17F42. The hosted installation path itself still needs F8.

- Fresh packaging and archive verification exited 0: five files, 1,955,965 archive bytes.
- Both jobs independently generated identical expected identity from commit `2b12972`, fictional run `10404`,
  attempt 1, and their selected toolchain. No expected identity was read from the copied artifact.
- The copied archive and manifest retained exactly the original SHA-256 values.
  Verification and extraction exited 0 after the copy.
- The actual extracted helper passed every F2 process assertion and printed `Bridge process checks passed`.
  It handled 15 fictional hook projections; invocation times were 6–606 ms and open-stdin checks were 71–72 ms.
  Its bytes and mode matched Build's helper. Helper's root contained no build directory.
  Static review also found no build/test/run.sh command in Helper's shell steps.
- A decimal artifact ID passed. Empty, nonnumeric and multiple-ID inputs failed the pre-download guard.
- Missing, modified and wrong-attempt artifacts each failed verification with exit 1.
  None published an extraction directory or reached the helper-execution step.
- Pinned actionlint 1.7.12 and `git diff --check` exited 0.
  No Swift source or tests changed, so the full suite was not repeated.

Evidence: `/private/tmp/notch-pet-ci/reports/f4-roundtrip.log` and the per-step logs under
`/private/tmp/notch-pet-ci/f4/roundtrip-i5udl7ek`.
This is local file-transfer and workflow-shell evidence. No GitHub upload, download, dispatch or push was performed.

For a direct local reproduction using the existing verified F3 output, choose a new temporary root:

```bash
ci_transfer_root=/private/tmp/notch-pet-ci/manual-transfer-1
mkdir -p "$ci_transfer_root"
cp -R /private/tmp/notch-pet-ci/bundle "$ci_transfer_root/downloaded"
python3 scripts/ci/bundle.py --verify "$ci_transfer_root/downloaded" --identity /private/tmp/notch-pet-ci/identity.json --extract-to "$ci_transfer_root/extracted"
python3 scripts/check-event-bridge.py --helper "$ci_transfer_root/extracted/Notch Pet.app/Contents/MacOS/NotchPetHook"
```

Use a fresh root on each run. If the normal socket exists, stop and leave it intact.
For a missing artifact ID or download failure, inspect Build's upload result before rerunning anything.
For identity/checksum rejection, retain the failed files and compare the expected context with the Build run/attempt.
Never rebuild in Helper, switch to another artifact, or copy expected identity out of its manifest to obtain a pass.

## F5 coverage contract

CLI: `coverage.py --build-root PATH --output REPORT_ROOT`.
Discover exactly one debug test runner, its sibling instrumented `NotchPetHook`, and the same build's
`codecov/default.profdata`. Require all three. The exporter does not build or execute them.
The caller must first establish a successful complete test run. F7 will enforce that sequencing.
Existing profile data alone is not proof of test success.

```python
def normalize_report(report: dict, sources: set[Path]) -> tuple[dict, dict]: ...
def export_coverage(build_root: Path, output: Path) -> None: ...
def main() -> int: ...
```

Use the selected toolchain's native `llvm-cov export` and `show` commands, with a real profile and both binaries.
Do not use `--empty-profile`, estimated values or a synthetic zero for a missing source.
Add the helper mapping because SwiftPM's default test-runner-only export omits that production module.
LLVM itself reports zero executed lines for the helper when its counters are absent from the successful test profile.

Scope is every current `Sources/**/*.swift` file, grouped by its first directory below Sources.
Exclude Tests and generated sources outside that tree by explicitly passing the complete production inventory to LLVM.
Use `--skip-functions --skip-expansions` for JSON: otherwise this toolchain exports unrelated function records even
when its file table is filtered. Keep native per-file segments, summaries and totals, with repository-relative filenames.
Require exactly the expected source set, valid nonnegative integer counts, consistent percentages and matching totals.
Any missing module/file or malformed report fails. A genuine measured zero is valid, and no threshold is enforced.

Publish only a fully validated `REPORT_ROOT/coverage/` directory, without replacing existing coverage output.
It contains native normalized `coverage.json`, `summary.json`, `summary.md`, input/tool metadata and portable `html/index.html`.
Normalize HTML source titles and links to `coverage/Sources/...`, preserving official LLVM source-line rendering.
Verify every local HTML asset/page link before publication.
Keep bounded tool diagnostics in REPORT_ROOT even after a native tool failure.
All outputs and temporary fixtures remain outside the checkout.

Verification: export the actual passing 132-test baseline, check all five modules and 38 production files,
validate HTML links and source rows, then reject missing/corrupt profiles, missing/uninstrumented binaries,
malformed counters/source tables and an existing output directory. No Swift implementation changes are planned.

### F5 verification, 2026-11-01

```bash
env DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer python3 scripts/ci/coverage.py --build-root /private/tmp/notch-pet-dev/build --output /private/tmp/notch-pet-ci/reports
env DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer python3 /private/tmp/notch-pet-ci/f5/check-coverage.py
```

Both commands exited 0. The exporter used the actual passing 132-test baseline's instrumented binaries and profile.
Apple LLVM 21.0.0 produced coverage JSON schema 3.0.1. No tests or builds were rerun for this task.
Production Swift source and tests are unchanged since that passing baseline.
The output covers all 38 production Swift files and five modules:

| Module | Files | Covered lines | Percent |
|---|---:|---:|---:|
| EventBridge | 6 | 534/578 | 92.39% |
| NotchPet | 15 | 109/1561 | 6.98% |
| NotchPetHook | 1 | 0/7 | 0.00% |
| Pet | 4 | 90/152 | 59.21% |
| SessionState | 12 | 1215/1259 | 96.51% |

This profile measures the Swift suite. The separate uninstrumented Helper job's process checks do not add coverage to it.
The helper's real instrumented mapping, not an invented placeholder, supplies its seven executable lines and zero hits.
No module is omitted for a low percentage, and no threshold is enforced.

The acceptance harness reported `F5 coverage acceptance passed: 22 checks; no test/build command executed`.
It verified complete production scope, native counts, five module summaries, all 39 HTML pages, portable paths,
and exact main-table source rows for every source file.
It rejected missing build/profile/test-runner/helper inputs, corrupt/empty profiles, an uninstrumented helper,
ambiguous profiles, unknown schemas, missing/duplicate/nonproduction files, invalid integer/percentage/segment data,
missing metrics and unfiltered function records. It also preserved existing valid coverage output.
Corrupt-profile tool diagnostics remained available in a bounded log without a published coverage directory.

The initial acceptance reader counted LLVM's nested instantiation tables as extra source lines.
Its table-depth tracking was corrected to compare the main source table strictly. The exporter did not change for that correction.
All main source rows then matched the original source text, including Unicode and escaped characters.
`git diff --check` exited 0; no generated files appeared in the checkout.

Artifacts are under `/private/tmp/notch-pet-ci/reports/coverage`:
`coverage.json`, `summary.json`, `summary.md`, `metadata.json`, and `html/index.html` with its source pages/assets.
`metadata.json` records actual LLVM/export versions and SHA-256 hashes of the input profile and both binaries.
Evidence logs: `/private/tmp/notch-pet-ci/reports/f5-coverage.log`, `f5-coverage-checks.log`, and `coverage-tool.log`.

For reproduction, first run the complete instrumented suite successfully, then export into a fresh report root.
An existing `coverage/` directory or `coverage-tool.log` is preserved rather than overwritten.
Missing input means the test build/coverage flag or scratch root is wrong; do not substitute zero coverage.
For native tool failure, retain `coverage-tool.log` and confirm the selected toolchain matches the instrumented build.
For missing source coverage, confirm both the test runner and instrumented helper are present from that same build.
Do not use the uninstrumented artifact from Build as the coverage mapping input.

## F6 result-checker contract

`python3 scripts/ci/required-result.py` reads one bounded JSON object from `CI_JOB_RESULTS`.
Its exact keys are the stable job IDs `workflow`, `tests`, `build`, `contract`, and `helper`.
Every value must be the string `success`. F7 will bind each ID directly to its corresponding `needs.<id>.result`.
The display names printed by the tool remain Workflow, Tests, Build, Contract and Helper.
Nested `toJSON(needs)` records are not this input shape and must fail.

```python
def required_result(raw: str | None) -> tuple[bool, list[str]]: ...
def main() -> int: ...
```

Caller example:

```bash
CI_JOB_RESULTS='{"workflow":"success","tests":"success","build":"success","contract":"success","helper":"success"}' python3 scripts/ci/required-result.py
```

Pass means exit 0 and `Required: success`. Every invalid fixture must exit 1 with `Required: failure`.
Accept no extra/missing/duplicate job, non-string/nested result, unknown state, oversized input or malformed JSON.
Limit input to 16 KiB. Print only the fixed job display names and bounded labels:
success, failure, cancelled, skipped, unknown, malformed or missing. Never print raw keys, values or parser errors.
Use exactly five fixture groups: all-success; non-success states; missing/extra jobs; malformed input; empty input.

### F6 verification, 2026-11-01

The all-success caller example exited 0 and printed all five job names plus `Required: success`.
The unset-input command exited 1 with five missing labels and `Required: failure`.
`python3 /private/tmp/notch-pet-ci/f6/check-required.py` exited 0:
`F6 Required acceptance passed: 5 groups, 90 CLI cases; invalid input never printed`.

| Group | Cases | Expected result |
|---|---:|---|
| All-success | 3 | Exit 0 for valid JSON order/whitespace variants |
| Non-success states/types | 65 | Exit 1 for every failure/cancel/skip/unknown/non-string value in each job |
| Missing/extra jobs | 8 | Exit 1 for any missing job, extra key, display-name key or empty object |
| Malformed input | 10 | Exit 1 for malformed/non-object/duplicate/deeply nested/oversized/invalid-encoding input |
| Empty input | 4 | Exit 1 for unset, empty and whitespace-only input |

The duplicate-key case placed failure before success to prove that a later value cannot overwrite failure.
The oversized case used otherwise valid successful results plus padding, proving the byte bound is enforced.
Every output stayed below 1 KiB and printed no synthetic private key/value marker or parser traceback.
No Swift tests, builds, configuration probes, helper processes or hosted actions ran for F6.
`git diff --check` exited 0. Evidence: `/private/tmp/notch-pet-ci/reports/f6-required-checks.log`.

For a local failure reproduction, change only `tests` to `cancelled` in the caller example above.
The script must exit 1 and show `Tests: cancelled` plus `Required: failure`.
If the job set is unexpected, compare the five stable workflow IDs with the explicit input object.
Do not remove a failed/missing job from that object or map a non-success state to success.

## F7 final workflow contract

Use native `swift test --event-stream-output-path PATH --event-stream-version 6.3`.
The selected Xcode emits schema `6.3.0`; a temporary real Swift Testing package qualified passing,
failing, skipped and parameterized tests. Preserve the raw JSON Lines without conversion.
Derive a separate summary from test IDs and terminal events. Require one complete run and at least one executed function.
Fail on missing/malformed/truncated results, failing issues, cancellation or incomplete test outcomes.
Keep skips and parameterized-case counts distinct from passed functions.
The original test command's exit status is recorded and cannot be replaced by report-generation success.

Keep shared metadata, command logging, report inventory and publication steps in YAML anchors.
No additional implementation file or runtime dependency is needed.
Record only allowlisted commit/run/attempt, selected runner/toolchain, actual OS/architecture/image and tool versions.
Bound command logs to 2 MiB while draining output to preserve the child's actual exit status.
Tests use a separate instrumented build; Build's artifact stays uninstrumented.

Every job inventories its expected reports and publishes available reports after failure when not cancelled.
Missing/malformed reports reject the evidence receipt and fail an otherwise successful job.
Reports use the existing pinned upload action with three-day retention; binary retention remains one day.
Each upstream job exposes `evidence-ok` as a bounded true/false receipt.
Required uses `always()`, needs exactly Workflow/Tests/Build/Contract/Helper, passes their actual result strings
to F6, and also rejects any missing/non-true evidence receipt. Its summary identifies failed jobs and absent evidence.
No report step uses continue-on-error, retries or success substitution.

Final local verification replays the actual YAML shell steps with separate job roots, the full Swift suite,
native result validation, real coverage, a fresh artifact transfer and actual packaged-helper checks.
Use the temporary real pass/fail/skip stream and bounded malformed-report fixtures to verify result handling.
Exercise failure-status preservation, bounded logs, missing-report receipts and Required's negative cases.
Use pinned actionlint, inspect every expected job binding and finalize local reproduction/troubleshooting recipes.
Hosted service scheduling, upload/download and cancellation remain F8.


### F7 verification, 2026-11-01

The final local replay executed the actual workflow shell steps with separate roots for all six jobs.
It used the final workflow against source commit `2ac1a85`, with only F7 workflow/record changes uncommitted.
The local Xcode application path substitutes for the hosted path. Both select Xcode 26.5 build `17F42`.
Checkout, upload and download actions were simulated locally. The verified Darwin actionlint binary replaced the Linux installer.
These substitutions do not qualify GitHub service behavior or its Linux installer.

```bash
python3 /private/tmp/notch-pet-ci/f7/replay-final.py
python3 /private/tmp/notch-pet-ci/f7/check-final-controls.py
/private/tmp/notch-pet-ci/tools/actionlint .github/workflows/ci.yml
git diff --check
```

The replay and 44 executed failure-control steps exited 0. actionlint and the final diff check exited 0.
The temporary harnesses are session evidence, not repository dependencies. Durable reproduction commands follow below.

- Workflow: six names, triggers, permissions, full-SHA pins, timeouts, report conditions and job bindings checked.
  Concurrency includes event type. A PR number cannot collide with a push/manual run ID.
- Tests: all 132 functions passed with zero failed, skipped, cancelled or incomplete functions.
  The complete native schema `6.3.0` stream was validated without modifying its bytes.
  Real coverage includes all 38 production files, five modules and 39 HTML pages.
- Build: a fresh uninstrumented app and helper were packaged, archived and verified against independent expected identity.
  A byte-identical local artifact transfer supplied Helper. Its separate root contained no build directory.
- Helper: archive verification and every existing fictional process assertion passed against the extracted helper.
- Contract: the unchanged reference checker passed. Its SessionStore evidence limit remains open.
- Required: all five actual local job results and complete evidence receipts passed.
  All six report inventories completed and their report trees were archived locally.

A real temporary Swift Testing package preserved two passed functions, one failed function, one skipped function,
and two parameterized cases. Its deliberate issue returned exit 1, and the workflow summary also rejected it.
Controls rejected eight invalid streams/statuses: nonzero original exit, empty/truncated/malformed/duplicate JSON,
missing run end, missing function terminal event and unknown test identity.
A failed command retained exit 23 even when metadata collection failed.
A 3 MiB command stream produced a 2 MiB log containing the final failure marker and retained exit 23.
All six early-setup inventories rejected missing evidence.
Required rejected 12 cancellation/missing-result/receipt cases, plus a duplicate evidence key.
Malformed metadata also failed inventory. None of these fictional failures reran or replaced a failed product baseline.

Evidence: `/private/tmp/notch-pet-ci/reports/f7-final-replay.log` and `f7-final-controls.log`.
The final replay root is `/private/tmp/notch-pet-ci/f7/final-replay-fd_igm3b`.
Each job has `notch-pet-ci/reports/`, step logs and a summary. `simulated-actions-artifacts/` contains local report archives.
The actual passing raw stream is `tests/notch-pet-ci/reports/tests.jsonl` under that root.
Earlier F2, F3, F5 and F6 acceptance fixtures remain valid because their implementation files did not change in F7.

### Final local reproduction

Use an arm64 Mac with Xcode 26.5 build `17F42` and the verified actionlint 1.7.12 binary on PATH.
Run each command from the checkout. Stop on any nonzero exit. Keep the failed output and do not retry to replace it.
Choose a new external root. Existing bundle, extraction and coverage outputs are intentionally not overwritten.

```bash
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
export ci_root="$(mktemp -d /private/tmp/notch-pet-ci-local.XXXXXX)"
mkdir -p "$ci_root/reports" "$ci_root/package"
actionlint .github/workflows/ci.yml
git diff --check
swift test --scratch-path "$ci_root/test-build" --enable-code-coverage \
  --event-stream-output-path "$ci_root/reports/tests.jsonl" --event-stream-version 6.3
python3 scripts/ci/coverage.py --build-root "$ci_root/test-build" --output "$ci_root/reports"
env TMPDIR="$ci_root/package" bash scripts/run.sh --build-only
env TMPDIR="$ci_root/package" python3 scripts/check-event-bridge.py
python3 scripts/check-event-contract.py
python3 - <<'PYIDENTITY'
import json, os, subprocess
from pathlib import Path
value = {
    'commit': subprocess.check_output(['git', 'rev-parse', 'HEAD'], text=True).strip(),
    'run_id': 'local', 'run_attempt': 1, 'platform': 'macos', 'architecture': 'arm64',
    'configuration': 'debug', 'xcode_build': '17F42',
    'swift_version': subprocess.check_output(['/usr/bin/xcrun', 'swift', '--version'], text=True).strip(),
}
(Path(os.environ['ci_root']) / 'identity.json').write_text(json.dumps(value) + '\n')
PYIDENTITY
python3 scripts/ci/bundle.py --app "$ci_root/package/notch-pet-dev/Notch Pet.app" \
  --output "$ci_root/bundle" --identity "$ci_root/identity.json"
python3 scripts/ci/bundle.py --verify "$ci_root/bundle" --identity "$ci_root/identity.json" \
  --extract-to "$ci_root/extracted"
python3 scripts/check-event-bridge.py --helper "$ci_root/extracted/Notch Pet.app/Contents/MacOS/NotchPetHook"
CI_JOB_RESULTS='{"workflow":"success","tests":"success","build":"success","contract":"success","helper":"success"}' \
  python3 scripts/ci/required-result.py
```

Expected results: every command exits 0, no failed Swift tests, both process modes print `Bridge process checks passed`,
and Required prints `Required: success`. `reports/coverage/` contains JSON, HTML, module summaries and tool/input metadata.
The bundle directory contains only `app.tar.gz` and `manifest.json`.
Local identity is independently supplied before verification. Hosted jobs use commit/run/attempt from GitHub context instead.
Never derive expected identity from a downloaded manifest.

The native-summary reproduction command is `python3 scripts/ci/test-results.py`.
Set `RUNNER_TEMP` to a disposable job root containing `notch-pet-ci/reports/tests.jsonl` and `tests-exit-code.txt`.
Set `GITHUB_STEP_SUMMARY` to an external Markdown path, then run that command.
Use the actual Swift command status in the receipt. Do not create a zero receipt for a failed or unobserved execution.
Its outputs are `test-summary.json` or a bounded `tests-summary-error.txt` and a nonzero exit.

For metadata, bounded logs, inventory and Required reporting, use the CLI table in F9 below.
Supply `GITHUB_SHA`, `GITHUB_RUN_ID`, `GITHUB_RUN_ATTEMPT`, `GITHUB_JOB`, `CI_RUNNER_LABEL`, `RUNNER_TEMP`,
`GITHUB_OUTPUT` and `GITHUB_STEP_SUMMARY` explicitly. They are identifiers and output paths, not credentials.
Set `CI_JOB_RESULTS` to actual upstream results and `CI_EVIDENCE_RESULTS` to their actual `evidence-ok` strings.
Manual all-success input tests the predicate only. It does not prove that any upstream job ran.

### Troubleshooting by job

| Job | First evidence to inspect | Next check |
|---|---|---|
| Workflow | `validator-setup.log`, `validator-version.txt`, `workflow.log` | Confirm download checksum and pinned validator. Never remove verification to accept a different binary. |
| Tests | `tests.log`, `tests-exit-code.txt`, raw `tests.jsonl`, `test-summary.json` or `tests-summary-error.txt` | Confirm selected Swift/schema and the recorded failing test. Preserve the original exit. Missing native records fail acceptance. |
| Tests coverage | `coverage-tool.log`, `coverage/metadata.json` | Confirm the successful test build has its matching profile, test runner and instrumented helper. Use a fresh output root. Missing coverage is not zero coverage. |
| Build | `build.log`, `archive.log`, `expected-identity.json`, `build-manifest.json` | Confirm native executables, plist, Pet resources, modes and the exact toolchain. Do not weaken archive bounds or identities. |
| Helper | `verification.log`, `expected-identity.json`, `helper.log` | Confirm Build's numeric artifact ID and same-run identity. Reject alteration before execution. An occupied socket stops the check. Never delete another instance's endpoint. |
| Contract | `contract.log` | Inspect the reference failure. Its known difference from SessionStore still needs its separate owning repair. |
| Required | `required.log` and summary's result/evidence table | Any non-success job or missing receipt fails. Inspect that job's inventory and original failure first. |
| Any job | `inventory.json` and available report archive | Missing/invalid evidence fails an otherwise successful job. Report upload failure also fails the job. Early checkout/setup failure or cancellation may leave no archive. |

Command logs retain at most 2 MiB, including final output after truncation. Native results allow at most 32 MiB,
100,000 records and 1 MiB per record. Inventory bounds each expected report to 32 MiB and rejects nonregular files.
Binaries expire after one day. Reports expire after three days. Preserve needed review evidence before expiry.
Inventories and available-report uploads use `!cancelled()`, while Required uses `always()`.
A cancelled or unavailable run never becomes passing because reports are absent.

F1–F7 are locally verified. F8b remains unchecked. Complete its hosted PR/failure/docs-only/artifact/cancellation drills
and finish with a passing hosted run before marking this specification done. F8a's results follow below.

## F8a hosted baseline diagnosis, 2026-11-01

The user approved this diagnostic task and the F8 split. No repair or new hosted execution ran.
The merged local branch was preserved as `archive/automation-ci-foundation-f7` at `a45d0ae`.
`feat/automation-ci-foundation` was recreated from fetched `origin/main` at `51d9b86`.

### Hosted observations

- [PR #8](https://github.com/eohnai/notch-pet/pull/8) merged on 2026-11-01 as
  `51d9b86bfd4f63cd92ae19a944b7f4a711bc5f24`.
  Its [PR run 41274351177](https://github.com/eohnai/notch-pet/actions/runs/41274351177) passed all six jobs.
  The API reports head `a45d0ae01ab443bf9a46b6d3003bbebd3b9f1231`.
  The report's tested checkout identity is `b56f2082969c4d758c9d352bc20bfd49a72eccdb`.
  Keep both identities when reviewing PR evidence. The saved native summary records 132 passed functions and zero other outcomes.
- [Main push run 41275848518](https://github.com/eohnai/notch-pet/actions/runs/41275848518) failed at
  `51d9b86bfd4f63cd92ae19a944b7f4a711bc5f24`, attempt 1.
  Tests recorded 131 passed functions and one failed function:
  `receiverDeadlineDoesNotResetForEachByte()` at `Tests/EventBridgeTests/ContractAndSocketTests.swift:178`.
  The only issue was `Expectation failed: (successfulWrites → 1) >= 2`.
  The native stream places that issue about 179 ms after the test-start event.
  It contains no trace of sender scheduling or individual socket operations.
- Workflow, Build, Contract, and Helper passed on main. Required rejected the failed Tests job and its incomplete evidence.
  The test log, original exit code 1, native stream, failed-test summary, metadata, and inventory were uploaded.
  Coverage export was skipped after the failed test command. Inventory reported its coverage inputs as missing.
  This observed failure does not substitute for the deliberate-failure drill in F8b.
- `git diff --exit-code a45d0ae 51d9b86 -- .` exited 0. The branch head and final merge have identical trees.
  This comparison does not independently compare the PR report's synthetic checkout tree.
  Both reports select `macos-26`, arm64, Xcode 26.5 build `17F42`, and Swift 6.3.2.
  The image changed from `20261021.0445.8` to `20261026.0455.2`. Python changed from 3.15.0 to 3.15.1.
  These environment differences were observed, not established as causes.

### Local observations and conclusion

The planned focused command ran against unchanged repository code:

```bash
env DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  swift test --scratch-path /private/tmp/notch-pet-f8-diagnosis/build \
  --enable-code-coverage --filter receiverDeadlineDoesNotResetForEachByte
```

The first sandboxed attempt failed before testing because the compiler could not write its module cache:
`error opening '/Users/ianhoe/.cache/clang/ModuleCache/Swift-5SCGS38H536W.swiftmodule' for output`.
The approved escalated execution exited 0: one test passed in 0.128 seconds.
This passing local run does not replace or clear the failed hosted baseline.

Hypothesis: the test requires the sender to run twice before a receiver deadline that can correctly expire independently.
`EventBridgeServer.receiveLoop` starts a 100 ms deadline after `accept` and passes the same deadline to every read.
The test sleeps for 15 ms between writes and requires at least two successful writes.
A sender pause can exceed 100 ms, so a correct receiver can close before the second write.

A disposable package copied all six production EventBridge source files byte-for-byte.
It retained the original test assertions and isolated endpoint, with timing prints and one controlled sleep selection.
Only `DIAG_DELAY` differed between the two executions:

| Execution | Result | Observed behavior |
|---|---|---|
| `DIAG_DELAY=0` | Exit 0, one test passed | Six writes. Closure observed at 113.6 ms. Zero delivered incomplete messages. |
| `DIAG_DELAY=1` | Expected exit 1, only the original write-count assertion failed | One write. The requested 150 ms sleep lasted 155.0 ms. Closure observed at 155.3 ms. Zero delivered incomplete messages. |

Both executions also passed the original check that a subsequent valid message reaches the callback.
The receiver source and its production deadline were unchanged. The probe confirmed that a sender delay is sufficient
to reproduce the exact failed assertion while the receiver rejects the incomplete message and remains available.
It does not prove that the hosted sender experienced that exact delay. No receiver defect was demonstrated by this probe.

The confirmed test defect is its assumption about sender scheduling within the production deadline.
The proposed repair must preserve fragmented-input coverage, closure, omission, and subsequent-message checks.
It must distinguish a fixed total deadline from an incorrectly reset deadline without requiring two scheduler turns within 100 ms.
Simply dropping the write-count assertion would weaken that evidence. The repair design and verification need a separate task review.
The existing maximum-frame buffering limitation is a different test issue and was not investigated or changed here.

### Reproduce the diagnostic probe

Session evidence is outside the checkout:

- `/private/tmp/notch-pet-f8-diagnosis/probe-control.log` and `probe-delayed.log`.
- `/private/tmp/notch-pet-f8-diagnosis/probe/` contains the instrumented test and unchanged receiver sources.
- `/private/tmp/notch-pet-f8-diagnosis/pr-artifacts/` contains the passing PR's saved test reports.
- `/private/tmp/notch-pet-f8-inspect-41275848518/` contains the failed main run's saved test reports.

The two actual probe commands used this form, first with `DIAG_DELAY=0`, then `DIAG_DELAY=1`:

```bash
env DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer DIAG_DELAY=1 \
  swift test --package-path /private/tmp/notch-pet-f8-diagnosis/probe \
  --scratch-path /private/tmp/notch-pet-f8-diagnosis/probe-build \
  --enable-code-coverage --filter receiverDeadlineDoesNotResetForEachByte
```

If temporary evidence is gone, recreate the controlled change in a fresh external package containing
`Sources/EventBridge`, `Tests/EventBridgeTests/ContractAndSocketTests.swift`, and a minimal Swift package manifest
with only the EventBridge target and its test target. Keep the original assertions and production sources.
Inside only `receiverDeadlineDoesNotResetForEachByte`, replace its sleep with:

```swift
let delayed = ProcessInfo.processInfo.environment["DIAG_DELAY"] == "1" && successfulWrites == 1
Thread.sleep(forTimeInterval: delayed ? 0.150 : 0.015)
```

Run the same filtered command with `DIAG_DELAY=0` and `DIAG_DELAY=1`, using the fresh package and scratch paths.
The delayed case should fail only `successfulWrites >= 2`, while closure, zero incomplete deliveries,
and subsequent valid-message delivery still pass. Preserve an unexpected outcome instead of retrying to replace it.
These commands require task-specific execution approval in a future session.

## F8r deadline-test repair, 2026-11-01

The user approved this repair, its focused test, disposable probes, and the full local suite.
Only `Tests/EventBridgeTests/ContractAndSocketTests.swift` changed. Receiver sources are unchanged.

### Change

The old test required two successful writes before closure. That assumed the sender runs twice within the 100 ms receiver deadline.
The new test judges each attempt by the gap between closure and the start of the last successful write:

| Attempt result | Meaning | Test action |
|---|---|---|
| Closure seen less than 100 ms after the last write started | That byte did not reset the deadline | Pass |
| Closure seen 100 ms or more after the last write started, or no write succeeded | Sender paused, so no evidence either way | Retry |
| A one-byte write misses its 50 ms limit (`BridgeError.timeout`) | Sender paused | Retry |
| No closure within 250 ms | Deadline resets per byte | Fail without retry |
| Five attempts without evidence | Correctness unproven | Fail |

The write start time is taken before `writeAll`. A pause after the byte leaves can then only make an attempt inconclusive.
It cannot make a resetting receiver look correct. Each attempt also expects closure no sooner than 100 ms after connect.
A correct receiver starts its deadline after `accept`, so this check cannot fail for a correct receiver.
The old `timeout` path was a second scheduling hazard: a pause inside `writeAll` threw out of the test.
The zero-delivery and subsequent-valid-message checks are unchanged.
The new test hard-codes the receiver's 100 ms deadline in one local constant, with a comment naming its source.

### Verification

| Check | Result |
|---|---|
| Changed test alone, repository package | Passed in 0.127 s |
| Probe, no pause | Attempt 1 conclusive, passed |
| Probe, 150 ms pause in the first attempt only | Attempt 1 inconclusive, attempt 2 conclusive, passed |
| Probe, 150 ms pause in every attempt | Five inconclusive attempts, failed as expected |
| Probe with a receiver that resets its deadline per byte | Attempt 1 stayed open, failed as expected |
| Resetting receiver, pause in the first attempt | Attempt 2 stayed open, failed as expected |
| Resetting receiver, pause in every attempt | Five inconclusive attempts, failed as expected |
| Full suite, repository package | 132 tests in 24 suites passed |

The probe was a disposable package outside the checkout with byte-identical EventBridge sources and the changed test.
It added only a `DIAG_DELAY` switch (`none`, `first`, `every`) that replaces one 15 ms sleep with 150 ms,
and an attempt-result print. The reset probe added `end = deadline(after: 100)` after each read in `readBounded`.
Commands used `env DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --filter receiverDeadlineDoesNotResetForEachByte`
with `--package-path` and `--scratch-path` outside the checkout. The subsequent hosted observations follow below.

## PR #9 merge verification, 2026-11-01

The user requested merging PR #9 and checking main before the proposed workflow extraction.
The repair is committed as `4f0226a` and its records as `90254a2`.
The workflow and CI scripts were unchanged by those commits.

- [PR #9](https://github.com/eohnai/notch-pet/pull/9) at head `90254a26464b1551807264b8878fc081b3942351`
  passed all six jobs in [run 41281269127](https://github.com/eohnai/notch-pet/actions/runs/41281269127).
- After checking all six results and the three changed paths, the PR merged with an exact-head guard.
  Its merge commit is `bf12b51bd670d730b5d7ebb45d691824dedd1c43`.
- The automatic [main run 41281493943](https://github.com/eohnai/notch-pet/actions/runs/41281493943), attempt 1,
  failed. Its native summary records 131 passed functions and one failed function.
  `receiverDeadlineDoesNotResetForEachByte()` passed. The sole failure was
  `invalidFramesNeverReachCallback()` at `Tests/EventBridgeTests/ContractAndSocketTests.swift:151`:
  `Expectation failed: (observations.count → 2) == 1`.
- Workflow, Build, Contract, and Helper passed. Tests and Required failed.
  The uploaded report preserved the native stream, summary, log, original exit status, metadata, and incomplete inventory.
  The failing input is not identified by the test's aggregate count assertion.
  Its maximum-frame buffering assumption is already a known limitation, but its role in this failure is unconfirmed.
- The main failure was inspected with `gh run view 41281493943` and its saved test report was downloaded.
  Evidence is outside the checkout at `/private/tmp/notch-pet-pr9-main-failure/`.
  `gh run watch 41281493943 --interval 20 --exit-status` exited 1.
  No run was repeated, and no additional local tests or repairs ran.

The workflow extraction remains proposed. Establish a passing main baseline before starting it.
Plan a separate diagnosis that identifies the extra callback's input, then review any resulting repair.
The remaining F8b acceptance drills are still open.

## Invalid-frame callback diagnosis, 2026-11-01

The user invoked `debug-issue` to explain main run `41281493943`'s failure.
This diagnosis used the saved reports, one focused repository test, and disposable probes.
No repository Swift code changed. No full suite, hosted rerun, or repair ran.

### Cause and evidence limit

`invalidFramesNeverReachCallback()` constructs `padded` at `ContractAndSocketTests.swift:139`:

```swift
let padded = Data(valid.dropLast()) + Data(repeating: 32, count: 16_384 - valid.count) + Data([10, 32])
```

Its first 16,384 bytes are valid JSON, trailing JSON whitespace, and LF.
Only its last byte, an extra space at position 16,385, makes the complete input exceed the frame limit.
The fixture therefore contains a valid complete frame before that extra byte.

The [accepted transport contract](../../contracts/agent-events-v1.md#socket-lifecycle-and-failure-behavior) requires rejection only
when extra bytes are already buffered after LF. It permits one bounded frame followed by connection closure.
`SocketSupport.readBounded` implements that rule with a nonblocking peek after LF at `SocketSupport.swift:146`.
It returns the valid frame if no extra byte is queued then.
`writeAll` can need multiple socket writes. Sending the complete fixture does not establish that its final byte
was available when the receiver checked.

Hypothesis: the test expects the final space to be available before the receiver returns the valid prefix.
A different delivery schedule can produce one allowed callback for that prefix and one for the final valid message.
The resulting count is two, while the test always expects one.

Two disposable cases confirmed that assumption against byte-identical copies of all six EventBridge source files:

| Case | Observation | Result |
|---|---|---|
| Queue all 16,385 bytes before calling the production reader | A peek confirmed all bytes were available. `readBounded` threw `BridgeError.invalidMessage`. | Control passed. |
| Send the fixture's 16,384-byte prefix to the actual server and hold the suffix until its callback | `HookEnvelopeV1.decode` accepted the prefix. The server delivered one callback before the suffix. The final valid message raised the count to two. | The original `observations.count == 1` assertion failed with the exact hosted error. |

The queued control used a socket pair with a 65,536-byte send buffer so all bytes could be queued first.
The delayed case used the unchanged server and an isolated listener, without changing receiver deadlines.
A separate local socket-pair observation reported an 8,192-byte default send buffer.
One nonblocking write requested 16,385 bytes and returned 8,192, demonstrating an actual short write on this Mac.
That observation does not establish the hosted socket's buffer size.

The test's buffering assumption is confirmed as a reproducible defect. The receiver behavior in both probes matches the contract.
The saved hosted report contains only the aggregate count failure, not per-input callbacks or socket traces.
It cannot prove which fixture caused the original extra callback or its exact delivery schedule.
The `valid + valid` fixture also contains a complete valid prefix and needs the same buffered-input distinction during repair review.

### Executed commands

```bash
env DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  swift test --scratch-path /private/tmp/notch-pet-f8-frame-diagnosis/build \
  --enable-code-coverage --filter invalidFramesNeverReachCallback
env DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  swift test --package-path /private/tmp/notch-pet-f8-frame-diagnosis/probe \
  --scratch-path /private/tmp/notch-pet-f8-frame-diagnosis/probe-build
```

The unchanged repository test exited 0: one test passed in 0.014 seconds.
The probe exited 1 as intended: its prequeued case passed and its delayed case reproduced
`Expectation failed: (observations.count → 2) == 1`.
Neither outcome replaces the failed hosted baseline.
The logs are `/private/tmp/notch-pet-f8-frame-focused.log` and
`/private/tmp/notch-pet-f8-frame-diagnosis/probe.log`. The probe source is beside its log, under `probe/`.

To recreate the probe, use a fresh external Swift package with the production EventBridge target and a test target.
Keep the production sources unchanged. Recreate `padded`, verify its LF-terminated prefix decodes,
and send only that prefix through an isolated server connection. Wait for its callback before attempting the suffix.
Then send a separate valid message and check the original count assertion.
For the rejection control, prequeue the entire fixture in a sufficiently buffered socket pair.
Confirm the queued byte count before calling `readBounded`. The result must be `invalidMessage`.
Future execution still needs task-specific authorization.

### Proposed repair

Keep unconditionally invalid stream fixtures invalid before their terminating LF.
Test extra-byte and second-frame rejection separately with explicitly prequeued input.
Retain valid maximum-size input coverage and the subsequent valid-message check.
Label cases so future failures identify the input. This is a proposed test repair, not an accepted implementation task.

## Test-timing repair, 2026-11-01

The user approved a repair of the invalid-frame test and other timing-sensitive socket tests.
Only test files changed: `Tests/EventBridgeTests/ContractAndSocketTests.swift` and `Tests/SessionStateTests/UsageReceiverTests.swift`.

- `invalidFramesNeverReachCallback`: the oversized fixture puts LF at byte 16,385, so every prefix is invalid.
  `valid + valid` moved out because its first frame is a valid prefix. The test asserts that the only callback carries the final message's event ID.
- `queuedExtraBytesAreRejected` (new): queues each input in a 64 KiB socket pair before `readBounded` runs.
  It checks a valid maximum-size frame, a second frame, an extra byte, and a maximum-size frame plus one byte, each by name.
- `fragmentedFrameAndPeerIdentity`: uses a socket pair instead of the server's 100 ms accept deadline.
  The second write waits until `SO_NREAD` is 0, and the test asserts that the prefix had its own read.
- `stopClosesStalledConnectionAndReleasesOwnership`: the bound is 1 s. A probe showed that the client sees end-of-file
  whether or not the server accepted. The test therefore requires stop to end at least 100 ms after connect begins,
  which shows a stalled accepted read. It retries a shorter attempt up to five times.
- `malformedAndInvalidQuotaCannotReachCallback`: waits for a final valid observation and asserts that it is the only one.
  `rawSend` now reports delivery. The 8,193-byte case cannot be delivered (see STATUS.md, usage datagram limit),
  so it is a `withKnownIssue`. That check fails once the limit is fixed and the datagram is delivered.

Verification, all local with `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`:
the two suites passed (20 tests, 1 known issue). The two suites also passed 30 of 30 runs with three `yes` processes loading the CPU.
One full suite run passed (133 tests in 24 suites, 1 known issue). No hosted run was started.
The receiver-deadline, write-backpressure, and stop tests still depend on timing, with wider margins.

## PR #10 passing hosted baseline, 2026-11-01

[PR #10](https://github.com/eohnai/notch-pet/pull/10) merged the test repairs as
`08cb137152c0255063d14dc8c21525c48128ea70`.
Its [PR run 41284668475](https://github.com/eohnai/notch-pet/actions/runs/41284668475) and
[main run 41286560025](https://github.com/eohnai/notch-pet/actions/runs/41286560025) both passed all six jobs.
The saved main native summary has 133 passed functions, zero failed/skipped/cancelled/incomplete functions, and one known issue.
The known issue concerns oversized usage datagrams that cannot reach the receiver under its current buffer configuration.
It is not proof of receiver-side rejection at the declared 8,192-byte limit.
These passing runs resolve the preceding baseline failure. They do not complete F8b's deliberate acceptance drills.

## F9 workflow script extraction, 2026-11-01

The user approved the proposed extraction after PR #10 passed on main, including the multi-file exception.
The workflow shrank from 608 to 214 lines. Its six jobs, scheduling, conditions, permissions, time limits,
action pins, artifact bindings, retention, and report publication remain unchanged.
The four new scripts use only the Python standard library. `bundle.py` and `coverage.py` are unchanged.

### CLI boundaries and reproduction

Run each command from the checkout. These commands read the same explicit environment as the previous inline blocks.
Keep `RUNNER_TEMP`, `GITHUB_OUTPUT`, and `GITHUB_STEP_SUMMARY` outside the checkout.
Existing task-specific execution authorization still applies when a command starts a real check.

| Command | Responsibility | Outputs |
|---|---|---|
| `python3 scripts/ci/metadata.py` | Record allowlisted run and tool versions | `metadata.json` under the job's reports directory |
| `python3 scripts/ci/metadata.py --identity` | Derive expected artifact identity from independent CI context | `identity.json` and `reports/expected-identity.json` |
| `python3 scripts/ci/run-check.py` | Execute the command selected by `GITHUB_JOB`, retain bounded output and original exit status | The job log, exit receipt and metadata update |
| `python3 scripts/ci/test-results.py` | Validate native Swift results and retain actual test outcomes | `test-summary.json`, or a bounded error report and nonzero exit |
| `python3 scripts/ci/reports.py` | Validate the expected inventory for the current job | `inventory.json`, the `complete` output and Markdown summary |
| `python3 scripts/ci/required-result.py --reports` | Check job results and evidence, then write the Required reports | `required.log`, its exit receipt and Markdown summary |

The public CLI without `--reports` retains F6's original predicate-only behavior.
Its existing `required_result(raw: str | None) -> tuple[bool, list[str]]` stays available.
The new `write_reports() -> int` calls that predicate directly, avoiding a child process and duplicate job labels.
Metadata exposes `collect_metadata() -> None` and `write_identity() -> None` behind its two CLI modes.
The other extracted scripts each keep a `main() -> None` entry point.

For example, after an actual test command has written the raw stream and its original exit receipt:

```bash
export RUNNER_TEMP="$ci_root"
export GITHUB_STEP_SUMMARY="$ci_root/summary.md"
python3 scripts/ci/test-results.py
```

For metadata, identity, inventory, and Required, also supply `GITHUB_SHA`, `GITHUB_RUN_ID`, `GITHUB_RUN_ATTEMPT`,
`GITHUB_JOB`, `CI_RUNNER_LABEL`, and `GITHUB_OUTPUT`. Run metadata first to create the reports directory.
Set the selected `DEVELOPER_DIR` for real macOS checks. Use observed upstream results in `CI_JOB_RESULTS`
and their actual evidence receipts in `CI_EVIDENCE_RESULTS`. Never derive expected identity from a downloaded manifest.

### Verification

The original six Python blocks and predicate script were saved before editing, against base `08cb137`.
A disposable harness compared their results with the extracted CLIs using the actual passing main reports,
the saved failed main report, and fictional command/metadata fixtures. It did not run Swift tests, package the app,
launch a helper, inspect installed integrations, or trigger a hosted workflow.

```bash
python3 /private/tmp/notch-pet-ci-refactor-zbhfr15w/check-equivalence.py
/private/tmp/notch-pet-ci/tools/actionlint .github/workflows/ci.yml
git diff --check
```

The comparison exited 0: `PASS: 144 old/new fixture comparisons`.
It compared exit status, stdout/stderr, report bytes, evidence receipts, and Markdown summaries.
Coverage included:

- Native streams: actual passing and failed runs, one known issue, skipped/parameterized cases,
  nonzero original exit, empty/truncated/malformed/duplicate records, missing run end, unknown test identity, and size limits.
- Inventory: all six complete jobs, missing and malformed evidence, a symlink, and oversized reports.
- Required: both CLI modes, exact success, failures/cancellations/skips, unknown states, malformed/missing/extra/duplicate jobs,
  and missing, malformed, false, oversized, or non-string evidence receipts.
- Metadata: Darwin/Linux fixtures, unavailable or excessive version output, invalid UTF-8, independent identity, and the allowlist.
- Runner: all five command bindings, original exit 23, signal exit 143, missing executable exit 127,
  report collection failure, and a 3 MiB stream retained within a 2 MiB log with its final marker.

Expanded YAML comparison found only the 21 intended command substitutions across the six jobs.
The rest of the workflow graph matched the saved original exactly. actionlint exited 0.
A preliminary harness run stopped on case-insensitive fixture-name collisions. Distinct names fixed the harness, not production logic.
Evidence is `/private/tmp/notch-pet-ci-refactor-zbhfr15w/equivalence.log` and its `checks-4s92a1o6/` directory.
The harness uses locally installed PyYAML only to compare expanded YAML. Runtime CI scripts add no dependency.
If temporary evidence is gone, recreate the comparison from base `08cb137` and the CLI boundaries above.
Subsequent hosted observations are recorded below. F8b remains open.

## PR #11 merge checkpoint, 2026-11-01

F9 is committed as `f8f9c6966d250bc983d2086fb9fb283f5f04e5ff`.
[PR #11](https://github.com/eohnai/notch-pet/pull/11) passed all six jobs in
[run 41288310649](https://github.com/eohnai/notch-pet/actions/runs/41288310649).
It merged as `366eee3f8488bdfeeea3ce6dfb79577ba3c3d954`.

The automatic [main run 41288722994](https://github.com/eohnai/notch-pet/actions/runs/41288722994) failed.
Its saved native summary records 132 passed functions, one failed function, and one separate known usage datagram issue.
The sole failed function is `receiverDeadlineDoesNotResetForEachByte()` at `ContractAndSocketTests.swift:217`:
`Expectation failed: (result → .inconclusive) == .closedDespiteInput`.
The test loop therefore ended after five inconclusive attempts. The report contains no per-attempt reason or socket trace.

Workflow, Build, Contract, and Helper passed. The Tests command retained exit 1.
The native summary retained the failed identity, inventory rejected the missing coverage evidence, and Required failed.
The failing assertion is in unchanged Swift test code. These observations do not establish its underlying cause.

The checkpoint inspected existing results with `gh run view 41288722994 --log-failed` and downloaded the test reports.
Evidence is outside the checkout at `/private/tmp/notch-pet-pr11-main-failure/`.
No local test, hosted rerun, dispatch, or implementation repair ran during the checkpoint.
The user then invoked `debug-issue` to diagnose the deadline-test failure.

## PR #11 deadline diagnosis, 2026-11-01

The new `debug-issue` request authorized a focused reproduction and disposable diagnostic probes.
The repository's Swift code, test assertions, and hosted workflow runs were unchanged during this diagnosis.

### Observed mechanism

The test returns `.inconclusive` if a write misses its 50 ms budget, no write succeeds before closure,
or closure is observed at least 100 ms after the last successful write began.
It retries at most five times, then expects `.closedDespiteInput`.
The failure therefore proves that none of five attempts supplied the required timing evidence.
It does not prove that the receiver reset its deadline or kept a connection open indefinitely.
The native stream places the assertion about 965 ms after test start and test completion about 1.197 seconds after start.
It contains no individual attempt trace, so the exact hosted inconclusive branches remain unknown.

The F9 commit changed no Swift files. The receiver still passes one fixed absolute deadline from `accept` into `readBounded`.
Hypothesis: a sender pause in every attempt can exhaust all retries while the receiver still closes every connection.
More retries reduce the chance of this result but cannot guarantee a conclusive observation within a real 100 ms window.

The focused unchanged test passed locally. A disposable package copied all six EventBridge source files byte-for-byte
and retained the current test's assertions and five-attempt loop. It added attempt/reason prints and one controlled sleep switch.
Only `DIAG_DELAY` differed between the two probe executions:

| Execution | Result | Observation |
|---|---|---|
| `DIAG_DELAY=none` | Exit 0 | Attempt 1 was conclusive. Six writes succeeded. Closure was observed 18.9 ms after the last write began. |
| `DIAG_DELAY=every` | Expected exit 1 | All five attempts were inconclusive. Each had one successful write and closure observed 151.9–155.3 ms later. The original assertion failed exactly as on main. |

The delayed probe requested a 150 ms sleep after the first successful write of each attempt.
It observed closure on every connection, zero delivered incomplete messages, and successful subsequent valid-message delivery.
This confirms that the current retry strategy admits the reported false failure against unchanged receiver code.
It does not establish that the hosted sender experienced precisely these injected delays.

### Commands and evidence

```bash
env DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  swift test --scratch-path /private/tmp/notch-pet-pr11-deadline-diagnosis/build \
  --enable-code-coverage --filter receiverDeadlineDoesNotResetForEachByte
env DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer DIAG_DELAY=none \
  swift test --package-path /private/tmp/notch-pet-pr11-deadline-diagnosis/probe \
  --scratch-path /private/tmp/notch-pet-pr11-deadline-diagnosis/probe-build \
  --filter receiverDeadlineDoesNotResetForEachByte
env DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer DIAG_DELAY=every \
  swift test --package-path /private/tmp/notch-pet-pr11-deadline-diagnosis/probe \
  --scratch-path /private/tmp/notch-pet-pr11-deadline-diagnosis/probe-build \
  --filter receiverDeadlineDoesNotResetForEachByte
```

The first two commands exited 0. The last exited 1 with
`Expectation failed: (result → .inconclusive) == .closedDespiteInput`.
Logs are `/private/tmp/notch-pet-pr11-deadline-focused.log` and the probe root's `control.log` and `delayed.log`.
The instrumented test remains under `probe/`. The controlled failure does not replace the failed hosted baseline.

### Deterministic repair proposal, approved for F10

The user asked for a reliable, always-enabled test. A real-clock observation window cannot guarantee that a shared runner
schedules the sender often enough. Removing that requirement needs a test that controls time.

Proposed approach: add an internal wait-operation parameter to `readBounded`, defaulting to the current production `waitFor`.
The test would use a prequeued socket pair and a virtual wait operation. It would verify that successive reads receive
the original absolute deadline and throw when virtual time reaches it. No sender thread, sleep, or retry is needed for that assertion.
Existing server delivery and socket tests remain separate coverage of real transport behavior.
This replacement tests `readBounded` alone. Removing the current server-level slow-sender test removes its coverage
that `EventBridgeServer.receiveLoop` creates the deadline once per accepted connection.
The reader hook does not verify that caller behavior. Keep that coverage loss explicit during implementation and review.

This changes one internal function signature and leaves the real wait as its default.
A wider replaceable clock/transport abstraction is another option, but changes more production code than this deadline invariant needs.
The user approved the minimal internal seam, the revised verification plan, and committing/pushing the result with a PR.
Verification must include two failing mutations: reset the deadline before every wait, and reset it only after the first read.
The fake wait must record every received deadline. The test must assert that all recorded values equal the original deadline,
not only that execution eventually times out. Virtual time must permit reads before expiry so the after-first-read mutation is exercised.
Also run the surrounding EventBridge tests and one full suite run.

## F10 deterministic reader deadline, 2026-11-01

The user approved the revised task list, both reset mutations, one full suite run, and committing/pushing the change with a PR.
This task uses `feat/automation-ci-foundation` recreated from main `366eee3`.
The previous local branch is preserved as `archive/automation-ci-foundation-pr11` at `f8f9c69`.

### Implementation and coverage

`readBounded` now accepts an internal wait operation with the existing function as its default:

```swift
func readBounded(_ fd: Int32, limit: Int, until end: UInt64, framed: Bool,
                 wait: (Int32, Int16, UInt64) throws -> Void = waitFor) throws -> Data
```

All production callers omit the new argument and continue to use the real `waitFor`.
The replacement test is `readerKeepsOriginalDeadlineAcrossFragments()`.
It uses one nonblocking socket pair on one thread. The first byte is queued before the reader starts.
The fake wait queues each following byte only after checking that the preceding fragment was consumed.
Virtual time advances by 40 ms per wait, with one original 100 ms deadline.

The test records every received deadline and requires `[original, original, original]`.
Two real reads consume bytes at virtual times 40 ms and 80 ms.
At virtual time 120 ms, another byte is queued, but the fake wait throws `BridgeError.timeout`.
The final queue check proves that byte remains unread.
The assertion uses no wall-clock interval, sender thread, sleep, or retry.
A deadline mismatch throws immediately after recording it, so a deliberate reset cannot hang the test.
The obsolete retry helper and result enum were removed.

**Coverage removed:** this is a reader-level test. It no longer verifies that `EventBridgeServer.receiveLoop`
creates a 100 ms deadline once per accepted connection. It also removes the old slow-sender case's server callback
omission and subsequent-message assertions. Existing invalid-frame and delivery tests cover those behaviors for other inputs,
but they do not replace that specific timeout-path integration coverage. The server itself is unchanged.

### Verification

```bash
env DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  swift test --scratch-path /private/tmp/notch-pet-total-deadline-repair/build \
  --enable-code-coverage --filter EventBridgeTests
python3 /private/tmp/notch-pet-total-deadline-repair/check-reset-mutants.py
env DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  swift test --scratch-path /private/tmp/notch-pet-total-deadline-repair/build \
  --enable-code-coverage \
  --event-stream-output-path /private/tmp/notch-pet-total-deadline-repair/full-tests.jsonl \
  --event-stream-version 6.3
git diff --check
```

The EventBridge command exited 0: 32 tests in four suites passed.
The full-suite command ran once and exited 0: 133 tests in 24 suites passed with the existing known usage datagram issue.
The mutation harness exited 0 only after checking all four outcomes:

| Disposable package | Required outcome | Observed outcome |
|---|---|---|
| Unmodified source and test | Exit 0 | Passed |
| Unmodified source, with a 150 ms real pause inside each fake wait | Exit 0 | Passed in about 0.465 seconds |
| Reset the deadline before every wait | Exit 1 from the new test | Failed on the first recorded deadline |
| Preserve the first deadline, then reset once after the first successful read | Exit 1 from the new test | Failed on the second recorded deadline |

Both mutations compiled and ran the intended test. Each failed its deadline invariant and recorded-deadline array assertions.
The second mutation completed the first read, so the verification covers the case an already-expired-deadline-only test would miss.
The paused control demonstrates that delaying the test thread beyond 100 real milliseconds does not affect the virtual-time assertion.

Evidence is outside the checkout at `/private/tmp/notch-pet-total-deadline-repair/`:
`mutations.log`, each named probe log, `full-suite.log`, and `full-tests.jsonl`.
The EventBridge log is `/private/tmp/notch-pet-total-deadline-repair-eventbridge.log`.
The disposable packages live under `probes/`. The reset variants change only the reader's deadline calculation.
The paused variant changes only the test. No mutation or delay was added to repository code.
Hosted PR confirmation follows the user's authorized push. F8b remains open until its remaining acceptance work is verified.
