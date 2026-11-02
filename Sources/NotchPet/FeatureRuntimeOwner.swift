@MainActor
final class FeatureRuntimeOwner {
    private let factories: [AppFeature: () -> (any AppFeatureService)?]
    private var running: [AppFeature: any AppFeatureService] = [:]
    private(set) var unavailableFeatures: Set<AppFeature> = []

    init(factories: [AppFeature: () -> (any AppFeatureService)?]) {
        self.factories = factories
    }

    var activeFeatures: Set<AppFeature> { Set(running.keys) }

    func apply(_ active: Set<AppFeature>) {
        unavailableFeatures.formIntersection(active)
        for feature in AppFeature.allCases.reversed() where !active.contains(feature) {
            running.removeValue(forKey: feature)?.stop()
        }
        for feature in AppFeature.allCases where active.contains(feature) && running[feature] == nil {
            guard let service = factories[feature]?() else {
                unavailableFeatures.insert(feature)
                continue
            }
            unavailableFeatures.remove(feature)
            running[feature] = service
            service.start()
        }
    }
}
