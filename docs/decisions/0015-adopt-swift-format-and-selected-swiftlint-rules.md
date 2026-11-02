# 0015: Adopt swift-format and selected SwiftLint rules

- Status: accepted
- Date: 2026-10-31

## Context

Before this decision, the Swift practices guide excluded formatters and linters for this small codebase.
The user approved comprehensive automation, including formatting and selected lint rules, on 2026-10-31.

## Options

- **Keep the existing manual style policy:** avoids tooling and migration work, but leaves formatting and rule checks to reviewers.
- **Use swift-format and selected SwiftLint rules:** automates formatting and chosen code checks, but needs version control, rule review, and a separate migration.

## Decision

Adopt toolchain swift-format for formatting and a pinned SwiftLint release for selected rules in automation/quality-gates.
This replaces the guide's no-linter direction. Neither tool is configured by this planning change.

## Reasoning

The user approved both tools after choosing comprehensive CI as a personal learning project.

## Consequences

Plan the rule set and formatting migration in [automation](../specs/automation/area.md).
Avoid conflicting formatting rules between tools. Run checks without automatic fixes in CI.
Pin tool versions and review changes alongside Xcode updates.
CLI tooling does not require adding a runtime package dependency to the app.
Use [swift-format's toolchain integration](https://github.com/swiftlang/swift-format)
and [SwiftLint's rule configuration](https://github.com/realm/SwiftLint) when planning implementation.
