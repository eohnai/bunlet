# 0019: Accept newer provider versions within the same major version

- Status: accepted
- Date: 2026-11-06

## Context

Connect accepted one exact documented version per provider: Claude Code `2.1.306` and Codex `0.164.0`.
The user tried Connect with Claude Code `2.1.319` and Codex `0.166.0`. Both were refused with
"This … version has no documented setup binding," and no session was tracked.
The [Codex setup spec](../specs/sessions/codex-setup.md) rejected a minimum-version range on 2026-10-30
because version-specific evidence was incomplete.

## Options

- **Exact versions only (current):** each accepted version has documented evidence. Connect fails after every provider release until someone adds the new version.
- **Add each new version to the list by hand:** keeps the exact-match rule. It breaks again with the next release.
- **Documented version or newer, same major version:** Connect works on current releases. A newer release can change the hook format without Bunlet knowing.

## Decision

Connect accepts the documented version or any newer release with the same major version.
The major version is the first number, for example the `2` in `2.1.319`.

## Reasoning

The user wants Connect to work with the versions they have installed.
An exact list stops working within days, because both providers release often. ^[inferred]

## Consequences

- Connect, Repair and the install transaction use the same rule, through `ProviderHookPolicy.supportsDocumented`.
- Check still labels a version other than the recorded ones as unverified. A newer version is accepted, not proven.
- If a newer release breaks the hooks, Check and the observed-delivery evidence must show it. Revisit this rule if that happens.
- A new major version, or an older version, is still refused.
- Runtime qualification of exact Codex releases stays a separate, empty registry.
