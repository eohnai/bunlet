# Pet workflows implementation policy

Selected under the approved full nine-area MVP goal on 2026-11-06. Source implementation only;
tests, builds, native interaction, captures and resource measurement remain NOT RUN. This specifies
routine implementation choices within decisions 0006/0013 and the accepted drag/overlap workflow.

## Reactions

The app translates shared SessionStore snapshots into pet-owned moods; Pet imports no agent types.
Confirmed pending notices take priority, then unknown/unconfirmed notices, working, response ready,
observed ended and ordinary idle. Every mood has visible text/symbol even when optional art falls back
to idle. Drag changes art only when it does not hide attention or unknown state. No silence implies end.
Master/provider pause retains unknown notices; uninstalling Agents retains their observation state.

A completion cue means only an observed finished response. It requires a newly observed response-ready
identity (agent/session/turn/first Stop time) with SessionStore’s accepted submit baseline. Existing ready records
at adapter startup/reinstallation do not cue. Deduplication is app-lifetime, at most 4096 identities;
saturation suppresses further cues. Hidden/asleep/disabled pets consume without replay. Cues last two
seconds, use optional complete art (idle fallback) and at most one system Glass sound if enabled.
Reduce Motion retains text and a stable frame. No event or action is sent by the adapter.

## Movement and return

Pet works on the desktop without Notch or Agents. Pointer hits are limited to the rendered art's alpha
and the visible status badge; transparent padding passes through. Left drag uses native screen coordinates
and never activates the app. The first drag movement hides installed Notch without destroying its view,
selection, drafts or retained notices. Dropping over the collapsed island return rectangle restores
Notch and places Pet beside/below it. Return Pet in the menu does the same; without Notch it restores
a clamped desktop position. Show Notch explicitly restores the island while leaving Pet usable.

Save display identity and normalized x/y within the display's visible frame, plus detached state and size.
Use NSScreenNumber display identity, never absolute global coordinates. Missing displays fall back to main;
invalid data falls back to lower right. Clamp size/origin after resize/display/wake/Space changes.
Use supported canJoinAllSpaces/fullScreenAuxiliary behavior. Sleep/hidden state cancels animation and
suppresses sounds; waking restores state without replaying cues. Screen-reader tests remain excluded.

## Asset packs

Version 1 JSON manifest uses name (1–80 UTF-8 bytes) and animations keyed by the seven PetPose names.
Each animation has frames (simple ASCII basename without extension, PNG files in the same directory)
and frameDurationMs (40–10000). Idle is required; optional missing poses fall back to idle.
Imported output contains no scripts, links, nested paths, atlases, archives or executable plugins.
Only manifest-referenced PNGs are read/copied; other source-folder files are ignored. The later local-only request adds sheet conversion and ordinary PNG transform animation; see the
[PNG animation](../specs/pets/local-png-animation.md) and [sheet import](../specs/pets/sprite-sheet-import.md) contracts. Bounds: manifest 64 KiB; 64 frames/pose, 128 unique PNGs;
each PNG 2 MiB, 16 MiB total encoded; dimensions 1–1024 per axis, equal across all frames;
32 MiB total decoded RGBA. Require single-image PNG with alpha and successful bounded decode.
Import copies only validated bytes into a private staged Application Support directory, revalidates,
then atomically renames with exclusive-destination semantics to an app-generated UUID directory.
Listing scans at most 256 entries and offers at most 32 valid pack records. Temporary/unrecognized
entries are never selected. Cancellation or a save failure after rename may leave a valid unselected
copy; the active selection and prior assets remain unchanged. No automatic pack deletion occurs. Selection changes only after successful
import and preference save. Invalid/cancelled import leaves current selection and assets intact.
Saved selection stores only generated UUID, never a source path; missing/invalid assets show built-in
fallback while preserving the saved preference and offering explicit recovery. Small selection, size,
sound and screen-relative placement preferences use UserDefaults. No pack or session data enters Git.

## Source provenance

Use original implementation, existing repository code and public documentation only. Do not import
company source, internal libraries, proprietary snippets or company-only dependencies (user instruction,
2026-11-06). This applies to the full MVP, including provider and terminal adapters.


Example custom pack (`manifest.json`, plus `idle-1.png` in the same folder):

```json
{"version":1,"name":"My pet","animations":{"idle":{"frames":["idle-1"],"frameDurationMs":150}}}
```

The loader rejects unsupported manifest keys/poses, non-ASCII frame basenames and mismatched frame
sizes. It validates PNG type, count, alpha and dimensions before bounded decoding; all frames in a
pack share dimensions. Imported frames are immutable in-memory bytes during playback, with a bounded
32 MiB/128-entry decoded image cache. Selecting a saved pack revalidates its assets. Failed selection
retains the active pet. A missing/invalid startup selection temporarily falls back to bundled artwork
and keeps its saved ID; explicit Use Built-in Pet resets it even if pack storage is unavailable.


## Local-only extension, 2026-11-06

The user accepted offline PNG animation and sprite-sheet import and excluded the AI workflow.
Both normalize into the existing asset-only pack transaction; no new runtime format, dependency,
provider authentication, model call or generation prompt. The full MVP goal was paused while this choice was discussed. The user resumed it during
implementation; after this coherent customization milestone, navigation and final handoff remain.

PNG source memory bounds account conservatively for 8/16-bit channels before ImageIO decode. Canonical
RGBA and generated outputs use 8-bit channels; opaque/empty ordinary PNGs are rejected. No background
removal or new-pose synthesis is implied by local transforms.
