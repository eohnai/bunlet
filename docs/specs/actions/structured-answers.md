# Structured question answers

Needs: permission-decisions

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
acceptance remain open; tests/builds/runtime qualification NOT RUN.
