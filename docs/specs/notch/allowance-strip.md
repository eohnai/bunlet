# Show usage limits in the notch's top row

Status: done
Needs: session-cards

## Goal

Replace the expanded notch's large "limits" sections with a compact allowance strip in the top row, to the left of the physical notch.
Each active provider shows its logo, its 5-hour percent left, and the time until reset.
The user removed hover details under [0014](../../decisions/0014-omit-usage-limit-tooltips.md).
This takes over the display part of usage/codex-allowance U5. See the [notch area](area.md) and [usage area](../usage/area.md) for shared context.

## Done when

- Collapsed, the top row still shows the paw and the session count, unchanged.
- Expanded, the top row shows the strip left of the notch: `[logo] 5h 96% 3h45m | [logo] 5h 80% 1h10m`. The right side stays empty for a later toolbar.
  Clicking the top row still expands and collapses the panel.
- Only providers with an observed active session appear. Idle, working, waiting, and response-ready count as active;
  Unknown and Ended do not. Each provider requires its own active session under [0015](../../decisions/0015-show-limits-only-for-active-providers.md).
  Claude Code uses the Claude logo and Codex uses the Codex logo.
- Each provider shows its 5-hour window. If the provider reports no 5-hour window, it shows its weekly window as `7d`.
- Percent left is `100 − used`, rounded down. It is green above 50% left, yellow from 20% to 50%, and red below 20%.
- The countdown reads `3h45m` or `4d22h`. A stale reading shows in gray. A provider with no window shows `5h —`. An unverified account shows a marker.
- The old "Codex limits" and "Claude Code limits" sections are gone from the panel.
- `swift test` passes, including new presentation tests.
- Real app: a real Codex reading appears in the strip and Claude shows `5h —` in the nonactivating panel.
  The user reviews it in the same batched visual pass as session-cards C5.

## Out of scope

- Toolbar icons on the right of the top row.
- Live Claude allowance in the app: usage/claude-allowance U2c3. The app has no receiver startup path yet.
- Refresh, retry, reconnect, and account switching: usage/refresh-recovery.
- Changes to the usage store, providers, or the Codex read loop.
- Session cards and panel size: [session-cards](session-cards.md).

## Constraints

