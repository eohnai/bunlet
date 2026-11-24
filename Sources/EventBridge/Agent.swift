import Foundation

public enum Agent: String, Codable, CaseIterable, Sendable {
    /// Cursor CLI observation only (decision 0025): no local actions, usage limits or subagents.
    case codex, claude, cursor

    public var displayName: String {
        switch self {
        case .codex: "Codex"
        case .claude: "Claude Code"
        case .cursor: "Cursor CLI"
        }
    }

    /// The command-line program Bunlet looks for.
    public var executableName: String {
        switch self {
        case .codex: "codex"
        case .claude: "claude"
        case .cursor: "cursor-agent"
        }
    }

    /// An npm-installed Codex launcher requires Node on PATH even when run by absolute path.
    public func launchEnvironment(for executable: URL, inheriting environment: [String: String] = ProcessInfo.processInfo.environment) -> [String: String] {
        guard self == .codex, executable.isFileURL else { return environment }
        let bin = executable.deletingLastPathComponent()
        guard !bin.path.contains(":"), FileManager.default.isExecutableFile(atPath: bin.appendingPathComponent("node").path) else {
            return environment
        }
        var updated = environment
        let path = environment["PATH"] ?? "/usr/bin:/bin:/usr/sbin:/sbin"
        updated["PATH"] = "\(bin.path):\(path)"
        return updated
    }

    /// The configuration folder in the home directory, and the variable that overrides it, if any.
    public var configurationFolder: String {
        switch self {
        case .codex: ".codex"
        case .claude: ".claude"
        case .cursor: ".cursor"
        }
    }

    public var configurationOverrideVariable: String? {
        switch self {
        case .codex: "CODEX_HOME"
        case .claude: "CLAUDE_CONFIG_DIR"
        case .cursor: nil
        }
    }

    /// The file that holds this agent's hooks.
    public var hookConfigurationName: String {
        self == .claude ? "settings.json" : "hooks.json"
    }

    /// Whether `--version` output names a version in this agent's own format.
    /// Claude uses `1.2.3`, Codex can append a prerelease, and Cursor CLI uses a dated build.
    public func isVersion(_ value: String) -> Bool {
        switch self {
        case .codex, .claude:
            guard value.utf8.count <= (self == .codex ? 64 : 32) else { return false }
            let release = value.split(separator: "-", maxSplits: 1, omittingEmptySubsequences: false)
            guard let core = release.first else { return false }
            let parts = core.split(separator: ".", omittingEmptySubsequences: false)
            guard parts.count == 3, parts.allSatisfy({
                !$0.isEmpty && $0.utf8.allSatisfy { (48...57).contains($0) }
            }) else { return false }
            guard release.count == 2 else { return true }
            let prerelease = release[1].split(separator: ".", omittingEmptySubsequences: false)
            guard self == .codex, let channel = prerelease.first, ["alpha", "beta", "rc"].contains(channel) else { return false }
            return prerelease.dropFirst().allSatisfy { part in
                !part.isEmpty && part.utf8.allSatisfy { (48...57).contains($0) }
            }
        case .cursor:
            let pieces = value.split(separator: "-", maxSplits: 1, omittingEmptySubsequences: false)
            guard value.utf8.count <= 64, pieces.count == 2 else { return false }
            let date = pieces[0].split(separator: ".", omittingEmptySubsequences: false)
            let digits = { (part: Substring, count: Int) in part.utf8.count == count && part.utf8.allSatisfy { (48...57).contains($0) } }
            return date.count == 3 && digits(date[0], 4) && digits(date[1], 2) && digits(date[2], 2) &&
                (6...40).contains(pieces[1].utf8.count) &&
                pieces[1].utf8.allSatisfy { (48...57).contains($0) || (97...102).contains($0) }
        }
    }
}
