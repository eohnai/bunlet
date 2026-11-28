# Interface direction

Bunlet's island matches the reference island's visible UI ([0017](../decisions/0017-match-reference-island-ui.md)).
[Reference UI](reference-ui.md) holds the exact values, and [reference adoption](reference-adoption.md#how-the-reference-works)
describes its behavior. Where Bunlet differs, it is to keep states truthful.

## Truthful states

- Every session state has a visible word, not only a color or icon. There is no unknown state.
- Missing quota never looks like zero remaining. A quota badge shows its last reading, and the popup says how old it is.
- Settings keeps four states apart for each agent: whether it is **on or paused**, whether its hooks are **connected**,
  what **health** checks show, and whether any session has been **seen**. A quiet agent is not "disconnected", and an
  empty session list is not a setup failure.
- A request shows only the actions its channel really supports, or terminal guidance.

## Layout and interaction

- Routine rows stay compact. Full paths, session IDs and refresh times sit behind the **⋯** chip.
- One clear primary action per request card.
- New events never take keyboard focus. Motion respects Reduce Motion.
- Settings follows a sidebar with clear page titles, grouped rows and short explanatory subtitles, using native macOS
  controls.

## Brand

The rabbit is the identity. The default pet is an original white lionhead rabbit. A simplified rabbit mark for the app
icon is a separate, undecided task. The user named REMME's Nemu-chan and the Palm Pals rabbit as visual inspiration for
a soft, plush-like look, not as names or artwork to copy.

## How to review UI changes

Use the Impeccable skill in its Operate mode: scanning, finishing the task, familiar controls and clear states come
before decoration. Check changes against Apple's Human Interface Guidelines for macOS. VoiceOver testing is excluded
from acceptance at the user's request, but native labels, keyboard controls, Reduce Motion and focus behavior stay.
