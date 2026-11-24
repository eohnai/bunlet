# Bunlet

A small macOS companion for Codex CLI, Claude Code, and Cursor CLI. Keep a pet on your desktop, follow coding sessions in the notch, and see your remaining usage allowance alongside your sessions.

Built with SwiftUI and AppKit. Agent monitoring uses local hooks. The pet can be docked in the notch or moved onto the desktop.

## What it does

- Keep a desktop pet that reacts to working sessions, requests needing attention and finished responses.
- Drag the pet around your desktop and return it by dropping it on the notch or using Display settings.
- See separate session cards with provider badges, project names, timers and pending requests.
- Check reported usage limits and reset countdowns for active providers.
- Approve or deny Claude Code requests, answer structured questions and send feedback through its waiting response hook.
- Customize your pet with a transparent PNG, an animated sprite sheet or a folder of PNG frames.

## Run from source

Requires macOS 14 or later and Swift 6. Install Xcode or Apple's Command Line Tools, then run this from the repository root:

```bash
bash scripts/run.sh
```

The script builds and opens `Bunlet.app` under `${TMPDIR:-/private/tmp}/notch-pet-dev`. The rabbit menu contains **Settings** and **Quit Bunlet**. Open sessions from the notch. Pet and notch recovery controls are under **Settings > Display**.

To build without opening the app:

```bash
bash scripts/run.sh --build-only
```

The command prints the app bundle's path. Build output goes to stderr. Quit the running app before rebuilding.

## Connect your agents

Open Bunlet to connect any supported CLI you have installed. Complete the provider’s normal hook review and start a new coding session.

Session monitoring starts on for all three agents. Each switch shows your monitoring preference. The line under the agent name shows whether setup or a new session is needed.

Setup works with any Claude Code or Cursor CLI version and Codex `0.129.0` or newer. Versions Bunlet has not been tested with show as "untested" in Settings.

Each provider has Check, Repair, Pause/Resume and Disconnect controls. Pause stops monitoring while keeping the setup in place. Disconnect removes the app-managed integration. Setup preserves unrelated hooks and settings, including an existing Claude status line.

Claude follow-up feedback is available during the waiting Stop hook's 60-second window. After that window, continue in the terminal. Local response controls are currently available for Claude Code.

## Return to your session

Clicking a session returns to the pane it runs in for Otty, tmux, Terminal, iTerm2, WezTerm and kitty (kitty needs remote control turned on), and to the project window in Cursor or VS Code. In any other terminal Bunlet brings the app the agent runs in to the front, and you pick the pane. Terminal and iTerm2 ask for macOS Automation approval the first time.

You can also choose a terminal application in Settings as a last fallback, or, for iTerm2, select a pane and choose **Link Current Pane** on its session card. Session monitoring and pet reactions work in any terminal.

## Make the pet yours

Pet settings includes artwork selection, size, sound and a way to restore the built-in rabbit.

- **Animate PNG** adds breathing, bobbing and tilt to a transparent image.
- **Import Sprite Sheet** reads seven rows of animation frames in this order: idle, play, sleep, running, attention, complete and drag.
- **Import Pet Pack** loads a folder containing `manifest.json` and its named PNG frames. See the [pet pack format](docs/contracts/pet-workflows.md).

Imported artwork stays in Application Support. Missing optional animations use idle artwork, and an unsuccessful import keeps the current pet selected.

## Development

The app owns session state and provider services, while the Pet module handles artwork and playback.

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
