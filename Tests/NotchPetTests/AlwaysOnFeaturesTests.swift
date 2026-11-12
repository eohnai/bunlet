import Foundation
import Testing
@testable import NotchPet

/// Decision 0020: the island, pet and agent services always run; there is no install state to read.
@MainActor
struct AlwaysOnFeaturesTests {
    @Test func startRunsEveryFeatureWithMonitoring() {
        var applied: [(Set<AppFeature>, Bool)] = []
        let model = FeatureSettingsModel(apply: { features, monitoring in
            applied.append((features, monitoring))
            return []
        })
        model.start()
        #expect(applied.count == 1)
        #expect(applied.first?.0 == Set(AppFeature.allCases))
        #expect(applied.first?.1 == true)
        #expect(model.unavailableFeatures.isEmpty)
    }

    @Test func failedRuntimeIsReportedAndRetried() {
        var failing: Set<AppFeature> = [.agents]
        let model = FeatureSettingsModel(apply: { _, _ in failing })
        model.start()
        #expect(model.unavailableFeatures == [.agents])
        failing = []
        model.retryUnavailable()
        #expect(model.unavailableFeatures.isEmpty)
    }
}