- The usage store keeps the reported used value. Percent left is derived only in presentation, under [D6](../../DECISIONS.md#d6-show-allowance-as-percent-left-not-percent-used).
- Read-only views use pure presentation functions, under [D3](../../DECISIONS.md#d3-add-view-models-only-where-a-view-owns-state).
- Several sessions never duplicate allowance. Providers are never combined into a total.
- The countdown updates no more than every 30 seconds, and only while the panel is expanded.
- Keep the nonactivating panel. Hovering must not take keyboard focus.
- Builds, tests, and app checks need the user's authorization for each task. App launches were allowed on 2026-10-31.

## Verify

- Seam: `UsageStore` snapshots into the expanded top row of the running app.
- Swift checks: `env DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --scratch-path /private/tmp/notch-pet-dev/build`.
  Passing means exit 0 with no failing tests.
- Build: `env DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer bash scripts/run.sh --build-only`. The packaged app contains both logo files.
- Real app: `env DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer bash scripts/run.sh` with an active Codex session.
  Keep no raw quota or account IDs in the repository. Do not request screen-capture permission. The user supplies the one visual review.

## Results

Checked 2026-11-02 on `feat/notch-allowance-strip`, working tree based on `96ff9c8`.

- Full Swift suite: final rerun passed 171 tests in 27 suites, exit 0.
- Final app build: exit 0, `Build complete!` and `Info.plist: OK`.
- User screenshots confirmed real Codex limits, Claude's empty state, logos/header fit, and session/request cards.
- The user confirmed advancing/fixed timers and preserved terminal focus. Tooltips were removed at their request under 0014.
- Provider filtering is covered for both agents and all session states under 0015. This last filter change did not repeat the visual review.
- The review app quit normally, clearing fictional sessions and removing its event socket. Existing agent configuration was preserved.
- VoiceOver, real-session hook setup, and live Claude forwarding remain outside this completed review.
- The known version-probe timeout recurred before the passing rerun. It remains unresolved.

Final logs: `/private/tmp/notch-pet-a5-active-providers-rerun.log` and `/private/tmp/notch-pet-a5-active-providers-build.log`.

## Decisions

- [D6: Show allowance as percent left, not percent used](../../DECISIONS.md#d6-show-allowance-as-percent-left-not-percent-used), 2026-10-31.
- **Put the strip in the top row only when expanded, 2026-10-31.** The user chose the top row beside the notch over a separate row below it.
  Collapsed, the paw and session count stay. The right side is kept for a later toolbar.
- **Show the 5-hour window, or the weekly window when there is no 5-hour window, 2026-10-31.** The user chose this over both windows per provider and over the window with the least left.
  Some plans have no 5-hour window.
- **Put details in a hover tooltip, 2026-10-31.** The user chose this over a details row that opens on click, and over dropping the details. (replaced by 0014 on 2026-11-02)
- **Keep the tooltip details and call them usage limits, 2026-11-02.** After clarifying the term, the user agreed to retain both limit windows, exact reset times, and missing/stale/account information.
  Deferring the tooltip was considered. Keeping it preserves access to the details omitted from the compact strip. (replaced by 0014 on 2026-11-02)
- [0014: Omit usage-limit tooltips](../../decisions/0014-omit-usage-limit-tooltips.md), accepted 2026-11-02.
  After seeing the native tooltips and their delay, the user chose removal as unnecessary. The compact strip remains.
- [0015: Show usage limits only for active providers](../../decisions/0015-show-limits-only-for-active-providers.md), accepted 2026-11-02.
  The user requires each provider to disappear when none of its sessions is active. Retained Unknown sessions no longer keep it visible.
- **Use the real Claude and Codex logos, 2026-10-31.** The user chose them over simple colored marks we draw ourselves.
  This means bundling the two companies' brand artwork in the app.
- **Prefer the matching `codex/` bucket, 2026-11-01.** The user approved this over choosing the bucket with the lowest allowance.
  Within the selected duration, use a sole matching window when no `codex/` window exists. Multiple remaining matches show unavailable.
  This avoids presenting an arbitrary bucket's quota as the provider's allowance.
- **Use the user-supplied LobeHub variants, 2026-11-02.** The user identified LobeHub as the source and approved resource packaging.
  This replaces the official-brand-page sourcing call below. These are third-party copies, not verified official provider downloads.

## My calls

- The strip waits for session-cards, because it fits in the 620-point panel width that session-cards C3 sets.
- The user supplies the two logo files (SVG or PDF) from each company's official brand page. The task records where each file came from. (replaced 2026-11-02)
- Logos go in the app's resources, with the pet resources as the pattern. A missing logo falls back to the provider name in text.
- Keep the two supplied SVGs in the repository and bundle them locally. This avoids runtime or build-time network fetches.
  Updates require an explicit asset change. Automatic fetching adds machinery for only two small files.
- The strip shows one entry per provider. If one provider has several sources, the entry uses the newest fresh reading.
- A passed reset counts as stale, as the usage store already decides.

## Current scope

Hover details and a replacement details surface are outside this feature under 0014.
The store keeps full usage observations. Historical tooltip plans and evidence below record the earlier scope.

## A1 plan, 2026-11-01

The user approved A1, the bucket rule above, and focused verification.
Branch: `feat/notch-allowance-strip`, stacked on session-cards C4 `a2a2ede`.
Session-cards C5 stays open for the combined C5/A5 visual review.

Files, in order:

1. Add failing cases in `Tests/SessionStateTests/NotchAllowancePresentationTests.swift`.
2. Add pure presentation in `Sources/SessionState/NotchAllowancePresentation.swift`.
3. Record verification here and checkpoint `docs/STATUS.md`. Tick A1 only after verification passes.

Approved API sketch, with empty computed properties and function bodies:

```swift
public enum AllowanceColor: Equatable, Sendable {
    case green, yellow, red, gray
}

public struct NotchAllowanceEntry: Equatable, Sendable {
    public let provider: IntegrationAgent
    public let source: UsageSnapshot?
    public let window: UsageWindow?

    public var windowLabel: String {}
    public var percentLeft: Int? {}
    public var color: AllowanceColor {}
    public var accountUnverified: Bool {}
}

public enum NotchAllowancePresentation {
    public static func entries(
        activeProviders: Set<IntegrationAgent>,
        snapshots: [UsageSnapshot]
    ) -> [NotchAllowanceEntry] {}
}
```

Later caller:

```swift
let snapshots = store.snapshots(activeProviders: providers, nowMs: nowMs)
let entries = NotchAllowancePresentation.entries(
    activeProviders: providers, snapshots: snapshots)
```

Implementation details:

- Return one entry per active provider in provider-name order, including providers without observations.
- Choose the newest fresh source, or the newest stale source when none are fresh.
  Break equal receipt-time ties by source ID in UTF-8 order. Never borrow another source's window or account evidence.
- Select 300 minutes first. Select 10,080 minutes only when no 300-minute window exists.
  Apply the bucket rule within that duration. Ambiguity does not trigger a weekly fallback.
- Missing windows have no percent value and use the `5h` label and gray color.
- Floor percent left before applying the color boundaries. Reuse `UsageSnapshot.isStale` for gray.
- Show the unverified marker when a selected observation has no account ID.
  No observation means missing data, without a separate unverified marker.
- Retain the selected source and window for A2. Derived values are computed, with no clock or I/O.

Approved verification, before implementation and again afterward:

```bash
env DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  swift test --scratch-path /private/tmp/notch-pet-a1/build \
  --filter 'NotchAllowancePresentationTests|UsageStoreTests'
git diff --check
```

Passing means exit 0, no failed tests, and no whitespace errors.
Full-suite verification remains for feature completion. A1 includes no app launch, helper injection, or capture.

## A1 verification, 2026-11-01

Implemented on `feat/notch-allowance-strip`, stacked on session-cards C4 `a2a2ede`.
The user approved implementation, the stacked branch, focused tests, and the Codex bucket rule.

`NotchAllowancePresentation.entries` returns one entry per active provider, including a missing-data entry when no source exists.
It selects the newest fresh source, or the newest stale source when none are fresh.
Receipt-time ties use source ID in UTF-8 order. Each entry retains its selected source and window for A2.
Percent left, label, color, and the account marker are computed without changing store values.
Colors use the rounded-down percent. Stale and missing values are gray.
Window selection follows the approved duration and bucket rules, without combining quotas or borrowing another source's data.

The first focused run exited 1 because the sandbox denied Swift's compiler cache.
The approved elevated retry exited 1 because the presentation types and function did not exist, establishing the failing cases.
After implementation, the same focused command exited 0: 19 tests in two suites passed.
The suites are `NotchAllowancePresentationTests` (14 tests) and `UsageStoreTests` (5 tests).
`git diff --check` also exited 0.
Compilation reported an existing warning in `Tests/NotchPetTests/PetWindowPlaybackTests.swift:108`:
`weak variable 'released' was never mutated; consider changing to 'let' constant`. It remains with the pet work.

Cases cover both providers, active-provider filtering, source ordering, fresh and stale selection, missing data,
5-hour preference, weekly fallback, Codex bucket preference, ambiguity, percent rounding, color boundaries,
account confidence, and store-owned age/reset/clock/failure freshness.
Logs remain outside the repository at `/private/tmp/notch-pet-a1-red.log` and `/private/tmp/notch-pet-a1-green.log`.

No full-suite run, standalone app build, app launch, helper injection, or capture ran for A1.
The app uses the existing limits view until A4. Runtime acceptance remains open for C5/A5.

## A2 verification, 2026-11-01

The user approved the chat task list and focused checks. No goal was activated.
Implemented on `feat/notch-allowance-strip`, preserving A1 commit `9a94fec`.

Files changed:

- `Tests/SessionStateTests/NotchAllowancePresentationTests.swift`: nine new text tests, with per-provider cases.
- `Sources/SessionState/NotchAllowancePresentation.swift`: pure countdown and tooltip methods.
- This spec and `docs/STATUS.md`: verification evidence and checkpoint.

The new public methods are:

```swift
public static func countdownText(for window: UsageWindow?, at nowMs: Int64) -> String
public static func tooltipText(for provider: IntegrationAgent,
                               snapshots: [UsageSnapshot],
                               missingSourceStatus: String,
                               locale: Locale,
                               timeZone: TimeZone) -> String
```

`countdownText` subtracts numeric timestamps without signed overflow and floors remaining minutes.
Its formats are `45m`, `3h45m`, and `4d22h`. Missing resets show `—`. Passed resets and less than one minute show `0m`.

`tooltipText` filters to one provider and lists every source and window without combining allowance.
Sources and windows sort by their IDs in UTF-8 order. Sources have ordinal labels instead of raw source IDs.
Each window shows its bucket, actual duration, used percentage, rounded-down percent left, and reset time.
Used percentages show up to one decimal place. Percent-left calculation is shared with A1 to keep one rule.
Missing 5-hour and weekly windows remain explicit.

Each source shows fresh/stale state, receipt and measurement dates, account confidence, and any failure status.
Missing measurement dates remain explicit. Receipt time does not substitute for measurement time.
Account confidence never prints the raw account ID. All six failure cases have fixed messages.
Only a provider without observations uses `missingSourceStatus`, supplied later by A4's caller.
This prevents the controller's initial status from appearing beside an existing reading.
Dates and numeric text use explicit locale and time-zone inputs. Presentation reads no clock and schedules no work.

Approved verification, before implementation and afterward:

```bash
env DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  swift test --scratch-path /private/tmp/notch-pet-a2/build \
  --filter 'NotchAllowancePresentationTests|UsageStoreTests'
git diff --check
```

The first run exited 1 because the sandbox denied Swift's compiler cache.
The approved elevated retry exited 1 because the two A2 methods did not exist, establishing the failing baseline.
After implementation, the focused command exited 0: 28 tests in two suites passed.
Review strengthened the tests for distinct reset, receipt and measurement dates and locale-specific decimals.
The final focused run also exited 0: 28 tests passed, comprising 23 presentation tests and 5 store tests.
`git diff --check` exited 0.

Tests cover countdown unit boundaries, missing/expired resets, extreme timestamps, both providers, separate sources/buckets,
stable ordering, fractional percentages, locales/time zones, distinct timestamp roles, missing timing evidence,
freshness, account confidence, all source failures, missing-provider status, and cross-provider filtering.
The first successful build reported the existing `PetWindowPlaybackTests.swift:108` weak-variable warning from A1's evidence.
That pet warning remains outside this task.
Logs stay outside the repository at `/private/tmp/notch-pet-a2-red.log` and `/private/tmp/notch-pet-a2-green.log`.

No full-suite run, standalone app build, app launch, helper injection, or capture ran for A2.
A4 still owns rendering and the expanded-only refresh schedule. A5/C5 still own the batched runtime and visual review.

## A3 asset preparation, 2026-11-02

The user supplied two SVG files and requested their placement and renaming.
Both files were copied unchanged, with the Downloads originals retained:

| Supplied file | Repository path |
|---|---|
| `/Users/ianhoe/Downloads/codex-color.svg` | `Sources/NotchPet/Resources/Logos/codex.svg` |
| `/Users/ianhoe/Downloads/claudecode-color.svg` | `Sources/NotchPet/Resources/Logos/claude-code.svg` |

Both files parse as SVG with a `0 0 24 24` view box.
Neither file has download-source metadata. The user later identified `lobehub.com` as the source and approved packaging.
The verified upstream file pages are:

- [Codex color SVG](https://github.com/lobehub/lobe-icons/blob/master/packages/static-svg/icons/codex-color.svg).
- [Claude Code color SVG](https://github.com/lobehub/lobe-icons/blob/master/packages/static-svg/icons/claudecode-color.svg).

`Sources/NotchPet/Resources/Logos/SOURCES.md` records the source links, original names, and bundled-file SHA-256 values.
`LobeIcons-LICENSE.txt` preserves the collection's MIT license. Both notices are packaged with the logos.
These files are third-party LobeHub variants. No official-provider download or upstream commit identity is claimed.

## A3 verification, 2026-11-02

The user approved resource registration, app packaging, and the build check on `feat/notch-allowance-strip`.
`Package.swift` now processes the app target's `Resources` directory.
`scripts/run.sh` copies `NotchPet_NotchPet.bundle` into the app's `Contents/Resources` directory.
No custom types or functions were added.

A pre-change assertion failed because the app target had no resource declaration.
The approved build command was:

```bash
env DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  TMPDIR=/private/tmp bash scripts/run.sh --build-only
```

The sandboxed attempt failed on compiler-cache access with `Operation not permitted`.
The same command passed outside the sandbox, with `Build complete!` and `Info.plist: OK`.
The packaged app is `/private/tmp/notch-pet-dev/Notch Pet.app`.

```bash
cmp Sources/NotchPet/Resources/Logos/codex.svg \
  "/private/tmp/notch-pet-dev/Notch Pet.app/Contents/Resources/NotchPet_NotchPet.bundle/codex.svg"
cmp Sources/NotchPet/Resources/Logos/claude-code.svg \
  "/private/tmp/notch-pet-dev/Notch Pet.app/Contents/Resources/NotchPet_NotchPet.bundle/claude-code.svg"
cmp Sources/NotchPet/Resources/Logos/SOURCES.md \
  "/private/tmp/notch-pet-dev/Notch Pet.app/Contents/Resources/NotchPet_NotchPet.bundle/SOURCES.md"
cmp Sources/NotchPet/Resources/Logos/LobeIcons-LICENSE.txt \
  "/private/tmp/notch-pet-dev/Notch Pet.app/Contents/Resources/NotchPet_NotchPet.bundle/LobeIcons-LICENSE.txt"
git diff --check
```

All comparisons and the whitespace check exited 0.
No Swift tests, app launch, helper injection, or capture ran for A3.

**A4 lookup requirement:** the generated `Bundle.module` accessor searches
`Bundle.main.bundleURL/NotchPet_NotchPet.bundle`, then the absolute build directory.
The app packages its bundle under `Contents/Resources` instead.
The planning example using `Bundle.module` alone therefore does not establish packaged-app lookup.
A4 must resolve the packaged resource bundle explicitly and retain the provider-name fallback.
The pet's generated accessor has the same pattern. Its separate lookup behavior was not changed or verified here.
Rendering and actual-app resource loading remain unverified until their owning tasks run.

## A4 plan and verification, 2026-11-02

The user approved A4, the focused tests, and the build-only check.
Stay on `feat/notch-allowance-strip`, stacked on session-cards C4 `a2a2ede`.

Files and order:

1. Add failing packaged-resource, missing-resource, and invalid-image cases in
   `Tests/NotchPetTests/ProviderLogoTests.swift`.
2. Add `Sources/NotchPet/ProviderLogo.swift` with
   `image(for provider: IntegrationAgent, appBundle: Bundle = .main) -> NSImage?`.
   Resolve packaged resources explicitly. Cache the app's decoded logos once.
3. Replace `NotchUsageView.swift` with `NotchAllowanceStrip.swift`.
   Its inputs are `store: UsageStore` and `activeProviders: Set<IntegrationAgent>`.
   Reuse A1/A2 for entries, countdowns, colors, and full tooltips.
4. Update `NotchSessionView.swift` to place the strip in the expanded header's left side.
   Keep the collapsed paw and count. Leave the expanded right side empty.
5. Record evidence here and checkpoint `docs/STATUS.md`.

`ProviderLogo` resolves `Contents/Resources/NotchPet_NotchPet.bundle` in an app bundle.
A missing or invalid packaged logo returns `nil`, without consulting a build-machine copy.
The strip then shows the provider name. Non-app development execution uses the SwiftPM resource bundle.
Both supplied SVGs decode and rasterize in tests using synthetic app bundles outside the repository.

The strip reads store snapshots and the controller's missing-source status.
It renders each active provider once, with the selected window, percent left, countdown, and account marker.
Missing allowance shows `5h —`. Each entry retains the A2 tooltip, including all sources and windows.
Provider entries sit outside the header button label, with their own accessibility labels and tooltips.
The header retains its expansion action and accessible button.
Equal-width header sides reserve the physical notch's space, and the left side clips at its boundary.

The parent creates the strip only while expanded.
The strip creates a 30-second `TimelineView` only when active providers exist.
The session-card timeline and usage read loop are unchanged.
Actual scheduling, constrained-width appearance, tooltips, focus, and accessibility remain for A5/C5.

Approved verification:

```bash
env DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  swift test --scratch-path /private/tmp/notch-pet-a4/build \
  --filter 'ProviderLogoTests|NotchAllowancePresentationTests|UsageStoreTests'
env DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  TMPDIR=/private/tmp bash scripts/run.sh --build-only
git diff --check
```

The first sandboxed test attempt failed on compiler-cache access with `Operation not permitted`.
The elevated baseline failed because `ProviderLogo` did not exist.
The first implementation build found an unsupported `accessibilityHelp` modifier.
Removing that call corrected compilation. The `.help` tooltip remains.
The focused tests then passed. After the final header changes, the same command passed again:
32 tests in three suites, comprising 4 logo tests, 23 presentation tests, and 5 store tests.
Logo cases cover both supplied SVGs, missing bundles, missing provider files, and invalid image data.
The invalid-image case emits an expected CoreSVG diagnostic.
The existing `PetWindowPlaybackTests.swift:108` weak-variable warning remains outside A4.

The sandboxed build also failed on compiler-cache access.
The elevated build exited 0 with `Build complete!` and `Info.plist: OK`.
Both packaged logos matched the source SVGs with `cmp`:

```bash
cmp Sources/NotchPet/Resources/Logos/codex.svg \
  "/private/tmp/notch-pet-dev/Notch Pet.app/Contents/Resources/NotchPet_NotchPet.bundle/codex.svg"
cmp Sources/NotchPet/Resources/Logos/claude-code.svg \
  "/private/tmp/notch-pet-dev/Notch Pet.app/Contents/Resources/NotchPet_NotchPet.bundle/claude-code.svg"
```

Both comparisons and `git diff --check` exited 0.
Logs remain outside the repository at `/private/tmp/notch-pet-a4-red.log`,
`/private/tmp/notch-pet-a4-green.log`, and `/private/tmp/notch-pet-a4-build.log`.
No full-suite run, app launch, helper injection, or capture ran for A4.
A5 and session-cards C5 remain open for the single batched runtime and visual review.

## A5/C5 review and final scope, 2026-11-02

Reviewed on `feat/notch-allowance-strip`, stacked on session-cards C4 `a2a2ede`, with A4 committed as `96ff9c8`.
The user approved full tests, builds, fictional helper injections, and runtime review.

The initial full-suite run failed the known Claude version-probe timeout at `IntegrationHealthTests.swift:99`:
`.unavailable(.timedOut)` instead of `.reported("2.1.306")`.
Five isolated probe tests and one full rerun then passed; that full run contained 177 tests in 27 suites.
The app build passed, and both packaged SVGs matched their source files.
Logs: `/private/tmp/notch-pet-a5-full.log`, `/private/tmp/notch-pet-a5-probe.log`, and `/private/tmp/notch-pet-a5-build.log`.

The packaged app launched with argument-only monitoring enabled and external evidence:

```bash
env DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  /usr/bin/open -g \
  --stdout /private/tmp/notch-pet-a5-runtime/stdout.log \
  --stderr /private/tmp/notch-pet-a5-runtime/stderr.log \
  --env NOTCH_PET_EVIDENCE_DIR=/private/tmp/notch-pet-a5-runtime \
  "/private/tmp/notch-pet-dev/Notch Pet.app" \
  --args -agentMonitoringEnabled YES -pet.setupComplete YES
python3 /private/tmp/notch-pet-a5-review.py
```

The script sent seven fictional cases through the packaged helper: a shared-folder running/stopped Codex pair,
Claude approval, Codex question, unknown, idle, and ended sessions. Every invocation was silent with exit 0.
The user supplied screenshots establishing actual delivery, logos/header fit, real Codex usage limits,
Claude's empty state, card labels, request guidance, short IDs, and expanded identity details.
The user confirmed timer advancement and preserved terminal focus while hovering and after clicking.
A stopped card showed three seconds; confirmation that it stayed fixed remains pending for C5.
VoiceOver remains untested. Fictional observations expire after two minutes, as the store requires.

The user's real Codex session did not appear. Bounded hook-structure inspection found no direct
`NotchPetHook` call in the selected hook file's supported event groups. Configuration and commands were not printed or changed.
Hook installation and Connect controls remain unfinished in `sessions/codex-setup`.
A fictional non-ended Codex session can trigger the existing independent real account-limits read.
This review does not establish real-session integration or change provider eligibility.

### Native tooltip trial

The first hover check failed. The installed SDK documents inactive-app tooltips as disabled by default.
Enabling `allowsToolTipsWhenApplicationIsInactive` and using "usage limits" in visible text was tried.
The full suite passed 177 tests in 27 suites and the build passed.
The user subsequently supplied screenshots confirming both native tooltips appeared after waiting.
Logs: `/private/tmp/notch-pet-a5-tooltip-full.log` and `/private/tmp/notch-pet-a5-tooltip-build.log`.
The revised wording assertions first failed as expected in `/private/tmp/notch-pet-a5-tooltip-red.log`.
Runtime evidence for this trial is `/private/tmp/notch-pet-a5-tooltip-runtime`.

The user then explicitly removed the tooltips as unnecessary, superseding a brief request for a shorter delay.
[0014](../../decisions/0014-omit-usage-limit-tooltips.md) records the final scope and tradeoff.

### Tooltip removal

The strip's `.help` call, tooltip-only environment dependencies, pure tooltip formatter, and seven tooltip-only
content tests were removed. The background-tooltip window setting was also removed.
Countdown, selection, provider filtering, stale color, account marker, and spoken summary remain.
No replacement details surface or public API is added.

The full suite after removal contained 170 tests. Its first run hit the same Claude version-probe timeout at line 99.
The review app was closed, and one full rerun passed all 170 tests in 27 suites with exit 0.
Logs: `/private/tmp/notch-pet-a5-no-tooltips-full.log` and `/private/tmp/notch-pet-a5-no-tooltips-rerun.log`.
The removed tests exercised only the deliberately removed tooltip API; all countdown/store/selection tests remain.
The build passed with `Build complete!` and `Info.plist: OK`; its log is
`/private/tmp/notch-pet-a5-no-tooltips-build.log`.
The final app launched with argument-only monitoring and external evidence under
`/private/tmp/notch-pet-a5-no-tooltips-runtime`.
The remaining runtime check uses `python3 /private/tmp/notch-pet-a5-review.py --timers-only`:
only the shared-folder timer pair and an idle Claude session are needed for the final check.
The user confirmed that `abc002` stayed at three seconds while `abc001` advanced.
The review app then quit normally, clearing the fictional sessions and removing the socket.
No native or custom tooltip remains in the strip.

### Active-provider filtering

The user then required each provider to disappear when none of its sessions is active.
Under [0015](../../decisions/0015-show-limits-only-for-active-providers.md), Unknown and Ended sessions no longer
keep a provider visible; idle, working, waiting, and response-ready sessions still count.
This shared filter also stops Codex reads when no observed active Codex session remains.
Cards and retained notices are unchanged.

The focused regression baseline failed before the fix with 17 expectation issues.
The first full run after the fix hit the known Claude probe timeout at `IntegrationHealthTests.swift:103`:
`.unavailable(.timedOut)` instead of `.unverified("99.0.0")`.
One full rerun passed all 171 tests in 27 suites, and the final app build passed.
The new tests cover each provider independently, all active/inactive states, and mixed-provider lists.
Logs: `/private/tmp/notch-pet-a5-active-providers-red.log`, `/private/tmp/notch-pet-a5-active-providers-full.log`,
`/private/tmp/notch-pet-a5-active-providers-rerun.log`, and `/private/tmp/notch-pet-a5-active-providers-build.log`.
The app stayed closed after this pure filtering change; no further visual pass or capture ran.

No agent-initiated capture or capture-permission request ran. User screenshots and real quota/account values remain outside the repository.
The temporary script's `--end` action targets only its seven fictional session IDs.

## Tasks

- [x] A1: Add pure strip presentation: pick the 5-hour window or the weekly fallback per provider, percent left rounded down, its color level, and the stale, missing, and unverified states; presentation tests cover each case.
- [x] A2: Add countdown text (`3h45m`, `4d22h`); presentation tests cover missing, expired, extreme, and unit-boundary resets. The original tooltip portion was removed under 0014; its earlier verification remains above.
- [x] A3: Add the Claude and Codex logo files to the app's resources with their sources recorded; the build passes and the packaged app contains both files.
- [x] A4: Show the strip left of the notch in the expanded top row with logos, keep the collapsed paw and count, and remove the old limits sections; the build passes. Hover details were removed under 0014.
- [x] A5: Verify the strip in the real app with a real Codex reading and Claude's empty state; the user reviews it with session-cards C5.
