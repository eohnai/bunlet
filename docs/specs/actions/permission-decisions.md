# Local permission decisions

Needs: verified-channels, notch/session-island

The approved MVP requires explicit approve-once or deny for an exact confirmed pending request.
The initial documented/unverified path is Claude PermissionRequest with a separate held action helper.
It returns behavior allow/deny only, without persistent permission updates or mode changes. Other
provider policy still applies. AskUserQuestion is excluded from command approval.

The native action card exposes bounded tool-input details before the decision controls. The service
revalidates provider/session/turn/request correlation and live channel state on Send. A missing tool-use
ID requires exactly one matching observation; competing offers or a previously dispatched observed
request are unavailable. Helper receipt, provider acceptance and lifecycle resolution remain distinct.

Implemented: typed decision encoding, transient store, single dispatch, uncertainty/cancellation and
native controls, guarded opt-in action-hook setup/check/removal and Settings/disconnect integration.
Source coverage is recorded in the full-goal turn-4 audit; acceptance remains unverified.
Original A3/A4 and relevant A7/A8 checks are preserved; tests/builds/runtime checks NOT RUN.
