import EventBridge
import Foundation
import Testing
@testable import Usage

struct NotchAllowancePresentationTests {
    private func window(_ id: String = "five_hour", used: Double = 25,
                        minutes: Int? = 300, reset: Int64? = nil) -> UsageWindow {
        UsageWindow(id: id, usedPercent: used, durationMinutes: minutes, resetsAtMs: reset)
    }

    private func snapshot(_ provider: Agent = .codex, source: String = "fictional-source",
                          receipt: Int64 = 1_000, account: String? = "fictional-account",
                          windows: [UsageWindow], failure: UsageFailure? = nil, measured: Int64? = nil,
                          laterFailure: UsageFailure? = nil) -> UsageSnapshot {
        UsageSnapshot(observation: UsageObservation(
            provider: provider.rawValue, sourceID: source, accountID: account,
            receivedAtMs: receipt, measuredAtMs: measured, windows: windows, failure: failure),
            failure: laterFailure)
    }

    private func entry(_ snapshot: UsageSnapshot, provider: Agent = .codex,
                       now: Int64 = 1_000) throws -> NotchAllowanceEntry {
        try #require(NotchAllowancePresentation.entries(
            activeProviders: [provider], snapshots: [snapshot], nowMs: now).first)
    }

    @Test func countdownFloorsMinutesAndChangesUnitsAtHourAndDayBoundaries() {
        let cases: [(Int64, String)] = [
            (0, "0m"), (59_999, "0m"), (60_000, "1m"), (2_700_000, "45m"),
            (3_599_999, "59m"), (3_600_000, "1h0m"), (13_500_000, "3h45m"),
            (86_399_999, "23h59m"), (86_400_000, "1d0h"), (424_800_000, "4d22h")
        ]
        for (remaining, expected) in cases {
            #expect(NotchAllowancePresentation.countdownText(
                for: window(reset: 1_000 + remaining), at: 1_000) == expected)
        }
    }

    @Test func countdownHandlesMissingExpiredAndExtremeTimestamps() {
        #expect(NotchAllowancePresentation.countdownText(for: nil, at: 0) == "—")
        #expect(NotchAllowancePresentation.countdownText(for: window(), at: 0) == "—")
        #expect(NotchAllowancePresentation.countdownText(for: window(reset: 10), at: 11) == "0m")
        #expect(NotchAllowancePresentation.countdownText(for: window(reset: .min), at: .max) == "0m")
        #expect(NotchAllowancePresentation.countdownText(
            for: window(reset: .max), at: .min) == "213503982334d14h")
        #expect(NotchAllowancePresentation.countdownText(for: window(reset: 0), at: -60_000) == "1m")
    }

    @Test func entriesIncludeEachActiveProviderOnceInStableOrder() {
        let snapshots = [snapshot(.codex, windows: [window(used: 10)]),
                         snapshot(.codex, source: "another-source", windows: [window(used: 90)]),
                         snapshot(.claude, windows: [window(used: 40)])]
        let entries = NotchAllowancePresentation.entries(activeProviders: [.codex, .claude], snapshots: snapshots,
                                                          nowMs: 1_000)
        #expect(entries.map(\.provider) == [.claude, .codex])
        #expect(NotchAllowancePresentation.entries(activeProviders: [.codex], snapshots: snapshots, nowMs: 1_000)
            .map(\.provider) == [.codex])
        #expect(NotchAllowancePresentation.entries(activeProviders: [], snapshots: snapshots, nowMs: 1_000).isEmpty)
    }

    @Test(arguments: [Agent.codex, .claude])
    func activeProviderWithoutObservationsHasAMissingEntry(provider: Agent) throws {
        let entries = NotchAllowancePresentation.entries(activeProviders: [provider], snapshots: [], nowMs: 0)
        #expect(entries.count == 1)
        let entry = try #require(entries.first)
        #expect(entry.provider == provider)
        #expect(entry.source == nil)
        #expect(entry.window == nil)
        #expect(entry.windowLabel == "5h")
        #expect(entry.percentLeft == nil)
        #expect(entry.color == .gray)
        #expect(!entry.accountUnverified)
    }

    @Test(arguments: [Agent.codex, .claude])
    func fiveHourWindowWinsOverWeeklyAndOtherDurations(provider: Agent) throws {
        let fiveHour = window(used: 25)
        let reading = snapshot(provider, windows: [window("weekly", used: 99, minutes: 10_080),
                                                   window("other", minutes: 15), fiveHour])
        let entry = try entry(reading, provider: provider)
        #expect(entry.source == reading)
        #expect(entry.window == fiveHour)
        #expect(entry.windowLabel == "5h")
        #expect(entry.percentLeft == 75)
    }

    @Test(arguments: [Agent.codex, .claude])
    func weeklyIsTheFallbackOnlyWhenNoFiveHourWindowExists(provider: Agent) throws {
        let weekly = window("weekly", used: 45, minutes: 10_080)
        let entry = try entry(snapshot(provider, windows: [window("other", minutes: nil), weekly]),
                              provider: provider)
        #expect(entry.window == weekly)
        #expect(entry.windowLabel == "7d")
        #expect(entry.percentLeft == 55)
    }

    @Test func missingAndUnsupportedWindowsNeverBecomeZeroAllowance() throws {
        let cases: [[UsageWindow]] = [[], [window(minutes: nil)], [window(minutes: 15)]]
        for windows in cases {
            let reading = snapshot(windows: windows)
            let entry = try entry(reading)
            #expect(entry.source == reading)
            #expect(entry.window == nil)
            #expect(entry.windowLabel == "5h")
            #expect(entry.percentLeft == nil)
            #expect(entry.color == .gray)
        }
    }

    @Test func percentLeftIsFlooredBeforeColorClassification() throws {
        let cases: [(Double, Int, AllowanceColor)] = [
            (0, 100, .green), (25.25, 74, .green), (49, 51, .green),
            (49.1, 50, .yellow), (50, 50, .yellow), (80, 20, .yellow),
            (80.1, 19, .red), (99.9, 0, .red), (100, 0, .red)
        ]
        for (used, left, color) in cases {
            let reading = snapshot(windows: [window(used: used)])
            let entry = try entry(reading)
            #expect(entry.percentLeft == left)
            #expect(entry.color == color)
            #expect(entry.source?.observation.windows.first?.usedPercent == used)
        }
    }

    @Test func oldReadingsKeepTheirPercentAndColor() throws {
        let entry = try entry(snapshot(windows: [window(used: 25, reset: 100_000_000)]), now: 90_000_000)
        #expect(entry.percentLeft == 75)
        #expect(entry.color == .green)
        #expect(!entry.isReset)
    }

    @Test func passedResetReadsAsAFullWindow() throws {
        let entry = try entry(snapshot(windows: [window(used: 90, reset: 5_000)]), now: 5_000)
        #expect(entry.isReset)
        #expect(entry.percentLeft == 100)
        #expect(entry.color == .green)
        #expect(entry.source?.observation.windows.first?.usedPercent == 90)
    }

    @Test(arguments: [Agent.codex, .claude])
    func accountMarkerReflectsOnlyTheSelectedSourcesAccountEvidence(provider: Agent) throws {
        for account: String? in [nil, "fictional-account"] {
            let entry = try entry(snapshot(provider, account: account, windows: [window()]), provider: provider)
            #expect(entry.accountUnverified == (account == nil))
        }
    }

    @Test func newestSourceWithWindowsWinsAndTiesUseSourceID() throws {
        let selected = snapshot(source: "a", receipt: 2_000, windows: [window(used: 80)])
        let snapshots = [snapshot(source: "old", windows: [window()]),
                         snapshot(source: "z", receipt: 2_000, windows: [window(used: 10)]), selected]
        for readings in [snapshots, Array(snapshots.reversed())] {
            let entry = try #require(NotchAllowancePresentation.entries(
                activeProviders: [.codex], snapshots: readings, nowMs: 2_000).first)
            #expect(entry.source == selected)
            #expect(entry.percentLeft == 20)
            #expect(entry.color == .yellow)
        }
    }

    /// A new Claude session reports no limits before its first reply. It must not hide the earlier reading.
    @Test func newerSourceWithoutWindowsDoesNotHideAnEarlierReading() throws {
        let earlier = snapshot(source: "old", windows: [window(used: 30)])
        let empty = snapshot(source: "new", receipt: 2_000, account: nil, windows: [], failure: .awaitingSource)
        let entry = try #require(NotchAllowancePresentation.entries(
            activeProviders: [.codex], snapshots: [earlier, empty], nowMs: 2_000).first)
        #expect(entry.source == earlier)
        #expect(entry.percentLeft == 70)
        let alone = try #require(NotchAllowancePresentation.entries(
            activeProviders: [.codex], snapshots: [empty], nowMs: 2_000).first)
        #expect(alone.source == empty)
        #expect(alone.percentLeft == nil)
        #expect(alone.color == .gray)
        #expect(alone.accountUnverified)
    }

    @Test func matchingCodexBucketWinsWithoutCombiningBuckets() throws {
        for minutes in [300, 10_080] {
            let codex = window("codex/primary", used: 25, minutes: minutes)
            let other = window("other/primary", used: 99, minutes: minutes)
            for windows in [[other, codex], [codex, other]] {
                let entry = try entry(snapshot(windows: windows))
                #expect(entry.window == codex)
                #expect(entry.percentLeft == 75)
            }
        }
        let entry = try entry(snapshot(windows: [window("other/primary"),
                                                          window("codex/secondary", minutes: 10_080)]))
        #expect(entry.window?.id == "other/primary")
        #expect(entry.windowLabel == "5h")
    }

    @Test func ambiguousMatchingWindowsStayMissingWithoutWeeklyFallback() throws {
        let cases = [
            [window("a/primary"), window("b/primary"), window("codex/secondary", minutes: 10_080)],
            [window("a/secondary", minutes: 10_080), window("b/secondary", minutes: 10_080)],
            [window("codex/primary"), window("codex/secondary")]
        ]
        for windows in cases {
            let entry = try entry(snapshot(windows: windows))
            #expect(entry.window == nil)
            #expect(entry.percentLeft == nil)
            #expect(entry.color == .gray)
        }
        let sole = window("other/primary")
        #expect(try entry(snapshot(windows: [sole])).window == sole)
    }

    @MainActor
    @Test func failedReadKeepsTheBadgeNumberAndColor() throws {
        let store = UsageStore()
        #expect(store.apply(snapshot(windows: [window(reset: 10_000_000)]).observation))
        #expect(store.apply(snapshot(receipt: 2_000, windows: [], failure: .timedOut).observation))
        let entry = try #require(NotchAllowancePresentation.entries(
            activeProviders: [.codex], snapshots: store.snapshots(activeProviders: [.codex]), nowMs: 400_000).first)
        #expect(entry.source?.failure == .timedOut)
        #expect(entry.percentLeft == 75)
        #expect(entry.color == .green)
    }

    @Test func popupListsEveryWindowItsAgeAndAFailedRead() throws {
        let source = snapshot(account: nil, windows: [
            window("weekly", used: 70, minutes: 10_080, reset: 3_600_000),
            window(used: 25.5, reset: nil),
            window("passed", used: 90, minutes: 60, reset: 0)
        ], laterFailure: .timedOut)
        let lines = NotchAllowancePresentation.detailLines(for: try entry(source), at: 721_000)
        #expect(lines == ["1h 100% left, reset since the last reading", "5h 74% left, reset time unknown",
                          "7d 30% left, resets in 47m", "Updated 12 min ago", "Last read failed: timed out",
                          "Account unverified"])
    }

    @Test func ageTextUsesWholeUnitsAndTreatsFutureReceiptsAsNow() {
        let cases: [(Int64, String)] = [(-5_000, "Updated just now"), (59_999, "Updated just now"),
                                        (60_000, "Updated 1 min ago"), (3_600_000, "Updated 1 h ago"),
                                        (90_000_000, "Updated 1 d ago")]
        for (age, expected) in cases {
            #expect(NotchAllowancePresentation.ageText(receivedAtMs: 1_000, at: 1_000 + age) == expected)
        }
    }

    @Test func popupNeverShowsMissingDataAsZero() throws {
        let missing = try #require(NotchAllowancePresentation.entries(activeProviders: [.claude], snapshots: [], nowMs: 0).first)
        #expect(NotchAllowancePresentation.detailLines(for: missing, at: 0) == ["Usage limits unavailable"])
        #expect(NotchAllowancePresentation.detailLines(for: try entry(snapshot(windows: [])), at: 1_000)
                == ["No limit windows reported", "Updated just now"])
    }
}
