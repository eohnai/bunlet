# Access sessions in the notch

Status: implementation merged in PR #16; feature acceptance remains deferred.

Needs: sessions/session-state


Merged evidence: [full MVP handoff](../notch-companion.md#merged-mvp-handoff-2026-11-06). Hosted build/package, existing tests and
coverage checks passed at `ab2ae13`. This is not feature-specific native/provider acceptance;
historical results and unrun acceptance checkboxes retain their original meaning.

## Goal

Let the user inspect agent sessions and their requests in a compact, expandable island around the physical notch.
Collapsed, it shows activity and the session count. Expanded, it shows every session and its details.
It replaces the temporary menu session list. See the [notch area](area.md) for shared context.

This is a retrospective spec. It moves I1 and N3–N5 and their evidence out of the [source specification](../notch-companion.md).
The notch code exists, but actual-app acceptance is incomplete. All four tasks stay unchecked.

## Done when

These checks come from "Feature 1: access sessions in the notch" in the source spec, approved on 2026-10-29.

- The panel sits correctly on the built-in display around the physical notch, using supported AppKit geometry.
- The user can expand and collapse the panel, including with the keyboard. Expanding or showing an alert does not take keyboard focus without a request.
- Transparent inactive areas pass clicks through to the windows below.
- Both providers and two sessions in the same project folder stay distinct in the expanded view.
- Every observed state keeps its meaning: working, question, approval, response ready, ended, and unknown. Retained unconfirmed notices stay visible as unconfirmed.
- Priority is derived once from shared snapshots. Confirmed requests come first, then response-ready notices, and every session stays reachable.
- The selected session stays selected while updates arrive.
- The menu bar has no session list. Quit and Show Notch stay available. Settings and Return Pet appear only when they exist.
- The real-app check uses fictional events through the bundled helper, not a second mock interface.
  Visual QA is one batched pass and at most one correction pass, with no repeated user screenshot requests.

## Out of scope

- Exact-pane terminal navigation (N1–N2) and its capability planning (N7).
- Live installed-agent acceptance through the notch (N6, N8, R6–R8).
- Display changes, Spaces, fullscreen, and sleep/wake recovery: [desktop-recovery](area.md) (R1–R3).
- Reduce Motion beyond the existing animation check, and full keyboard accessibility: [accessible-controls](area.md) (R4).
- Usage sections in the notch: [usage/codex-allowance](../usage/codex-allowance.md) and [usage/claude-allowance](../usage/claude-allowance.md).
- The pet, local actions, and replies.

## Constraints

- Keep SwiftUI/AppKit and a nonactivating panel. New alerts must not take keyboard focus.
- Views render snapshots from the shared `SessionStore`. Session meaning stays in the store, under [decision 0002](../../decisions/0002-use-mvvm-with-services.md).
- Keep shared presentation rules reusable by the later pet.
- Display sessions without terminal navigation metadata, under [decision 0012](../../decisions/0012-support-terminal-independent-operation.md).

## Verify

- Seam: the bundled `NotchPetHook` helper into the running app and the visible notch panel.
- Code: `Sources/NotchPet/NotchPanelController.swift`, `NotchSessionView.swift`, `NotchSessionCard.swift`, `NotchRequestCard.swift`, and `Sources/SessionState/NotchPresentation.swift`.
- Build: `bash scripts/run.sh --build-only`.
- Swift checks: `env DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --scratch-path /private/tmp/notch-pet-dev/build`.
  Placement tests are in `NotchPresentationTests.swift`. Selection and provider tests are in `NotchSelectionTests.swift`.
- Real app: `bash scripts/run.sh`, then send fictional observations through the bundled helper.

These are reproduction commands. This retrospective spec ran documentation checks only.

## Decisions

- **Use the notch as the session interface, 2026-10-29.** The user chose session access in the notch and rejected a menu-bar session list as unnecessary. Basic app controls stay in the menu bar. Copied from the source spec.
- [0001: Use SwiftUI and AppKit](../../decisions/0001-use-swiftui-and-appkit.md).
- [0002: Use services and shared stores](../../decisions/0002-use-mvvm-with-services.md).
- [0011: Organize records by area and feature](../../decisions/0011-organize-records-by-feature.md).
- [0012: Support terminal-independent operation](../../decisions/0012-support-terminal-independent-operation.md).

## My calls

- I1 moves here because the notch replaces the menu session list. The older I1 menu evidence is kept below as history, not as a requirement to finish the retired menu walkthrough.
- N5 moves here, not to `session-state`. Its rules decide presentation order and selection, not session meaning.
- N6 stays in the source spec. It needs live agents and Otty pane jumps, which depend on N1–N2.
- No new tasks are added. The remaining work is actual-app verification, which N3–N5 and I1 already require.

## Merged source coverage

`CompanionMenu` now contains Show Pet/Return Pet, Show Notch/Open Sessions, provider setup controls,
Settings and Quit as installed features allow; it renders no session rows. Open Sessions explicitly
opens the retained native panel and enables keyboard input. NotchSessionView owns selected SessionKey
and renders shared snapshots/cards, requests, navigation and supported action composers. Observable
NotchWindowState updates geometry without rebuilding selection/drafts. NotchPresentation owns ordering,
selection and observed-turn timers; hidden/asleep/collapsed presentation stops unnecessary ticking.
I1/N3–N5 source implementation is merged; their remaining actual-app checks are not new implementation tasks.

## Current layout, 2026-11-12

[Decision 0017](../../decisions/0017-match-flux-island-ui.md) replaced the click-to-expand panel described in the evidence below.
The [island UI reference](../../notes/flux-ui-reference.md) holds the exact values; this summary is enough to read the code.

- One fixed transparent window, 740 wide and up to 572 tall, sits at the top center of the notched screen. `IslandGeometry`
  (in `SessionState`) computes it; `NotchPlacement` no longer exists. Only the black shape inside the window takes the pointer.
- Closed, the shape is a pill as tall as the notch: phase icon, a label on screens without a notch, and the session count.
- Hovering the pill for 200 ms opens it; leaving the open island for 300 ms closes it, unless the user is typing.
  Clicking the pill also opens it. Escape collapses it.
- New approvals, questions and completions open the island without taking keyboard focus. Completions, and requests
  with no local reply channel, close again after 5 seconds unless the pointer is inside.
- Open, the panel is 680–704 points wide (46% of the screen width, clamped) and grows with its content up to 540 tall.
- Pressing the closed pill and dragging down more than 50 points pulls the pet out, when Pet is installed.

The **Done when** checks above still apply. Hover-open and notification-open are additions; neither takes keyboard focus.

## Closed-notch correction, 2026-11-14

The user approved removing the visible seam and aligning the closed island to display pixels.
The black shape has no light outline. Window placement and closed width use the selected display's backing scale.
Cutout width and header height still come from AppKit, rather than fixed MacBook model dimensions.
The extra width holds the status icon and session count. It remains intentional.
The correction costs the decorative border. It avoids model-specific dimensions that fail under display scaling.
Actual appearance on the user's M2 Air remains unverified. No screen captures were taken.

- [x] Verify centered closed-island edges at 1× and 2× backing scales with `NotchPresentationTests`.

Verification: the Xcode-toolchain full suite passed all 207 tests on 2026-11-14.
Command: `env DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --scratch-path /private/tmp/bunlet-notch-hooks-xcode`.
`swift build --scratch-path /private/tmp/bunlet-notch-hooks-build` also passed.

## Remaining open questions

- Physical-notch focus, click-through, keyboard expansion, hover-open and notification-open are not verified in the actual app.
- Response-ready, ended, and unknown-with-retained-notice states have no fresh actual-notch evidence.

## Tasks

- [ ] I1: Retire the temporary menu session list when N3–N5 provide notch session access; retain partial menu verification as historical evidence, not a requirement to finish the retired menu walkthrough.
- [ ] N3: Add a compact/expandable native notch panel on the built-in display with supported geometry, no unsolicited focus, keyboard expansion/collapse and click-through inactive areas; verify launch and placement.
- [ ] N4: Present all sessions and request details in the expanded notch, preserving selection and distinguishing same-folder sessions; remove menu session rows and retain basic controls when the notch is usable.
- [ ] N5: Derive notch attention selection once from shared snapshots, prioritizing confirmed requests and retaining unknown/unconfirmed, response-ready and ended meanings; reuse this state for the later pet.

## Evidence from the paused goal

The source spec does not record this work. It comes from the [paused goal log](../../goals/notch-agent-limits-log.md). It is summarized here, not copied.
None of it was rerun for this spec.

- N3: turn 1 added `NotchPlacement` with five placement tests. Turns 2–3 added the native panel and observed compact and expanded views in the actual app. Turn 4 set the 560-point expanded width and a 0.24-second animation that respects Reduce Motion. Turn 5 could not confirm the latest width and animation. Full focus and hit-testing checks remain open.
- N4 and I1: turn 7 added disclosure rows keyed by `SessionKey`, with project and session identity, status, refresh time, and retained requests. The menu now has only Show Notch and Quit. The log records no checkbox tick without actual-app verification.
- N5: turn 8 added three presentation functions with five selection and provider tests: active providers, request ordering, and selection kept through priority changes.
- Turn 24 observed fictional sessions through the bundled helper in the actual app, including an ended view. Remaining focus and hit-testing checks stay open.
- Commits: `886bb18` placement, `6bf60c0` panel, `4ed152a` width, `d59fef3` session details, `aa552d6` presentation rules.

## Historical evidence

The following records are copied from the [source specification](../notch-companion.md#i1-implementation-awaiting-verification-2026-10-28).
Only relative link paths changed. They were not rerun for this spec.
The source spec also keeps them. The I1 records describe the retired menu list.

### I1 implementation awaiting verification, 2026-10-28

`Sources/NotchPet/NotchPetApp.swift` now reads the existing observable `SessionStore` in `CompanionMenu`
and renders each snapshot through `SessionMenuEntry(snapshot:)` in the existing native menu.
Entries include agent, project, source session identity, and the shared-store status.
Each submenu exposes the full project path and session identity, the recorded state-refresh time when available,
plain-language unknown reasons, and unresolved requests marked according to `isConfirmed`.
Same-folder sessions remain separate through `SessionKey`; response stops use the label "Response ready".
The empty state says "No sessions observed yet" without claiming configuration or connection failure.

Runtime behavior remained unverified at the initial checkpoint. The existing 48-test Swift suite had passed before this source change;
that baseline result did not verify I1. After the user first authorized verification,
`bash scripts/run.sh --build-only` failed because the default scratch directory contained Swift 6.3.2 modules
that the selected Swift 6.2 compiler could not import. No source change was needed for that cache mismatch.
The isolated build command
`env TMPDIR=/private/tmp/notch-pet-i1-20261028 DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer bash scripts/run.sh --build-only`
completed with exit 0, both executables, and a valid Info.plist before the pending build could be stopped.
Its artifacts are outside the repository in `/private/tmp/notch-pet-i1-20261028/notch-pet-dev/`.

The accessibility probe
`osascript -e 'tell application "System Events" to tell process "NotchPet" to get {name, count of menu bars}'`
was denied with `osascript is not allowed assistive access. (-25211)`.
No changed-source Swift test run, fictional helper injection, or visible-menu inspection was completed at that initial checkpoint.
The user then requested skipping checks. The task checkbox remained open.

The user subsequently authorized resuming I1 verification and committing it when verified. The same isolated build command above
completed with exit 0 and a valid Info.plist. The changed-source check
`env DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --scratch-path /private/tmp/notch-pet-i1-20261028/notch-pet-dev/build`
completed with exit 0: 48 tests in five suites, zero failures. Both commands required running outside the filesystem sandbox;
the initial sandboxed build could not write the compiler module cache (`Operation not permitted`). No source correction was needed.

The same accessibility probe now returned `NotchPet, 2`. Inspection of the already-running older app showed
the previous "Agent connections are not set up." placeholder, not I1's rebuilt session menu.
A temporary harness was prepared at `/private/tmp/notch-pet-i1-verify/verify_menu.py` to restart the rebuilt app and check fictional
observations through its bundled helper. Its execution was interrupted; no completed helper-to-visible-menu evidence was obtained.
The user then instructed "don't run the tests now", "just commit", and "and push". Further checks are paused;
the explicit commit/push instruction permits saving the implementation and records without claiming I1 is verified.
I1 remains unchecked, and I2's prepared goal remains inactive behind its I1 verification gate.

When the user authorizes verification, use the existing build and Swift commands in **Verify**, then launch
with `bash scripts/run.sh` and exercise fictional observations through the bundled helper.
Check both providers, concurrent same-folder sessions, idle/working/question/approval/response-ready/ended labels,
unknown state with retained unconfirmed notices, the recorded evidence time, and empty state after restart.
Include long project paths and source session identities in the native-menu inspection.
Keep temporary fixtures and any captures outside the repository. I6 retains installed-agent/Otty acceptance.

### I1 verification resumed by combined goal, 2026-10-28

The user activated `docs/goals/codex-setup.md`, authorizing the combined task list and its checks.
I3's separate design approval gate remains. No commit, push, or production configuration update is authorized.

`env TMPDIR=/private/tmp/notch-pet-codex-setup DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer bash scripts/run.sh --build-only`
exited 0 with app/helper executables and a valid Info.plist after creating the temporary root and allowing compiler-cache access.
The same environment with `bash scripts/run.sh` exited 0 and launched the rebuilt app.
A read-only process check confirmed PID 56750 running the executable from that exact app bundle.

`env DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --scratch-path /private/tmp/notch-pet-codex-setup/notch-pet-dev/build`
initially exited 1: 59 tests, with two issues in the provider cases of
`IntegrationHealthProbeTests.diagnosticsDiscardUnrelatedFictionalValues` at line 206.
The probe returned `timedOut` instead of expected `invalidOutput`.
The unchanged command with `--filter diagnosticsDiscardUnrelatedFictionalValues` then exited 0
with one parameterized test passing for both agents. The unchanged full suite then exited 0:
59 tests across seven suites, zero failures. No source or tests changed; the initial timeout's cause is not established.
These executions do not complete I2's separate app-wiring acceptance.

Computer Use could not obtain the app UI: bundle-ID and exact-bundle-path connections each returned
`Computer Use server error -10005: timeoutReached`; display-name connection returned `Invalid app: Notch Pet`.
The earlier temporary verification harness no longer exists. No fictional observations were injected,
and none of I1's ten visible-menu cases has fresh evidence. I1 remains unchecked.
The [I3 design review](../../contracts/codex-hook-setup.md#i3-design-review-for-the-activated-goal)
records proposed schema, recovery states, concurrency limitation, interfaces and required size review.
These proposals are not implementation approval.

### Guided I1 evidence, 2026-10-29

The user resumed the goal. Computer Use still timed out, but user-supplied screenshots verified
actual bundled-helper-to-menu delivery. The running rebuilt bundle was confirmed as PID 15730.
The temporary sender `/private/tmp/notch-pet-codex-setup/verify-menu-events.py` sent three basic
and three request observations; each invocation exited 0 silently. Visible delivery is established
by the screenshots, not those exit codes.

Verified: initial empty menu; Codex observed idle and Claude working; distinct sessions in the
same shared-project folder; Codex approval and Claude question labels; Codex submenu agent,
session, full project path, approval status, refresh timestamp, Bash request and i1-approval tool ID.
Screenshots supplied in this conversation end in 7668801, 7714634, 7780684 and 7831284.
Captures and sender remain outside the repository.

Response-ready, ended, unknown with retained unconfirmed notice, long identity/path handling,
and empty state after restart remain unverified. I1 stays unchecked. The user questioned the
manual screenshot burden; no further screenshots are requested. I3 design approval remains pending.

### N3 placement foundation, 2026-10-29

Historical: `NotchPlacement` was replaced by `IslandGeometry` on 2026-11-12 (see **Current layout**).

NotchPlacement.frame(screen:safeTop:notchWidth:expanded:) now computes compact/expanded panel
frames without AppKit. Five frozen NotchPresentationTests cover physical cutout room, negative
screen origins, narrow/short screens, displays without a cutout and invalid dimensions.
The initial test baseline failed because the type was missing. The first implementation needed
an explicit CoreGraphics import; assertions were unchanged. The isolated Swift command with
`--filter NotchPresentationTests` exited 0: five tests, zero failures.
This is N3's placement foundation only; no panel is rendered yet, and N3 remains unchecked.
