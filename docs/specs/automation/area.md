# Automation

Owns automated repository validation, build evidence, maintenance, and merge requirements for Notch Pet.
Code: `.github/`, `scripts/ci/`, and the existing verification scripts in `scripts/`.
App behavior and feature acceptance remain with their existing areas.

## Specs

- `ci-foundation`: Build and test changes through GitHub Actions, with coverage reports, reusable build artifacts, and a strict final result.
- `quality-gates`: Check Swift formatting, selected SwiftLint rules, compiler warnings, scripts, workflows, documentation links, and module dependencies. Needs: ci-foundation.
- `coverage-gates`: Compare per-module and changed-line coverage against a measured base, and prevent coverage from decreasing. Needs: ci-foundation.
- `compatibility-matrix`: Verify Apple Silicon and Intel, selected macOS/Xcode combinations, and debug/release configurations. Needs: ci-foundation.
- `robustness-checks`: Qualify sanitizers, repeat tests to expose intermittent failures, generate bounded malformed inputs, and verify process timeout/cancellation. Needs: ci-foundation.
- `security-maintenance`: Scan for secrets and tracked runtime data, verify pinned tools, maintain dependencies, and qualify available static security analysis. Needs: ci-foundation.
- `native-acceptance`: Automate isolated app startup, pet-only service boundaries, helper delivery, and shutdown, with a separate manual GUI acceptance record. Needs: ci-foundation.
- `merge-gates`: Enforce the current commit's required checks, verify rejection through failure drills, and document operation and recovery. Needs: quality-gates, coverage-gates, compatibility-matrix, robustness-checks, security-maintenance, native-acceptance.

## Shared context

- The user approved this eight-spec roadmap on 2026-10-31, including formatting and selected lint rules.
  They chose comprehensive CI as a personal learning project over the earlier minimal pipeline proposal.
- [0014](../../decisions/0014-use-comprehensive-github-actions-ci.md) records CI scope and ownership.
  [0015](../../decisions/0015-adopt-swift-format-and-selected-swiftlint-rules.md) records the tooling choice.
- Plan ci-foundation before resuming notch/session-cards C2. Its branch is `feat/automation-ci-foundation`, created from `origin/main` at `7735ec6`.
  Approval of this roadmap does not approve implementation task lists, tests, builds, helper injections, or repository settings changes.
- Only ci-foundation has a full spec now. Plan later specs from the code and hosted evidence available when they start.
  The legacy notch-companion checklist remains at its current path until its existing migration review finishes.

## Execution and evidence

- Every PR runs the foundation checks. Later specs add quality, coverage gates, repository guards, and required compatibility checks.
- Nightly runs extend the matrix and run qualified sanitizers, repeated tests, bounded malformed-input checks, and benchmark reports.
  A failed scheduled run stays failed even when PR checks pass.
- Weekly runs maintain dependencies and pinned tools, repeat supported security checks, and validate clean-cache behavior.
  Manual runs cover native GUI acceptance and diagnostic recipes.
- Cancel superseded runs for the same PR. Let default-branch runs finish. Keep stable job names and explicit timeouts.
- A single `Required` result must reject failed, cancelled, missing, malformed, or unexpectedly skipped required work.
  Never use a passing repetition, automatic retry, or `continue-on-error` to erase a failure.
- Record the commit, run, attempt, runner architecture, macOS, Xcode, Swift, tool versions, and check outcomes.
  Save available reports after failures. Cancellation can prevent report upload and cannot establish success.
- Build artifacts carry checksums and a manifest. Downstream checks consume that run's exact build instead of rebuilding it.
  Retain binaries for one day and reports for three days initially. Signed provenance requires its own availability review.
- Start without caches. Before enabling build caches, prove cold/warm correctness and invalidation by platform, architecture,
  toolchain, build configuration, sanitizer, manifests, and relevant source inputs. Cache hits never replace check execution.
