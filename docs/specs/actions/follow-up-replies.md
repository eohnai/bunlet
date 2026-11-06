# Explicit follow-up replies

Needs: permission-decisions

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
lifecycle. Remaining: opt-in guarded setup/removal, clear reply-window setup guidance and source audit.
This bounded channel is a capability limit, not a claim of arbitrary-time replies to every provider.
Original A6 and follow-up-specific A7/A8 checks remain open; tests/builds/runtime checks NOT RUN.
