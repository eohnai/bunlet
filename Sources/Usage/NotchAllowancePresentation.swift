import EventBridge
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
    public let provider: Agent
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

    /// One line per reported window for the hover popup (decision 0018). Missing data never reads as zero left.
    public static func detailLines(for entry: NotchAllowanceEntry, at nowMs: Int64) -> [String] {
        guard let source = entry.source else { return ["Usage limits unavailable"] }
        let windows = source.observation.windows.sorted {
            ($0.durationMinutes ?? .max, $0.id) < ($1.durationMinutes ?? .max, $1.id)
        }
        var lines = windows.map { window in
            let left = Int((100 - window.usedPercent).rounded(.down))
            let reset = window.resetsAtMs == nil ? "reset time unknown" : "resets in \(countdownText(for: window, at: nowMs))"
            return "\(label(for: window)) \(left)% left, \(reset)"
        }
        if lines.isEmpty { lines.append("No limit windows reported") }
        if source.isStale { lines.append("Stale: this reading may no longer apply") }
        if entry.accountUnverified { lines.append("Account unverified") }
        return lines
    }

    public static func label(for window: UsageWindow) -> String {
        switch window.durationMinutes {
        case 300: return "5h"
        case 10_080: return "7d"
        case let minutes? where minutes % 1_440 == 0: return "\(minutes / 1_440)d"
        case let minutes? where minutes % 60 == 0: return "\(minutes / 60)h"
        case let minutes?: return "\(minutes)m"
        case nil: return window.id
        }
    }

    public static func entries(activeProviders: Set<Agent>,
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

    private static func selectedWindow(_ windows: [UsageWindow], provider: Agent) -> UsageWindow? {
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
