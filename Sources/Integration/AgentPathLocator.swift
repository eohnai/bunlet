import Foundation

public enum AgentPathLocator {
    private static let searchPathByteLimit = 16_384
    private static let searchComponentLimit = 64
    private static let configurationDirectoryByteLimit = 4_096

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
        agent: IntegrationAgent,
        policy: ExecutablePolicy,
        searchPath: String?,
        homeDirectory: URL,
        isExecutable: (String) -> Bool = { FileManager.default.isExecutableFile(atPath: $0) }
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
        if case .usage = policy {
            directories.append(contentsOf: [homeDirectory.appendingPathComponent(".local/bin").path,
                                           "/opt/homebrew/bin", "/usr/local/bin"])
        }
        for directory in directories where directory.hasPrefix("/") {
            let candidate = URL(fileURLWithPath: directory).appendingPathComponent(agent.rawValue)
            if isExecutable(candidate.path) { return .found(candidate) }
        }
        return .notFound
    }

    public static func configurationDirectory(
        agent: IntegrationAgent,
        override: String?,
        homeDirectory: URL
    ) -> URL? {
        if let override, !override.isEmpty {
            guard override.hasPrefix("/"), override.utf8.count <= configurationDirectoryByteLimit else { return nil }
            return URL(fileURLWithPath: override)
        }
        return homeDirectory.appendingPathComponent(agent == .codex ? ".codex" : ".claude")
    }
}
