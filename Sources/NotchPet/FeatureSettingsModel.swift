import Foundation
import Observation

/// Every part of Bunlet always runs (decision 0020). This model only starts the runtimes and reports
/// any that failed to start so Settings can offer a retry. Agent intake is gated per provider by
/// `ProviderMonitoringModel`, not here.
@MainActor
@Observable
final class FeatureSettingsModel {
    let installed: Set<AppFeature> = Set(AppFeature.allCases)
    let monitoringEnabled = true
    private(set) var unavailableFeatures: Set<AppFeature> = []
    @ObservationIgnored private let apply: (Set<AppFeature>, Bool) -> Set<AppFeature>

    init(apply: @escaping (Set<AppFeature>, Bool) -> Set<AppFeature>) {
        self.apply = apply
    }

    /// App launch calls this once; Settings reuses the model without restarting services.
    func start() {
        unavailableFeatures = apply(installed, monitoringEnabled)
    }

    func retryUnavailable() {
        unavailableFeatures = apply(installed, monitoringEnabled)
    }
}
