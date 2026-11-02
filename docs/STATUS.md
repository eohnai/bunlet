# Status

## Now

PR #13 integrates main `79268d4` into `feat/notch-allowance-strip` to resolve its conflict.
Session cards C1–C5 and allowance A1–A5 are recorded complete in this branch through `ae7009e`; preserve their existing user-review evidence and limits.
Main's CI, socket/reader test repairs and Observation practices are integrated. Only STATUS conflicted; the approved tooltip removal and active-provider filter are preserved.
The merged branch passed all 172 Swift tests on 2026-11-02, with the existing usage-datagram known issue and no unexpected failures. Staged whitespace and unresolved-conflict checks passed. Evidence: `/private/tmp/notch-pet-pr13-swift.log`.
The user authorized commit/push and conflict resolution. No new app launch, capture or installed configuration change is part of this resolution; older goals remain paused.

## Next

1. Review PR #13's hosted checks after publication. Do not merge the PR into main without authorization.
2. Review the feature difference against PR #14: PR #13 contains the cards plus the allowance strip. Preserve decisions 0014/0015 and the recorded A5/C5 review rather than repeating captures.
3. Keep broader session-island/VoiceOver and real-session setup acceptance separate. Current hook installation/Connect support remains unimplemented.
4. Retain main's F10 reduced integration coverage and outstanding F8b hosted drills; handle further automation work on its owning branch.
5. Do codex-setup R4, then plan R2/R3 and the remaining setup prerequisites with their existing design gates. Older goals stay paused.

## Blockers

