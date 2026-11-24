# 0029: Use agent switches for desktop setup

- Status: accepted
- Date: 2026-11-24
- Amends: [0023](0023-connect-agents-automatically.md), [0024](0024-repair-hooks-and-connect-quota-at-launch.md), and [0027](0027-support-local-desktop-coding-sessions.md)

Users should be able to install Bunlet and use local Codex or Claude Code in their desktop apps. A launch-only check can miss a runtime downloaded after Bunlet starts. Re-enabling monitoring previously required a separate confirmation when Bunlet's hooks were absent.

The agent switches save the monitoring choice and start setup when enabled. When an enabled desktop runtime is missing, Bunlet waits for it and checks again while running. Approvals, manual repair, and diagnosis live under Advanced. Codex still owns hook trust, and automatic setup uses the existing ownership and policy checks.
