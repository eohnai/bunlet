# Companion interface reference and proposed direction

Date: 2026-11-02

Use Vorssaint as the main reference for native Settings and feature management, and Flux Island for the hierarchy
of compact session and request interactions. Keep the desktop pet usable on its own. This is a source-based design
recommendation, with the supplied Flux settings image and Vorssaint's published Features image as visual references.
It is not a live visual/accessibility acceptance report or an approved UI implementation task list.

## Accepted product choices

- **Use both references as inspiration for an original, polished Notch Pet interface (2026-11-02).** The user explicitly rejects copying either
  app's complete UI. Combine useful behavior and organization, then improve hierarchy, spacing, copy, motion and native interaction through
  Impeccable and Apple guidance. Reference screenshots are evidence of patterns, not visual templates. Preserve the pet's own personality and
  truthful session/installation states. This direction does not claim that the current UI has passed visual acceptance.
- **Future brand direction (2026-11-02):** the user wants to rename the project eventually and use the rabbit as the logo. Keep the new name open;
  plan a recognizable simplified white lionhead rabbit mark and app icon as a separate branding task. Do not treat this direction as a completed
  logo, chosen name or authorization to rename package/bundle identifiers during feature-management work.
- **Mascot inspiration clarified (2026-11-02):** REMME Rabbit and the Palm Pals rabbit are visual references, not proposed app names. Explore an
  original soft, plush-like rabbit with a distinct silhouette and face; derive a simplified logo from that character. No specific reference variant,
  final mascot drawing or replacement of the existing pet assets has been selected yet.
  Portable sources: [REMME's Nemu-chan](https://remme.stores.jp/items/64a78e7c3c52b7002cfca524) and
  [Palm Pals' pet collection](https://palmpals.com/collections/pets). These links identify the references, not a chosen final rabbit variant.
- [D7](../DECISIONS.md#d7-install-and-uninstall-features-from-settings): one app, with Pet, Notch and Agents installed/uninstalled
  in Settings. Pet requires neither of the other features. Preserve preferences for reinstall.
- **Name selected (2026-11-06):** use Bunlet to emphasize the pet, including desktop use.
  This replaces the earlier open-name direction. [Decision 0016](../decisions/0016-use-bunlet-name.md)
  and the [product-name spec](../specs/settings/product-name.md) define the visible rename.
  The final mascot artwork and icon remain separate choices.
- [0013](../decisions/0013-separate-standalone-pet-scope.md): independent pet module and pet-first use with optional agent services.
- [0010](../decisions/0010-add-local-agent-actions.md): local approval, structured answers and explicit follow-ups are in scope,
  conditional on verified provider channels. Lifecycle observation alone does not establish action support.
- [0012](../decisions/0012-support-terminal-independent-operation.md): monitoring and pet reactions require no specific terminal.
- Observation keeps its metadata allowlist. Flux's prompt/activity previews and request content are not permission to widen it.
- Preserve the allowance strip's accepted removal of hover tooltips on the feature branch. Clarification should not silently restore them.

The following layout choices are proposals. Installing this reference does not implement them or change acceptance checkboxes.

## Settings should be closer to Vorssaint

Vorssaint's Features page places feature availability in a dedicated settings destination. Its screenshot has a sidebar,
a Features/Permissions selector, grouped feature rows and trailing Install/Uninstall buttons. Rows combine an icon, a clear name,
a one-line purpose and, where relevant, permission/activity information. Installed features can open their settings separately
from the removal action. The feature entry stays discoverable after uninstall.

The reviewed implementation ships one app. Availability gates deferred service bindings; unavailable features are skipped at launch.
Removal invokes teardown immediately. A singleton already created in the process can stay resident until restart, and the UI can
explain when restart will unload it. Preferences survive reinstall. “Install” here is feature availability, not a new binary download.

Sources pinned to reviewed commit `63a57362ffe1c0f8689c8924a32fad01d40f215b` (v3.4.3):
[Features image](https://github.com/vorssaint/vorssaint-utils/blob/63a57362ffe1c0f8689c8924a32fad01d40f215b/docs/assets/readme/features-hub.png),
[FeatureRuntime](https://github.com/vorssaint/vorssaint-utils/blob/63a57362ffe1c0f8689c8924a32fad01d40f215b/Sources/Vorssaint/App/FeatureRuntime.swift),
[FeatureHubSettings](https://github.com/vorssaint/vorssaint-utils/blob/63a57362ffe1c0f8689c8924a32fad01d40f215b/Sources/Vorssaint/UI/Settings/FeatureHubSettings.swift).
The descriptions here remain useful if these links are unavailable.

### Proposed smaller feature manager

Start with three rows. Each has a name, purpose, installation state, and Install or Uninstall action:

| Feature | Purpose | Relationship |
| --- | --- | --- |
| Desktop Pet | Show and customize the desktop companion | Works by itself |
| Notch | Show the optional compact island surface | Never installed silently as a requirement of Pet |
| Agents | Connect coding agents and observe supported sessions | Independent of Pet artwork and window placement |

Retain a small General and Features navigation structure, then show settings for installed features.
The exact navigation belongs to the settings-window plan. Keep a Features recovery entry even when no optional feature is installed.
Avoid copying Vorssaint's many preset bundles, installation counters and utility categories into a three-feature app.

Do not combine these different states in one green “Active” indicator:

- **Installed:** this feature is available in the app.
- **Enabled or paused:** the installed feature's current runtime preference.
- **Connected:** a provider has its supported setup/connection evidence.
- **Health:** what configuration, receiver and delivery checks actually establish.

For example, an installed Agents feature may show “Codex — Setup needed” with Connect, or “Claude Code — Paused” with Resume.
A quiet agent can be configured correctly without a recently observed session. Show the relevant evidence in provider settings.
Installing Agents must not silently install hooks or request permissions for features the person did not choose.

### Removal behavior to settle before implementation

Uninstalling a feature should close its surfaces, unregister its shortcuts and cancel its owned tasks/observers.
Preferences remain available for reinstall. Hook ownership/removal needs the existing safe setup contract;
removing Agents cannot delete another tool's configuration or resolve a pending request as successful.

Dependency rules remain open: which useful Notch content exists without Agents, how to expose Agents without either surface,
and how pet reactions attach when both relevant features are installed. Explain affected features before applying a removal that
changes another feature's behavior. Do not copy Vorssaint's notch-extension cascade as an already accepted dependency graph.

## Session island should borrow Flux's hierarchy

The portable [Flux reference](flux-island-adoption.md#portable-implementation-reference) describes the actual components and their
provider limitations. Flux groups phase, provider, session identity and duration in a compact row, then presents contextual approval,
question or follow-up controls. This matches the user's momentary task: identify what needs attention and choose the next action.

Proposed hierarchy for our expanded island:

1. Compact provider limits, with freshness/uncertainty kept understandable.
2. Session heading: provider, project, explicit status and observed turn duration.
3. A pending request, marked confirmed or unconfirmed, with only verified actions or terminal-return guidance.
4. Optional details: full path, complete session identity and refresh time behind deliberate disclosure.

Keep routine rows compact. Full identities are useful for distinguishing sessions, but should not dominate the first glance.
Use a restrained native palette, system typography, aligned metadata and one clear primary action per request.
Retain status words beside color/icon cues. Session state, unavailable quota and “not installed” have different meanings.
Use conditional motion that respects Reduce Motion and avoid introducing focus when an observation arrives.

### Findings in our current feature branch

The reviewed target is PR #13's `Sources/NotchPet/NotchSessionView.swift` and its card/presentation components,
including the inherited session-card changes. PR #13 subsequently merged into main as `e856686` on 2026-11-02.

- **P1 — Detail disclosure can compete with requests.** `NotchPresentation.selection(nil, sessions:)` chooses the first ordered session;
  `NotchSessionView` invokes it on appearance and updates. That selection opens full path, session identity and refresh metadata.
  Requests follow the card inside a 240-point content region. Keep compact default rows and separate selection from details expansion
  when planning a refinement. This is a source-based space/hierarchy risk, not observed clipping.
- **P1 — Feature availability needs a visible owner.** The requested install/uninstall lifecycle is not the current provider connection
  preference. Build a feature manager with truthful states, rather than relabeling a switch “Install.”
- **P2 — Uncertain quota needs understandable copy.** `5h —` and a question mark carry less visible explanation than the spoken labels.
  Plan concise visible clarification where needed while preserving the no-tooltip decision. Missing data must not look like zero remaining.
- **P2 — Stale quota needs a textual state.** The current presentation grays stale values, while the accessibility summary still reports
  percentage/reset without saying stale. Add visible and spoken freshness meaning during a reviewed clarification task; an absent reset
  should not be spoken as “resets in —.” This requires no new hover tooltip.
- **P2 — Empty sessions need contextual recovery.** “No sessions observed yet” accurately describes observations. Settings should explain
  whether monitoring is absent, paused, awaiting setup or merely quiet; do not derive “Disconnected” from the empty list.
- **P2 — Native keyboard acceptance remains open.** Real buttons and labels are a useful foundation, but the nonactivating
  panel's complete keyboard route, focus behavior and announcements need approved runtime validation. Source inspection cannot establish them.

Preserve existing strengths: explicit unknown/unconfirmed wording, provider identity, distinct request cards, shared selection rules,
observed turn timing and conditional update work. Review each proposed refinement against the existing decisions before changing behavior.

## Pet should keep its own quiet interface

Give pet-only users a preview, native size control and clear Show Pet/Settings recovery. Pet setup should finish without agent questions.
Keep personality in the artwork and purposeful interaction, while routine controls use familiar macOS behavior.

The current built-in pet is independent of agent models, but its compact placement does not establish the requested desktop pet without
Notch. Plan independent placement and return behavior. Dragging back to the island applies only when Notch is installed.

## How to apply Impeccable and Apple guidance

Use Impeccable's Operate mode: scanning, task completion, familiar controls and clear states take priority over decoration.
The source/reference assessment used independent design and mechanical-evidence passes. It did not launch apps or capture screens.
The mechanical pass ran `node /Users/bytedance/.agents/skills/impeccable/scripts/detect.mjs --json` with the feature branch's five explicit
Swift targets: `NotchSessionView.swift`, `NotchSessionCard.swift`, `NotchRequestCard.swift`, `NotchAllowanceStrip.swift` and `PetSettingsView.swift`.
It returned exit 0 and an empty findings array. The detector's text rules target web/CSS/JSX patterns; this does not verify SwiftUI semantics,
native contrast, keyboard access or VoiceOver. No numerical comparison score is assigned from this limited evidence.
No PRODUCT.md or DESIGN.md exists yet; record a brief before a new visual design or broad redesign. A scoped comparison does not require one.

The requested `apple-design` skill was not found in installed skill locations. Use Apple's primary guidance until that skill is supplied:

- [Settings](https://developer.apple.com/design/human-interface-guidelines/settings): a standard menu entry and Command-Comma,
  stable organization of related settings, and restoration of the last pane.
- [Toggles](https://developer.apple.com/design/human-interface-guidelines/toggles): use familiar controls for persistent state.
  Our proposed Install/Uninstall buttons communicate feature lifecycle separately from enable/pause controls.

Before implementation, shape the small Features page and one provider detail flow, then harden unavailable/error/removal states.
Polish after the agreed behavior works. Do not begin by copying either reference app's full layout or color treatment.

Questions skipped: the user selected installation through Settings, and this comparison proposes a direction without starting a redesign.
New implementation tasks, runtime acceptance, captures and goal resumption remain separate.
