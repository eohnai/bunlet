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
    /// The window's reset time has passed since the reading (decision 0036). Nothing has been used in the new window
    /// as far as Bunlet knows, so it reads 100% left with no countdown until the next reading.
    public var isReset = false

    public var windowLabel: String {
        window?.durationMinutes == 10_080 ? "7d" : "5h"
    }

    public var percentLeft: Int? {
        guard let window else { return nil }
        return isReset ? 100 : window.allowancePercentLeft
    }

    /// Gray only when there is no number to show. An old reading keeps its level color.
    public var color: AllowanceColor {
        guard let percentLeft else { return .gray }
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
            guard let resetMs = window.resetsAtMs else {
                return "\(label(for: window)) \(window.allowancePercentLeft)% left, reset time unknown"
            }
            if resetMs <= nowMs { return "\(label(for: window)) 100% left, reset since the last reading" }
            return "\(label(for: window)) \(window.allowancePercentLeft)% left, resets in \(countdownText(for: window, at: nowMs))"
        }
        if lines.isEmpty { lines.append("No limit windows reported") }
        lines.append(ageText(receivedAtMs: source.observation.receivedAtMs, at: nowMs))
        if let failure = source.failure { lines.append("Last read failed: \(failureText(failure))") }
        if entry.accountUnverified { lines.append("Account unverified") }
        return lines
    }

    /// When Bunlet received the reading. A receipt time in the future reads as just now.
    public static func ageText(receivedAtMs: Int64, at nowMs: Int64) -> String {
        let minutes = nowMs > receivedAtMs ? (nowMs - receivedAtMs) / 60_000 : 0
        if minutes < 1 { return "Updated just now" }
        if minutes < 60 { return "Updated \(minutes) min ago" }
        let hours = minutes / 60
        return hours < 24 ? "Updated \(hours) h ago" : "Updated \(hours / 24) d ago"
    }

    static func failureText(_ failure: UsageFailure) -> String {
        switch failure {
        case .awaitingSource: "no limits reported"
        case .signedOut: "signed out"
        case .unsupportedAccount: "account type has no limits"
        case .sourceUnavailable: "source unavailable"
        case .malformed: "unreadable reply"
        case .timedOut: "timed out"
        }
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

    /// One entry per provider. The newest source with windows wins, so a new session that has not reported limits yet
    /// does not hide an earlier reading. A source without windows is chosen only when no source has any.
    public static func entries(activeProviders: Set<Agent>, snapshots: [UsageSnapshot],
                               nowMs: Int64) -> [NotchAllowanceEntry] {
        activeProviders.sorted { $0.rawValue < $1.rawValue }.map { provider in
            let source = snapshots.filter { $0.observation.provider == provider.rawValue }.sorted { left, right in
                let leftHasWindows = !left.observation.windows.isEmpty
                if leftHasWindows != !right.observation.windows.isEmpty { return leftHasWindows }
                if left.observation.receivedAtMs != right.observation.receivedAtMs {
                    return left.observation.receivedAtMs > right.observation.receivedAtMs
                }
                return left.observation.sourceID.utf8.lexicographicallyPrecedes(right.observation.sourceID.utf8)
            }.first
            let window = selectedWindow(source?.observation.windows ?? [], provider: provider)
            return NotchAllowanceEntry(provider: provider, source: source, window: window,
                                       isReset: window?.resetsAtMs.map { $0 <= nowMs } ?? false)
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
