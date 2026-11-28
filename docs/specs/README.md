# Bunlet specs

Bunlet is a native macOS app for one person's MacBook. It shows local coding-agent sessions (Codex, Claude Code and
Cursor CLI, in a terminal or in the ChatGPT and Claude desktop apps) in an island around the camera notch. From the
island the user can see what each agent is doing, answer its requests, check quota, and jump back to it. A pet rabbit
lives in the island and reacts to the sessions.

Bunlet observes agents only through their official hooks and status line. It never reads transcripts or credentials,
and it changes agent configuration only through its own recorded, reversible entries.

Each spec describes how a feature works now and what is left to do. Code is the source of truth when they disagree.
Git history holds earlier versions and the work that led here ([0033](../decisions/0033-docs-describe-the-present.md)).
Start with [STATUS.md](../STATUS.md) for current priorities and [ARCHITECTURE.md](../ARCHITECTURE.md) for how the code
fits together.

## Sessions

- [Observe local agent events](sessions/observation-bridge.md): the bundled hook helper delivers allowed agent event
  fields to the running app over a private Unix socket.
- [Track agent session state](sessions/session-state.md): one in-memory store turns events into per-session state.
  The latest event decides, and there is no unknown state.
- [Report integration health](sessions/integration-health.md): Settings shows version, hook configuration, helper,
  receiver and last delivery as separate evidence per agent.
- [Connect Codex](sessions/codex-setup.md): Bunlet installs, repairs and removes its own Codex lifecycle hooks without
  touching anything else in `hooks.json`.
- [Connect Claude Code](sessions/claude-setup.md): Bunlet installs, repairs and removes its Claude Code lifecycle hooks
  and, separately, its quota status-line wrapper.
- [Per-agent monitoring](sessions/monitoring-controls.md): each agent has its own switch that pauses or resumes
  monitoring without losing pending requests.
- [Jump to a session's terminal](sessions/pane-navigation.md): clicking a session jumps to the pane or app it runs in.
  Navigation is optional and never needed for monitoring.
- [Desktop coding sessions](sessions/desktop-coding-sessions.md): Bunlet tracks Codex in the ChatGPT app and Claude
  Code in the Claude app, and clicks return to that app.

## Notch

- [Session island](notch/session-island.md): a pill around the camera notch that opens into a panel listing agent
  sessions, without taking keyboard focus.
- [Session rows](notch/session-cards.md): each session row shows its agent, folder, prompt timer and previews. A
  request with no reply channel gets its own card.
- [Quota badges](notch/allowance-strip.md): badges left of the notch show each active agent's 5-hour or weekly
  allowance, with details on hover.
- [Desktop behavior and focus](notch/desktop-recovery.md): the island keeps its state across displays, Spaces,
  fullscreen and sleep, and follows native focus and keyboard rules.
- [Resource efficiency](notch/resource-efficiency.md): Bunlet stays cheap at idle on a 16 GB M2 MacBook Air. Its
  budgets are proposed and not yet measured.

## Usage

- [Codex allowance](usage/codex-allowance.md): Bunlet reads Codex's 5-hour and weekly limits from the read-only App
  Server while a Codex session is active.
- [Claude allowance](usage/claude-allowance.md): Claude Code's status line forwards its 5-hour and weekly limits to
  Bunlet through a wrapper that keeps the original output.
- [Token statistics](telemetry/statistics.md): Settings → Statistics shows daily Claude Code token totals from the
  status line. The counting is known to undercount.

## Actions

- [Local responses](actions/local-responses.md): approve or deny, answer questions and send follow-ups from the island,
  only through verified local channels.

## Pet

- [The pet](pets/pet.md): a white lionhead rabbit docks in the island, comes out onto the desktop when dragged, and
  reacts to agent sessions.
- [Custom pet artwork](pets/custom-artwork.md): users replace the rabbit with a pet pack, an animated PNG or a sprite
  sheet, all converted offline into one pack format.

## App

- [Settings](settings/settings.md): one native Settings window with General, Agents, Display, Sound, Shortcuts,
  Statistics and About pages.
- [Software updates](settings/software-updates.md): Settings → About → Check for Updates installs signed releases
  through Sparkle, and a GitHub workflow packages them.
- [Continuous integration](automation/ci.md): every pull request and push to `main` builds, tests and checks Bunlet on
  GitHub Actions, with one strict Required result.

## Contracts and notes

- [Agent events v1](../contracts/agent-events-v1.md): the wire format between the hook helper and the app.
- [Codex hook setup](../contracts/codex-hook-setup.md) and [provider setup](../contracts/provider-setup.md): ownership,
  journal and removal rules for hooks Bunlet installs.
- [Local actions v1](../contracts/local-actions-v1.md): identities, limits and failure rules for replies to agents.
- [Quota intake](../contracts/usage-intake.md): the private socket that carries Claude quota readings.
- [Pet workflows](../contracts/pet-workflows.md): artwork limits, fallbacks and failure rules.
- [Reference adoption](../notes/reference-adoption.md) and [reference UI](../notes/reference-ui.md): what Bunlet
  adopted from the reference island, described so the reference app is not needed.
