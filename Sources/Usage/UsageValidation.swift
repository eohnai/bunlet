import EventBridge
import Foundation

enum UsageValidation {
    static let claudeSourcePrefix = "claude-status-v1:"

    static func accepts(_ observation: UsageObservation) -> Bool {
        Agent(rawValue: observation.provider) != nil &&
        !observation.sourceID.isEmpty && observation.sourceID.utf8.count <= 256 &&
        (observation.accountID.map { !$0.isEmpty && $0.utf8.count <= 256 } ?? true) &&
        observation.receivedAtMs >= 0 && (observation.measuredAtMs.map { $0 >= 0 } ?? true) &&
        observation.windows.count <= 64 &&
        Set(observation.windows.map(\.id)).count == observation.windows.count &&
        observation.windows.allSatisfy { window in
            !window.id.isEmpty && window.id.utf8.count <= 256 &&
            window.usedPercent.isFinite && (0...100).contains(window.usedPercent) &&
            (window.durationMinutes.map { $0 > 0 } ?? true) &&
            (window.resetsAtMs.map { $0 >= 0 } ?? true)
        }
    }

    static func acceptsClaudeIngress(_ observation: UsageObservation) -> Bool {
        let suffix = observation.sourceID.dropFirst(claudeSourcePrefix.count)
        return observation.provider == "claude" && observation.accountID == nil && observation.measuredAtMs == nil &&
            observation.sourceID.hasPrefix(claudeSourcePrefix) && suffix.utf8.count == 64 &&
            suffix.utf8.allSatisfy { (48...57).contains($0) || (97...102).contains($0) } && accepts(observation)
    }
}
