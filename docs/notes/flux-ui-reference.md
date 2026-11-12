# Flux Island UI reference

Date: 2026-11-12

This note makes Flux Island's visible UI reproducible without the installed app.
It supports [decision 0017](../decisions/0017-match-flux-island-ui.md): Bunlet matches Flux's look while keeping its own behavior.
For Flux's architecture and provider behavior, see [Flux adoption](flux-island-adoption.md).

## Source

- Installed `/Applications/Flux Island.app`, version 0.1.25, `app.asar` SHA-256
  `25bf9e27fb025668d193f8323b5151bfbc37d62b2bd87bae8101cabf41f8e758` (unchanged since 2026-10-28).
- Read from the bundled renderer: `out/renderer/assets/island-DH0GYq24.js` (window and triggers),
  `island-DzP_CVFS.js` (pill and shape), `IslandPanel-DSRHjja3.js` (panel, rows, cards),
  `island-De4B4VoU.css` and `IslandPanel-CgVhWn8Q.css` (styles). Line numbers drift between versions; component names are stable.
- The source repository (`cloud-fe/flux-desktop`) is not readable by the user's account. No access was requested.
- No Flux file is a build input. Its artwork, agent logo PNGs, ByteSans font and sounds are not copied (0017).

Values below are CSS pixels, which equal macOS points. Colors are given as Flux writes them.

## Palette and type

| Use | Value |
| --- | --- |
| Island fill | `#000` |
| Primary text | `#FFFFFF` or `rgba(255,255,255,0.9)` |
| Secondary text | `#D1D3DB` |
| Muted text and chips | `#9599A6` |
| Dim text (replies) | `#666B75`; activity `#646B77` |
| Chip background | `rgba(224,230,242,0.06)` |
| Card border | `1px rgba(224,226,242,0.16)` |
| Card fill | `rgba(224,230,242,0.04)`; card header `rgba(221,230,244,0.04)` with `1px rgba(224,226,242,0.1)` bottom border |
| Divider | `1px rgba(255,255,255,0.07)`, inset 18 |
| Attention label | `#FFD60A` |
| Completed label/badge | `#42E86B`; badge fill `rgba(66,232,107,0.12)` |
| Usage level | ≥80% used `#FF304B`, ≥50% `#FFC224`, else `#00F873` |
| Link | `#387BFF` |

Type is the system font (SF Pro Text), antialiased, with monospace (SF Mono) for tool names and code.
Common sizes: 13 semibold titles, 13 medium session titles, 12 for nearly everything else, 11 tooltips, 10 small badges.

Provider badge text/background colors: Claude `#DA7250`, Codex `#8EA1FF`; background is the same color at 16% opacity.

## Island window and shape

- One transparent window, 740 wide × 750 tall, centered under the notch. Pointer events pass through everywhere except the black shape.
- The shape is drawn by a clip path: a flat top that **flares outward** at both top corners (concave top radius),
  straight sides, and convex bottom corners.
  - Closed (pill): top radius 8, bottom radius 10, height = notch height (or menu bar height, else 24).
  - Open (panel): top radius 24, bottom radius 18, top inset 8, height = content height, at least notch height + 40.
  - The outer width is body width + 2 × min(top radius, bottom radius); the flare sits outside the body width.
- A strip as tall as the top radius and as wide as the outer shape sits behind the top edge so the shape joins the screen edge.
- Shadow: closed has a 1 px hairline `rgba(255,255,255,0.1)`; open has `0 8 8 rgba(0,0,0,0.35)`. Shadow changes over 0.3 s ease-out.

### Widths

- Notch width = the physical cutout width, or 126 without a notch.
- Pill body width = max(notch width, 126) + extra, capped at window width minus the flare:
  - With a notch: extra 72 when any session is visible, else 62.
  - Without a notch: idle 72; running 100; approval/question 108; completed 112.
- Panel body width = clamp(screen width × 0.46, 680, 740), capped the same way.
- Panel max height: default 540, user-adjustable 200–700. The window grows to max height + 32 for the shadow while open.

