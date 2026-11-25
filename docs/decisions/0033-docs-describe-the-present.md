# 0033: Docs describe the present, and history lives in git

- Status: accepted
- Date: 2026-11-25
- Amends: [0011](0011-organize-records-by-feature.md)

## Context

The docs had grown to 116 Markdown files and about 145,000 words. Most of that was history: dated plans,
verification runs, command logs and goal logs kept inside specs. Every spec also repeated the same caveats.
Decision 0011 required preserving task IDs, checkbox states and historical verification evidence in the specs,
so nothing was ever removed. The user found the docs too long and asked for them to be updated in place. A comparison
with another workspace the user maintains showed short, current-state specs, an index with one-line summaries, and
history kept outside the docs.

## Decision

- **Docs describe the present.** A spec says what a feature does now, what still needs doing, and why, through links
  to decisions. Edit it in place when behavior changes. Code is the source of truth when a doc and the code disagree.
- **History lives in git.** Old versions of every doc, commit messages and pull request descriptions keep the record.
  Dated plans, verification logs, run IDs and command transcripts do not go into docs.
- **Decision records stay.** They are short, dated and not rewritten. A later decision supersedes an earlier one.
- **One index.** [`docs/specs/README.md`](../specs/README.md) lists every spec with a one-line summary and replaces
  the per-area `area.md` files. Each spec starts with a `summary:` line that matches its index entry.
- **One template.** Each spec has: summary, how it works now, requirements, out of scope, and open work. Open work is a
  short list of what remains. Finished tasks are removed.
- **Removed:** the `docs/goals/` folder, the retired feature-management spec and the original single specification
  (`notch-companion.md`). Their still-open items moved into the specs that own them.

0011's area folders stay. Its rules about preserving task IDs, checkbox states and historical evidence are replaced by
this decision, as are the matching instructions inside individual specs.

## Consequences

Reading a spec no longer requires skipping history. Finding an old plan or verification run means looking at git
history or the pull request that changed the spec. Links in older decision records may point to removed files or
sections. They describe the past and are left as written.
