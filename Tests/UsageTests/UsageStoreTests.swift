import Testing
@testable import Usage

@MainActor
struct UsageStoreTests {
    private func observation(provider: String = "codex", source: String = "source", percent: Double = 25,
                             receipt: Int64 = 1000, reset: Int64? = 1000000) -> UsageObservation {
        UsageObservation(provider: provider, sourceID: source, accountID: nil,
                         receivedAtMs: receipt, measuredAtMs: nil,
                         windows: [UsageWindow(id: "primary", usedPercent: percent,
                                               durationMinutes: 300, resetsAtMs: reset)], failure: nil)
    }

    @Test func inactiveProvidersAreHiddenEvenWithCachedValues() {
        let store = UsageStore()
        #expect(store.apply(observation()))
        #expect(store.apply(observation(provider: "claude")))
        #expect(store.snapshots(activeProviders: [.codex], nowMs: 1000).map(\.observation.provider) == ["codex"])
        #expect(store.snapshots(activeProviders: [.claude], nowMs: 1000).map(\.observation.provider) == ["claude"])
        #expect(store.snapshots(activeProviders: [.codex, .claude], nowMs: 1000).count == 2)
        #expect(store.snapshots(activeProviders: [], nowMs: 1000).isEmpty)
    }

    @Test func repeatSourcesReplaceAndAnonymousSourcesRemainSeparate() {
        let store = UsageStore()
        #expect(store.apply(observation(provider: "claude", source: "one")))
        #expect(store.apply(observation(provider: "claude", source: "one", percent: 30, receipt: 2000)))
        #expect(store.apply(observation(provider: "claude", source: "two")))
        let snapshots = store.snapshots(activeProviders: [.claude], nowMs: 2000)
        #expect(snapshots.count == 2)
        #expect(snapshots[0].observation.windows[0].usedPercent == 30)
        #expect(snapshots.allSatisfy { $0.observation.accountID == nil })
    }

    @Test func invalidOrOlderPayloadCannotOverwriteGoodValues() {
        let store = UsageStore()
        #expect(store.apply(observation(receipt: 2000)))
        for percent in [Double.nan, Double.infinity, -1, 101] {
            #expect(!store.apply(observation(percent: percent, receipt: 3000)))
        }
        #expect(!store.apply(observation(receipt: 1000)))
        #expect(!store.apply(observation(provider: "unsupported")))
        #expect(store.snapshots(activeProviders: [.codex], nowMs: 2000)[0].observation.windows[0].usedPercent == 25)
    }

    @Test func ageResetAndClockDiscontinuityNeverFabricateZeroUsage() {
        let store = UsageStore()
        #expect(store.apply(observation(reset: 5000)))
        #expect(!store.snapshots(activeProviders: [.codex], nowMs: 1000)[0].isStale)
        for now in [Int64(5000), 400000, 999] {
            let snapshot = store.snapshots(activeProviders: [.codex], nowMs: now)[0]
            #expect(snapshot.isStale)
            #expect(snapshot.observation.windows[0].usedPercent == 25)
            #expect(snapshot.observation.measuredAtMs == nil)
        }
    }

    @Test func missingAndNonstandardWindowsRemainTruthful() {
        let store = UsageStore()
        let window = UsageWindow(id: "other", usedPercent: 12.5, durationMinutes: 15, resetsAtMs: nil)
        let payload = UsageObservation(provider: "codex", sourceID: "source", accountID: "fictional-account",
                                       receivedAtMs: 1000, measuredAtMs: nil, windows: [window], failure: nil)
        #expect(store.apply(payload))
        #expect(store.snapshots(activeProviders: [.codex], nowMs: 1000)[0].observation.windows == [window])
        let missing = UsageObservation(provider: "claude", sourceID: "none", accountID: nil,
                                       receivedAtMs: 1000, measuredAtMs: nil, windows: [], failure: .awaitingSource)
        #expect(store.apply(missing))
        #expect(store.snapshots(activeProviders: [.claude], nowMs: 1000)[0].observation.failure == .awaitingSource)
    }
}
