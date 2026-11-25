---
summary: Users replace the rabbit with a pet pack, an animated PNG or a sprite sheet, all converted offline into one pack format.
---

# Custom pet artwork

## How it works

Settings offers three imports. Each produces the same pack format ([0006](../../decisions/0006-import-asset-only-pet-packs.md)):
a `manifest.json` with named PNG frames. Packs hold data only, never executable code.

- **Import Pet Pack** loads a folder with `manifest.json` and its frames.
- **Animate PNG** turns one transparent PNG into six 256-pixel frames for each of the seven poses, 150 ms per frame,
  using only translation, rotation and scaling of the original pixels. The PNG must have alpha, visible content and some
  transparency. It can be at most 2 MiB encoded, 1 to 1,024 pixels per side, and 4 MiB decoded.
- **Import Sprite Sheet** slices a PNG with exactly seven equal-height rows (idle, play, sleep, running, attention,
  complete, drag) of square cells. Transparent trailing padding is allowed, but gaps before visible cells are rejected.
  An empty optional row falls back to idle, and an empty idle row is invalid. Cells are 1 to 1,024 pixels, with up to 64
  columns, the sheet is at most 8,192 pixels per side, 16 MiB encoded and 32 MiB decoded, and the result keeps at most
  128 frames.

All three go through `PetLibraryModel` and `PetPackLibrary`: guarded reads, private staging in Application Support,
validation, an exclusive rename, then a saved selection. One import runs at a time and can be cancelled.

## Requirements

- An invalid, cancelled or failed import never changes the selected pet. The built-in rabbit is always recoverable.
- Each frame is at most 2 MiB. A pack is at most 16 MiB encoded and 32 MiB decoded.
- Imported files stay in Application Support, outside the repository.
- No AI generation, prompts, accounts or network requests.

## Open work

- Check on screen: each import with real artwork, including frame bounds, transparent edges and timing.
- Check invalid, opaque, empty and oversized input, cancellation, and restart with a saved selection.

## Decisions

[0006](../../decisions/0006-import-asset-only-pet-packs.md),
[pet workflow contract](../../contracts/pet-workflows.md).
