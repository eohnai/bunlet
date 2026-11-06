# Desktop movement and return

Status: source implementation present under the approved full MVP task list; acceptance unverified.

Native PetPanelController supports alpha-limited pointer drag, island hide/overlap-return and menu Return Pet. Placement restores by display identity and normalized origin, clamped for resize/display/wake/Spaces changes. Pet-only use has no Notch dependency; surface changes leave shared session/action state intact.

The [pet workflow contract](../../contracts/pet-workflows.md) fixes the resource limits, fallback and failure rules before coding. Source obligations are P1–P4/P7 and the relevant P8/R1–R4 portions from the source specification. Preserve original checkboxes and historical evidence. No tests/builds/native checks are requested during this run.

Source path: `PetDragView` alpha hit test and mouse-motion pass-through → native drag → app island hide callback → drop/Return Pet → clamped panel and retained Notch view. PetPreferences saves normalized placement; screen/wake/Space notifications restore it. Menu and Settings expose Return Pet. Native interaction and physical display acceptance remain NOT RUN.
