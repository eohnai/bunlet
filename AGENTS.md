# Project instructions

- Read `docs/STATUS.md` before working on this project.
- Find the relevant spec in `docs/specs/README.md` and read it with its decision records before changing code.
- Docs describe the present (decision 0033). When behavior changes, update the spec, `docs/STATUS.md` and `docs/ARCHITECTURE.md` in place. Keep plans, verification logs and run details in commits and pull request descriptions, not in docs.
- Read `docs/SWIFT-PRACTICES.md` before writing or reviewing Swift code.
- Keep proposed decisions distinct from accepted decisions.
- VoiceOver/screen-reader testing is excluded from all feature acceptance at the user's request. Keep native labels, keyboard controls, Reduce Motion and focus behavior.
- Make the reference island and other external UI references self-contained in repository notes: describe layout, triggers, states, actions and limitations so implementation does not require the reference app or this chat. Start with `docs/notes/reference-adoption.md` and `docs/notes/companion-ui-direction.md`.
- The repository contains a native app shell and project records.
- Do not start implementation until the user approves the task list.
- Never commit, push, or open a pull request without the user's explicit instruction.
- Preserve existing Codex, Claude Code, and Otty configuration during future integration work.
- Do not read or print credentials when inspecting notification or usage integrations.
- Keep runtime files, imported pet packs, and captured session data outside the repository.

