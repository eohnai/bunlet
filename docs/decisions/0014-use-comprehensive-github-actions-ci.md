# 0014: Use comprehensive GitHub Actions CI

- Status: accepted
- Date: 2026-10-31

## Context

Before this planning change, the inspected local and remote-tracking branches contained no CI workflow or CI specification.
The user requested comprehensive CI for this personal project, using personal-website and SMRT as references.

## Options

- **Minimal pipeline:** quickly run the existing build and tests, with less setup and fewer learning opportunities.
- **Comprehensive staged automation:** expose separate checks, reports, artifacts, compatibility, robustness, and maintenance, with more implementation and runner usage.

## Decision

Use GitHub Actions with separate jobs and a strict final required result.
Build the eight-spec [automation roadmap](../specs/automation/area.md), starting with ci-foundation before session-cards C2.

## Reasoning

The user explicitly wants to overengineer CI as part of this personal project.
They approved the expanded roadmap, including coverage, artifact reuse, cancellation, quality tools, and native acceptance.

## Consequences

Preserve local reproduction commands and verify hosted behavior before calling CI complete.
Cancel superseded PR runs and let default-branch runs finish. Keep failures visible and separate scheduled work from PR validation.
Signed releases, purchases, billing changes, and installed agent configuration changes remain outside this scope.
Roadmap approval does not authorize implementation, runtime checks, commits, pushes, pull requests, or repository rule changes.
