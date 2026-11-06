# Optional agent reactions

Status: implementation merged in PR #16; feature acceptance remains deferred.

Merged evidence: [full MVP handoff](../notch-companion.md#merged-mvp-handoff-2026-11-06). Hosted build/package, existing tests and
coverage checks passed at `ab2ae13`. This is not feature-specific native/provider acceptance;
historical results and unrun acceptance checkboxes retain their original meaning.

App-owned PetSessionAdapter observes authoritative shared snapshots, selecting pet-owned moods and bounded one-shot response-ready cues. Native status text preserves attention/unknown/ended even with idle-only artwork. Requires Pet; Agents and its monitoring are optional. Notch/navigation metadata are not required.

The [pet workflow contract](../../contracts/pet-workflows.md) fixes the resource limits, fallback and failure rules before coding. Source obligations are P1–P4/P7 and the relevant P8/R1–R4 portions from the source specification. Preserve original checkboxes and historical evidence. No tests/builds/native checks are requested during this run.

Source path: `PetSessionAdapter` → `PetPanelController.setReaction` → pet-owned mood/pose and native status badge. Response identities are bounded/deduplicated; hidden/asleep/absent Pet consumes cues without replay. No provider I/O or lifecycle mutation.
