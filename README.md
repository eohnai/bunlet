# Bunlet

A small macOS companion for Codex CLI and Claude Code. Keep a pet on your desktop, follow coding sessions in the notch, and see your remaining usage allowance alongside your sessions.

Built with SwiftUI and AppKit. Agent monitoring uses local hooks, so you can keep using your preferred terminal. Pet, Notch and Agents can each be enabled independently.

## What it does

- Keep a desktop pet that reacts to working sessions, requests needing attention and finished responses.
- Drag the pet around your desktop and return it to the notch through overlap or the menu bar.
- See separate session cards with provider badges, project names, timers and pending requests.
- Check reported usage limits and reset countdowns for active providers.
- Approve or deny Claude Code requests, answer structured questions and send feedback through its waiting response hook.
- Customize your pet with a transparent PNG, an animated sprite sheet or a folder of PNG frames.

## Run from source

Requires macOS 14 or later and Swift 6. Install Xcode or Apple's Command Line Tools, then run this from the repository root:

```bash
bash scripts/run.sh
```

The script builds and opens `Bunlet.app` under `${TMPDIR:-/private/tmp}/notch-pet-dev`. The app lives in the menu bar and has no Dock icon. Click the paw icon to open Settings, show the pet or open sessions.

Fresh installations start with Pet. Open **Settings > Features** to add Notch or Agents and choose the parts you want to use.

To build without opening the app:

```bash
bash scripts/run.sh --build-only
```

The command prints the app bundle's path. Build output goes to stderr. Quit the running app before rebuilding.

## Connect your agents

1. Open **Settings > Features** and install Agents. Add Notch if you want session cards and usage limits in the island.
2. Choose Codex or Claude Code on the Agents page and select **Connect**. Complete the agent's normal workspace and hook review.
3. For Claude usage limits, select **Connect quota**. To respond to Claude requests from the app, select **Connect actions**.
4. Open your coding agent in your preferred terminal.

Setup currently recognizes Codex `0.164.0` and Claude Code `2.1.306`.

Each provider has Check, Repair, Pause/Resume and Disconnect controls. Pause stops monitoring while keeping the setup in place. Disconnect removes the app-managed integration. Setup preserves unrelated hooks and settings, including an existing Claude status line.

Claude follow-up feedback is available during the waiting Stop hook's 60-second window. After that window, continue in the terminal. Local response controls are currently available for Claude Code.

## Return to your terminal

Choose a terminal application in Settings to activate its running instance. Session monitoring and pet reactions work independently of this navigation setting.

For iTerm2, select the intended pane, return to its session card and choose **Link Current Pane**. You can then use **Focus Linked Pane** to return to it. Other terminals use application activation followed by manual pane selection.

## Make the pet yours

Pet settings includes artwork selection, size, sound and a way to restore the built-in rabbit.

- **Animate PNG** adds breathing, bobbing and tilt to a transparent image.
- **Import Sprite Sheet** reads seven rows of animation frames in this order: idle, play, sleep, running, attention, complete and drag.
- **Import Pet Pack** loads a folder containing `manifest.json` and its named PNG frames. See the [pet pack format](docs/contracts/pet-workflows.md).

Imported artwork stays in Application Support. Missing optional animations use idle artwork, and an unsuccessful import keeps the current pet selected.

## Development

The Swift package has no external dependencies. The app owns session state and provider services, while the Pet module handles artwork and playback.

Run the Swift tests with full Xcode selected:

```bash
env DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  swift test --scratch-path /private/tmp/notch-pet-dev/build
```

For the local bridge checks, build the bundle first and quit the app before running:

```bash
python3 scripts/check-event-bridge.py
python3 scripts/check-event-contract.py
```

The bridge checks use fictional input and temporary local files. They do not install provider hooks.

For implementation details, see the [architecture](docs/ARCHITECTURE.md) and [event format](docs/contracts/agent-events-v1.md).
