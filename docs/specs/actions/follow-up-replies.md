# Explicit follow-up replies

Status: implementation merged in PR #16; feature acceptance remains deferred.

Needs: permission-decisions

Merged evidence: [full MVP handoff](../notch-companion.md#merged-mvp-handoff-2026-11-06). Hosted build/package, existing tests and
coverage checks passed at `ab2ae13`. This is not feature-specific native/provider acceptance;
historical results and unrun acceptance checkboxes retain their original meaning.

The initial documented/unverified Claude binding replies through a live Stop hook. User-submitted text
becomes that hook's blocking reason, continuing the same existing prompt as feedback. It does not create
a new user-role turn or resume another process. The reply window is at most 60 seconds and requires the
same turn's response-ready observation with no pending requests. After the window, use the terminal.
stop_hook_active=true offers no additional window, preventing automatic continuation loops.

Only explicit Send emits feedback. No draft, usage refresh, reconnect, deadline or cancellation submits
text. The draft belongs to this offer UUID and is memory-only. Sending/acknowledgement never marks the
session working or successful. Helper output receipt can be confirmed while provider acceptance remains
unknown; uncertain delivery has no replay. Incoming offers do not activate the app; Respond explicitly
opens the composer. Follow-up capability has no dependency on terminal navigation metadata.

Implemented: the concrete Stop-feedback adapter, native composer, identity/draft/receipt bounds and app
lifecycle, opt-in guarded setup/check/removal and Settings controls. Setup explains the bounded reply
window and possible prompt delay. The full-goal turn-4 audit records the complete source path.
This bounded channel is a capability limit, not a claim of arbitrary-time replies to every provider.
Original A6 and follow-up-specific A7/A8 checks remain open; native/provider acceptance NOT RUN; hosted build/test evidence is recorded above.
