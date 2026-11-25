---
summary: A white lionhead rabbit docks in the island, comes out onto the desktop when dragged, and reacts to agent sessions.
---

# The pet

## How it works

Bunlet ships an original white lionhead rabbit as its default pet. The pet lives in the island. Dragging the closed
pill down more than 50 points, or choosing **Show Pet**, brings it out onto the desktop and hides the island. Dragging
the pet back over the island, or choosing **Return Pet**, docks it again and shows the island
([0020](../../decisions/0020-one-app-with-pet-mode.md)). The pet takes the pointer only where its artwork is opaque.

`PetSessionAdapter` turns session snapshots into a mood: idle, working, attention, response ready, unknown or ended.
Each mood picks a pose from the artwork's seven rows: idle, play, sleep, running, attention, complete and drag. A
response-ready cue plays once per finished response. A text badge spells out attention, unknown and ended, so the
meaning survives artwork that has only an idle frame.

Settings sets the pet's size from 50% to 150%. Bunlet saves the size, the selected artwork, the sound choice and the
desktop position. The position is stored per display as a normalized origin, and is clamped back on screen after
display changes, wake and Space changes.

## Requirements

- A single idle frame is enough. A missing optional pose falls back to a visible one.
- Hidden or sleeping surfaces stop animation. Reduce Motion shows a stable pose.
- Showing the pet never takes keyboard focus.
- "Complete" means response ready, never that the task succeeded.
- The `Pet` module imports no session or event types. The app owns the adapter.

## Out of scope

- Custom artwork: [custom-artwork](custom-artwork.md).

## Open work

- Check on screen: dragging out and back, Show and Return Pet, display changes, sleep and wake, and Spaces.
- Check on screen: every mood, the once-per-response cue, Reduce Motion and hidden or asleep playback.
- Measure the animated pet's CPU and memory ([resource-efficiency](../notch/resource-efficiency.md)).

## Decisions

[0006](../../decisions/0006-import-asset-only-pet-packs.md) asset-only packs,
[0020](../../decisions/0020-one-app-with-pet-mode.md) one app with a pet mode,
[pet workflow contract](../../contracts/pet-workflows.md) limits and fallbacks.
