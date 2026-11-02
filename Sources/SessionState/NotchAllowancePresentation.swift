import Foundation

private extension UsageWindow {
    var allowancePercentLeft: Int {
        Int((100 - usedPercent).rounded(.down))
    }
}

public enum AllowanceColor: Equatable, Sendable {
    case green, yellow, red, gray
}

public struct NotchAllowanceEntry: Equatable, Sendable {
    public let provider: IntegrationAgent
    public let source: UsageSnapshot?
    public let window: UsageWindow?

    public var windowLabel: String {
        window?.durationMinutes == 10_080 ? "7d" : "5h"
    }

    public var percentLeft: Int? {
        window?.allowancePercentLeft
    }

    public var color: AllowanceColor {
        guard source?.isStale == false, let percentLeft else { return .gray }
        if percentLeft > 50 { return .green }
        return percentLeft >= 20 ? .yellow : .red
    }

    public var accountUnverified: Bool {
        guard let source else { return false }
        return source.observation.accountID == nil
    }
}

public enum NotchAllowancePresentation {
    public static func countdownText(for window: UsageWindow?, at nowMs: Int64) -> String {
        guard let reset = window?.resetsAtMs else { return "—" }
        guard reset > nowMs else { return "0m" }
        // The positive difference between signed endpoints can exceed Int64.max.
        let remainingMs = UInt64(bitPattern: reset) &- UInt64(bitPattern: nowMs)
        let minutes = remainingMs / 60_000
        if minutes < 60 { return "\(minutes)m" }
        let hours = minutes / 60
        if hours < 24 { return "\(hours)h\(minutes % 60)m" }
        return "\(hours / 24)d\(hours % 24)h"
    }

    public static func entries(activeProviders: Set<IntegrationAgent>,
                               snapshots: [UsageSnapshot]) -> [NotchAllowanceEntry] {
        activeProviders.sorted { $0.rawValue < $1.rawValue }.map { provider in
            let source = snapshots.filter { $0.observation.provider == provider.rawValue }.sorted { left, right in
                if left.isStale != right.isStale { return !left.isStale }
                if left.observation.receivedAtMs != right.observation.receivedAtMs {
                    return left.observation.receivedAtMs > right.observation.receivedAtMs
                }
                return left.observation.sourceID.utf8.lexicographicallyPrecedes(right.observation.sourceID.utf8)
            }.first
            return NotchAllowanceEntry(provider: provider, source: source,
                                       window: selectedWindow(source?.observation.windows ?? [], provider: provider))
        }
    }

    private static func selectedWindow(_ windows: [UsageWindow], provider: IntegrationAgent) -> UsageWindow? {
        let fiveHour = windows.filter { $0.durationMinutes == 300 }
        let matches = fiveHour.isEmpty ? windows.filter { $0.durationMinutes == 10_080 } : fiveHour
        if provider == .codex {
            let codex = matches.filter { $0.id.hasPrefix("codex/") }
            if !codex.isEmpty { return codex.count == 1 ? codex.first : nil }
        }
        // Ambiguous buckets cannot establish one provider-wide allowance.
        return matches.count == 1 ? matches.first : nil
    }
}
