# 0014: Omit usage-limit tooltips from the notch

- Status: accepted
- Date: 2026-11-02

## Context

The expanded notch shows one compact usage-limit window per active provider.
Native hover tooltips exposed other windows, exact reset times, and source/account details.
The user confirmed both tooltips appeared after enabling inactive-app tooltips, but found the delay confusing.
They then explicitly requested removing the tooltips as unnecessary.

## Options

- **Keep hover details:** exposes all reported windows and diagnostics, but adds a delayed interaction the user does not want.
- **Remove hover details:** keeps the compact strip and removes the tooltip interaction and formatter.

## Decision

Remove the notch's usage-limit tooltips. Keep the selected-window percentage, reset countdown,
missing-value placeholder, stale color, and account marker.
Use "usage limits" in user-facing text. This replaces the allowance-strip tooltip choices from earlier in the review.

## Reasoning

The user found the tooltips unnecessary and chose removal after seeing their contents and delay.

## Consequences

The notch no longer exposes both windows together, exact reset timestamps, or detailed source/failure messages.
No replacement details view or custom hover popup is included.
Usage stores and providers still retain their full observations and existing freshness/account rules.
Provider eligibility and real-session setup remain unchanged.
The related usage specifications retain their data and integration obligations; their notch display follows this reduced scope.
