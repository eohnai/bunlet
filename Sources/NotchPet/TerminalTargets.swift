import AppKit
import EventBridge
import Foundation
import SessionState

/// Jumps to and types into the terminal a hook reported (decision 0025).
/// Commands run without a shell and with a short deadline; text is passed as one argument, never interpreted.
enum TerminalTargets {
    static let ottyBundleID = "io.appmakes.otty"
    static let appleTerminalBundleID = "com.apple.Terminal"
    static let itermBundleID = "com.googlecode.iterm2"
    static let weztermBundleID = "com.github.wez.wezterm"
    static let kittyBundleID = "net.kovidgoyal.kitty"
    static let deadlineSeconds = 3.0
    static let tmuxCandidates = ["/opt/homebrew/bin/tmux", "/usr/local/bin/tmux", "/usr/bin/tmux", "/run/current-system/sw/bin/tmux"]

    enum JumpResult: Equatable {
        /// The exact pane, tab or window was selected.
        case exact
        /// Only the terminal's app was brought forward; the user picks the pane.
        case application
    }

    /// Brings the session's own pane, tab or window forward, else its app (decision 0026). Nil means nothing did.
    @MainActor
    static func jump(_ terminal: HookEnvelopeV1.Terminal, projectPath: String?) async -> JumpResult? {
        guard terminal.isValid else { return nil }
        if await exact(terminal, projectPath: projectPath) { return .exact }
        if let app = terminal.hostApp, activate(bundleID: app) { return .application }
        return nil
    }

    @MainActor
    private static func exact(_ terminal: HookEnvelopeV1.Terminal, projectPath: String?) async -> Bool {
        switch terminal.kind {
        case .otty:
            guard let cli = bundledTool(ottyBundleID, "otty-cli") else { return false }
            guard await run(cli, ["pane", "focus", "--pane", terminal.paneSelector, "--quiet"]) else { return false }
            return activate(bundleID: ottyBundleID)
        case .tmux:
            guard let tmux = tmuxExecutable(), let socket = terminal.socket else { return false }
            guard await run(tmux, ["-S", socket, "select-window", "-t", terminal.paneSelector]),
                  await run(tmux, ["-S", socket, "select-pane", "-t", terminal.paneSelector]) else { return false }
            // The terminal showing this tmux session now, else the one tmux was started from.
            if let client = await tmuxClientApplication(tmux, socket: socket, pane: terminal.paneSelector) {
                _ = client.activate(options: [])
            } else if let app = terminal.app {
                _ = activate(bundleID: app)
            }
            return true
        case .appleTerminal:
            guard running(appleTerminalBundleID) != nil else { return false }
            return await appleScriptSelect(appleTerminalSelect(tty: terminal.paneSelector))
        case .iterm:
            guard running(itermBundleID) != nil else { return false }
            return await appleScriptSelect(itermSelect(session: terminal.paneSelector))
        case .wezterm:
            guard let cli = bundledTool(weztermBundleID, "wezterm"),
                  await run(cli, ["cli", "activate-pane", "--pane-id", terminal.paneSelector]) else { return false }
            return activate(bundleID: weztermBundleID)
        case .kitty:
            // Needs kitty's remote control; without it the command fails and only the app is activated.
            guard let socket = terminal.socket,
                  let cli = bundledTool(kittyBundleID, "kitten") ?? bundledTool(kittyBundleID, "kitty"),
                  await run(cli, ["@", "--to", "unix:" + socket, "focus-window", "--match", "id:" + terminal.paneSelector])
            else { return false }
            return activate(bundleID: kittyBundleID)
        case .editor:
            guard let projectPath, projectPath.hasPrefix("/"),
                  let app = NSWorkspace.shared.urlForApplication(withBundleIdentifier: terminal.paneSelector) else { return false }
            let configuration = NSWorkspace.OpenConfiguration()
            configuration.activates = true
            // Opening a folder the editor already has open brings that window forward.
            return (try? await NSWorkspace.shared.open([URL(fileURLWithPath: projectPath, isDirectory: true)],
                                                       withApplicationAt: app, configuration: configuration)) != nil
        case .app:
            return false
        }
    }

