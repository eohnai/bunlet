import EventBridge
import Foundation

public enum ProviderHookPolicy {
    /// Any version in the agent's own format at or above its floor (decision 0026).
    public static func supportsDocumented(_ version: String, agent: Agent) -> Bool {
        guard agent.isVersion(version) else { return false }
        guard let floor = minimumVersion(agent) else { return true }
        let release = version.split(separator: "-", maxSplits: 1)
        guard let core = release.first else { return false }
        switch compare(String(core), floor) {
        case .orderedAscending: return false
        case .orderedSame: return release.count == 1
        case .orderedDescending: return true
        }
    }

    /// The oldest version setup accepts.
    public static func minimumVersion(_ agent: Agent) -> String? {
        switch agent {
        case .codex: "0.129.0"
        case .claude, .cursor: nil
        }
    }

    /// Versions with recorded compatibility evidence. Others connect but show as untested.
    public static func testedVersions(_ agent: Agent) -> [String] {
        switch agent {
        case .codex: ["0.163.0", "0.164.0"]
        case .claude: ["2.1.306"]
        case .cursor: []
        }
    }

    /// Numeric comparison of dotted versions; a missing part counts as zero.
    static func compare(_ lhs: String, _ rhs: String) -> ComparisonResult {
        let left = lhs.split(separator: ".").map { Int($0) ?? 0 }
        let right = rhs.split(separator: ".").map { Int($0) ?? 0 }
        for index in 0..<max(left.count, right.count) {
            let l = index < left.count ? left[index] : 0
            let r = index < right.count ? right[index] : 0
            if l != r { return l < r ? .orderedAscending : .orderedDescending }
        }
        return .orderedSame
    }

    static func installationFailure(_ support: HookSetupSupport, agent: Agent) -> HookPlanningFailure? {
        let version: String
        let helper: Bool
        switch support {
        case .unverified: return .unverifiedVersion
        case .documented(let value, let available):
            guard supportsDocumented(value, agent: agent) else { return .unsupportedVersion }
            version = value
            helper = available
        case .verified(let value, let enabled, let available):
            guard enabled else { return .hooksDisabled }
            version = value
            helper = available
        }
        guard agent.isVersion(version) else { return .unsupportedVersion }
        return helper ? nil : .helperUnavailable
    }

    static func configurationName(_ agent: Agent) -> String { agent.hookConfigurationName }
}
