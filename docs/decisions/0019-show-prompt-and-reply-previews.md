# 0019: Show prompt and reply previews in session rows

- Status: accepted
- Date: 2026-11-12
- Amends: the metadata-only observation rule in [ARCHITECTURE](../ARCHITECTURE.md),
  [Flux adoption: existing choices](../notes/flux-island-adoption.md#existing-choices-to-retain)
  and [companion UI direction](../notes/companion-ui-direction.md#accepted-product-choices)

## Context

Bunlet's observer hook forwards an allowlist of metadata and drops prompt and reply text.
Flux Island shows the latest user prompt and the agent's last reply under each session title.
Under [0017](0017-match-flux-island-ui.md) the rows match Flux. On 2026-11-12 the user chose to show both texts,
after being told that the island floats over all windows, including screen shares.

## Options

- **Keep metadata only:** same row layout without the two text lines.
- **Forward short previews for display:** rows match Flux; text exists in Bunlet's memory.

## Decision

Forward two additional observation fields: the latest submitted prompt and the agent's last reply,
each limited to a short preview (about 200 characters, cut on a character boundary).
Show them in the session row as Flux does.

## Reasoning

The user wants the rows to look and read like Flux's.

## Consequences

Previews stay in memory with the session snapshot. They are never written to logs, files, preferences,
integration-health evidence or diagnostics, and they are cleared when the session is removed.
Command input, tool input, transcripts and credentials remain excluded from observations.
Only hook payload fields are used; transcripts are never read. Which hook events carry the text is verified per
installed provider version before relying on it. Tests that asserted no content may enter the envelope change to
assert that only these two bounded fields do. The separate action contract is unchanged.
