# Built-in pet

Status: replaced by [0021](../../decisions/0021-use-the-persons-own-pet-image.md) on 2026-11-06. The rabbit artwork and Use Built-in Pet are removed. Earlier tasks and evidence below keep their original meaning. `scripts/check-standalone-pet.py` still expects the built-in pet and needs rework before it runs again.


Merged evidence: [full MVP handoff](../notch-companion.md#merged-mvp-handoff-2026-11-06). Hosted build/package, existing tests and
coverage checks passed at `ab2ae13`. This is not feature-specific native/provider acceptance;
historical results and unrun acceptance checkboxes retain their original meaning.

## Goal

Let someone launch and set up a pet without coding agents, terminal software, or hook configuration.
Ship the standalone pet in the existing native app through an independent pet module.
See the [pets area](area.md) for later detachment, custom artwork, and agent reactions.

## Done when

- The actual app shows independently supplied default artwork with no agent installed or configured.
- First-use pet setup previews the default pet and lets the user choose its size without connecting an agent.
- Completing pet setup reveals ordinary pet behavior without agent setup warnings or empty session and quota panels.
- Pet-only startup starts no event receiver, usage receiver, provider process, configuration probe, or agent refresh loop.
- The pet module imports no `SessionState` or `EventBridge` types. It builds and its behavior checks run independently of agent services.
- Size survives Quit and relaunch. Missing or invalid preferences use a usable default.
- A single idle frame works. Missing optional animations retain a visible pose.
- Hidden or sleeping surfaces stop unnecessary animation. Reduce Motion uses a stable visible pose.
- Showing the pet does not take keyboard focus. Settings can take focus when explicitly opened.
- Basic menu controls open pet settings, reveal the pet, and quit the app without requiring an agent connection.

## Out of scope

- Session detection, agent reactions, request cards, allowance display, navigation, and provider actions.
- Connect, Pause monitoring, and Disconnect implementation. The owning session setup and first-use features provide those controls later.
- A second app, background service, repository split, or new installation format.
- Desktop drag-out, notch overlap return, placement persistence, and full display or Spaces recovery.
- Custom pack import, artwork selection across packs, sprite-sheet conversion, sound controls, or new pet artwork generation.
- Completing shared physical-desktop acceptance or resource profiling through model tests alone.

## Constraints

- Follow [decision 0013](../../decisions/0013-separate-standalone-pet-scope.md) and retain SwiftUI/AppKit.
- Keep the pet independent from agent models. A later adapter supplies agent-driven presentation.
- The app owns lifecycle and optional services. A SwiftUI pet view does not start monitoring or usage I/O.
- Never infer that no agent process exists from an empty observed-session list.
- Preserve existing hook configuration. Completing or skipping pet setup does not install, remove, or rewrite hooks.
- Use the accepted [asset-only format](../../decisions/0006-import-asset-only-pet-packs.md) and independently supplied artwork.
- Do not copy Flux artwork or execute pet-pack scripts. Keep imported packs and runtime files outside the repository.
- Keep preferences in UserDefaults. No database or persisted live session state is added.
- Preserve all source P0–P8 task lines and checkbox states. BP1–BP4 were approved through the standalone-rabbit goal; the user later approved BP5 implementation with tests deferred. The user approved the BP6a/BP6b split and BP6a implementation with focused tests and a packaged build on 2026-10-30. The later BP6b1/BP6b2/BP6b3 split and BP6b1 rendering plan are approved; BP6b2, BP6b3 and BP7 implementation/acceptance remain proposed.
- Before each implementation task, confirm a limit of three changed files, three added production functions, and five added test cases.
- Include assets, package configuration, and packaging scripts in that file budget. Split a task before coding if it cannot fit.
- The approved [standalone-rabbit goal](../../goals/standalone-rabbit.md), including its later BP5 extension, permits bounded implementation slices and exempts mandatory goal/log, STATUS and spec checkpoint edits from the three-file limit. It separately authorizes original artwork preparation.
- The separately approved BP6a goal permits two implementation/test files and three added production members, plus mandatory STATUS and spec records. It does not resume the older goal, app launches/captures, or other deferred acceptance.
- The approved BP6b1 task permits two implementation/test files, at most three added production functions and three new tests, plus STATUS and spec checkpoint records outside the file budget. Its approval covers focused tests and a packaged build only; no goal, native lifecycle wiring or actual-app acceptance is resumed.

## Verify

- Seam: the actual bundled app launched with isolated preferences and no configured agents.
- Build: `bash scripts/run.sh --build-only`.
- Swift checks: `env DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --scratch-path /private/tmp/notch-pet-dev/build`.
- Real app: `bash scripts/run.sh`, with runtime data and isolated preferences outside the repository.
- Check first launch, size changes, Quit and relaunch, Show Pet, explicit Settings focus, and an ordinary launch without agent services.
- Inspect service ownership and instrument isolated service factories to establish that pet-only startup starts no agent I/O.
- Check single-frame fallback and hidden, asleep, and Reduce Motion behavior with focused checks and one batched actual-app pass.
- Existing physical recovery and five-minute resource measurements remain in source R1–R5 and their later feature owners.
- Run builds, tests, and app checks only during approved implementation. BP6a authorizes the focused command `env DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --scratch-path /private/tmp/notch-pet-dev/build --filter PetPlaybackPolicyTests` (five tests, zero failures) and the packaged build above. Actual app checks remain deferred.
- BP6b1 focused checks: `env DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --scratch-path /private/tmp/notch-pet-dev/build --filter 'Pet(ViewPlayback|PlaybackPolicy)Tests'`. Pass: eight tests in two suites, zero failures. Then run `bash scripts/run.sh --build-only`; pass: exit 0 and `Info.plist: OK`. Frame selection checks do not establish actual scheduling, native lifecycle or focus acceptance.

## Decisions

- [0021: Use the person's own image as the pet, with no built-in pet](../../decisions/0021-use-the-persons-own-pet-image.md). Accepted 2026-11-06. Replaces this spec's built-in artwork.
- [0013: Use one app with an independent pet module](../../decisions/0013-separate-standalone-pet-scope.md). Accepted on 2026-10-30 for pet-first use and optional session-driven features.
- [0001: Retain SwiftUI and AppKit](../../decisions/0001-use-swiftui-and-appkit.md).
- [0002: Keep shared state and service ownership explicit](../../decisions/0002-use-mvvm-with-services.md).
- [0003: Use preferences and files without a database](../../decisions/0003-store-state-without-a-database.md).
- [0006: Use asset-only packs with optional-animation fallbacks](../../decisions/0006-import-asset-only-pet-packs.md).
- [0011: Preserve original tasks and evidence during migration](../../decisions/0011-organize-records-by-feature.md).
- **BP6 split, approved 2026-10-30:** implement the independent playback policy as BP6a, then separately plan BP6b view/lifecycle/focus wiring. The policy owns no timer or window. Only visible, awake, multi-frame playback with Reduce Motion off may advance; otherwise use the first frame. Invalid elapsed values also return the first frame. The caller owns monotonic elapsed time and scheduling. This approval covers BP6a's five focused tests and packaged build, not actual app acceptance.
- **Share app-owned window playback handling, accepted 2026-10-30:** the user approved the feature-completion goal's shared observable lifecycle wrapper over duplicate observers in the panel and settings controllers. Reuse keeps both surfaces on the same visibility/sleep handling and leaves the Pet module independent of native service ownership.

## My calls

- Use the existing compact notch location for this first slice. Desktop placement remains in detachable-pet.
- Start with one default pet and a size control. Custom appearance selection arrives with custom-packs.
- Make ordinary behavior an idle pose or supplied idle animation. Roaming, games, and autonomous play are not required here.
- Use a stable fallback pose when optional animations are absent. Do not invent missing art or agent status.
- Pet-only is the first-use default. Later explicit agent setup enables monitoring without a per-session mode switch.
- Keep agent connection entry points with their owning features. Do not add dead setup buttons before those features exist.
- Keep the original integrated P1 task in the source spec until agent-reactions is written. Do not split or reword it here.
- The user chose original white lionhead rabbit artwork on 2026-10-30. Its first idle PNG and manifest are now bundled through the independent pet target.
- Track no deadline or owner because none was supplied.

## Tasks

The user approved BP1–BP4 and a separate original-artwork step through the standalone-rabbit goal on 2026-10-30. The user subsequently approved BP5 implementation with tests deferred, then approved splitting BP6 and implementing BP6a as a bounded goal with focused verification. The user later approved splitting BP6b into rendering, native lifecycle wiring and app acceptance, and implementing only BP6b1 with focused tests and a packaged build. BP6b2, BP6b3 and BP7 remain proposals. Written implementation is distinguished from completed verification below.

- [x] BP1: Add standalone idle presentation and missing-animation fallback in an agent-free pet module, with focused behavior checks and required package configuration.
- [ ] BP2: Bundle and render independently supplied default pet artwork through the pet module, checking the packaged resource and visible fallback.
- [ ] BP3: Launch the pet through an app-owned presentation path that starts no agent or usage services, checking isolated startup and preserving the optional integration path.
- [x] BP4: Save and restore pet size with safe defaults, checking missing and invalid preferences without persisting session state.
- [ ] BP5: Add minimal pet setup and settings with a preview and size control, plus menu actions to open settings and reveal the pet without agent setup.
- [x] BP6a: Add an independent playback policy with five focused tests covering normal playback, single-frame artwork, hidden state, sleep and Reduce Motion; verify the packaged build.
- [x] BP6b1: Connect PetPlaybackPolicy to PetView rendering with monotonic elapsed time, cancellable scheduling, visibility/sleep inputs, Reduce Motion and artwork fallback; verify three component frame-selection tests, the five policy tests and the packaged build.
- [x] BP6b2: Wire app-owned visibility and sleep lifecycle into pet rendering, including the settings preview; review a bounded implementation and verification plan before coding.
- [ ] BP6b3: Verify actual scheduling cancellation/resumption, single-frame and missing-artwork fallback, stable visible artwork, Reduce Motion and no unsolicited focus in a batched actual-app pass; review and approve the acceptance plan first.
- [ ] BP7: Verify first launch, setup, settings, size restoration, fallback, and pet-only service isolation in the actual app, recording results and remaining limitations.

Coverage: BP1–BP2 cover module independence, artwork, and fallback. BP3 covers pet-only startup and service isolation.
BP4–BP5 cover setup, preferences, and basic controls. BP6a covers playback policy; BP6b retains animation lifecycle, Reduce Motion, stable visible artwork and focus acceptance.
BP7 checks the complete standalone flow in the real app.

## Planning evidence (before implementation)

The user approved pet-first setup, optional one-time agent connection, automatic session-driven features, and one app with an independent pet module.
They also approved separate built-in-pet and agent-reactions specs, with only this first spec written now.

Static inspection found no pet target or pet artwork in `Package.swift` or `Resources/`.
The current app starts the event bridge and notch panel during launch.
The notch controller starts the usage receiver, and current session presentation depends on `SessionState`.
These are implementation constraints, not evidence that standalone behavior exists.

Source P0 records the packaging discussion. Its direction is now accepted in decision 0013.
P0 stays unchecked pending final planning review. P1 remains unchecked and belongs to the future agent-reactions spec.
P2–P8 and shared R1–R5 requirements remain with their existing source lines and later feature owners.
No historical evidence is moved or rewritten by this plan.

Known prerequisite: the current app has a reported `ambiguous use of 'sync(execute:)'` build error in `NotchPanelController.swift`.
It was not reproduced or fixed here. Resolve that separate blocker before requiring an app build for these tasks.
No build, runtime check, Swift test, configuration access, or paused-goal work ran in this planning session.

## Implementation checkpoint, 2026-10-30

BP1–BP4 implementation is written on `feat/pets-built-in-pet`. No new tests or app launches ran during this checkpoint; the user requested skipping tests and focusing on implementation.

- BP1 is verified by the independent Pet target build and three focused presentation tests run earlier in this session. Pet imports no EventBridge or SessionState types.
- BP2 has an original white lionhead rabbit idle PNG, a versioned manifest, resource lookup, SwiftUI rendering and packaged SwiftPM resources. Two artwork tests passed earlier. It remains unchecked because actual visual/fallback acceptance is incomplete.
- BP3 has a nonactivating pet panel, pet-first app delegate, lazy optional-service owner and production service-start instrumentation. Existing session handling remains in optional AgentServices; usage I/O moved out of the view. Three lifecycle tests passed earlier. The isolated app recorded a visible 120-point window, loaded artwork, monitoring disabled and zero starts across event receiver, usage receiver, provider process, configuration probe and agent refresh. Full real-app acceptance remains incomplete, so BP3 stays unchecked.
- BP4 is verified by four earlier preference tests: missing/invalid/nonfinite values use 120 points, writes accept 64–256 points, a new preference instance restores the saved size, and only pet size is persisted. Actual Quit/relaunch size acceptance remains with the deferred app check.
- The full Swift command from the approved goal passed earlier with 116 tests and zero failures (104 existing plus 12 new). Module and packaged-app builds also exited 0. These are historical results from this session, not checks rerun for this checkpoint.
- The six-case app harness did not pass: `python3 scripts/check-standalone-pet.py --app "/private/tmp/notch-pet-first/notch-pet-dev/Notch Pet.app" --artifacts /private/tmp/notch-pet-first/evidence` reached window capture, where `screencapture` exited 1 with `could not create image from window`. The first case's diagnostic snapshot is in `.../evidence/b76eca08a3884cd9a610263ca73ba2ca/missing-preferences/pet.json`; it is not a screenshot or proof of all six cases.
- The earlier build-error report was not reproduced: both unchanged-baseline and changed-source packaged builds passed. No separate build repair was made. The temporary-directory diagnostic guard was fixed after a direct Foundation probe confirmed `/private/tmp` canonicalizes to `/tmp` on this Mac.

The user prefers Flux-like opening, Escape-to-close and limits presentation. Those preferences guide later setup/session interface work. Drag-out/hide and overlap-return stay accepted for detachable-pet; neither is implemented here.

## BP5 implementation, 2026-10-30

The user explicitly approved BP5 setup/settings, preview, size control, menu access and Escape-to-close, with tests deferred. Implementation is written in three bounded slices:

1. PetSettingsView (initializer and body) plus PetSettingsWindow.cancelOperation: two files, three production members. Preview uses the existing PetView; the view forwards actions to its app-owned controller.
2. PetSettingsController.init(defaults:onSizeChange:), show(activate:) and close(): one file, three functions. Size changes persist through PetPreferences and update the live pet. Start/Done sets pet.setupComplete; Escape/window close dismisses without claiming setup completion. First-use show uses activate:false; explicit settings requests activation.
3. PetAppController/NotchPetApp/PetPanelController wiring: three files, two added functions (showSettings and setSize). Added Pet Settings… with Command-comma. Resizing retains the pet's top-center anchor. Agent connection and monitoring configuration remain with their owning features.

The compile-only packaged build exited 0 with valid Info.plist after these changes. No new tests, captures or app launches ran for BP5. Its checkbox remains open until setup, persistence, focus, Escape and menu behavior are verified. The next proposed implementation task is BP6; it is not authorized by this BP5 approval.

## BP6a verification, 2026-10-30

The user approved BP6a as a separate bounded goal after reviewing its task split, API,
five-test plan and packaged-build command. This does not resume the standalone-rabbit goal.

- Added `PetPlaybackPolicy` in `Sources/Pet/PetPresentation.swift`, with three production members: `init(animation:isVisible:isSleeping:reduceMotion:)`, `shouldAnimate`, and `frame(at:)`. Added exactly five tests in `Tests/PetTests/PetPlaybackPolicyTests.swift`; no other production or test files changed.
- The first focused test attempt was blocked by sandbox compiler-cache access. The outside-sandbox retry exited 1 with `cannot find 'PetPlaybackPolicy' in scope`, establishing the expected failure before implementation.
- After implementation, `env DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --scratch-path /private/tmp/notch-pet-dev/build --filter PetPlaybackPolicyTests` exited 0: `Test run with 5 tests in 1 suite passed`. The cases cover frame timing/looping, single-frame playback, hidden state, sleep and Reduce Motion. Normal playback also checks invalid and very large elapsed values.
- `bash scripts/run.sh --build-only` exited 0 with `Info.plist: OK`. The packaged app is at `/var/folders/t3/6n_zw1rn5nn6vv7ccx9r6s240000gn/T/notch-pet-dev/Notch Pet.app`; it was not launched.
- Both successful commands ran outside the sandbox because Swift requires its user compiler cache. The full test suite, app checks and captures were not run.
- BP6a is complete. `PetView` still selects its first frame; the policy is not yet connected to rendering. Actual scheduling, visibility/sleep signals, Reduce Motion updates and focus/visible-artwork acceptance remain open in BP6b and BP7. BP2/BP3/BP5 acceptance states are unchanged.

## BP6b1 verification, 2026-10-30

The user approved the BP6b1/BP6b2/BP6b3 task split and the BP6b1 rendering API, limits, three-test plan and packaged-build command. This is one hands-on task, not a goal resumption. The approved split is recorded in Tasks rather than as a new architecture decision.

- Changed only `Sources/Pet/PetView.swift` and the new `Tests/PetTests/PetViewPlaybackTests.swift` outside mandatory STATUS/spec records. Added three production functions: `frame(at:reduceMotion:)`, `image(for:)` and `updatePlayback()`. Extended the existing initializer with defaulted `isVisible`/`isSleeping` inputs, preserving existing callers. Private `PlaybackID` contains the frames, timing and playback inputs so SwiftUI cancels/restarts its task when they change.
- The view uses PetPlaybackPolicy for frame selection, reads SwiftUI's accessibility Reduce Motion environment and derives elapsed seconds from monotonic system uptime. Its task returns before entering the sleep loop when the policy disables animation, and exits on cancellation. Missing frame resources still fall back to the first idle resource, then the existing unavailable-artwork symbol. The bundled rabbit remains single-frame artwork.
- Exactly three new component tests cover requested-pose timing, missing-pose idle playback and stable frame selection for hidden/sleeping/Reduce Motion inputs plus single-frame artwork. They exercise the method used by the view body; they do not mount a SwiftUI view or measure task scheduling.
- The first sandboxed focused command failed with `error opening '/Users/bytedance/.cache/clang/ModuleCache/Swift-7JL1KBZ3A6V3.swiftmodule' for output` / `Operation not permitted`. The outside-sandbox retry exited 1 with the expected missing `frame(at:reduceMotion:)`/initializer API errors before production implementation.
- After implementation, `env DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --scratch-path /private/tmp/notch-pet-dev/build --filter 'Pet(ViewPlayback|PlaybackPolicy)Tests'` exited 0: `Test run with 8 tests in 2 suites passed`. `bash scripts/run.sh --build-only` exited 0 with `Info.plist: OK`. Both successful commands ran outside the sandbox for Swift compiler-cache access. The packaged app is under `$TMPDIR/notch-pet-dev/Notch Pet.app` and was not launched.
- BP6b1 is complete. Native panel/settings visibility and sleep signals remain unwired; existing callers use the default visible/awake inputs. Actual scheduling cancellation/resumption, Reduce Motion changes and visible-artwork/focus acceptance remain open in BP6b2/BP6b3. The full suite, app launch/capture, BP2/BP3/BP5 acceptance and older goals were not resumed.

## Proposed feature-completion goal, 2026-10-30

The user requested a goal spanning multiple tasks, preferably completing this feature.
[Complete built-in pet](../../goals/complete-built-in-pet.md) proposes BP6b2 panel and settings wiring in bounded slices, native harness/diagnostic work, BP2/BP3/BP5/BP7 acceptance, BP6b3 scheduling/focus acceptance and an audit of every Done-when item.
The user subsequently approved its full task list, resumption of deferred tests/app launches/captures and shared lifecycle wrapper. The conversation goal is active; prior goals remain untouched.
The goal retains the three-file/three-production-member/five-test per-slice limits and proposes an exemption for mandatory goal/log/STATUS/spec records. It freezes twelve native acceptance groups alongside the existing six-case harness, focused/full Swift checks and packaged build. In-app injected lifecycle/environment evidence must be labelled and cannot establish physical system sleep or shared desktop-recovery acceptance.
No task state changed, implementation began or acceptance ran during preparation; earlier goals remain untouched.

## BP6b2 verification and visual-check deferral, 2026-10-30

The user approved the feature-completion goal, bounded task list, shared lifecycle wrapper and native acceptance. BP6b2 was implemented in two slices: three files/three production members/five tests for the shared wrapper and panel, then two settings files with no new production functions.

- `PetWindowPlaybackState` observes bound-window visibility/occlusion, miniaturization and closure plus workspace sleep/wake. It releases Combine subscriptions with the state and uses weak window/owner references. The shared SwiftUI wrapper forwards inputs to the panel and settings preview without replacing the settings view's state on each lifecycle event.
- The full unchanged baseline suite passed 124 tests. The five new tests first failed with missing `PetWindowPlaybackState` errors. After implementation the focused command with filter `Pet(WindowPlayback|ViewPlayback|PlaybackPolicy)Tests` passed five lifecycle and eight playback tests. The final full Swift command from Verify passed 129 tests (73 + 17 + 8 + 31), zero failures. The independent Pet target build exited 0; it still has no agent imports/dependencies. Packaged build exited 0 with `Info.plist: OK` after correcting the wrapper's implicit controller capture.
- `env DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer python3 scripts/check-standalone-pet.py --app "/private/var/folders/t3/6n_zw1rn5nn6vv7ccx9r6s240000gn/T/notch-pet-dev/Notch Pet.app" --artifacts /private/tmp/notch-pet-completion/evidence/standalone` reproduced `could not create image from window` / screencapture exit 1. Evidence under `391dc2a78c844f8bac472505813aee15/missing-preferences` records a native 120-point panel, artwork loaded, unchanged frontmost PID and zero production starts in all five service categories, followed by normal termination. This is incomplete native acceptance, not visual proof.
- A read-only native permission probe reported `screenCaptureAuthorized=false` and `accessibilityAuthorized=true`. The user then explicitly requested no screen recording and skipping that part of testing while continuing implementation. This supersedes capture/visual-inspection requirements and the goal's missing-screen-access stop for this run only. Do not request Screen Recording again or capture windows. Keep the checks recorded as skipped by request; do not turn them into passes. Other native verification remains authorized, and actual scheduling/focus acceptance remains in BP6b3/BP7.

## Implementation handoff after testing deferral, 2026-10-30

The user subsequently instructed "no need to test, just implement". No additional builds, tests, app launches or diagnostics were started after that instruction. BP6b2 finishes the remaining production implementation in this spec; BP2/BP3/BP5 implementation was already written. BP6b3 and BP7 are acceptance tasks, and no additional test-only production APIs or twelve-group harness were added after the deferral. The feature is implemented but not fully accepted; its remaining checkboxes stay open and no Status: done is added.

The already-running final no-capture command completed with exit 0: five nonvisual checks passed and one visual check was explicitly skipped. Evidence is under `/private/tmp/notch-pet-completion/evidence/standalone/fafc23e05da84e7485c82286620c6668`. The native harness observes production size restoration across Quit/relaunch, missing/invalid size defaults, zero event/usage receiver, provider, probe and refresh starts, and absence of test-app focus activation. It now records workspace activation events because endpoint focus equality failed when two external applications changed focus; the target app was neither PID. The event trace strengthens the actual no-app-activation assertion while retaining endpoint observations for diagnosis.

First-use Start/slider/menu interaction, actual multi-frame scheduling/cancellation/resumption, Reduce Motion changes and visual appearance/fallback acceptance remain unverified. Runtime artifacts stay outside the repo; optional integrations and real configuration remain unchanged.