    /// Types one line and presses Return in an addressable pane. The caller checks TerminalPolicy first.
    static func type(_ line: String, into terminal: HookEnvelopeV1.Terminal) async -> Bool {
        guard TerminalPolicy.addressable(terminal), let text = TerminalPolicy.singleLine(line) else { return false }
        switch terminal.kind {
        case .otty:
            guard let cli = await bundledTool(ottyBundleID, "otty-cli") else { return false }
            // Otty reads C-style escapes such as \x03 in a text argument; --from-file sends the bytes verbatim.
            guard let file = privateTextFile(text) else { return false }
            defer { try? FileManager.default.removeItem(at: file) }
            guard await run(cli, ["pane", "send-text", "--pane", terminal.paneSelector, "--quiet", "--from-file", file.path])
            else { return false }
            return await run(cli, ["pane", "send-keys", "--pane", terminal.paneSelector, "--quiet", "key:Enter"])
        case .tmux:
            guard let tmux = tmuxExecutable(), let socket = terminal.socket else { return false }
            // -l sends the text literally, so words such as "Enter" or "C-c" are not read as key names.
            guard await run(tmux, ["-S", socket, "send-keys", "-t", terminal.paneSelector, "-l", "--", text]) else { return false }
            return await run(tmux, ["-S", socket, "send-keys", "-t", terminal.paneSelector, "Enter"])
        case .appleTerminal, .iterm, .wezterm, .kitty, .editor, .app:
            return false
        }
    }

    // MARK: Helpers

    /// A user-only file in the per-user temporary folder, removed by the caller right after sending.
    static func privateTextFile(_ text: String) -> URL? {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("bunlet-reply-\(UUID().uuidString)")
        guard FileManager.default.createFile(atPath: url.path, contents: Data(text.utf8),
                                             attributes: [.posixPermissions: 0o600]) else { return nil }
        return url
    }

    /// A program shipped inside a running app, such as `otty-cli` or `wezterm`. Never one found on the PATH.
    @MainActor
    static func bundledTool(_ bundleID: String, _ name: String) -> URL? {
        guard let bundle = running(bundleID)?.bundleURL else { return nil }
        let tool = bundle.appendingPathComponent("Contents/MacOS/\(name)")
        return FileManager.default.isExecutableFile(atPath: tool.path) ? tool : nil
    }

    static func tmuxExecutable() -> URL? {
        tmuxCandidates.first { FileManager.default.isExecutableFile(atPath: $0) }.map { URL(fileURLWithPath: $0) }
    }

