# Show sessions as compact cards in the notch

Status: done

## Goal

Replace the expanded notch's disclosure rows with compact session cards, based on the reference layout the user supplied on 2026-10-31.
Each card shows the provider, project folder, status, and a timer for the current prompt. A pending request gets its own card with the tool name.
The allowance strip above the cards is a separate spec, `allowance-strip`. See the [notch area](area.md) for shared context.

## Done when

- Each session card shows a provider badge, the project folder name, the status, and the prompt timer.
  Two sessions in the same folder also show a short session ID. Opening a card shows the full project path and session ID.
- The timer starts at the turn's `UserPromptSubmit` and recalculates elapsed time each second while the panel is open.
  It stops at its final duration on `Stop`.
  It is hidden for unknown and ended sessions, and for sessions with no observed turn.
- A pending request shows a request card with the tool name and the text "Answer in the terminal".
  No prompt, command, question, or tool-input text appears anywhere in the panel.
- Every observed state keeps its label: idle, working, question, approval, response ready, ended, and unknown.
- The expanded panel is wider and shorter than before, at the sizes under **My calls**.
- `swift test` passes, including new store and presentation tests.
- Real app: fictional events sent through the bundled helper show two same-folder sessions, a running timer, a stopped timer, a request card, and an unknown session.
  The user reviews them in one batched visual pass.

## Out of scope

- The allowance strip (icon, `5h`, percent left, reset countdown, `7d`): `allowance-strip`.
- Toolbar icons, per-row pet icons (pets/agent-reactions), and the terminal kind tag (`otty`).
- "Go to terminal" buttons and any terminal navigation: sessions/pane-navigation.
- The latest tool name while a session is working.
- Prompt or command text in rows. That needs its own decision and a contract v2.
- The collapsed view, and session-island's N3–N5 actual-app acceptance.
- Keyboard controls and Reduce Motion beyond the existing animation check: accessible-controls.

## Constraints