### Motion

- Open: clip path animates over 0.26 s, `cubic-bezier(0.32, 0.02, 0.2, 1)`. Close: 0.24 s ease-out.
- Pill and panel layers cross-fade over 0.15 s; the hidden layer takes no input.
- "Pop" on new attention: whole island scales 1 → 1.04 → 1 over 0.28 s from top center.
- The window shrinks back to pill size 0.3 s after a close starts.

## Pill (closed state)

Left to right, 10 padding, 6 gap, full height:

1. **Phase icon** 28×28: idle (app logo), running, approval (also used for questions), completed.
   The dominant phase across sessions wins in this order: approval, question, running, completed.
   The icon is also the drag handle (see below).
2. **Label**, only when the screen has **no** notch (a notched Mac shows icon and count only):
   - no sessions: the app name, right-aligned;
   - approval/question: "Please note" in `#FFD60A`;
   - completed: "N Completed" in `#42E86B`;
   - running: "You: {latest prompt}" from the most recently updated running session, else its current activity, else "In Progress".
   12 semibold, 90% white, one line with ellipsis.
3. **Count** at the right edge: number of visible sessions, 12 semibold, hidden when zero.

## Triggers

- Hovering the pill for **200 ms** opens the panel (reason: hover). Leaving the open island for **300 ms** closes it.
- Clicking the pill opens the panel (reason: click).
- Dragging the pill icon **down more than 50** px detaches the pet: the island hides and the pet follows the pointer.
- A notification (approval, question, completion) opens the panel focused on that session and pops.
  Completion notifications auto-close after the "completion popup" duration (a setting); attention notifications that
  can be dismissed close after the same duration; an open follow-up editor cancels auto-close.
- Keyboard shortcuts (global, default modifier Control): toggle island `I`, collapse `Esc`, approve `Y`, reject `N`, always allow `A`,
  plus next/previous session and "jump to session".
- Clicking a session row jumps to its terminal and collapses the panel.
- On launch Flux runs one quick open/close warm-up cycle.

## Panel (open state)

Column, clipped to the max height:

1. **Usage row** — height = notch height, 18 horizontal padding, so it sits beside the physical notch.
   - Left: one cell per provider with limit data, 12 gap, separated by a faint `|` (`rgba(224,226,242,0.25)`).
     Cell: 12×12 provider logo, then `{window} {pct}% {reset}` — 12 medium, 70% white, tabular digits; the percentage is colored by level.
   - Hovering a cell shows an **immediate** popup 4 below it: `rgba(40,40,40,0.96)`, 6 radius, 6×10 padding, 11 text,
     one line per window: "{window} used {pct}%, resets in {time}".
   - Right (12 gap): status icons (16×16 with a 6 px orange `#FF8C00` badge for a disconnected service), sound toggle,
     clear-sessions button (visible when sessions exist), settings button. Icon buttons are 16×16, 50% white, 6 radius, hover 85% white on 8% white.
2. **Divider.**
3. **Session list** — 16 padding, **24 gap between sessions**, vertical scroll with a 4 px thin scrollbar.
   Empty state: centered 40×40 app logo and "No sessions" (11, 90% white), 28×18 padding.
   Each session is a column (12 gap): session row, optional subagent list, then the actionable card or follow-up editor (8 gap).

### Session row

Row, 8 gap, 18 radius; the whole row is clickable.

- **Phase icon** 32×32 on the left (same four icons as the pill).
- **Body** (column, 2 gap):
  - **Headline** (space-between, 8 gap):
    - Left: provider badge (12 regular, 0×4 padding, 4 radius, provider color on 16% fill) and **title**
      (13 medium, white, one line, ellipsis — the project folder name).
    - Right meta (8 gap): remote badge when remote; **terminal app** chip; **elapsed** chip; "💬 Follow up" chip when allowed;
      delete button (hidden until row hover, 14×14, 30% white).
      Chips: 12 regular, `#9599A6` on `rgba(224,230,242,0.06)`, 0×4 padding, 4 radius, tabular digits for time.
  - **Prompt line**: "You: {latest prompt}" — 12, `#9599A6`, one line, ellipsis.
  - **Activity line**: current activity, else last assistant message — 12, `#646B77`, one line, ellipsis.
  - In the active (focused) row, prompt and activity lines brighten to `#D1D3DD`.
  - Paths under the session's working directory are shown relative to it.
