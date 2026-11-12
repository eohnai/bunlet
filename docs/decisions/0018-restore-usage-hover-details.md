# 0018: Restore usage hover details as an immediate popover

- Status: accepted
- Date: 2026-11-12
- Supersedes: [0014](0014-omit-usage-limit-tooltips.md)

## Context

Decision 0014 removed the usage strip's native tooltips because their delay was confusing.
Under [0017](0017-match-flux-island-ui.md) the island matches Flux Island, whose usage cells show hover details.
Flux draws its own hover popup instead of relying on the system tooltip.

## Options

- **Keep no hover details:** keeps 0014; the usage row differs from Flux.
- **Restore native tooltips:** matches Flux's content; reintroduces the delay the user rejected.
- **Show an immediate custom popover:** matches Flux and avoids the native delay.

## Decision

Show usage details in a custom popover that appears on hover over a usage cell, without the native tooltip delay.
It shows every reported window, its percentage left and reset time, and freshness.

## Reasoning

The user chose to match Flux. The original complaint was the native delay, which a custom popover avoids.

## Consequences

Missing data must not read as zero remaining, and stale data must say stale ([D6](../DECISIONS.md#d6-show-allowance-as-percent-left-not-percent-used)).
Hover never takes keyboard focus or activates the app.
