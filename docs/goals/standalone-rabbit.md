# First standalone rabbit

Status: blocked on user-deferred acceptance; approved implementation through BP5 is written.

This is the proposed first runnable pet milestone, not completion of the built-in-pet feature.
The user chose original artwork and specified a white lionhead rabbit on 2026-10-30.
The user explicitly approved this goal and requested continuation on 2026-10-30. The first conversation goal submission exceeded 4000 characters. After the user asked to see active goal progress, the saved 3977-character block was successfully registered; the conversation goal is now active.

## Paste after /goal

```text
GOAL: Deliver the first visible standalone white lionhead rabbit: original idle artwork plus pets/built-in-pet BP1-BP4, with optional agent services.

ENTRY: Read AGENTS.md, docs/STATUS.md, docs/specs/pets/{area,built-in-pet}.md and decisions 0001/0002/0003/0006/0013. Activation approves the asset step, BP1-BP4 and workflow exceptions; preparation does not. Create feat/pets-built-in-pet from the latest default branch, preserving uncommitted records. Leave other goals paused.

PLAN: Generate one original white lionhead rabbit transparent PNG with imagegen; then BP1 independent Pet module and idle fallback; BP2 bundle/render the rabbit; BP3 app-owned pet-only startup preserving explicit optional-agent startup; BP4 UserDefaults size persistence. Single idle pose is sufficient. Before each slice print files, API signatures, caller example and failing checks. Split within this scope to keep <=3 implementation files, <=3 added production functions and <=5 added tests per slice. Log/STATUS/spec checkpoint edits are exempt from the file limit; assets/package/packaging/check scripts count.

DONE WHEN all hold, with fresh output:
1. `env DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift build --target Pet --scratch-path /private/tmp/notch-pet-first/notch-pet-dev/build` exits 0; Pet has zero EventBridge/SessionState dependencies.
2. `env DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --scratch-path /private/tmp/notch-pet-first/notch-pet-dev/build` exits 0, zero failures, existing cases enabled and >=12 new pet cases: single idle, supplied optional animation, missing-animation idle fallback, packaged PNG decode/visibility, bundled resource lookup, zero pet-only service starts, explicit optional startup, preserved optional session path, missing size default, invalid size fallback, saved size restoration, no persisted session state.
3. `env TMPDIR=/private/tmp/notch-pet-first DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer bash scripts/run.sh --build-only` exits 0 with app/helper, valid Info.plist and rabbit resources. Create temp root first.
4. `python3 scripts/check-standalone-pet.py --app "/private/tmp/notch-pet-first/notch-pet-dev/Notch Pet.app" --artifacts /private/tmp/notch-pet-first/evidence` exits 0, 6/6 real-app checks: visible white lionhead rabbit without session/quota/setup warnings; usable default size; saved size after Quit/relaunch; invalid size fallback; zero event/usage receivers, provider processes, config probes or agent refresh starts; no stolen keyboard focus. Isolate preferences/config; record bundle/window/captures and production service-start instrumentation. Mocks, process absence alone or a demo UI do not prove this. One batched visual pass plus one correction.
5. `git diff --check` exits 0. Tick BP1-BP4 only on their evidence; leave BP5-BP7/source tasks open.

EVERY TURN: run applicable checks, print output and pass/fail/not-run per criterion; append a numbered timestamped row to docs/goals/standalone-rabbit-log.md. No stale results as fresh.

CONSTRAINTS: Change only Package.swift, Sources/Pet/**, Sources/NotchPet/**, Tests/PetTests/**, Tests/NotchPetTests/**, scripts/run.sh, scripts/check-standalone-pet.py, docs/specs/pets/built-in-pet.md, docs/STATUS.md and this goal/log. Freeze new checks before corresponding code; never weaken, skip or delete checks. No dependencies, commits, pushes, PRs, credentials, transcripts or real hook/config changes. Keep runtime/captures outside Git. No agent setup, reactions, detachment, imports or BP5-BP7 work. Use app-owned services; views start no I/O. No reference code/assets.

STOP AND REPORT: 30 turns; same failure 3 consecutive turns; missing access/tool, unrelated baseline failure, unresolved design or scope conflict. No separate build repair is authorized. ON FINISH/STOP: set log Status/Final result, run checkpoint, print proof/gaps and exact git add/commit commands for user review. Partial evidence is incomplete.
```

## Scope and approval

- Asset preparation is a separate step: create original artwork with the imagegen skill and built-in image tool, then supply the selected PNG to BP2. The existing built-in-pet spec excludes artwork generation from its implementation tasks; this goal explicitly adds the separate asset step. Do not generate artwork while merely preparing this goal.
- Activating the block approves only the asset step and BP1-BP4. It also approves bounded implementation slices and excludes mandatory log/status/spec checkpoint edits from their three-file limit. Package configuration, production assets, packaging changes and verification scripts still count. Preserve the limit of three added production functions and five added tests per slice.
- Keep the independent pet module, pet-first startup, app-owned optional services, and accepted manifest/PNG frame runtime format. A single-frame idle animation satisfies this milestone; there is no sprite-sheet input decision here.
- BP5 setup/settings, BP6 animation lifecycle, BP7 full-flow acceptance and the detachable-pet feature remain later work. The accepted drag-out/hide and overlap-return behavior stays recorded in the pets area; this goal does not implement it.
- BP4 can verify size persistence through isolated preferences and relaunch before a size-control UI exists. Do not add settings UI or a hidden alternate pet demo to make this milestone look complete.
- This goal does not resume or replace the paused notch/allowance goal. Do not inherit commit permission from any older goal.

## Artwork brief

