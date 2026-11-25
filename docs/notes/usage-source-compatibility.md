# Provider usage-source compatibility

Checked on 2026-10-22. The [Codex](../specs/usage/codex-allowance.md) and [Claude](../specs/usage/claude-allowance.md) allowance specs are built on these findings.

Codex returned account usage through its installed App Server without starting a thread or turn.
Claude Code supports the documented status-line fields, but this investigation did not obtain a live quota payload.
The installed Claude account is eligible according to documentation; runtime forwarding still needs verification.

This investigation adds no application code and accepts no architecture proposal.
Read the [event compatibility record](agent-event-compatibility.md) for session and pane findings.

## Evidence boundaries

- **Runtime** means an installed command or protocol request returned the stated result.
- **Installed** means the generated protocol schema or installed binary contains the interface.
- **Documented** means an official source describes behavior that was not exercised here.
- **Unverified** means this investigation cannot establish the behavior.

Installed versions were Codex CLI `0.163.0` and Claude Code `2.1.306`.
The probes started no agent threads, turns, prompts, or model requests.
They did not attach to, interrupt, or change an existing agent session.
The current Codex session remained usable while the auxiliary App Server completed its reads.
This does not verify long-running coexistence, cross-process notifications, or account switching.

No real authentication file, Keychain entry, token, transcript, or private usage endpoint was inspected directly.
Each provider handled its own authentication through its public command or protocol.
Codex can maintain its normal runtime storage and managed authentication during these operations.
Authentication storage was not fingerprinted, and unchanged tokens are not claimed.

The probes retained only selected account-mode metadata and usage-shape summaries outside the repository.
Real account identifiers, emails, percentages, reset times, and raw protocol responses were not retained.
The examples below contain fictional values.

SHA-256 fingerprints matched before and after the investigation for these configuration files:

- `~/.codex/config.toml`
- `~/.codex/hooks.json`
- `~/.claude/settings.json`

No Otty command or configuration change was needed.

## Account-mode matrix

| Provider and mode | Evidence | Result and limit |
|---|---|---|
| Codex, existing managed ChatGPT account | **Runtime** | Two successful usage reads. Each returned one bucket, two windows, and an account identifier. |
| Codex, signed out | **Runtime**, isolated configuration | Account was null. Both usage reads returned error `-32600`, classified as signed out. Show unavailable. |
| Codex, API key | **Runtime**, fictional key in isolated configuration | Account type was `apiKey`. Both usage reads returned `-32600`, requiring ChatGPT authentication. No real API-key account was contacted. |
| Codex, other ChatGPT plans or workspaces | **Installed**, **unverified** per plan | The schema supports plan metadata and optional quota fields. An enum member does not prove a plan supplies particular windows. |
| Codex, externally managed ChatGPT authentication | **Documented**, **unverified** | A host must manage its own authentication lifecycle. This investigation did not supply or copy tokens. |
| Codex, Bedrock or another model provider | **Unverified** | This investigation establishes no supported subscription-allowance source for these modes. Do not substitute model token totals or API throttling limits. |
| Claude, Pro | **Runtime** account check; **installed/documented** fields | Normal-access authentication status reported a signed-in Pro account. Live quota payload and forwarding remain unverified. |
| Claude, Max | **Documented**, **unverified** locally | Eligible for subscription windows after an API response. No Max account was tested. |
| Claude, Team or Enterprise | **Unverified** for subscription windows | The status-line documentation does not promise these windows for these plans. Missing fields must remain unavailable. |
| Claude, Console/API key, Bedrock, Google Cloud, or Foundry | **Unverified** locally | No subscription-window support was established through this source. Account access alone does not establish quota availability. |
| Claude apps gateway | **Installed/documented**, **unverified** locally | Optional `spend_limit` fields describe a spending limit. They do not establish five-hour or weekly subscription allowance. |

The account-mode matrix is not a promise that every supported plan returns every optional field.
Missing data needs a reason such as signed out, unsupported account mode, awaiting first response, or source unavailable.
Use an unknown reason when the source does not distinguish these cases.

## Codex connection and returned fields

The auxiliary process used `codex app-server --stdio` with analytics and feedback disabled through command-line overrides.
It used the provider's existing managed authentication without reading or copying credentials.
The requests were limited to:

```text
initialize
initialized
account/read                 {"refreshToken": false}
account/rateLimits/read      {"excludeResetCreditDetails": true}
account/rateLimits/read      {"excludeResetCreditDetails": true}
```

`initialize` supplied a probe client name and version, with experimental API access disabled.
`initialized` was a notification; the other entries were requests.
Skipping reset-credit detail lookup avoids an unnecessary additional lookup during this investigation.
No reset credit was consumed, and no account login or logout method was called.

Both successful responses contained a multi-bucket map with one bucket.
Each contained a primary window of `300` minutes and a secondary window of `10080` minutes.
All four observed percentages were numeric and within 0–100.
All four reset values had the shape of Unix timestamps in seconds.
The account identifier was present; its value was discarded.
These observed window lengths must not become assumptions for every account.

The installed schemas establish these details:

