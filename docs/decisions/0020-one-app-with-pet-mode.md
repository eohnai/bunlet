# 0020: One app with the pet as a mode of the island

- Status: accepted
- Date: 2026-11-12
- Supersedes: [D7](../DECISIONS.md#d7-install-and-uninstall-features-from-settings) and
  [0013](0013-separate-standalone-pet-scope.md)

## Context

D7 let users install and uninstall Pet, Notch and Agents in Settings, and 0013 made the pet usable on its own.
After matching Flux Island's UI under [0017](0017-match-flux-island-ui.md), the user decided on 2026-11-12 that
the pet does not need to be a separate thing and should follow Flux: the island and agent services always run,
and the pet is a mode you enter by dragging it out of the island.

## Options

- **Keep installable features:** pet-only use stays possible; keeps a Features page and lifecycle code Flux does not have.
- **One app, pet as a mode:** matches Flux; removes the feature manager and its lifecycle states.
- **One app, agents optional:** a middle ground the user did not choose.

## Decision

Remove feature installation. Bunlet always runs the island and agent services. The pet is part of the app,
but Bunlet ships no pet of its own: the user chooses their own image (a PNG that Bunlet animates, a seven-row
sprite sheet, or a pet pack). Until they do, there is no pet. Once chosen, the pet
docks inside the island and comes out by dragging the pill down or with Show Pet; pet mode hides the island.
Agent tracking still needs per-provider Connect and per-provider monitoring consent.

## Reasoning

The user wants one app that behaves like Flux Island for personal use.

## Consequences

The Features page and `FeatureSettingsModel` install state are removed; every runtime starts at launch.
The built-in white lionhead rabbit artwork is removed from the app; an earlier "built-in" selection becomes "no pet". A saved feature choice is ignored,
not deleted. Pet-only startup without agent services is no longer supported. Connecting a provider still never happens
without the user's confirmation, and removing hooks keeps its existing contract. Earlier feature-management specs
(settings/feature-management, FM1–FM7) describe superseded behavior and are not resumed.
