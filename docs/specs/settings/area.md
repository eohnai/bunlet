# Settings

Owns the shared native settings window, sidebar navigation, and app-wide general preferences.
Code: settings views and window controllers in `Sources/NotchPet/`.
Feature-specific behavior stays with Sessions, Notch, Usage, Pets, and Telemetry.

## Specs

- `product-name`: [Use Bunlet as the visible product name](product-name.md), aligning app labels, bundle output and CI packaging.
- `feature-management`: [Install/uninstall optional Pet, Notch and Agents](feature-management.md), preserve preferences and coordinate service/surface teardown. FM1–FM6 are implemented/verified; the goal is paused and FM7 is deferred by the user.
- `settings-window`: Open a native sidebar settings window from the app menu and show the existing pet controls through a working page.
- `general-preferences`: Save launch-at-login and language preferences and apply them through supported native behavior. Needs: settings-window.

## Merged MVP status, 2026-11-06

Implementation is merged through PR #16 (including PR #15). See the
[nine-area handoff](../notch-companion.md#merged-mvp-handoff-2026-11-06) for production paths,
hosted build/test evidence and capability limits. Existing unchecked acceptance tasks are not
missing implementation by default; inspect their current feature handoff before selecting work.
Native/provider acceptance remains deferred. Broader roadmap entries without specs remain future work.

## Shared context

- [D7: Install and uninstall features from Settings](../../DECISIONS.md#d7-install-and-uninstall-features-from-settings) is accepted on 2026-11-02. Retain one app; Pet works without Notch or Agents. Keep the feature manager reachable when optional surfaces are uninstalled. Feature availability is separate from runtime enablement and provider connection health.
- Use the portable [UI direction](../../notes/companion-ui-direction.md) and [Flux behavior reference](../../notes/flux-island-adoption.md#portable-implementation-reference) during planning. Their proposed layouts do not approve implementation tasks.
- The user approved this area and both roadmap entries on 2026-10-30 after supplying settings reference images.
- Sessions and real allowance limits remain the first delivery milestone. This area extends that path without making the settings shell a prerequisite for existing session work.
- Use the supplied reference's sidebar, clear page titles, grouped controls, and explanatory secondary text as the settings direction.
- Initial feature pages include General, Agents, Display, Pet, and Statistics as their owned features become available. Do not expose dead navigation entries.
- The first settings-window feature connects the real menu entry, window, navigation, and existing pet controls. It does not require agent setup or telemetry.
- Session setup contributes the Agents controls. Notch owns attention behavior and display preferences. Telemetry owns statistics and their data requirements.
- Opening Settings is an explicit focus request. Showing the pet, session updates, and attention expansion retain their separate focus rules.
- Preserve pet-first setup, existing size preferences, and optional agent services. Opening Settings alone does not enable monitoring or a collector.
- General preferences use UserDefaults. Login registration and localization need their own reviewed implementation tasks and acceptance.
- Other sidebar labels in the reference do not define additional integrations or provider support. Keep future page scope explicit.
- Roadmap approval defines feature scope and order. Full specifications and implementation task lists remain separate work.

## Open questions

- Review launch-at-login ownership and the enabled/disabled/error states before changing system registration.
- Choose supported languages and define fallback and restart behavior during general-preferences planning.
- The merged PetSettingsController/AppSettingsView hosts feature pages and preserves pet setup/recovery. A retrospective settings-window spec is still unwritten; native FM7 acceptance remains deferred.
