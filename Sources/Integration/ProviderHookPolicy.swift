import EventBridge
import Foundation

public enum ProviderHookPolicy {
    /// Decision 0019: exact-version matching broke Connect after every provider release,
    /// so accept the documented version or newer within the same major version.
    public static func supportsDocumented(_ version: String, agent: Agent) -> Bool {
        let documented = agent == .codex ? [0, 164, 0] : [2, 1, 306]
        guard version.utf8.count <= 32 else { return false }
        let parts = version.split(separator: ".", omittingEmptySubsequences: false)
        let numbers = parts.compactMap { part in
            part.utf8.allSatisfy { (48...57).contains($0) } ? Int(part) : nil
        }
        guard parts.count == 3, numbers.count == 3, numbers[0] == documented[0] else { return false }
        return numbers.lexicographicallyPrecedes(documented) == false
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
        let parts = version.split(separator: ".", omittingEmptySubsequences: false)
        guard version.utf8.count <= 32, parts.count == 3,
              parts.allSatisfy({ !$0.isEmpty && $0.utf8.allSatisfy { (48...57).contains($0) } }) else {
            return .unsupportedVersion
        }
        return helper ? nil : .helperUnavailable
    }

    static func configurationName(_ agent: Agent) -> String { agent == .codex ? "hooks.json" : "settings.json" }
}
