# Asset-only custom packs

Status: implementation merged in PR #16; feature acceptance remains deferred.

Merged evidence: [full MVP handoff](../notch-companion.md#merged-mvp-handoff-2026-11-06). Hosted build/package, existing tests and
coverage checks passed at `ab2ae13`. This is not feature-specific native/provider acceptance;
historical results and unrun acceptance checkboxes retain their original meaning.

Implement decision 0006 manifest/PNG imports, safe private staging, selection rollback and saved preferences. No executable plugins. The later local-only request adds the separate PNG/sheet input features linked below. Settings must expose import, selection and built-in recovery.

The [pet workflow contract](../../contracts/pet-workflows.md) fixes the resource limits, fallback and failure rules before coding. Source obligations are P1–P4/P7 and the relevant P8/R1–R4 portions from the source specification. Preserve original checkboxes and historical evidence. No tests/builds/native checks are requested during this run.


Source: `PetLibraryView` → app-owned `PetLibraryModel` → detached `PetPackLibrary` worker →
`PetPackDirectory` guarded reads/staging → manifest/PNG validation → exclusive rename → saved selection
→ `PetPanelController.setArtwork` and Settings preview. Invalid/cancelled input cannot switch selection;
built-in recovery does not depend on the pack directory. UserDefaults retains generated pack ID, size,
sound and normalized placement; imported bytes remain in private Application Support. Sheet conversion is now selected and has a source path; its original P5/P6 acceptance remains unverified. Native/provider acceptance remains NOT RUN; hosted build/test evidence is recorded above; original P3/P4/P7/P8
checkboxes are preserved.

Additional local inputs: [ordinary PNG animation](local-png-animation.md) and [sprite sheets](sprite-sheet-import.md). Both reuse this persistence and selection contract.