- Elapsed format: `45s`, `3m`, `3m07s`, `1h`, `1h05m`. Flux measures from session creation and ticks each second until completed.

### Cards

All cards use the card border/fill from the palette. Headers are 5×8 padding with the header fill and divider.

- **Approval**: column, 10 gap. Box with a monospace tool-name header (12, `#D1D3DB`) and request details or a code diff.
  Button row (8 gap, equal widths, 5×6 padding, 4 radius, 12 medium):
  Deny `#D1D3DB` on 8% white · Allow `#0C0C0D` on `#DADDE5` · Always allow `#0C0C0D` on `#11BEF3` (only when offered) ·
  "Jump to terminal" `#F5F7FF` on 14% white for terminal-only requests. Each button shows its shortcut key in a small
  dimmed chip after the label.
- **Question**: column, 12 gap. Box with header "{n} questions" and title rows; options are 18 high with a radio/check mark,
  selected label `#D1D3DB`; optional custom-text field. Actions: Submit (fills, 24 high, 6 radius, black on `#D8DDE7`) and
  Cancel (80 wide, outlined, `#9599A6`).
- **Completion**: column, 8 gap. Box (6 radius) with a header "Completed" (12, `#D1D3DB`) and the prompt (42% white, ellipsis);
  content up to 200 high, scrolling, with the last assistant message rendered as Markdown (12/16, `#D1D3DB`).
  Optional green "Completed" badge. Actions reuse approval button styles with 6 radius (Follow up, Jump).
- **Plan confirmation**: 12 padding, 8 radius, 5% white fill; plan text and choices; Submit in indigo `rgba(99,102,241,0.9)`.
- **Follow-up editor**: borderless text area 40–76 high, `#EEEEEE` text, Cancel (12, `#9599A6`) and a send button;
  Escape cancels, Command-Return sends, errors stay visible.

## How Bunlet applies this

