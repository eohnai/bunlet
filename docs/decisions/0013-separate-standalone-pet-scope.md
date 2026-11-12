# 0013: Use one app with an independent pet module

- Status: superseded by [0020](0020-one-app-with-pet-mode.md) on 2026-11-12
- Date: 2026-10-30

## Context

The user identified people who want a pet without agentic coding.
They asked whether the pet should be a separate service or project.
The earlier pet plan depends on notch session presentation. Pet rendering is not implemented.
The user wants to set up the pet first and show agent features when sessions are observed.

## Options

- **One app with an independent pet module:** use one installation and release path. Optional agent services need explicit ownership.
- **Two apps sharing a pet module:** give each audience a focused app. Maintain two release paths and coordinate integration.
- **Separate pet project or repository:** allow independent maintenance. Coordinate shared behavior across projects.
- **Separate background service:** let several apps control one pet. Add process communication and lifecycle recovery.

## Decision

Use one SwiftUI/AppKit app with an independent pet module and optional agent services.
The user approved this direction and separate standalone-pet and agent-reaction features on 2026-10-30.

Start with pet setup. Agent setup is optional and skippable.
Connect supported agents once through approved setup, then react automatically to received session events.
Do not require a manual mode switch for each session.
Settings offer Connect, Pause monitoring, and Disconnect through the owning integration features.

## Reasoning

The user wants the pet to work for people without coding agents.
They approved automatic session-driven features after optional setup, with one installation and release path.
Separate apps, a repository split, and a background service add coordination that this behavior does not require.

## Consequences

The pet module owns animation, assets, interaction, placement, and preferences without importing agent session types.
An optional adapter translates authoritative session snapshots into pet presentation.
The app owns agent service lifecycle. Pet-only use starts no agent or usage services and requires no hook configuration.

Show ordinary pet behavior when no observed sessions or unresolved notices require agent presentation.
Silence and expiry do not prove a session ended. Preserve unknown state and retained unconfirmed requests.
Pausing or disconnecting monitoring must not resolve requests or report a successful turn.
Installing hooks still needs explicit approval and must preserve existing configuration.

The standalone pet no longer depends on notch session presentation.
Agent reactions depend on the standalone pet and shared session presentation.
Keep existing pet/session requirements and historical task states during the feature split.
This accepts scope and packaging, not an implementation task list or a second app, service, or repository.
