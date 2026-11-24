import Foundation
import Testing
@testable import Usage

/// Decision 0025: Claude status-line token totals become daily statistics. Fictional data only.
@MainActor
struct TokenLedgerTests {
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }()
    private let day: Int64 = 86_400_000
    /// 2026-11-16 00:00 UTC.
    private let start: Int64 = 1_794_787_200_000

    private func defaults() -> UserDefaults {
        UserDefaults(suiteName: "bunlet-token-ledger-\(UUID().uuidString)")!
    }

    private func reading(_ source: String, input: Int64, output: Int64, at ms: Int64,
                         provider: String = "claude") -> UsageObservation {
        var observation = UsageObservation(provider: provider, sourceID: source, accountID: nil, receivedAtMs: ms,
                                           measuredAtMs: nil, windows: [], failure: .awaitingSource)
        observation.tokens = TokenTotals(input: input, output: output)
        return observation
    }

    @Test func statusLineTotalsAreParsedAlongsideLimits() throws {
        let input = Data(#"{"rate_limits":{"five_hour":{"used_percentage":10}},"context_window":{"total_input_tokens":1200,"total_output_tokens":340,"context_window_size":200000}}"#.utf8)
        let result = try ClaudeUsageProvider.parse(input, sourceID: "fixture", receivedAtMs: 0)
        #expect(result.tokens == TokenTotals(input: 1200, output: 340))
        #expect(result.windows.count == 1)
        let odd = Data(#"{"context_window":{"total_input_tokens":-1,"total_output_tokens":5}}"#.utf8)
        #expect(try ClaudeUsageProvider.parse(odd, sourceID: "fixture", receivedAtMs: 0).tokens == nil)
    }

    @Test func onlyGrowthIsCountedPerSession() {
        let ledger = TokenLedger(defaults: defaults(), calendar: calendar)
        ledger.record(reading("a", input: 100, output: 10, at: start + 1000))
        ledger.record(reading("a", input: 150, output: 30, at: start + 2000))
        ledger.record(reading("a", input: 150, output: 30, at: start + 3000))
        ledger.record(reading("b", input: 5, output: 5, at: start + 4000))
        #expect(ledger.total(on: Date(timeIntervalSince1970: Double(start) / 1000)) == 190)
        // A shrinking total starts a new baseline instead of subtracting.
        ledger.record(reading("a", input: 20, output: 0, at: start + 5000))
        ledger.record(reading("a", input: 25, output: 0, at: start + 6000))
        #expect(ledger.total(on: Date(timeIntervalSince1970: Double(start) / 1000)) == 195)
        // Older readings, other providers and readings without totals change nothing.
        ledger.record(reading("a", input: 999, output: 0, at: start + 1))
        ledger.record(reading("c", input: 999, output: 0, at: start + 7000, provider: "codex"))
        #expect(ledger.total(on: Date(timeIntervalSince1970: Double(start) / 1000)) == 195)
    }

    @Test func daysAreSeparatedKeptAndRestored() {
        let store = defaults()
        let ledger = TokenLedger(defaults: store, calendar: calendar)
        ledger.record(reading("a", input: 10, output: 0, at: start))
        ledger.record(reading("a", input: 30, output: 0, at: start + day))
        let recent = ledger.recent(3, endingAt: Date(timeIntervalSince1970: Double(start + day) / 1000))
        #expect(recent.map(\.day) == ["2026-11-15", "2026-11-16", "2026-11-17"])
        #expect(recent.map(\.total) == [0, 10, 20])
        #expect(TokenLedger(defaults: store, calendar: calendar).days == ledger.days)

        ledger.record(reading("b", input: 1, output: 0, at: start + 95 * day))
        #expect(ledger.days.map(\.day) == ["2027-02-19"])
        ledger.reset()
        #expect(TokenLedger(defaults: store, calendar: calendar).days.isEmpty)
    }
}