| Flux element | Bunlet |
| --- | --- |
| Window, shape, sizes, timings, colors, type | Same values, drawn with SwiftUI/AppKit |
| Phase icons, app logo, provider logos | Bunlet's own icons at the same sizes; the idle logo and menu bar icon are the SF Symbols hare |
| Pill label and count | Same, with Bunlet's app name |
| Usage percentage | Percent **left** ([D6](../DECISIONS.md#d6-show-allowance-as-percent-left-not-percent-used)); color levels mirror Flux's (≤20% left red, ≤50% yellow) |
| Usage hover popup | Same, per [0018](../decisions/0018-restore-usage-hover-details.md) |
| Prompt and activity lines | Short previews per [0019](../decisions/0019-show-prompt-and-reply-previews.md); activity shows the last reply |
| Elapsed chip | Bunlet's observed prompt-turn timer; unknown shows no timer |
| Status word | Unknown/ended states keep a visible word; Flux has no unknown phase |
| Session order and visibility | Bunlet's rules: confirmed requests first; ended and unknown stay visible |
| Approval/question buttons | Only for verified local channels (Claude); otherwise the card shows "Jump to terminal" guidance |
| Always allow, plan confirmation | Omitted until a verified channel exists |
| Follow-up | Claude Stop-hook reply window only; never typed into a terminal |
| Subagents, remote badge, token totals, update tag, sound, SSH/cloud status | Omitted (no Bunlet data) |
| Shortcuts | Esc collapses; other global shortcuts are separate work |
| Drag pill down to detach pet | Same 50-point threshold when Pet is installed; the pet follows the pointer and the island hides. Releasing over the pill docks it: the pet window hides and the island returns. Show Pet brings it back to its last desktop spot. Without Notch the pet always stays on the desktop |
| Warm-up open/close on launch | Omitted |

## Settings window

Source: the bundled settings renderer plus three screenshots the user supplied on 2026-11-12 (General, Agents, Display, dark mode).

- **Window:** two columns, about 1350×1040 in the screenshots, standard traffic-light buttons over the sidebar.
- **Sidebar:** 220 wide, `rgba(40,40,44,0.95)` with a 1 px right border at 10% white. Items are an emoji icon and a 13-point
  label (85% white); the selected item is a full-width rounded rectangle (about 10 radius) filled with the system blue, white text;
  hover 8% white. Sections: an untitled group (General ⚙️, Agents 🤖, Display 🖥️, Sound 🔊, Feishu 📨), "ADVANCED"
  (Shortcuts ⌨️, Remote SSH 🌐) and "FLUX" (Mine 👤, Statistics 📊, About ℹ️ with a blue "Update" capsule, Contact 💬).
  Section headers are 11 semibold uppercase at 40% white with letter spacing.
- **Content:** `#1E1E22`. Page title 22 bold (renders large, about 30 pt in the screenshots), 85% white, 16 below.
  Each group has a gray heading (about 15 semibold, 55% white) and a card: `#2C2C30`-like fill, about 12 radius, rows of
  title (13–15 regular, white) with an optional gray subtitle, trailing control, and inset 1 px dividers.
- **Controls:** large blue switches; pop-up menus with a rounded dark field and chevron; a slider with a percentage on the right;
  inline blue links ("Modify", "Open folder").
- **General:** System (Launch at login; Language). Behavior (Expand panel when a session ends — "Auto-expand panel to show results when
  task completes", default off; Expand when action is needed, default on; Focus-aware suppression — "Agent does not automatically expand
  when the terminal tab is in the foreground", on; Haptic feedback on hover, on; collapse on mouse leave; reminder duration, with Esc to
  close early). Visibility (always hidden; hide in fullscreen). Sessions (idle auto-clean, 30 min–7 days; panel max height 200–700).
  A destructive "Remove all automatic configuration".
- **Agents:** heading "CLI Hooks"; one row per agent: name, green dot and "Active" (or gray "Disabled"), optional gray hint, switch.
- **Display:** "Island Location" (Display preference: Main display / Automatic, follow the frontmost app; current main display with
  Modify). "Desktop Pet" (Pet size slider 50–150%; customization with Open folder). "Top Info Items" (switches per item:
  Claude Code subscription, Codex subscription, token count, sound icon, SSH status, …).
- **Sound:** enable, smart mute during Feishu meetings, volume, session and interaction event groups, custom sound folder.
- **Shortcuts:** modifier key, global shortcuts (toggle panel, anywhere; arrows navigate, Enter jumps), panel shortcuts (collapse,
  approve, deny, always allow, jump, switch session), key recording, conflict warnings, restore defaults.

Bunlet builds the subset in [decision 0021](../decisions/0021-settings-scope.md) with native SwiftUI controls styled to these values,
an untitled group (General, Agents, Display, Sound), "ADVANCED" (Shortcuts) and "BUNLET" (About). There is no Features page
([0020](../decisions/0020-one-app-with-pet-mode.md)).

## Pet and pet panel

- Flux's pet is its own transparent window. A speech bubble above the pet shows a short colored status; clicking it toggles the panel.
- The panel is a separate window 400 wide, up to 400 tall, opening above the pet or below when there is no room.
  Fill `rgba(18,19,20,0.9)`, 1 px light border, shadow `0 16 48 rgba(0,0,0,0.35)`. It lists the same session rows and actionable
  cards as the island; clicking a row jumps to the terminal. Empty state: centered "No sessions" at 45% white.

Flux ships a default pet that users replace by dropping a same-named PNG into a folder. Bunlet ships none:
Display → Desktop Pet → Choose Image… (or a sprite sheet or pack) creates it. The pet is part of the app ([0020](../decisions/0020-one-app-with-pet-mode.md)): it docks in the island
and comes out by dragging the pill down or with Show Pet. Its bubble shows the existing mood label (attention yellow,
response ready green, unknown orange).
