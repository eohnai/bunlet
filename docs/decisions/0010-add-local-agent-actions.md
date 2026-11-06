# 0010: Include local approvals and replies in the first release

Implementation addendum, 2026-11-06: the user requested full code implementation with tests,
builds and runtime qualification left unverified. Documented action bindings may be implemented
with an explicit unverified label; they do not become runtime-verified capabilities. See the
[local action contract](../contracts/local-actions-v1.md) for the initial Claude callback scope
and its bounded Stop-feedback follow-up limitation. The accepted local-action scope below is unchanged.

- Status: accepted
- Date: 2026-10-28

## Context

The original release scope sent the user back to Otty to approve or reply.
After reviewing Flux's interaction features, the user explicitly requested adding local approvals and replies
and keeping SSH/cloud support as optional future work.
The existing event helper and version-1 contract provide observations only; supported response paths remain unverified.

## Options

- **Keep the monitor-and-jump scope:** reuse the one-way event path; every approval or reply still requires returning to Otty.
- **Include local agent actions:** let the user handle supported requests and replies in the app; requires agent-specific response channels, acknowledgement, and cancellation handling.
- **Include remote integrations now:** cover SSH/cloud workflows too; adds remote identity, connection, API, and authentication work to release acceptance.

## Decision

Include local approve-once/deny decisions, structured-question answers, and explicitly submitted follow-up replies.
Expose only verified per-agent/version capabilities and preserve Otty navigation for unavailable actions.
Record SSH/cloud integrations as optional future work, with no first-release dependency.
The user accepted this scope; a response-channel design and detailed implementation are not yet accepted or verified.

## Reasoning

The conversation selected handling local requests directly in the app as useful functionality.
The user explicitly described SSH/cloud support as potential future work and optional.

## Consequences

Retain SwiftUI/AppKit, shared authoritative state, and conservative observation meanings.
Decisions 0004/0005 continue to govern lifecycle observation; the historical version-1 observation contract and silent bounded helper remain unchanged.
Specify separate action capabilities, target identities, bounds, acknowledgements, timeout/cancellation, and ambiguous-delivery rules before implementation.
Necessary request details and user replies are transient action data, outside the version-1 observation allowlist and routine logs.
Verify support in existing local sessions; lifecycle hooks alone do not establish action support.
The spec's A1–A8 tasks cover the new capability; a missing required response path stays a visible blocker.