- Follow the [event contract's omission rule](../../contracts/agent-events-v1.md): rows show only the tool name from a request.
- Session meaning stays in `SessionStore`. Views render snapshots through pure `NotchPresentation` functions, under [D3](../../DECISIONS.md#d3-add-view-models-only-where-a-view-owns-state).
- Keep the nonactivating panel. Cards and timers must not take keyboard focus.
- Tick the timer only while the panel is expanded and at least one timer is running. Idle cost belongs to [resource-efficiency](resource-efficiency.md).
- Builds, tests, and helper injections need the user's authorization for each task. App launches were allowed on 2026-10-31.

## Verify

- Seam: the bundled `NotchPetHook` helper into the running app and the expanded notch panel.
- Swift checks: `env DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --scratch-path /private/tmp/notch-pet-dev/build`.
  Passing means exit 0 with no failing tests. Store tests are in `SessionStoreTests.swift`. Presentation and placement tests are in `NotchSelectionTests.swift` and `NotchPresentationTests.swift`.
- Build: `env DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer bash scripts/run.sh --build-only`.
- Real app: `env DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer bash scripts/run.sh`, then send fictional observations through the bundled helper.
  Do not request screen-capture permission or retry the prohibited capture path. The user supplies the one visual review.

## Results

Checked 2026-11-02 on `feat/notch-allowance-strip`, stacked on C4 `a2a2ede`.

- Final full Swift suite: 171 tests in 27 suites passed, exit 0; final app build passed.
- The user's screenshots confirmed same-folder short IDs, full identity details, request cards, and idle/unknown/ended labels.
- The user confirmed `abc002` stayed at three seconds while `abc001` advanced, and terminal focus survived clicking/hovering.
- The review app quit normally, clearing fictional sessions and its socket. No agent configuration changed or agent-initiated capture ran.
- VoiceOver and broader session-island acceptance remain unverified. The known version-probe timeout remains recorded.

See [allowance-strip Results](allowance-strip.md#results) for final commands, logs, and the subsequent provider-filter test coverage.

## Decisions

- **Change the layout before session-island's acceptance checks, 2026-10-31.** The user chose this over waiting for session-island (`Needs: session-island`).
  This avoids verifying the old row layout and then the new one. ^[inferred] Session-island's N3–N5 checks then run on the cards.
- **Rows keep the contract's omission rule, 2026-10-31.** The user chose tool names only, over showing prompt and command text as in the reference.
  Showing that text needs its own decision and a contract v2.
- **Time each prompt from `UserPromptSubmit` until `Stop`, 2026-10-31.** The user asked for the timer to stop at its final duration when the response is ready.
  The store must therefore keep the turn's start time. At planning time, the store did not keep it.
- **Calculate duration from numeric timestamps, 2026-11-01.** The user chose the existing `Int64` millisecond timestamps over parsing display strings or adding `Date` conversions.
  Subtract start from current or stop time, then format once for display. This avoids string parsing and counter drift after delayed updates.
- **Use conditional SwiftUI `TimelineView` scheduling, 2026-11-01.** The user approved this over a custom `.task(id:)` loop.
  It avoids custom clock state and cancellation code. Create the one-second timeline only while expanded with a running prompt timer.
- [0002: Use services and shared stores](../../decisions/0002-use-mvvm-with-services.md).
- [0012: Support terminal-independent operation](../../decisions/0012-support-terminal-independent-operation.md).

## My calls

- Expanded panel: 620 points wide (was 560) and 240 points below the header (was 280). The user asked for "a little shorter but a little wider".
- Timer times come from the events' `observed_at_ms`, not the app's receipt times. A delayed delivery does not shorten the timer.
- A new turn resets the timer. A repeated `Stop` does not change the final duration.
- C1 exposes `turnStartedAtMs` and `responseReadyAtMs` on `SessionSnapshot`, using event capture times in Unix milliseconds.
  A matching stop records its first time even when the session stays unknown. C2 owns hiding timers for unknown and ended sessions.
- Timer format: `45s`, `2m03s`, `1h02m`.
- An unknown session hides its timer, because the app cannot confirm the turn is still running. Waiting for approval or an answer keeps the timer running.
- Short session ID: the last 6 characters. The first characters of time-ordered IDs can match for sessions started close together. ^[inferred]
- Folder name: the last part of the project path, or "Project not observed".
- The request card replaces the reference's "Go to terminal to confirm" button with plain text, because no navigation exists yet.
- The existing "Codex limits" sections stay until `allowance-strip` replaces them.

## C2 plan


The user approved C2 implementation and the focused tests on 2026-11-01. The numeric timing approach is accepted.
This timer belongs to the session card. The allowance strip's reset countdown remains in `allowance-strip`.

Branch: `feat/notch-session-cards`, preserving C1 commit `1f30a3c`.
The user chose a normal branch switch. The earlier CI cleanup and plan are preserved in the stash named
`preserve ci cleanup and c2 plan before feature work`, with a patch backup at `/private/tmp/notch-pet-c2-documentation-before-switch.patch`.
No main merge ran. Restore the CI cleanup on its owning branch and integrate main separately before PR review.

Files, in order:

1. Add `Tests/SessionStateTests/NotchCardPresentationTests.swift` with failing presentation cases.
2. Update `Sources/SessionState/NotchPresentation.swift` with the value types and pure functions below.
3. Update this spec and `docs/STATUS.md` with verification evidence. Tick C2 only after verification passes.

Approved API sketch, with empty function bodies:

```swift
public enum PromptTimer: Equatable, Sendable {
    case running(startedAtMs: Int64)
    case stopped(durationMs: Int64)

    public func elapsedSeconds(at nowMs: Int64) -> Int64 {}
}

public struct NotchCardPresentation: Equatable, Sendable {
    public let folderName: String
    public let shortSessionID: String?
    public let timer: PromptTimer?
}

// New methods shown inside the existing enum. Keep its current methods too.
public enum NotchPresentation {
    public static func card(for session: SessionSnapshot,
                            among sessions: [SessionSnapshot]) -> NotchCardPresentation {}
    public static func timerText(seconds: Int64) -> String {}
}
```

C4 caller example:

```swift
let card = NotchPresentation.card(for: snapshot, among: sessions)
if let timer = card.timer {
    let seconds = timer.elapsedSeconds(at: nowMs)
    let text = NotchPresentation.timerText(seconds: seconds)
    // Render text in the session card.
}
```

The card has no stored `timerText` or `isTimerRunning` property.
C4 identifies running timers by matching `.running`, so a second boolean cannot disagree with the timer state.
Pass current time into the calculation. These functions do not read a clock, schedule updates, or perform I/O.
Keep the functions in the existing enum because it is small and already owns notch presentation.
An extension is valid Swift, but adds no useful separation for this change.

Behavior and test cases:

- Show the final path component, or "Project not observed" for a missing or empty path.
- Show the last six session-ID characters only when another session key shares the same full observed project path.
  Two different paths with the same final folder name do not count as one folder. Include both providers in these cases.
- Return `.running` for working, question-needed, or approval-needed sessions with an observed start time.
- Return `.stopped` for response-ready sessions with both start and stop times. Later current times leave its duration unchanged.
- Return no timer for idle, unknown, or ended sessions, missing starts, or response-ready sessions missing a stop time.
- Floor elapsed milliseconds to whole seconds and clamp negative durations to zero.
  Cover delayed updates, current time before start, and the second/minute/hour format boundaries: `45s`, `2m03s`, `1h02m`.
- Calculate every update from timestamps. Never parse the displayed text or increment a stored elapsed counter.

Approved focused verification:

```bash
env DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  swift test --scratch-path /private/tmp/notch-pet-c2/build \
  --filter 'NotchCardPresentationTests|NotchSelectionTests|NotchPresentationTests'
git diff --check
```

Run the focused command before implementation to establish the failing cases, then repeat after implementation.
Passing means exit 0 with no failed tests. `git diff --check` must also exit 0.
C2 adds no app launch, helper injection, layout change, timer scheduling, or capture. C3–C5 retain those separate responsibilities.

## C2 verification, 2026-11-01

Implemented on `feat/notch-session-cards`, based on C1 commit `1f30a3c`.
The functions live directly in `NotchPresentation`. `PromptTimer` supplies numeric running/stopped states and elapsed seconds.
Display formatting is separate. The existing app UI does not use the new card presentation until C4.

The approved focused command above first exited 1 because `card`, `PromptTimer`, and `timerText` did not exist.
After implementation, the same command exited 0: 20 tests in three suites passed.
The suites are `NotchCardPresentationTests`, `NotchSelectionTests`, and `NotchPresentationTests`.
`git diff --check` also exited 0.

The cases cover both providers, full-path folder sharing, missing paths and timing evidence, hidden timers,
fixed stopped durations, delayed updates, millisecond rounding, and second/minute/hour formatting boundaries.
No full-suite run, app launch, helper injection, or capture ran for C2.
Logs remain outside the repository at `/private/tmp/notch-pet-c2-red.log` and `/private/tmp/notch-pet-c2-green.log`.

## C3 verification, 2026-11-01

The user approved C3's task list and focused placement tests on 2026-11-01.
Implemented on `feat/notch-session-cards`, preserving C1 `1f30a3c` and committed C2 `c25c699`.
`NotchPlacement.frame` now requests 620 points wide and 240 points below the header when expanded.
Its API, collapsed dimensions, screen bounds, centering, and top alignment remain unchanged.

Approved focused verification:

```bash
env DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  swift test --scratch-path /private/tmp/notch-pet-c3/build \
  --filter NotchPresentationTests
git diff --check
```

The sandbox initially denied access to Swift's compiler cache. The approved elevated run reached the tests.
Before implementation, the focused command exited 1 with five expectation failures for the old expanded dimensions.
After implementation, it exited 0: six tests in `NotchPresentationTests` passed, including both parameterized header cases.
`git diff --check` also exited 0.

The tests cover expanded sizes with and without a physical notch, narrow-screen width bounds,
small-screen height bounds, screen coordinates, collapsed sizes, and invalid geometry.
No full-suite run, standalone app build, app launch, helper injection, or capture ran for C3.
Logs remain outside the repository at `/private/tmp/notch-pet-c3-red.log` and `/private/tmp/notch-pet-c3-green.log`.

## C4 plan, 2026-11-01

The user approved C4 implementation, the conditional `TimelineView` approach, the pure timer-update policy,
focused tests, and the build-only check. Stay on `feat/notch-session-cards` and preserve C3's uncommitted changes.

Files and order:

1. Add failing update-policy cases in `Tests/SessionStateTests/NotchCardPresentationTests.swift`.
2. Add `NotchPresentation.shouldTickPromptTimers(expanded: Bool, sessions: [SessionSnapshot]) -> Bool`.
   Reuse the existing timer classification. Require expansion and at least one running timer.
3. Replace `NotchSessionRow.swift` with `NotchSessionCard.swift` and add `NotchRequestCard.swift`.
   Session-card inputs are `snapshot`, `presentation`, `nowMs`, and a `selection` binding.
   Request-card input is `SessionRequest`. Show requests outside the session's expandable identity details.
4. Wire cards and conditional one-second updates in `NotchSessionView.swift`.
   Keep full identity details available when a card opens and retain unconfirmed request labels.
5. Record verification here and checkpoint `docs/STATUS.md`. Tick C4 only after the checks pass.

Approved verification:

```bash
env DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  swift test --scratch-path /private/tmp/notch-pet-c4/build \
  --filter 'NotchCardPresentationTests|NotchSelectionTests|NotchPresentationTests'
env DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  bash scripts/run.sh --build-only
git diff --check
```

Run the focused tests before implementation and again afterward. Passing means exit 0 and no failed tests,
a successful app bundle build, and no whitespace errors. Actual timer scheduling and appearance remain for C5/A5's
single batched user review. No app launch, helper injection, or capture is part of C4.

## C4 verification, 2026-11-01

Implemented on `feat/notch-session-cards`, preserving committed C1 `1f30a3c`, C2 `c25c699`,
and C3's uncommitted resize and placement tests.

`NotchSessionCard` replaces `NotchSessionRow` with a provider badge, folder and status, shared-folder short ID,
and numeric prompt duration. Opening the card shows the full project path and session ID, retained unknown-state
guidance, and the last refresh time. Each pending request has a separate `NotchRequestCard` outside those details,
with its tool name, pending/unconfirmed question or approval label, and "Answer in the terminal".
No prompt, command, question, or tool-input content was added.

`NotchPresentation.shouldTickPromptTimers` reuses the existing timer classification.
`NotchSessionView` creates a one-second `TimelineView` only inside the expanded content and when this policy returns true.
The timeline wraps the session cards, leaving allowance rendering on its existing schedule.
Stopped durations stay fixed. Current time comes from the timeline date, with elapsed time calculated from event timestamps.
The nonactivating AppKit panel remains unchanged.

The approved focused test command initially failed because the sandbox denied Swift's compiler cache.
The elevated retry exited 1 because `shouldTickPromptTimers` did not exist, establishing the failing cases.
After implementation, the same focused command exited 0: 24 tests in three suites passed.
The new policy cases cover expansion/collapse, working/question/approval states, stopped and hidden timers,
missing/invalid starts, empty lists, and a mixed-provider list with one running timer.

The approved build-only command exited 0 and produced the development app bundle with `Info.plist: OK`.
The build included the final timer accessibility label, which contains the displayed duration.
`git diff --check` exited 0. Logs remain outside the repository at `/private/tmp/notch-pet-c4-red.log`,
`/private/tmp/notch-pet-c4-green.log`, and `/private/tmp/notch-pet-c4-build.log`.

No full-suite run, app launch, helper injection, or capture ran for C4.
Actual scheduler behavior, layout, focus, and fictional-event acceptance remain unverified for C5/A5's batched user review.

## C5/A5 review preparation, 2026-11-02

The user approved the combined runtime review on `feat/notch-allowance-strip`, including full tests,
the app build, fictional helper injections, and real Codex allowance.
The full-suite rerun passed 177 tests in 27 suites. The build passed.
The first full-suite run hit the known version-probe timeout. The isolated probe tests passed.
See [A5/C5 review preparation](allowance-strip.md#a5c5-review-preparation-2026-11-02)
for exact commands, launch arguments, limitations, and external evidence paths.

The temporary helper script prepares two Codex sessions in the same fictional `shared-project` folder:
`a5-review-run-abc001` keeps a running timer and `a5-review-stop-abc002` stops after about three seconds.
Additional cases cover a Claude `Bash` approval, Codex `request_user_input` question,
unknown, idle, and ended sessions. The unknown case has no observed turn and must hide its timer.
The user must confirm actual receipt, labels, short IDs, fixed/running timers, request cards,
expanded identity details, collapse/reopen behavior, and focus in the running app.
The script ran with exit 0; every helper invocation was silent with exit 0.
This does not acknowledge delivery. The user has been asked for the batched review.
The user's supplied screenshots establish visible receipt. They show the `Bash` approval and
`request_user_input` question cards with the terminal guidance, the same-folder `abc001`/`abc002` IDs,
an opened working card with full path/session identity, and idle/unknown/ended labels.
The unknown session correctly shows `Project not observed` and no timer: its uncorrelated tool event
does not establish trusted project metadata. The stopped card shows a three-second duration.
The working and waiting sessions show elapsed durations; screenshots alone do not prove the stopped timer stays fixed.

The user confirmed the timer advanced and keyboard focus remained in the terminal while hovering
and after clicking the notch. In the final review, they confirmed the stopped timer stayed at three seconds while the other advanced.
VoiceOver labels remain untested. Inactive observations expire after two minutes.
C5 is complete. The paired A5 tooltips were later confirmed by screenshots,
then explicitly removed at the user's request under [0014](../../decisions/0014-omit-usage-limit-tooltips.md).
The final app has no hover details. After removal, the full-suite rerun passed 170 tests in 27 suites and the build passed.
The final review used only the shared-folder timer pair and an idle Claude session to avoid scrolling through prior cases.
See the allowance spec for the implementation and test evidence.
No agent-initiated capture or capture-permission request ran; the user supplied the images.

## Tasks

- [x] C1: Keep each turn's start and response-ready times in `SessionStore` and expose them on `SessionSnapshot`; store tests cover start, stop, repeated stop, and a new turn resetting both times.
- [x] C2: Add pure card presentation to `NotchPresentation`: folder name, short session ID for a shared folder, numeric running/stopped timer states, elapsed-time calculation, and separate display formatting. Presentation tests cover each case.
- [x] C3: Make the expanded panel 620 points wide and 240 points below the header in `NotchPlacement`; update the placement tests.
- [x] C4: Replace `NotchSessionRow` with a session card (badge, folder · status, timer) and a request card (tool name, "Answer in the terminal"); recalculate elapsed time once per second only while expanded with a running timer; build passes.
- [x] C5: Verify the cards in the real app with fictional events through the bundled helper: same-folder sessions, running and stopped timers, a request card, and an unknown session; one batched visual review by the user.
