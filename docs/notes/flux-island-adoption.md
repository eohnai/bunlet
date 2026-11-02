# Flux Island reference findings and adoption plan

Date: 2026-10-28

Portable reference expanded: 2026-11-02. Start with [the implementation reference](#portable-implementation-reference)
when Flux Island is unavailable on the development machine. For the combined Flux/Vorssaint UI direction,
see [companion UI direction](companion-ui-direction.md). Source descriptions below explain behavior;
accepted decisions and proposed adaptations remain distinct.

## Scope and evidence

The user requested a comparison with the Flux Island installed on this Mac, accepted retaining SwiftUI/AppKit,
and then requested specification changes that adapt useful Flux behavior while preserving this app's strengths.
This note supports the [revised companion specification](../specs/notch-companion.md).
The user subsequently accepted local approvals and replies and designated SSH/cloud support as optional future work;
[decision 0010](../decisions/0010-add-local-agent-actions.md) records that scope expansion.
It records behavioral observations and recommendations, not a license assessment, copied implementation, or runtime benchmark.

The inspected installation was `/Applications/Flux Island.app`, version `0.1.25`,
bundle identifier `com.bytedance.flux.desktop`, from `Contents/Info.plist`.
Its `Contents/Resources/app.asar` SHA-256 was
`25bf9e27fb025668d193f8323b5151bfbc37d62b2bd87bae8101cabf41f8e758`.
Selected packaged JavaScript was inspected through a temporary extraction outside this repository.
No app was launched, no user configuration or credentials were read, and no performance or end-to-end compatibility check was performed.
No packaged source, internal artwork, or captured session content is included in this repository.

References below name entries inside that archive and their inspection-time line numbers.
The extraction is temporary and is not a build input. A later Flux version may differ.

## Portable implementation reference

This section is sufficient for planning without the installed app, temporary extraction, internal guides,
or the original chat images. It describes Flux Island 0.1.25, then states how each behavior relates to notch-pet.
These are packaged-source findings, supplemented by the agent-settings image supplied by the user;
they do not establish live compatibility for every listed agent.

### What the agent settings look like

The supplied reference shows a dark settings panel with a vertical list of agents. Each row has the agent name
at the left, a status dot and status text beside it, and a trailing switch. Thin dividers separate rows.
Enabled examples say **Active** with a green dot and a blue switch. A disabled example says **Disabled** with a gray dot
and an off switch. The visible list includes Claude Code, Codex, Cursor, OpenCode, Kimi Code CLI, Gemini CLI,
GitHub Copilot CLI, Hermes, Aiden CLI, Sara CLI and Oh My Pi. The image does not establish that every listed integration
has delivered events, provides usage limits, or supports answering requests.

The useful interaction is one understandable row per agent. In notch-pet, distinguish installing the Agents feature
from connecting an individual provider. Installation makes the feature available; Connect configures a supported agent.
Connection health needs separate evidence for configuration, receiver readiness and actual delivery.

### How additional agents fit

Flux uses multiple extension points rather than a universal switch that makes any CLI compatible:

- **Setup managers** install, remove and check provider-specific hooks or plugins. The coordinator stores them by agent ID.
- **Event adapters** translate provider payloads into shared session events. The bridge also has dedicated paths for plugin
  and custom agent IDs, alongside its built-in adapters and pull integrations.
- **A custom-agent registry** supplies identities, display names and configuration locations. It validates names and
  configuration-path conflicts, watches for changes and updates the available managers and settings UI.
- **A generic custom adapter** recognizes registered sources and a fixed set of hook-shaped events, including session start,
  prompt submission and tool activity. Its inspected path is nonblocking. Registration alone does not supply permission responses,
  questions, usage data or terminal navigation for an arbitrary program.

The inspected coordinator registers 14 built-in setup managers: Claude, Codex, Coco, Trae, Trae CN, Cursor,
OpenCode, Sara, Kimi, Gemini, Copilot CLI, Hermes, Aiden and Traex. Plugin declarations and registered custom agents
add managers dynamically. This list describes setup registrations, not a tested capability matrix.

For notch-pet, keep provider identity, event parsing, setup, usage, user actions and terminal navigation as distinct responsibilities.
A provider can ship observation support before usage or actions. Shared views should render capabilities and snapshots,
without embedding provider payload parsing or assuming that all providers have equivalent support.
The exact Swift protocols and module split remain design work.

### How a session appears in the island

Flux's session row puts a phase icon beside a body containing a provider badge and session title.
Metadata includes the terminal application when known, an elapsed timer, and a remote label when relevant.
The body may also show the latest user prompt and current activity or last assistant message.
Follow-up and delete controls are conditional parts of the row.

The renderer filters the list before sorting visible sessions by latest update. Pending approvals and questions remain visible;
child sessions are excluded from the top-level list. Hook-managed ended sessions are hidden by the inspected filter,
and other visibility conditions vary by provider, prompt availability and completion dismissal.
An actionable item can scroll into view, with that automatic scrolling suppressed while a follow-up editor is open.

The elapsed timer in this renderer measures from session creation. It updates once per second while the phase differs
from `completed`, then uses the session's update timestamp as the endpoint. Our accepted card timer instead measures the
observed prompt turn. These are different measurements; importing the visual timer must not change its meaning.

Notch-pet keeps provider/project/session identity, explicit state and the turn timer as the compact hierarchy.
Its normal observations omit prompts, commands and assistant messages. Same-folder sessions remain distinguishable,
and ended/unknown states and retained notices follow our shared-store rules rather than Flux's visibility filter.

### What happens when an agent needs approval

Flux presents a dedicated approval card with the tool name and request details. Where supplied, it can show code differences.
For a bridge-handled request, the card exposes deny and allow-once actions. An additional persistent approval choice is
conditional on permission suggestions or a special plan-mode case; it is not a universal button for all requests.

Some requests have an external approval mode. Terminal-native and cloud-agent modes direct the user to the owning interface
instead of offering local approval buttons. The coordinator rejects ordinary local bridge approval/denial for those modes.
Thus an approval card is not evidence that Flux can approve that provider's request from the island.

Our accepted scope is approve once or deny an exact supported local request. Before a button becomes available,
the provider/version needs a verified response channel and request identity. Pending submission, acknowledged delivery,
timeout and an uncertain outcome need distinct feedback. Showing an alert or clicking a button cannot by itself confirm
that the agent resumed. Necessary request details belong to the separate action contract, not routine observation logs.

### How questions and follow-ups work

Flux's structured-question card supports multiple questions, single- or multiple-choice answers and, for selected providers,
custom text. It builds a structured answer from the question and option positions. Cancel and terminal-return paths also exist.
The inspected UI sends Codex, Kimi, Hermes and Copilot CLI question handling back to the CLI; custom input is enabled for
Claude, OpenCode and Sara in that component. Do not generalize the rendered controls into uniform provider support.

Follow-up text uses a separate editor for an existing completed session. In the inspected local terminal path, eligibility
requires Claude or Codex, a nonremote jump target, and suitable tmux, iTerm or Apple Terminal targeting metadata.
The editor disables submission while sending, requires nonempty text, supports Escape to cancel and Command/Control-Return
to send, and keeps an error visible if delivery fails. Draft reset follows session identity.

Notch-pet can adapt the explicit composer, draft ownership and progress/error feedback. Its accepted scope excludes terminal
keystroke injection; a supported provider response mechanism must be established independently. Missing navigation should not
disable a separately verified action channel. An incoming alert never requests keyboard focus; opening an editor is explicit intent.

### How usage fits beside sessions

Flux has a quota service separate from token statistics. Codex quota refresh uses an App Server connection with update handling
and refresh/retry logic. Claude quota uses a status-line cache, with a separately managed wrapper around the existing status line.
The quota service supplies a provider map to presentation; token statistics have a different service and units.

Adapt the service ownership and failure recovery, preserving actual provider windows, reset timestamps, freshness and account
confidence. A percentage needs an explicit used/remaining meaning. Token totals cannot establish subscription allowance,
and the number of sessions must not multiply an account's limits. Our active-provider strip is a compact presentation of quota,
not a requirement to reproduce Flux's entire statistics interface.

### How the pet and island relate

Flux has separate island and pet windows. Entering pet mode hides the island and sends visible session information to the pet.
Dragging the pet so its bounds overlap the island's location restores the island. The app's bridge, quota and reconciliation
services start in the ordinary coordinator path; changing surfaces does not demonstrate pet-only service isolation.

Our accepted drag-out/overlap-return behavior remains with `pets/detachable-pet`. Under the later modular-feature decision,
a user who installs only Pet must be able to use a desktop pet without installing Notch or Agents. Overlap-return applies only
when the Notch feature is installed. The independent desktop placement and fallback behavior still need feature planning.

### Scenarios to implement from this reference

These are planning examples, not additional approved implementation tasks:

1. **Pet only:** choose Pet; show the desktop companion and its controls. No session receiver, quota process, provider probe
   or agent setup is needed. The feature manager stays reachable even with every optional surface removed.
2. **First agent:** install Agents and connect a supported provider. Show setup/health evidence separately from the first
   observed session. Add Notch only if the user wants that presentation surface; do not silently install it for Pet.
3. **Two sessions in one project:** show separate identities, preserve selection during updates and place a confirmed request
   ahead of routine activity without losing access to the other session.
4. **Action unavailable:** keep the request and its actual state visible, explain the capability gap and offer verified navigation
   or manual-return guidance. A disabled or absent action is preferable to a control that cannot reach the provider.
5. **Connection lost:** retain unconfirmed requests and report unknown evidence. Do not convert silence into completion.
6. **Feature removed:** close its surfaces, cancel owned work and remove its shortcuts. Preserve preferences for reinstall;
   handle owned hook cleanup and unresolved notices through an explicit removal contract.

### Where this belongs in notch-pet

| Behavior | Existing owner | Status of the reference |
| --- | --- | --- |
| Connect, repair and owned hook removal | [Codex setup](../specs/sessions/codex-setup.md) | Accepted setup direction; detailed task/qualification gates remain |
| Configuration versus delivery evidence | [Integration health](../specs/sessions/integration-health.md) | Retain separate evidence and actionable messages |
| Cards, turn timers, compact usage | [Session cards](../specs/notch/session-cards.md), [allowance strip](../specs/notch/allowance-strip.md) | Feature PRs contain implementation; reference is not new acceptance |
| Focus, selection and session visibility | [Session island](../specs/notch/session-island.md) | Existing acceptance remains open |
| Approve, answer and explicitly send | [Actions](../specs/actions/area.md) | Accepted scope; provider channels and implementations remain planned |
| Pet detachment and return | [Pets](../specs/pets/area.md) | Accepted interaction; implementation remains planned |
| Install/uninstall optional features in Settings | [D7](../DECISIONS.md#d7-install-and-uninstall-features-from-settings), [Settings](../specs/settings/area.md) | Newly accepted product behavior; no implementation task approval |

### Source anchors for a later reinspection

These are archive-relative paths and symbols, not dependencies on this Mac's temporary files.
The version and archive hash above identify the inspected build.

| Archive entry | Inspection-time location | Evidence |
| --- | --- | --- |
| `out/main/index.js` | `hookManagers`, line 58935; `CustomAgentRegistry`, line 46942 | Setup registry and dynamic custom identities |
| `out/main/index.js` | `GenericCustomAdapter`, line 37412; `BridgeServer`, line 39135 | Custom event translation and separate pending permissions/questions |
| `out/main/index.js` | `getHookStatus`, line 60386; `installHook`, line 60402; `uninstallHook`, line 60425 | Health, setup result and removal entry points |
| `out/main/index.js` | `approveSession`, line 59935; `answerSession`, line 59971 | Mode-specific response dispatch |
| `out/main/index.js` | `QuotaService`, line 47476; `loadClaudeQuota`, line 47104 | Quota ownership and provider-specific reads |
| `out/renderer/assets/IslandPanel-DSRHjja3.js` | `isVisibleInIsland`, line 6; `useActionable`, line 43; `useElapsed`, line 472; `SessionRow`, line 484 | Filtering, selection-related scrolling and row content |
| Same renderer entry | Approval card around line 940; question card around line 1020; follow-up editor around line 1280 | Capability-specific request and composer interactions |

Future feature descriptions should state the visible hierarchy, trigger, resulting action, failure/unavailable state,
and the owner in our app. A reference consisting only of “like Flux Island” is insufficient for implementation elsewhere.

## Observed behavior worth adapting

### Reversible setup and useful connection health

`out/main/index.js` contains `ClaudeHookManager` around line 41475 and `CodexHookManager` around line 42316.
They implement installation/removal, app-managed configuration, manifests, and integration checks.
Claude quota setup includes an existing-status-line wrapper; Codex setup also manages feature/trust configuration.

Adapt installation ownership, idempotence, removal that preserves other settings, and actionable health messages.
Retain our explicit hook trust review; do not import trust-bypass behavior or assume Flux's version gates apply to the installed agents here.
Separate configured, receiver available, and delivery observed so a quiet session is not mislabeled disconnected.
Tasks I2–I6 cover this work. It does not require expanding our one-way event protocol.

### Session picker and window behavior

`IslandWindow` around line 24828 creates a transparent Electron window, uses all-workspace/fullscreen visibility,
mouse passthrough, and a native `fixPanel` helper.
`PetWindow` around line 25462 owns a separate transparent pet surface.
`enterPetMode` around line 59404 sends the current visible sessions to the pet;
`tryReturnToIsland` around line 59430 returns it when pet and notch rectangles overlap.

Adapt the accessible session picker, retained selection, transparent inactive regions, drag-out/overlap-return interaction,
and a menu-bar recovery action. Implement those behaviors using supported SwiftUI/AppKit APIs and the existing shared stores.
Do not assume Electron's native helper implementation or window constants transfer to AppKit.
Tasks I1, N1–N6, P1–P2, and R1–R4 cover the visible workflow and physical desktop checks.

### Local approvals and replies

Flux's `BridgeServer` around line 39135 supports pending questions/permissions and directives returned to hooks.
`approveSession` around line 59935 supports selected modes; terminal-native/cloud modes have different handling.
`answerSession` around line 59971 returns structured answers.
The renderer's `canContinueSessionViaTerminalPrompt` supports follow-up text only for selected local terminal/session combinations.

The user accepted adapting the ability to act inside the app: approve once/deny, answer a question, and explicitly send follow-up text.
Tasks A1–A8 verify our providers' mechanisms before choosing the action-channel structure and implementing those controls.
This does not establish feature parity with every Flux adapter or authorize terminal keystroke injection as a fallback.
Keep our lifecycle helper one-way and bounded; interaction has a separate identity/acknowledgement/cancellation contract.

### Optional sprite-sheet compatibility

`out/renderer/assets/pet-H4m9z7If.js` around lines 31–38 defines seven rows:
`idle`, `play`, `sleep`, `running`, `attention`, `complete`, `drag`.
Around line 127 it derives square cells from image height divided by seven;
around line 136 it samples alpha to locate each row's final frame.
The main bundle's sprite path logic around line 61256 supports a user-supplied PNG override.

Adapting that input layout can make user-authored artwork easier to import. ^[inferred]
It does not require using Flux's artwork or replacing our accepted manifest/frame runtime format.
The proposed choice is conversion at import versus a second runtime loader; it remains open in the spec.
Define full validation, deterministic frame detection, resource bounds, and rollback independently.
Tasks P5–P6 cover the choice and conditional implementation, with independently created fixtures.

### Independent quota refresh

`QuotaService` around line 47476 uses a Codex App Server connection, update notifications, retries, and refresh scheduling.
`CodexAppServerClient.start` around line 47319 opens a stdio App Server connection.
`loadClaudeQuota` around line 47104 reads a status-line cache; the Claude wrapper is managed separately.
Flux also has token statistics, separate from quota, in `StatsService` around line 30665.

Adapt independent refresh/cancellation/reconnect/backoff and preserving the user's status-line output.
Retain our supported-interface restriction, full bucket map, separate account confidence and timestamps, and explicit stale/unavailable states.
Flux's inspected quota normalization uses daily/weekly slots and transcript fallback; those are not additions to our plan.
Tasks U1–U6 cover the compatible behavior without conversation turns, credential copying, or private endpoints.

## Existing choices to retain

- **Native presentation:** SwiftUI/AppKit remains accepted after considering Electron/React. This choice alone does not prove better CPU or memory usage.
- **Separate responsibilities:** agent adapters, terminal navigation, usage providers, shared stores, and window controllers remain distinct. Both surfaces use one session authority.
- **Bounded observation delivery:** both apps use Unix sockets and newline JSON, but our existing helper keeps one-way, bounded, silent observations. New user actions require a separate verified response mechanism and contract.
- **Conservative evidence:** preserve event identity/order checks, bounded memory, unknown state, retained unconfirmed requests, and terminal restrictions. Missing events cannot establish completion.
- **Content minimization:** lifecycle integration continues to forward allowlisted metadata without prompts, command input, transcript reading, or credential inspection. Necessary request details and user replies remain transient action data outside routine logs.
- **Otty first:** exact-pane validation is a primary release requirement. The inspected Flux main bundle had no `otty` match; that establishes no explicit adapter there, not proof that every generic fallback fails.
- **Simple storage:** sessions stay in memory, preferences in UserDefaults, assets in Application Support. Quota display does not introduce a database.
- **Local scope:** local approvals and replies are now included. SSH/cloud integrations are optional future work; terminal keystroke injection and Feishu forwarding remain excluded.

## Behaviors not adopted

Do not adopt Flux's entire control protocol or assume action support from observed lifecycle hooks.
The accepted scope expansion adds user-facing local actions; its response-channel design and supported combinations still require A1–A2 verification.

Flux's `ClaudeTranscriptWatcher` around line 37652, `ProcessMonitor` around line 48028,
and reconciliation around line 60899 supplement hooks with transcripts, process checks, and timeout heuristics.
In the inspected paths, quiet Claude sessions can become completed after 120 seconds and certain Codex sessions after 180 seconds.
Those fallbacks are not adopted: silence and process existence do not establish an agent response or task result.
Any future source of additional lifecycle evidence needs a separate compatibility investigation and contract decision.

Flux writes recent session snapshots through `saveSessions` around line 40862, but calls `saveSessions([])` at startup around line 58972.
The inspection therefore does not establish restoration of old snapshots into live sessions.
Our restart behavior continues to require fresh evidence.

## Pet comparison refreshed, 2026-10-30

The installed app is still version `0.1.25`, with the same archive SHA-256 recorded above.
Selected packaged JavaScript was re-extracted into `/private/tmp/notch-pet-flux-review/` for read-only inspection.
No app launch, credential/configuration-file inspection, build, runtime benchmark, or code reuse occurred.

The internal [pet customization guide](https://bytedance.larkoffice.com/wiki/NzngwydZGihADLkW6picsbATnqf)
documents a built-in default appearance and externally generated replacement `usagi.png` files.
Artwork generation belongs to the external `flux-double-pet` skill, not the pet renderer.
The [product guide's pet-mode section](https://bytedance.larkoffice.com/wiki/YeuYwd83siaJlrkC49bcR7pMnic#ByVxdFhDSoksJoxLSYWcUh0knTg)
documents dragging out the icon and dragging it back to the island.

Reconfirmed packaged behavior:

- `out/renderer/assets/pet-H4m9z7If.js:31` defines the seven sprite rows. `derivePetStatus` at line 57 prioritizes attention, running, then complete. The renderer slices the PNG onto an HTML canvas and advances frames at 90, 120, or 150 ms intervals.
- The same renderer falls back to bundled artwork on an image-load error. Empty optional rows do not fall back to the idle pose: their frame count becomes one, which can render transparent pixels. The animation effect continues to schedule a timer for a single frame; no visibility or Reduce Motion gate was found in this pet renderer.
- `out/main/index.js:61256` resolves a user PNG override before the packaged default. `initSpriteDirs` seeds the user directory from the bundled asset when needed.
- `PetWindow` at line 25462 provides a separate transparent Electron window, mouse passthrough, drag movement, and a session panel. `enterPetMode` at line 59404 hides the island and supplies the current sessions. `tryReturnToIsland` at line 59430 compares the pet canvas rectangle with the island rectangle and restores the island on overlap.
- The coordinator at line 59242 starts the bridge, quota service, process monitor, and reconciliation in the ordinary startup path. Entering pet mode changes presentation; it does not establish a service-free pet startup path.

At the comparison point, before the subsequent rabbit implementation, local code had a SwiftUI/AppKit session island, the event bridge, shared session state, and usage infrastructure.
`Package.swift` has no pet target, and `Resources/` has no pet artwork.
`BridgeAppDelegate.applicationDidFinishLaunching` starts the bridge and island;
`NotchUsageView.refreshCodex` owns a view-triggered refresh loop.
The independent pet module, pet rendering, setup/settings, size persistence, detachment/return, and pet-only startup remain unimplemented.
This records the pre-implementation static comparison, not current runtime acceptance or a numerical completion estimate. The later pet implementation and remaining acceptance are recorded in [built-in-pet](../specs/pets/built-in-pet.md#implementation-checkpoint-2026-10-30).

The user reaffirmed pet-first startup with optional agent services and accepted drag-out/hide plus overlap-to-return.
The accepted behavior is recorded in [pets area decisions](../specs/pets/area.md#decisions).
Its implementation remains with `detachable-pet`; the comparison itself changed no BP or source task checkbox.

## Planning outcome

The spec retains the user's existing single-spec layout and completed foundation tasks.
Remaining work is grouped into bridge verification, setup/visible sessions, Otty/notch, local actions/replies, pet imports, usage, and desktop acceptance.
New tasks are proposed for review; choosing to update the plan does not complete verification or accept the open sprite-format choice.
The helper maximum-input/deadline failure remains the first implementation blocker.
The earlier reference-model and socket-boundary test corrections remain separate proposed follow-ups.