| Field | Meaning and handling implication |
|---|---|
| `rateLimitsByLimitId` | Optional map of metered buckets. The compatibility `rateLimits` view is not an additional allowance to add. |
| `accountId` | Optional identity on the full response. It permits account grouping when available; provider alone is insufficient. |
| `primary`, `secondary` | Optional windows. Either may be missing or null. |
| `usedPercent` | Required integer within a present window. Its label is **used**. |
| `windowDurationMins`, `resetsAt` | Optional or null. A known percentage does not guarantee a known reset time. |
| `credits` | Optional balance information. Keep it separate from window percentages. |
| `individualLimit.remainingPercent` | Optional spending-control information. Its percentage label is **remaining**, unlike window usage. |
| `ordinaryUsageAllowed` | Optional permission metadata. Null does not prove recovery when a reset passes. |

`account/rateLimits/updated` exists in the installed protocol.
Its schema describes sparse updates: merge available values into the last full snapshot, or read the snapshot again.
Nullable metadata in an update does not clear a previously observed value.
No quota-update notification was observed during these short reads.
The process received account and remote-control status notifications, with no server requests.
Update delivery across independent CLI processes remains unverified.

The [official App Server documentation](https://learn.chatgpt.com/docs/app-server) describes initialization, account reads, quota reads, and update notifications.
The installed schema supplied the additional field details above.
No caller needs to start a conversation merely to request the current account snapshot.

## Claude source and forwarding boundary

The installed binary constructs these status-line fields:

- `rate_limits.five_hour.used_percentage` and `resets_at`
- `rate_limits.seven_day.used_percentage` and `resets_at`
- Optional gateway `rate_limits.spend_limit` fields

It omits `rate_limits` when none of those windows exists.
This is source inspection, not a captured live status-line payload.

The [official status-line documentation](https://code.claude.com/docs/en/statusline#rate-limit-usage) limits subscription windows to Pro and Max after the first API response.
Percentages mean used allowance, and resets use Unix seconds.
Gateway spend fields describe a separate spending limit.

The status-line command receives JSON on stdin and returns terminal output on stdout.
It can rerun on session events or a refresh timer, and an overlapping invocation can cancel an earlier invocation.
Rerunning a display command does not by itself establish a fresh provider observation.

The read-only `claude auth status --json` check reported `claude.ai`, `firstParty`, and `pro` with normal macOS access.
Only allowlisted account categories were retained.
The user settings contained no `statusLine` command.
No existing command was executed or replaced.
Project, managed, and command-line overrides were not exhaustively inventoried, so effective configuration still needs setup-time review.

Future forwarding must give the existing command the same input and preserve its stdout.
Forwarding failures must not suppress that output or block the terminal.
The later setup task must preserve all effective status-line options and make removal reversible.
These are constraints for later work, not a tested wrapper implementation.

No supported standalone quota-refresh command was established for this Claude source.
This investigation did not run `/usage`, `/statusline`, a print-mode prompt, or an interactive turn.
Live fields, output preservation, cancellation, and app-unavailable behavior remain checks for the forwarding task.

## Freshness and account identity

Record local receipt time separately from a provider's reset time.
Neither tested quota shape supplied a general quota-observation timestamp.
A recently received payload therefore does not prove when the provider measured its values.
A reset passing does not prove that a reported percentage has become zero.

The Claude status-line quota fields do not provide a stable account identifier.
Do not use a session ID, project folder, model, or Pro/Max plan name as account identity.
Cross-session account grouping remains unresolved when a supported identity is absent.
Keep anonymous observations separate until the architecture review defines an honest presentation.

Both providers' allowance is an account concern, not a total to sum across session panes.
Context-window percentages and token-cost totals are separate measurements.
Do not derive subscription allowance from them.

## Fictional payload examples

These are source-shaped fragments for verification, not an application event contract.
The Codex account identifier is deliberately fictional.

```json
{
  "example_kind": "fictional",
  "codex_full": {
    "accountId": "fictional-account",
    "rateLimits": {
      "limitId": "codex",
      "primary": {"usedPercent": 23, "windowDurationMins": 300, "resetsAt": 1792670400},
      "secondary": {"usedPercent": 41, "windowDurationMins": 10080, "resetsAt": 1793188800}
    },
    "rateLimitsByLimitId": {
      "codex": {
        "limitId": "codex",
        "primary": {"usedPercent": 23, "windowDurationMins": 300, "resetsAt": 1792670400},
        "secondary": {"usedPercent": 41, "windowDurationMins": 10080, "resetsAt": 1793188800}
      }
    }
  },
  "codex_missing_reset": {
    "rateLimits": {"primary": {"usedPercent": 0, "resetsAt": null, "windowDurationMins": null}}
  },
  "codex_sparse_update": {"rateLimits": {"limitId": "codex", "primary": {"usedPercent": 24}}},
  "claude_subscription": {
    "rate_limits": {
      "five_hour": {"used_percentage": 12.5, "resets_at": 1792670400},
      "seven_day": {"used_percentage": 37.5, "resets_at": 1793188800}
    }
  },
  "claude_missing": {},
  "claude_zero": {"rate_limits": {"five_hour": {"used_percentage": 0, "resets_at": 1792670400}}}
}
```
