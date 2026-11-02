import Foundation
import Testing
@testable import NotchPet

@MainActor
struct FeatureTransitionTests {
    private final class Service: AppFeatureService {
        var starts = 0
        var stops = 0
        func start() { starts += 1 }
        func stop() { stops += 1 }
    }

    @Test(arguments: 0..<64) func everyOrderedFeatureTransitionPreservesRuntimeAndConsent(pair: Int) throws {
        let suite = "local.notchpet.tests.transitions." + UUID().uuidString
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let from = Set(AppFeature.allCases.enumerated().compactMap { index, feature in
            (pair / 8) & (1 << index) != 0 ? feature : nil
        })
        let to = Set(AppFeature.allCases.enumerated().compactMap { index, feature in
            (pair % 8) & (1 << index) != 0 ? feature : nil
        })
        #expect(FeaturePreferences.save(from, to: defaults) == .saved)
        defaults.set(from.contains(.agents), forKey: FeaturePreferences.monitoringKey)
        var instances: [AppFeature: Service] = [:]
        var factories: [AppFeature: () -> (any AppFeatureService)?] = [:]
        for feature in AppFeature.allCases {
            factories[feature] = {
                let service = Service()
                instances[feature] = service
                return service
            }
        }
        let runtime = FeatureRuntimeOwner(factories: factories)
        let apply: (Set<AppFeature>, Bool) -> Set<AppFeature> = { selected, monitoring in
            runtime.apply(monitoring ? selected : selected.subtracting([.agents]))
            return runtime.unavailableFeatures
        }
        let model = FeatureSettingsModel(defaults: defaults, apply: apply, pendingNotices: { 0 })
        model.start()
        let initialInstances = instances
        for feature in AppFeature.allCases where from.contains(feature) && !to.contains(feature) {
            model.requestUninstall(feature)
        }
        for feature in AppFeature.allCases where to.contains(feature) && !from.contains(feature) {
            model.install(feature)
        }
        #expect(model.installed == to)
        let retainedConsent = from.contains(.agents) && to.contains(.agents)
        #expect(model.monitoringEnabled == retainedConsent)
        #expect(runtime.activeFeatures == (retainedConsent ? to : to.subtracting([.agents])))
        #expect(FeaturePreferences.read(from: defaults) == .ready(to, origin: .stored))
        for feature in from.intersection(to) {
            #expect(instances[feature] === initialInstances[feature])
            #expect(initialInstances[feature]?.starts == 1 && initialInstances[feature]?.stops == 0)
        }
        for feature in from.subtracting(to) { #expect(initialInstances[feature]?.stops == 1) }
        if to.contains(.agents) && !retainedConsent {
            #expect(instances[.agents] == nil)
            model.setMonitoring(true)
        }
        #expect(runtime.activeFeatures == to)
        let restored = FeatureSettingsModel(defaults: try #require(UserDefaults(suiteName: suite)),
                                             apply: apply, pendingNotices: { 0 })
        restored.start()
        #expect(restored.installed == to)
        #expect(restored.monitoringEnabled == to.contains(.agents))
        #expect(runtime.activeFeatures == to)
        #expect(instances.values.allSatisfy { $0.starts == 1 })
        runtime.apply([])
        #expect(instances.values.allSatisfy { $0.stops == 1 })
    }
}
