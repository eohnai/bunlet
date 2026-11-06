# Local animation from a PNG

Status: source implementation present; verification NOT RUN at the user's request.

## Scope and decisions

- **Local-only customization (accepted 2026-11-06):** the user accepted the offline animation/sprite import recommendation and explicitly excluded the AI workflow. No AI SDK, login, generation prompt, hosted request, paid turn or copied company code/assets is part of this change.
- **My calls:** normalize an ordinary transparent PNG into 256px frames, six frames per pose and 150ms per frame. Fit the visible subject with transparent margins; use only translation, rotation and scaling. This keeps the existing manifest/frame runtime and stays within pack limits. These transforms do not invent new poses or remove a background.

## Contract

Settings offers Animate PNG separately from Import Sprite Sheet and Import Pet Pack. An ordinary image
must be a single-image PNG with alpha, visible content and some transparency, at most 2 MiB encoded,
1–1024px per axis and 4 MiB decoded RGBA. Reject opaque/empty input with useful recovery guidance.
Produce six frames for each of idle/play/sleep/running/attention/complete/drag using the original pixels.
Generated frames are asset data, not executable code. Existing mood/pose selection, hidden/asleep
playback cancellation, Reduce Motion and textual attention/unknown/ended labels remain authoritative.
No new lifecycle event is emitted and visual complete still means response ready, never task success.

The file chooser and cancellable worker share PetLibraryModel's one-operation limit. Guarded descriptor
reads, PNG bounds, private staging, validation, exclusive rename, preference save and rollback all use
the same PetPackLibrary path as folder imports. The source file and selected pet survive failed/cancelled
conversion. A completed copy may remain unselected if cancellation/save failure follows rename.

## Deferred acceptance

- [ ] Inspect actual PNG conversion, original subject identity, frame bounds and transparent edges.
- [ ] Inspect all supplied poses, hidden/asleep scheduling and Reduce Motion in the native app.
- [ ] Inspect invalid/opaque/empty/oversized input, cancellation, saved selection and restart recovery.

No tests, builds, helper/app launches, source image generation or captures are authorized by this task.

Source path: PetLibraryView → PetLibraryModel chooser/worker → PetPackLibrary input adapter → bounded converter → private staged pack install → saved selection → existing panel/preview playback. Tests/builds/native interaction remain NOT RUN.
