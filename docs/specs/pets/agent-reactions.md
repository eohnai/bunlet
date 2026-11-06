# Optional agent reactions

Status: source implementation present under the approved full MVP task list; acceptance unverified.

App-owned PetSessionAdapter observes authoritative shared snapshots, selecting pet-owned moods and bounded one-shot response-ready cues. Native status text preserves attention/unknown/ended even with idle-only artwork. Requires Pet; Agents and its monitoring are optional. Notch/navigation metadata are not required.

The [pet workflow contract](../../contracts/pet-workflows.md) fixes the resource limits, fallback and failure rules before coding. Source obligations are P1–P4/P7 and the relevant P8/R1–R4 portions from the source specification. Preserve original checkboxes and historical evidence. No tests/builds/native checks are requested during this run.

Source path: `PetSessionAdapter` → `PetPanelController.setReaction` → pet-owned mood/pose and native status badge. Response identities are bounded/deduplicated; hidden/asleep/absent Pet consumes cues without replay. No provider I/O or lifecycle mutation.
