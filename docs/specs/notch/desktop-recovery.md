---
summary: The island keeps its state across displays, Spaces, fullscreen and sleep, and follows native focus and keyboard rules.
---

# Desktop behavior and focus

## How it works

**Displays and sleep.** The app keeps one hosting view for the island across hiding, display changes, sleep and Spaces,
so selection, field focus and drafts survive. The header height, cutout width and frame update for the current display
without replacing the view. Bunlet prefers a display with a physical notch, then the previous display if it is still
connected, then the main display. The panel joins all Spaces and shows beside fullscreen apps unless **Hide in
fullscreen** is on. Sleep hides the panel and wake restores it. While the pet is out, the island stays hidden until the
pet returns.

**Focus and keyboard.** The island, pet and Settings use native SwiftUI controls, so Tab, Space and Return work as
usual. Only **Open Sessions** and **Respond** take focus. Incoming events never activate the app. Escape collapses the
island and returns focus to the previous app, but only while Bunlet owns focus. **Done Editing** ends editing without
changing the session or request.

**Pointer and motion.** The island's transparent corners pass clicks through, following its rounded shape, and a mouse
drag stays owned until mouse-up. The pet takes the pointer only where its artwork is opaque. Reduce Motion turns off
panel geometry transitions and frame animation. Hidden or sleeping surfaces cancel prompt and quota timers, while
monitoring keeps running.

## Requirements

- Automatic recovery never activates the app or takes focus.
- VoiceOver testing is excluded from acceptance at the user's request. Native labels stay in place.

## Open work

- Check on screen: adding and removing displays, size and cutout changes, fullscreen, Spaces, and sleep and wake.
- Check on screen: Tab, Space, Return and Escape, focus return, and keeping drafts and selection.
- Check on screen: transparent corner clicks, Reduce Motion, and hidden or asleep timers.