- A5/C5 user review established cards, fixed/running timers, usage limits and preserved focus. VoiceOver and broader session-island acceptance remain unverified. The final provider filter has unit coverage; no later visual pass is claimed.
- Real agent session integration remains unverified: the A5/C5 review used fictional observations and a real Codex allowance read, not a real configured session. No direct supported `NotchPetHook` invocation was found during that earlier bounded structural inspection.
- Provider-logo packaging does not establish the separate pet `Bundle.module` fallback lookup; preserve its existing limitation.
- Earlier branch full-suite runs intermittently timed out in `IntegrationHealthProbeTests.versionProbeBoundsItsProcessAndOutput`; the final historical rerun passed 171 tests. Main's newer test changes are now integrated; this merged run passed 172 tests. One successful run does not establish that every intermittent failure is eliminated.
- Historical pre-F10 main failure (F10 is now included through PR #12): `gh run view 41288722994 --log-failed` reports commit `366eee3` and `Expectation failed: (result → .inconclusive) == .closedDespiteInput` at `ContractAndSocketTests.swift:217`. F10 replaces that test. Preserve the failed run and saved reports at `/private/tmp/notch-pet-pr11-main-failure/`. The exact hosted per-attempt reason remains unknown.
- F10's reader-only test removes the old server-level deadline-creation check and its slow-sender timeout-path callback/recovery assertions. Other frame/delivery tests remain, but do not replace that specific integration coverage. The decision and both reset-mutation results are recorded in the spec.
- The user approved F10's internal wait seam, revised test, both reset mutations, EventBridge tests, one full suite run, commit, push, and PR. Additional repairs, unrelated runtime checks, captures, and installed configuration changes remain outside that scope. F8b's deliberate hosted drills still need authorization.
- The user approved F9's previously proposed script extraction, multi-file exception, and local verification after PR #10 passed on main. Verification used saved CI reports and fictional commands. Further repairs, broader runtime tests, hosted drills, app launches, captures, and installed configuration changes need separate authorization. Account-specific security capabilities and additional runner combinations remain unqualified.
- Stale: `docs/goals/ci-foundation-local-log.md` still says F7 awaits commit approval. F7 is committed as `a45d0ae` and merged in PR #8. Preserve that historical goal record until its owning update.
- Stale: `docs/specs/sessions/codex-setup.md` "My calls": the bullet "Preserve the source checklist…" is joined onto the end of the R7/R8 bullet with no line break.
- Full built-in-pet acceptance is deferred: setup/slider/menu interaction, actual multi-frame scheduling, Reduce Motion changes and visual appearance remain unverified. Keep BP2/BP3/BP5/BP6b3/BP7 open; agent reactions and detachment remain separate unimplemented features. The implementation-only goal is closed.
- Capture reproduction command: `env DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer python3 scripts/check-standalone-pet.py --app "/private/var/folders/t3/6n_zw1rn5nn6vv7ccx9r6s240000gn/T/notch-pet-dev/Notch Pet.app" --artifacts /private/tmp/notch-pet-completion/evidence/standalone` failed with `could not create image from window` / screencapture exit 1. The native preflight returned screenCaptureAuthorized=false; the user explicitly prohibited further captures and later all further testing. Do not request that permission or retry the failing capture.
- Telemetry C1–C8, H1–H7 and S1–S6 remain proposed implementation tasks. Service lifecycle, IPC, schema/durability and instrumentation coverage require their recorded reviews. Battery targets are provisional and unmeasured.
- Stale: `docs/specs/usage/codex-allowance.md` describes view-owned reads. AgentUsageController now owns those reads; NotchPanelController still owns the store/controller. Reconcile during feature review.
- Stale: `docs/specs/usage/claude-allowance.md` describes uncommitted receiver wiring and an `ambiguous use of 'sync(execute:)'` build error. Current app code has no UsageReceiver startup path or that closure. Review its five open decisions against current code before U2c3.
- I3b1's design is accepted, including the final independent-editor race and indistinguishable identical replacement. Codex 0.164.0 is a qualification candidate, not a qualified installer release. Effective enablement/policy evidence and timeout enforcement still need isolated verification. `integration-health` and `notch/session-island` acceptance remain open before dependent implementation.
- Migration pending: planned area specs still have no file, including monitoring-controls and the five settings/reference additions. Derive counts from the progress board. Codex setup maps its source obligations without removing shared I5/I6 tasks. Keep the source specification and its original tasks/evidence until every requirement has a destination; confirm its final move/removal before changing it.
- Terminal independence is accepted scope, not completed compatibility verification. Optional version-1 terminal metadata remains Otty-specific. N7–N8 need planning and live acceptance.
- Real Claude forwarding and terminal-output/cancellation preservation remain incomplete. Codex reconnect/account switching and remaining physical-notch acceptance are unverified. Settle the five open Claude allowance decisions before U2c3.
- Stale: `docs/specs/usage/codex-allowance.md` leaves U3b2 unchecked despite historical goal-log evidence. Review U3b2, U1 and I2a–I2c evidence before changing those checkboxes.
- Stale: `scripts/check-event-contract.py` permits a previously conflicting turn ID to restore working state; SessionStore enforces the accepted unseen-turn rule.
- Usage datagram limit (production bug, not fixed): `UsageDelivery` and `UsageReceiver` keep the default Unix datagram buffers. A probe on this Mac sent nothing over 2,048 bytes (`EMSGSIZE`, `net.local.dgram.maxdgram: 2048`). With a 16 KiB send buffer, nothing over the receiver's 4,096-byte buffer arrived (`ENOBUFS`). The 8,192-byte limit in both types is unreachable, and larger observations are silently dropped. `UsageReceiverTests` records this as a known issue. Choosing the fix needs a decision.
- Stale: `README.md` still calls implemented session/notch/usage surfaces planned and decision 0013 proposed; `docs/ARCHITECTURE.md` still describes visible session/usage and health services, plus the now-written pet boundary, as planned. It also describes view models for every view; the code has none, and D3 now sets the rule (codex-setup R4). Leave their unrelated edits with their owning work.
- Stale: `docs/specs/sessions/integration-health.md` describes health supplied through the menu environment. Current `AgentServices` keeps its health controller private and the menu has no health controls; codex-setup I6a owns exposing those actions.
- Sprite-sheet input choice P5 remains proposed and blocks source P6. Monitoring pause/disconnect/resume and notice retention need planning in sessions/monitoring-controls. No deadlines or owners are recorded.
- Activity counting and token-counter sources remain unverified. Define coverage, units, deduplication, and time boundaries before statistics implementation. Hook events do not establish chat-message totals, and tokens do not establish remaining allowance.
