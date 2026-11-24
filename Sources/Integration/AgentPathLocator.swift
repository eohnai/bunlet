import EventBridge
import Foundation

public enum AgentPathLocator {
    private static let searchPathByteLimit = 16_384
    private static let searchComponentLimit = 64
    private static let configurationDirectoryByteLimit = 4_096
    private static let nvmVersionLimit = 32
    private static let desktopRuntimeLimit = 32

    // Keep the existing caller policies until a separate behavior change is approved.
    public enum ExecutablePolicy: Sendable {
        case health
        case usage
    }

    public enum ExecutableLookup: Equatable, Sendable {
        case found(URL)
        case notFound
        case invalidSearchPath
    }

    public static func executable(
        agent: Agent,
        policy: ExecutablePolicy,
        searchPath: String?,
        homeDirectory: URL,
        isExecutable: (String) -> Bool = { FileManager.default.isExecutableFile(atPath: $0) },
        listDirectory: (String) -> [String] = { (try? FileManager.default.contentsOfDirectory(atPath: $0)) ?? [] },
        desktopApplication: (String) -> URL? = { _ in nil }
    ) -> ExecutableLookup {
        let defaultPath: String
        let omitsEmptyComponents: Bool
        switch policy {
        case .health:
            defaultPath = "/usr/bin:/bin:/usr/sbin:/sbin"
            omitsEmptyComponents = false
        case .usage:
            defaultPath = "/usr/local/bin:/opt/homebrew/bin:/usr/bin:/bin"
            omitsEmptyComponents = true
        }
        let path = searchPath ?? defaultPath
        guard path.utf8.count <= searchPathByteLimit else { return .invalidSearchPath }
        var directories = path.split(separator: ":", omittingEmptySubsequences: omitsEmptyComponents)
            .prefix(searchComponentLimit).map(String.init)
        // An app opened from Finder gets launchd's minimal PATH, not the user's shell PATH.
        // Search the usual per-user install locations after PATH so Connect and quota find the same agent the terminal runs.
        directories.append(contentsOf: userInstallDirectories(home: homeDirectory, listDirectory: listDirectory))
        for directory in directories where directory.hasPrefix("/") {
            let candidate = URL(fileURLWithPath: directory).appendingPathComponent(agent.executableName)
            if isExecutable(candidate.path) { return .found(candidate) }
        }
        guard let identifier = agent.desktopBundleIdentifier, let application = desktopApplication(identifier),
              application.isFileURL else { return .notFound }
        if let executable = desktopExecutable(agent: agent, application: application, home: homeDirectory,
                                              isExecutable: isExecutable, listDirectory: listDirectory) {
            return .found(executable)
        }
        return .notFound
    }

    private static func desktopExecutable(agent: Agent, application: URL, home: URL,
                                          isExecutable: (String) -> Bool, listDirectory: (String) -> [String]) -> URL? {
        switch agent {
        case .codex:
            let resources = application.appendingPathComponent("Contents/Resources", isDirectory: true)
            return ["codex-cli/bin/codex", "codex"].lazy.map { resources.appendingPathComponent($0) }
                .first { isExecutable($0.path) }
        case .claude:
            // Claude downloads its local Code runtime the first time Code is used.
            let root = home.appendingPathComponent("Library/Application Support/Claude/claude-code", isDirectory: true)
            let versions = listDirectory(root.path).filter { agent.isVersion($0) }
                .sorted { ProviderHookPolicy.compare($0, $1) == .orderedDescending }.prefix(desktopRuntimeLimit)
            for version in versions {
                let directory = root.appendingPathComponent(version, isDirectory: true)
                let builds = listDirectory(directory.path).filter { name in
                    (12...64).contains(name.utf8.count) && name.utf8.allSatisfy { (48...57).contains($0) || (97...102).contains($0) }
                }.sorted().prefix(desktopRuntimeLimit)
                for build in builds {
                    let executable = directory.appendingPathComponent("\(build)/claude.app/Contents/MacOS/claude")
                    if isExecutable(executable.path) { return executable }
                }
            }
            return nil
        case .cursor:
            return nil
        }
    }

    /// Native installers, Homebrew, and Node version managers, in that order. Newest nvm version first.
    static func userInstallDirectories(home: URL, listDirectory: (String) -> [String]) -> [String] {
        let path = { (relative: String) in home.appendingPathComponent(relative).path }
        let nvmRoot = path(".nvm/versions/node")
        let nvm = listDirectory(nvmRoot)
            .filter { $0.hasPrefix("v") && !$0.contains("/") }
            .sorted { nodeVersion($1).lexicographicallyPrecedes(nodeVersion($0)) }
            .prefix(nvmVersionLimit)
            .map { "\(nvmRoot)/\($0)/bin" }
        return [path(".local/bin"), "/opt/homebrew/bin", "/usr/local/bin",
                path(".bun/bin"), path(".volta/bin"), path(".npm-global/bin")] + nvm
    }

    /// "v24.18.0" → [24, 18, 0]; unparsable parts count as zero.
    private static func nodeVersion(_ name: String) -> [Int] {
        name.dropFirst().split(separator: ".").map { Int($0) ?? 0 }
    }

    public static func configurationDirectory(
        agent: Agent,
        override: String?,
        homeDirectory: URL
    ) -> URL? {
        if let override, !override.isEmpty {
            guard override.hasPrefix("/"), override.utf8.count <= configurationDirectoryByteLimit else { return nil }
            return URL(fileURLWithPath: override)
        }
        return homeDirectory.appendingPathComponent(agent.configurationFolder)
    }
}
