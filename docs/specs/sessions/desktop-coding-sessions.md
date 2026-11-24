# Desktop coding sessions

Status: in progress

[Decision 0027](../../decisions/0027-support-local-desktop-coding-sessions.md) covers standalone use on the user's personal MacBook.

## Tasks

- [x] Discover the installed ChatGPT and Claude coding runtimes with no standalone CLI and install owned hooks with clean Bunlet preferences. Preserve other settings and normal hook review.
- [ ] Verify local desktop session activity, permission notifications, completion alerts, and return navigation. Codex should open the observed thread. Claude should bring its app forward.
- [x] Package Bunlet for installation in Applications on Apple silicon and check the installed bundle and helpers.

## Workflow

Open Claude's Code tab once to download its runtime. Bunlet detects it after download even if Bunlet is already open. Settings → Agents shows the monitoring choice and setup status, with approvals and repair under Advanced. Complete Codex's hook review and start a fresh local coding session. When possible, Bunlet shows the session and opens the matching desktop target on click. An unavailable Codex thread falls back to app activation when macOS rejects the open request. See [decision 0029](../../decisions/0029-automate-desktop-agent-setup.md).

## Verification on 2026-11-24

- The release app launched with a disposable profile, minimal `PATH`, and desktop runtimes Codex `0.169.0-alpha.11.1` and Claude Code `2.1.325`. It installed seven Codex and nine Claude lifecycle hooks alongside existing fixture hooks, preserved the output of the wrapped Claude status line, and left both configurations byte-identical on relaunch.
- Swift tests covered connect and removal, refusal of unknown file metadata, reported desktop hosts, the exact Codex URL and its fallback conditions, and working → attention → completion with fictional desktop events. The installed ChatGPT app registers the `codex` URL scheme and includes a thread route.
- The bundled Claude Code 2.1.325 executable loaded fixture user settings and emitted `SessionStart` and `UserPromptSubmit` for a fictional prompt with model traffic directed to a closed loopback port. The prompt event included `prompt_id`, which the Bunlet adapter uses to correlate a turn. This exercised the bundled executable with an isolated profile.
- The release app and all three helpers are arm64. The Mach-O deployment target is macOS 14. The extracted archive passed strict code signature verification. The package uses an ad-hoc signature and has no notarization ticket.
- During investigation of a missing Codex desktop session, the seven Bunlet hook commands matched the recorded trust hashes for both the CLI and desktop runtime. In a disposable profile, a thread opened before an external hook installation and trust change kept its empty hook list. A fresh thread and an existing thread after an explicit config reload both emitted `SessionStart` and `UserPromptSubmit`.
- The user subsequently reported that both desktop apps now work with Bunlet. On-screen notifications and desktop return navigation still need dedicated acceptance checks.
