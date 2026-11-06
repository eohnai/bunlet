# Local quota intake

Implementation policy selected under the user's full MVP authorization, 2026-11-06.
This records source behavior, not runtime qualification. Existing acceptance checks stay open.

- The app owns UsageStore, Codex refresh and the optional Claude receiver. Notch only renders.
- The datagram ingress accepts Claude only. Its source namespace is `claude-status-v1:` followed
  by a SHA-256 of the status-line session_id. The hash distinguishes sessions, never accounts.
  No socket message can replace the app's `codex-managed` source. Same-user IPC is not provider authentication.
- Each observation is a complete source snapshot. Independently absent windows are removed, not
  merged with earlier readings. Empty/malformed/failed readings cannot refresh old percentages.
  Receipt time is stamped by the app; Claude has no provider measurement timestamp/account ID.
- Sources expire from storage after 24 hours at the next intake. At 128 sources, refuse a new source
  and expose capacity loss; never merge anonymous accounts or silently evict a recent source.
  The visible allowance is stale after five minutes, any passed reset, clock rollback or source failure.
- The endpoint is private (directory 0700/socket 0600), nonblocking and bounded to 8192 bytes.
  Per-socket send/receive buffers support that bound; global OS settings are untouched.
  A private persistent lock serializes participating receivers. Under that lock, only an owned socket
  whose nonblocking connect returns ECONNREFUSED and whose inode is unchanged may be removed.
  Live endpoints, symlinks, regular files and changed identities are preserved.
- One bounded inbox hands batches to the main actor; queued work is discarded after service stop.
  Receiver state, last receipt, invalid input and overflow are distinct from event-bridge health.
  Receiver startup failure does not stop Codex refresh or lifecycle intake. Settings/notch expose it.
- Codex failures retry after 5, 15, 30, 60, then 120 seconds, capped at 120 while Codex is active.
  A successful complete read restores 120 seconds. Stop/pause cancels outstanding work and retries.
  Reads never start a turn, sign in, read credentials or alter installed configuration.

Claude's documented status-line fields and shell command interface:
[status-line reference](https://code.claude.com/docs/en/statusline).
Forwarding must preserve original input/output, cancellation and exit semantics; its installation is
separate from lifecycle hooks and must preserve the original statusLine value for exact removal.
`NotchPetStatusLine` now pumps input to the original `/bin/sh -c` command in bounded chunks,
inherits stdout/stderr/cwd/environment, forwards cancellation to its process group and returns its
shell exit status. Only the first 256 KiB is retained for parsing; oversized input still reaches the
original command but yields no quota. A command that exits early adds at most 250 ms to drain the
available input; cancellation escalates to group kill after 250 ms. Input, command and output are
never logged or spooled. No-argument mode forwards metadata silently without an original command.
Packaging includes the executable. Owned status-line setup remains subsequent implementation work.
