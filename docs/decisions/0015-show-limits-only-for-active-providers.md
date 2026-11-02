# 0015: Show usage limits only for providers with observed active sessions

- Status: accepted
- Date: 2026-11-02

## Context

The user requires the strip to omit Claude Code when no Claude Code session is active, and likewise for Codex.
The existing provider filter includes every non-ended session, including Unknown sessions retained after observation expiry.

## Options

- **Any non-ended session:** keeps usage limits visible for retained Unknown sessions.
- **An observed active session:** hides a provider when only Unknown or Ended sessions remain.

## Decision

Treat idle, working, question-needed, approval-needed, and response-ready sessions as active for provider visibility.
Unknown and Ended sessions do not make a provider visible. Each provider requires its own active session.
Retain Unknown/Ended session cards and notices independently of the strip.

## Reasoning

The user wants providers hidden when none of their sessions are active.
Unknown state does not establish an active session, so it cannot keep the provider visible. ^[inferred]

## Consequences

The shared filter also controls Codex usage reads, so reads stop when no observed active Codex session remains.
An observation timeout can hide a provider even if its process still exists; process discovery is not added here.
Fresh session evidence can make it visible again. Session retention and account-level usage data remain unchanged.