One original white lionhead rabbit, recognizable by its fluffy mane framing the face, upright rabbit ears, compact rabbit body and white coat.
Use one calm idle pose with the full ears, mane and feet inside the image, padding on all sides, and genuine alpha transparency.
Use subtle neutral shading to keep white fur legible against light and dark desktops. No scene, text, costume, logos or reference artwork.
A small readable illustration is sufficient; animation frames and subjective polishing are outside this milestone.
Inspect the generated output before bundling it. Check its alpha, visible pixels, complete silhouette and readability at the default displayed size.
Use the built-in image tool; if unavailable, stop rather than substituting procedural artwork or an unapproved API workflow.
Keep intermediate generation outputs outside the repo; copy the final production PNG into Sources/Pet/Resources/.

## Expected implementation map

These are proposed files and interfaces, to refine in the printed plan before the relevant slice.

- BP1: Package.swift; Sources/Pet/PetPresentation.swift; Tests/PetTests/PetPresentationTests.swift. Add the independent Pet target, animation value data and missing-animation fallback.
- BP2: Sources/Pet/Resources/white-lionhead-idle.png; Sources/Pet/PetView.swift; resource declarations/packaging in Package.swift and scripts/run.sh as separate budgeted slices. Ensure SwiftPM resource bundles are included in the actual app, not just available from the build directory.
- BP3: Sources/NotchPet/NotchPetApp.swift; a new app-owned pet panel/controller and explicit optional-service owner; Tests/NotchPetTests/ and scripts/check-standalone-pet.py in separate slices. Preserve current optional session functionality. Default launch does not start it. A nonactivating AppKit surface renders the same Pet view used by the actual application.
- BP4: Sources/Pet/PetPreferences.swift and focused preference tests; connect the restored size to the app-owned pet surface in a separate slice if required. Use isolated UserDefaults suites in tests; no database or live session persistence.

Suggested public core sketch (bodies deliberately omitted; not an implementation):

```swift
struct PetAnimation {
    init?(frames: [String], frameDurationMs: Int) { }
}
struct PetPresentation {
    init(idle: PetAnimation, animations: [PetPose: PetAnimation] = [:]) { }
    func animation(for pose: PetPose) -> PetAnimation { }
}
```

Caller: the app owns one presentation with a valid idle asset; requesting an unavailable optional pose returns that idle animation. Pet types import no agent models. Keep the asset identifiers and pose type agent-independent.

## Frozen evidence requirements

The twelve test behaviors listed in the block are required, not a test-count substitute for behavior. Parameterized tests may cover more cases. Tests must assert actual outcomes, not merely mirror data declarations.
Before corresponding implementation, write the relevant failing checks, print their failures and freeze their requirements. Do not lower counts, remove assertions or skip unrelated failures. Tests may be extended to detect newly discovered defects.
The initial baseline may fail because the Pet target, tests, script or asset does not exist. Record that expected failure. An unrelated baseline error requires a stop and a separately authorized fix.

The new Python harness must exercise the built app via its actual launch path, identify the exact executable and window, and save evidence outside the repo.
Use isolated preference/config contexts, preserve the user's running app and configuration, and restore any temporary verification process state afterward.
Its six cases are exactly those in criterion 4. A capture and actual window inspection must establish a visible rabbit. Instrument production service-start boundaries for every prohibited category; an unused mock factory or absence of one child process is insufficient.
Prove size restoration by quitting and starting a new app process with the same isolated preferences, and prove defaults with separate missing/invalid preference cases.
For keyboard focus, record the frontmost application before and after showing the pet; a nonactivating style flag alone is insufficient.
If GUI capture, focus inspection or required instrumentation cannot be obtained, report the corresponding criterion blocked. Never replace actual-app acceptance with model tests.

Build/check commands are proposed reproduction commands. None ran while preparing this goal. Shell, GUI and image-tool permissions remain subject to the environment's actual approval controls.


## Activation and interface preference

The user approved the goal, its task slices and workflow exceptions on 2026-10-30, and asked to refer to the reference island whenever useful. They prefer similar opening behavior, Escape-to-close and limits presentation. Preserve pet-first startup and optional agent services. Apply relevant pet-surface behavior within this goal; retain limits/settings parity for its owning future interface work.

## Verification deferred by user

On 2026-10-30 the user requested "skip the tests first", then "just focus on further implementation" and a checkpoint. Stop further test/capture runs for now and do not retry the interrupted app-open request. Preserve the frozen criteria and keep the goal incomplete. Asset preparation and BP1–BP4 implementation are written; BP1 and BP4 have earlier focused verification, while BP2/BP3 retain incomplete actual-app acceptance. The latest app case observed a 120-point window and zero service starts before window capture failed. BP5 setup/settings is the proposed next coding task and requires approval beyond this goal's BP1–BP4 scope.

## Approved BP5 extension

The user explicitly selected "Approve BP5 implementation" after the approval question for native setup/settings with a rabbit preview, size control, menu access and Escape-to-close, while keeping tests deferred. This later instruction supersedes the original block's BP5 implementation exclusion for BP5 only. BP6/BP7, agent reactions and detachment remain outside authorized implementation scope. The original acceptance criteria are retained and have not been weakened.

BP5 implementation is written and its compile-only packaged build exited 0. No tests/captures/app launches ran for this extension. The user still defers acceptance, so the goal is incomplete. Next-task implementation would require a further approved scope extension; do not automatically run deferred checks or restart the interrupted app-open request.

## Git authorization

The user explicitly requested committing and pushing this work after the checkpoint. This supersedes the original block's no-commit/no-push restriction for the requested save. It does not authorize more tests, app launches, a PR, or additional implementation. Deferred acceptance and the blocked goal state remain unchanged.
