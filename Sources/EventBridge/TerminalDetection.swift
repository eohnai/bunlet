import Darwin
import Foundation

/// Decides where an agent runs from the hook's inherited environment (decisions 0025 and 0026).
/// Pure apart from the tty and host-app lookups, which callers pass in. An unusable value yields no terminal,
/// so a strange environment never drops the lifecycle event itself.
public enum TerminalDetection {

    /// The environment variables the observer helper reads. Nothing else is copied out of the environment.
    public static let variables = ["TMUX", "TMUX_PANE", "OTTY_PANE_ID", "TERM_PROGRAM", "__CFBundleIdentifier",
                                   "ITERM_SESSION_ID", "WEZTERM_PANE", "KITTY_WINDOW_ID", "KITTY_LISTEN_ON"]

    public static func terminal(environment: [String: String], tty: () -> String?,
                                host: () -> String? = { nil }) -> HookEnvelopeV1.Terminal? {
        let inherited = environment["__CFBundleIdentifier"].flatMap { HookEnvelopeV1.Terminal.bundleIdentifier($0) ? $0 : nil }
        func valid(_ candidate: HookEnvelopeV1.Terminal) -> HookEnvelopeV1.Terminal? { candidate.isValid ? candidate : nil }
        // tmux runs inside another terminal, so its pane is the most exact address and is checked first.
        if let pane = environment["TMUX_PANE"], let server = environment["TMUX"],
           let socket = server.split(separator: ",", maxSplits: 1, omittingEmptySubsequences: false).first.map(String.init),
           let found = valid(.init(kind: .tmux, paneSelector: pane, socket: socket, app: inherited)) {
            return found
        }
        if let pane = environment["OTTY_PANE_ID"], let found = valid(.init(kind: .otty, paneSelector: pane)) {
            return found
        }
        // `w0t0p0:6A0E…`: the part after the colon is the session's unique id.
        if let session = environment["ITERM_SESSION_ID"], let id = session.split(separator: ":").last,
           let found = valid(.init(kind: .iterm, paneSelector: String(id))) {
            return found
        }
        if let pane = environment["WEZTERM_PANE"], let found = valid(.init(kind: .wezterm, paneSelector: pane)) {
            return found
        }
        // kitty can be addressed only through a listening socket; without one, only the app is known.
        if let window = environment["KITTY_WINDOW_ID"], let listen = environment["KITTY_LISTEN_ON"], listen.hasPrefix("unix:/"),
           let found = valid(.init(kind: .kitty, paneSelector: window, socket: String(listen.dropFirst("unix:".count)))) {
            return found
        }
        switch environment["TERM_PROGRAM"] {
        case "Apple_Terminal":
            if let path = tty(), let found = valid(.init(kind: .appleTerminal, paneSelector: path)) { return found }
        case "vscode":
            if let inherited, editorBundleIdentifiers.contains(inherited) {
                return HookEnvelopeV1.Terminal(kind: .editor, paneSelector: inherited)
            }
        default:
            break
        }
        // Any other terminal: the app the agent runs in, found from its parent processes.
        guard let app = host() ?? inherited else { return nil }
        return valid(.init(kind: .app, paneSelector: app))
    }

    /// Editors whose integrated terminal sets `TERM_PROGRAM=vscode` and that open a folder in its existing window.
    public static let editorBundleIdentifiers: Set<String> = [
        "com.todesktop.230313mzl4w4u92", "com.microsoft.VSCode", "com.microsoft.VSCodeInsiders", "com.vscodium"
    ]

    // MARK: Parent processes

    /// The controlling terminal of the nearest ancestor that has one, such as `/dev/ttys003`.
    /// Agents run hooks without a terminal of their own, so the helper walks up its parents (bounded).
    public static func ancestorTTY(startingAt pid: pid_t = getppid(), depth: Int = 8) -> String? {
        var current = pid
        for _ in 0..<depth {
            guard current > 1, let info = processInfo(current) else { return nil }
            let device = info.kp_eproc.e_tdev
            // NODEV (-1) and 0 mean "no controlling terminal".
            if device != -1, device != 0, let raw = devname(device, S_IFCHR) {
                return "/dev/" + String(cString: raw)
            }
            current = info.kp_eproc.e_ppid
        }
        return nil
    }

    /// The bundle identifier of the nearest ancestor that runs from an application bundle, skipping the helper's own app.
    public static func hostApplication(startingAt pid: pid_t = getppid(), depth: Int = 12) -> String? {
        let own = Bundle.main.executablePath.flatMap(outermostBundle(inExecutablePath:))
        return hostApplication(startingAt: pid, depth: depth, parent: parent(of:), executablePath: executablePath(of:)) { bundle in
            bundle == own ? nil : bundleIdentifier(atBundlePath: bundle)
        }
    }

    /// Testable core: walks `parent` up to `depth` steps and returns the first bundle `identify` names.
    static func hostApplication(startingAt pid: pid_t, depth: Int, parent: (pid_t) -> pid_t?,
                                executablePath: (pid_t) -> String?, identify: (String) -> String?) -> String? {
        var current = pid
        for _ in 0..<depth {
            guard current > 1 else { return nil }
            if let path = executablePath(current), let bundle = outermostBundle(inExecutablePath: path),
               let identifier = identify(bundle),
               HookEnvelopeV1.Terminal.bundleIdentifier(identifier) {
                return identifier
            }
            guard let next = parent(current), next != current else { return nil }
            current = next
        }
        return nil
    }

    /// `/Applications/Visual Studio Code.app/Contents/Frameworks/Code Helper.app/…` → `/Applications/Visual Studio Code.app`.
    /// The outermost bundle is the app the user sees; helper apps nest inside it.
    public static func outermostBundle(inExecutablePath path: String) -> String? {
        guard path.hasPrefix("/"), let range = path.range(of: ".app/") else { return nil }
        return String(path[..<range.lowerBound]) + ".app"
    }

    public static func parent(of pid: pid_t) -> pid_t? {
        processInfo(pid).map { $0.kp_eproc.e_ppid }
    }

    public static func executablePath(of pid: pid_t) -> String? {
        var buffer = [CChar](repeating: 0, count: 4 * Int(MAXPATHLEN))
        let length = proc_pidpath(pid, &buffer, UInt32(buffer.count))
        guard length > 0 else { return nil }
        return String(decoding: buffer.prefix(Int(length)).map { UInt8(bitPattern: $0) }, as: UTF8.self)
    }

    /// Reads only `CFBundleIdentifier` from a bounded Info.plist.
    static func bundleIdentifier(atBundlePath path: String) -> String? {
        let url = URL(fileURLWithPath: path).appendingPathComponent("Contents/Info.plist")
        guard let values = try? url.resourceValues(forKeys: [.fileSizeKey]), let size = values.fileSize, size <= 1_048_576,
              let data = try? Data(contentsOf: url),
              let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any] else { return nil }
        return plist["CFBundleIdentifier"] as? String
    }

    private static func processInfo(_ pid: pid_t) -> kinfo_proc? {
        var info = kinfo_proc()
        var size = MemoryLayout<kinfo_proc>.stride
        var name: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_PID, pid]
        guard sysctl(&name, 4, &info, &size, nil, 0) == 0, size > 0 else { return nil }
        return info
    }
}
