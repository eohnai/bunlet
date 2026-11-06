# Sprite-sheet import

Status: implementation merged in PR #16; feature acceptance remains deferred.


Merged evidence: [full MVP handoff](../notch-companion.md#merged-mvp-handoff-2026-11-06). Hosted build/package, existing tests and
coverage checks passed at `ab2ae13`. This is not feature-specific native/provider acceptance;
historical results and unrun acceptance checkboxes retain their original meaning.

## Decisions

- **Normalize sheets at import (accepted scope 2026-11-06; implementation choice):** the user requested the custom-pet workflow, accepted offline customization and excluded AI. Convert the sheet into decision 0006's existing manifest/PNG frames; a second runtime loader adds no user capability here. This settles the earlier proposed P5 direction for this requested source change, without claiming P5/P6 acceptance checks ran.
- **My calls:** inspect every alpha pixel, accept transparent trailing padding, reject leading/interior gaps before visible cells. Empty optional rows use idle; empty idle is invalid. Default timing is 150ms per frame for every supplied row.

## Input contract

A ready-made single-image alpha PNG has exactly seven equal-height rows in this order:
idle, play, sleep, running, attention, complete, drag. Cells are square; width must contain a whole
number of cells. Cell size 1–1024px, 1–64 columns, width/height at most 8192px, total decoded RGBA
at most 32 MiB and encoded input at most 16 MiB. Output retains at most 128 nonempty frames and
must also satisfy every manifest/frame pack bound (2 MiB/frame; 16 MiB encoded and 32 MiB decoded).

The importer reads only the explicitly selected file, slices the seven rows, writes normalized PNGs
and a manifest to the existing private staging transaction, then saves selection only after success.
It does not consume Flux source, scripts or artwork. User-authored compatible image geometry is data.
Do not add the external AI workflow, generation prompts, subscription linking or model dependencies.

## Deferred acceptance

- [ ] Inspect row ordering, square-cell geometry, frame timing, alpha padding and optional fallbacks.
- [ ] Inspect gaps, empty idle, oversized/corrupt PNG, cancellation and selected-pet rollback.
- [ ] Inspect native import/selection and persisted playback using independently supplied artwork.

Original P5/P6/P8 checkbox/evidence history stays in the source spec. All checks remain NOT RUN.

Source path: PetLibraryView → PetLibraryModel chooser/worker → PetPackLibrary input adapter → bounded converter → private staged pack install → saved selection → existing panel/preview playback. Native interaction remains NOT RUN; hosted build/test evidence is recorded above.
