# 0021: Build a personal subset of Flux Island's settings

- Status: accepted
- Date: 2026-11-12

## Context

The user supplied Flux Island's General, Agents and Display settings pages and asked for Bunlet's Settings to match.
Flux also has Sound, Feishu, Shortcuts, Remote SSH, Mine, Statistics, About and Contact pages.
Asked which to build for a personal app, the user approved this recommendation.

## Decision

Build General, Agents, Display, Sound, Shortcuts and About pages in Flux's layout:

- **General:** launch at login; open on session end (default off); open when action is needed (default on);
  focus-aware suppression, approximated as "the session's terminal app is frontmost"; haptic feedback on hover;
  reminder duration; panel maximum height; remove all Bunlet hook configuration.
- **Agents:** one row per supported agent with a status dot and word; the switch connects or disconnects after confirmation.
- **Display:** island screen (main display or follow the active app); pet size; custom pet folder and import; top-row items.
- **Sound:** on/off, volume and per-event switches using system sounds.
- **Shortcuts:** fixed global keys, each with an on/off switch: ⌃I toggle island, Esc collapse, ⌃Y approve, ⌃N deny,
  ⌃↩ jump to terminal.
- **About:** version only.

Not built: Language (English only), idle-session auto-clean (it would treat silence as completion), Feishu, Remote SSH,
Mine, Statistics, Contact, custom key recording, and Flux's own sounds.

## Reasoning

These are the settings that change daily use of a single-user notch companion at low maintenance cost.

## Consequences

Launch at login uses the system login-item service. Shortcuts use system hot keys that need no extra permission.
Haptics use the trackpad feedback API. Settings keep native controls and Bunlet's existing persistence in UserDefaults.
