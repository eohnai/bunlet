import Foundation
import Observation

/// Daily token totals from Claude status-line readings (decision 0025).
/// Each reading carries a session's running totals, so only the growth since the last reading of that
/// session is added to the day it was received. Kept in preferences for 90 days; no transcripts are read.
@MainActor
@Observable
public final class TokenLedger {
    public struct Day: Codable, Equatable, Sendable, Identifiable {
        public var id: String { day }
        /// Local calendar day, `yyyy-MM-dd`.
        public let day: String
        public var input: Int64
        public var output: Int64
        public var total: Int64 { input + output }
    }

    private struct Seen: Codable, Equatable {
        var input: Int64
        var output: Int64
        var atMs: Int64
    }

    private struct Stored: Codable {
        let version: Int
        var days: [Day]
        var seen: [String: Seen]
    }

    public static let retentionDays = 90
    public static let sourceLimit = 256
    /// A session not heard from for this long is forgotten; its totals cannot be told apart from a new session's.
    static let sourceRetentionMs: Int64 = 3 * 86_400_000
    static let key = "statistics.tokens.v1"

    /// Ascending by day.
    public private(set) var days: [Day] = []
    @ObservationIgnored private var seen: [String: Seen] = [:]
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let calendar: Calendar

    public init(defaults: UserDefaults, calendar: Calendar = .current) {
        self.defaults = defaults
        self.calendar = calendar
        if let data = defaults.data(forKey: Self.key), data.count <= 262_144,
           let stored = try? JSONDecoder().decode(Stored.self, from: data), stored.version == 1 {
            days = stored.days.filter { $0.input >= 0 && $0.output >= 0 }.sorted { $0.day < $1.day }
            seen = stored.seen
        }
    }

    /// Adds the growth in one reading. Readings without totals, or from other providers, change nothing.
    public func record(_ observation: UsageObservation) {
        guard observation.provider == "claude", let totals = observation.tokens, totals.isValid else { return }
        let source = observation.sourceID
        let previous = seen[source]
        guard previous.map({ observation.receivedAtMs >= $0.atMs }) ?? true else { return }
        // A first reading counts in full. A total that shrinks starts a new baseline instead of a negative day.
        let input = max(0, totals.input - (previous.map { totals.input >= $0.input ? $0.input : totals.input } ?? 0))
        let output = max(0, totals.output - (previous.map { totals.output >= $0.output ? $0.output : totals.output } ?? 0))
        seen[source] = Seen(input: totals.input, output: totals.output, atMs: observation.receivedAtMs)
        if input > 0 || output > 0 {
            let day = Self.dayString(Date(timeIntervalSince1970: Double(observation.receivedAtMs) / 1000), calendar: calendar)
            if let index = days.firstIndex(where: { $0.day == day }) {
                days[index].input = min(TokenTotals.limit, days[index].input + input)
                days[index].output = min(TokenTotals.limit, days[index].output + output)
            } else {
                days.append(Day(day: day, input: input, output: output))
                days.sort { $0.day < $1.day }
            }
        }
        prune(nowMs: observation.receivedAtMs)
        save()
    }

    public func total(on date: Date) -> Int64 {
        let day = Self.dayString(date, calendar: calendar)
        return days.first { $0.day == day }?.total ?? 0
    }

    /// The last `count` days ending at `date`, oldest first, with empty days filled in.
    public func recent(_ count: Int, endingAt date: Date) -> [Day] {
        (0..<max(0, count)).reversed().compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: -offset, to: date) else { return nil }
            let name = Self.dayString(day, calendar: calendar)
            return days.first { $0.day == name } ?? Day(day: name, input: 0, output: 0)
        }
    }

    public func reset() {
        days = []
        seen = [:]
        defaults.removeObject(forKey: Self.key)
    }

    static func dayString(_ date: Date, calendar: Calendar) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }

    private func prune(nowMs: Int64) {
        seen = seen.filter { nowMs - $0.value.atMs < Self.sourceRetentionMs }
        if seen.count > Self.sourceLimit {
            let kept = seen.sorted { $0.value.atMs > $1.value.atMs }.prefix(Self.sourceLimit)
            seen = Dictionary(uniqueKeysWithValues: kept.map { ($0.key, $0.value) })
        }
        if let cutoff = calendar.date(byAdding: .day, value: -(Self.retentionDays - 1),
                                      to: Date(timeIntervalSince1970: Double(nowMs) / 1000)) {
            let first = Self.dayString(cutoff, calendar: calendar)
            days.removeAll { $0.day < first }
        }
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(Stored(version: 1, days: days, seen: seen)) else { return }
        defaults.set(data, forKey: Self.key)
    }
}