- Keep reports in repository-scoped Actions artifacts. Avoid external reporting services initially.
  Keep scratch builds, generated fixtures, runtime data, imported packs, and captures outside the repository.
- Use read-only permissions and checkout without persisted credentials. Pin remote actions and downloaded tools to verified immutable inputs.
  PR validation runs without release secrets. Do not execute untrusted PR artifacts from a privileged follow-up workflow.

## Ownership boundaries

- quality-gates owns a separate formatting migration, selected lint rules, and checks for accepted module boundaries.
  Coordinate with sessions/codex-setup R2. Do not require its proposed target split before it exists.
- coverage-gates owns threshold selection after a baseline, comparisons with the correct base commit, exclusions,
  missing-report rejection, and tests proving that a coverage regression fails. Coverage reports alone do not establish adequate tests.
- compatibility-matrix owns qualification of available hosted images and toolchains. A deployment-target build is not proof of running on macOS 14.
  Record unavailable combinations and obtain separate native evidence instead of marking an unrun combination as passed.
- robustness-checks owns sanitizer qualification, retained failure seeds, repetition results, and fault-injection recipes.
  Reuse the real parser, transport, and subprocess boundaries. Keep generated inputs fictional and bounded.
- security-maintenance owns secret detection, runtime-data path/type rules, and dependency/tool updates.
  Allow bundled pet artwork and approved fictional fixtures. Redact findings and never print matched secret values.
  The package currently has no external dependencies. Do not add unrelated npm or Python dependency audits.
- native-acceptance reuses feature acceptance contracts and owns automation, not new product behavior.
  Preserve nonactivating windows, pet-only startup, optional agents, and isolated preferences/configuration.
  No capture permission requests or retries of the prohibited capture path are authorized.
- [notch/resource-efficiency](../notch/resource-efficiency.md) owns performance budgets and M2 Air battery acceptance.
  Automation may report benchmark regressions. Hosted measurements do not establish physical-notch behavior or battery life.
- merge-gates owns repository rule changes after their concrete configuration receives approval.
  CI configuration alone does not prevent direct pushes or merging failed changes.
- Signing, notarization, publishing, billing changes, and service purchases are outside this roadmap.
  Existing Codex, Claude Code, and Otty configuration must remain intact. Old goals remain paused.

## References

- Personal website: `~/Projects/personal-website/docs/ci.md`, `docs/specs/ci.md`, and `.github/workflows/ci.yml`.
  Reuse staged jobs, report/artifact handling, strict aggregation, pinned actions, and maintenance separation.
- SMRT: `~/Projects/SMRT-Enhanced-Cybersecurity-Monitoring-of-OT-System/.github/workflows/ci.yml` and `security.yml`.
  Reuse PR cancellation, completion of default-branch runs, and tracked-data checks.
  SMRT permits skips for untouched areas. This foundation runs every required job and rejects skipped jobs.
- [GitHub: required-check behavior](https://docs.github.com/en/pull-requests/how-tos/merge-and-close-pull-requests/troubleshooting-required-status-checks).
- [GitHub: runner selection](https://docs.github.com/en/actions/how-tos/write-workflows/choose-where-workflows-run/choose-the-runner-for-a-job).

## Open questions

- Qualify exact runner/Xcode versions in foundation F1, then additional combinations in compatibility-matrix.
- Measure baseline coverage before choosing enforcement levels. Choose nightly/weekly budgets and repetition counts in their owning specs.
- Check repository visibility and account capabilities before planning CodeQL, secret-protection integrations, or signed artifact attestations.
  Unavailable services stay explicit. Do not substitute a skipped successful check or purchase an upgrade.
  See [CodeQL availability](https://docs.github.com/en/code-security/reference/code-scanning/troubleshoot-analysis-errors/private-repository-enablement)
  and [attestation availability](https://docs.github.com/en/actions/how-tos/secure-your-work/use-artifact-attestations/use-artifact-attestations).