    @MainActor
    static func running(_ bundleID: String) -> NSRunningApplication? {
        NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).first { !$0.isTerminated }
    }

    @MainActor
    static func activate(bundleID: String) -> Bool {
        running(bundleID)?.activate(options: []) ?? false
    }

    /// Exit status zero within the deadline. Output is discarded; nothing is logged.
    static func run(_ executable: URL, _ arguments: [String]) async -> Bool {
        await Task.detached(priority: .userInitiated) { runBlocking(executable, arguments, capture: false) != nil }.value
    }

    /// Standard output (at most 64 KB) of a command that exits zero within the deadline.
    static func output(_ executable: URL, _ arguments: [String]) async -> String? {
        await Task.detached(priority: .userInitiated) {
            runBlocking(executable, arguments, capture: true).map { String(decoding: $0, as: UTF8.self) }
        }.value
    }

    private static let outputLimit = 65_536

    private static func runBlocking(_ executable: URL, _ arguments: [String], capture: Bool) -> Data? {
        let process = Process()
        process.executableURL = executable
        process.arguments = arguments
        process.standardInput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        let pipe = Pipe()
        process.standardOutput = capture ? pipe : FileHandle.nullDevice
        let finished = DispatchSemaphore(value: 0)
        process.terminationHandler = { _ in finished.signal() }
        do { try process.run() } catch { return nil }
        // Output beyond the pipe's buffer stalls the command until the deadline, which then fails it;
        // the commands read here print a few short lines.
        if finished.wait(timeout: .now() + deadlineSeconds) == .timedOut {
            process.terminate()
            return nil
        }
        guard process.terminationStatus == 0 else { return nil }
        guard capture else { return Data() }
        let reader = pipe.fileHandleForReading
        defer { try? reader.close() }
        guard let data = try? reader.read(upToCount: outputLimit + 1) ?? Data(), data.count <= outputLimit else { return nil }
        return data
    }

    // MARK: tmux clients

    /// The app showing the pane's tmux session: its clients, most recently active first, walked up to their app.
    @MainActor
    static func tmuxClientApplication(_ tmux: URL, socket: String, pane: String) async -> NSRunningApplication? {
        guard let listing = await output(tmux, ["-S", socket, "list-clients", "-t", pane, "-F", "#{client_activity} #{client_pid}"])
        else { return nil }
        for pid in tmuxClients(listing) {
            if let app = application(containing: pid) { return app }
        }
        return nil
    }

    /// Parses `activity pid` lines into pids, most recently active first. Malformed lines are skipped.
    static func tmuxClients(_ listing: String) -> [pid_t] {
        listing.split(separator: "\n").compactMap { line -> (Int64, pid_t)? in
            let parts = line.split(separator: " ")
            guard parts.count == 2, let activity = Int64(parts[0]), let pid = pid_t(parts[1]), pid > 1 else { return nil }
            return (activity, pid)
        }.sorted { $0.0 > $1.0 }.map(\.1).prefix(16).map { $0 }
    }

    /// The nearest regular app among a process and its parents.
    @MainActor
    static func application(containing pid: pid_t, depth: Int = 12) -> NSRunningApplication? {
        var current = pid
        for _ in 0..<depth {
            guard current > 1 else { return nil }
            if let app = NSRunningApplication(processIdentifier: current), app.activationPolicy == .regular, !app.isTerminated {
                return app
            }
            guard let next = TerminalDetection.parent(of: current), next != current else { return nil }
            current = next
        }
        return nil
    }

    /// Selects the Terminal tab whose tty matches. The tty is validated as `/dev/ttysNNNN`, so it is safe in the script.
    static func appleTerminalSelect(tty: String) -> String? {
        guard HookEnvelopeV1.Terminal(kind: .appleTerminal, paneSelector: tty).isValid else { return nil }
        return """
        tell application id "\(appleTerminalBundleID)"
            repeat with w in windows
                repeat with t in tabs of w
                    if tty of t is "\(tty)" then
                        set selected of t to true
                        set index of w to 1
                        activate
                        return true
                    end if
                end repeat
            end repeat
        end tell
        return false
        """
    }

    /// Selects the iTerm2 session with this unique id. The id is validated as a UUID, so it is safe in the script.
    static func itermSelect(session: String) -> String? {
        guard HookEnvelopeV1.Terminal(kind: .iterm, paneSelector: session).isValid else { return nil }
        return """
        tell application id "\(itermBundleID)"
            repeat with w in windows
                repeat with t in tabs of w
                    repeat with s in sessions of t
                        if unique id of s is "\(session)" then
                            select w
                            select t
                            select s
                            activate
                            return true
                        end if
                    end repeat
                end repeat
            end repeat
        end tell
        return false
        """
    }

    /// Runs a selection script; true only when it reports that it found the target.
    static func appleScriptSelect(_ source: String?) async -> Bool {
        guard let source else { return false }
        return await Task.detached(priority: .userInitiated) {
            var error: NSDictionary?
            let result = NSAppleScript(source: source)?.executeAndReturnError(&error)
            return error == nil && result?.booleanValue == true
        }.value
    }
}
