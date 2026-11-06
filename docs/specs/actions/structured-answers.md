# Structured question answers

Status: implementation merged in PR #16; feature acceptance remains deferred.

Needs: permission-decisions

Merged evidence: [full MVP handoff](../notch-companion.md#merged-mvp-handoff-2026-11-06). Hosted build/package, existing tests and
coverage checks passed at `ab2ae13`. This is not feature-specific native/provider acceptance;
historical results and unrun acceptance checkboxes retain their original meaning.

The documented/unverified Claude path holds PreToolUse for AskUserQuestion, then returns the original
questions/input with the user's answer map in updatedInput and the required allow decision. The app
cannot invent questions or route through a transcript/new session. Codex has no implemented action path.

Native controls show up to four source questions and bounded options, support single/multiple choices
and custom text, and retain drafts by offer UUID. The current exact session/turn/tool invocation must
remain confirmed. Send revalidates every answer and target; it cannot resolve SessionStore itself.
Oversized drafts are bounded visibly and require an edit before Send. Switching cards cannot move drafts
to another request. Cancel/expiry returns to the provider's normal question flow without an answer.

Implemented: adapter/encoding, validation, drafts/options, native composer and single dispatch/receipt.
Guarded interactive-hook setup/check/removal and Settings/disconnect controls complete the source path.
A5 and question-specific A7/A8
acceptance remain open; native/provider qualification NOT RUN; hosted build/test evidence is recorded above.
