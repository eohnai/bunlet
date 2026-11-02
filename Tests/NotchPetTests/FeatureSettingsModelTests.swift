import Foundation
import Testing
@testable import NotchPet

private final class FeatureRejectingDefaults: UserDefaults, @unchecked Sendable {
    var rejectedKey: String?
    override func set(_ value: Any?, forKey defaultName: String) {
        if defaultName != rejectedKey { super.set(value, forKey: defaultName) }
    }
}

@MainActor
struct FeatureSettingsModelTests {
    private final class Service: AppFeatureService {
        var starts = 0
        var stops = 0
        func start() { starts += 1 }
        func stop() { stops += 1 }
    }

    @Test(arguments: 0..<8) func constructingModelDoesNoWorkAndStartupAppliesSelectedSet(mask: Int) throws {
        let suite = "local.notchpet.tests.settings." + UUID().uuidString
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set(true, forKey: FeaturePreferences.monitoringKey)
        let selected = Set(AppFeature.allCases.enumerated().compactMap { index, feature in
            mask & (1 << index) != 0 ? feature : nil
        })
        #expect(FeaturePreferences.save(selected, to: defaults) == .saved)
        var creations: [AppFeature: Int] = [:]
        var factories: [AppFeature: () -> (any AppFeatureService)?] = [:]
        for feature in AppFeature.allCases {
            factories[feature] = {
                creations[feature, default: 0] += 1
                return Service()
            }
        }
        let owner = FeatureRuntimeOwner(factories: factories)
        let model = FeatureSettingsModel(defaults: defaults, apply: { installed, monitoring in
            owner.apply(monitoring ? installed : installed.subtracting([.agents]))
            return owner.unavailableFeatures
        }, pendingNotices: { 0 })
        #expect(creations.isEmpty)
        #expect(owner.activeFeatures.isEmpty)
        model.start()
        #expect(model.installed == selected)
        #expect(owner.activeFeatures == selected)
        #expect(model.monitoringEnabled == selected.contains(.agents))
        for feature in AppFeature.allCases {
            #expect(creations[feature, default: 0] == (selected.contains(feature) ? 1 : 0))
        }
        owner.apply([])
    }

    @Test func installingAgentsRequiresSeparateConsentAndReopenPreservesIt() throws {
        let suite = "local.notchpet.tests.settings." + UUID().uuidString
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set(true, forKey: FeaturePreferences.monitoringKey)
        #expect(FeaturePreferences.save([.pet], to: defaults) == .saved)
        var lastMonitoring = false
        let model = FeatureSettingsModel(defaults: defaults, apply: { _, monitoring in
            lastMonitoring = monitoring
            return []
        }, pendingNotices: { 0 })
        model.start()
        model.install(.agents)
        #expect(model.installed == [.pet, .agents])
        #expect(!lastMonitoring && !model.monitoringEnabled)
        #expect(!defaults.bool(forKey: FeaturePreferences.monitoringKey))
        model.setMonitoring(true)
        #expect(lastMonitoring && model.monitoringEnabled)
        let reopened = FeatureSettingsModel(defaults: defaults, apply: { _, _ in [] }, pendingNotices: { 0 })
        reopened.start()
        #expect(reopened.monitoringEnabled)
    }

    @Test func pendingRemovalRequiresConfirmationAndReinstallDoesNotReconnect() throws {
        let suite = "local.notchpet.tests.settings." + UUID().uuidString
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set(true, forKey: FeaturePreferences.monitoringKey)
        defaults.set(184.0, forKey: "pet.size")
        #expect(FeaturePreferences.save(Set(AppFeature.allCases), to: defaults) == .saved)
        var monitoringChanges: [Bool] = []
        let model = FeatureSettingsModel(defaults: defaults, apply: { _, monitoring in
            monitoringChanges.append(monitoring)
            return []
        }, pendingNotices: { 2 })
        model.start()
        model.requestUninstall(.agents)
        #expect(model.pendingRemoval == .agents && model.monitoringEnabled)
        #expect(monitoringChanges == [true])
        model.cancelUninstall()
        #expect(model.pendingRemoval == nil && model.installed.contains(.agents))
        model.requestUninstall(.agents)
        model.confirmUninstall()
        #expect(model.installed == [.pet, .notch])
        #expect(!model.monitoringEnabled && monitoringChanges.last == false)
        #expect(!defaults.bool(forKey: FeaturePreferences.monitoringKey))
        model.install(.agents)
        #expect(model.installed == Set(AppFeature.allCases))
        #expect(!model.monitoringEnabled)
        #expect(defaults.double(forKey: "pet.size") == 184)
        let reopened = FeatureSettingsModel(defaults: defaults, apply: { _, _ in [] }, pendingNotices: { 0 })
        reopened.start()
        #expect(!reopened.monitoringEnabled)
    }

    @Test func surfaceRemovalLeavesMonitoringAndOtherFeaturesRunning() throws {
        let suite = "local.notchpet.tests.settings." + UUID().uuidString
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set(true, forKey: FeaturePreferences.monitoringKey)
        #expect(FeaturePreferences.save(Set(AppFeature.allCases), to: defaults) == .saved)
        let pet = Service()
        let notch = Service()
        let agents = Service()
        let owner = FeatureRuntimeOwner(factories: [.pet: { pet }, .notch: { notch }, .agents: { agents }])
        let model = FeatureSettingsModel(defaults: defaults, apply: { installed, monitoring in
            owner.apply(monitoring ? installed : installed.subtracting([.agents]))
            return owner.unavailableFeatures
        }, pendingNotices: { 0 })
        model.start()
        model.requestUninstall(.pet)
        model.requestUninstall(.notch)
        #expect(owner.activeFeatures == [.agents])
        #expect(pet.stops == 1 && notch.stops == 1)
        #expect(agents.starts == 1 && agents.stops == 0 && model.monitoringEnabled)
        model.requestUninstall(.agents)
        #expect(model.installed.isEmpty && owner.activeFeatures.isEmpty)
        #expect(FeaturePreferences.read(from: defaults) == .ready([], origin: .stored))
    }

    @Test func incompatibleChoicesArePreservedAndRetryCanReadAnExternalRestore() throws {
        let suite = "local.notchpet.tests.settings." + UUID().uuidString
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let original = Data(#"{"version":2,"installed":["future"]}"#.utf8)
        defaults.set(original, forKey: FeaturePreferences.key)
        var applied: Set<AppFeature> = []
        let model = FeatureSettingsModel(defaults: defaults, apply: { installed, _ in
            applied = installed
            return []
        }, pendingNotices: { 0 })
        model.start()
        #expect(model.preferenceIssue == .unsupportedVersion)
        model.install(.pet)
        model.setMonitoring(true)
        #expect(applied.isEmpty && model.installed.isEmpty)
        #expect(defaults.data(forKey: FeaturePreferences.key) == original)
        defaults.set(Data(#"{"version":1,"installed":["pet"]}"#.utf8), forKey: FeaturePreferences.key)
        model.start(allowStoredMonitoring: false)
        #expect(model.preferenceIssue == nil && applied == [.pet])
    }

    @Test func failedRemovalLeavesAgentsInstalledButStoppedUntilRetry() throws {
        let suite = "local.notchpet.tests.settings." + UUID().uuidString
        let defaults = try #require(FeatureRejectingDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set(true, forKey: FeaturePreferences.monitoringKey)
        #expect(FeaturePreferences.save(Set(AppFeature.allCases), to: defaults) == .saved)
        var monitoring = false
        let model = FeatureSettingsModel(defaults: defaults, apply: { _, enabled in
            monitoring = enabled
            return []
        }, pendingNotices: { 0 })
        model.start()
        defaults.rejectedKey = FeaturePreferences.key
        model.requestUninstall(.agents)
        #expect(model.installed.contains(.agents))
        #expect(!model.monitoringEnabled && !monitoring)
        #expect(model.operationIssue == .featureWriteFailed)
        #expect(!defaults.bool(forKey: FeaturePreferences.monitoringKey))
        defaults.rejectedKey = nil
        model.start(allowStoredMonitoring: false)
        model.requestUninstall(.agents)
        #expect(!model.installed.contains(.agents) && model.operationIssue == nil)
    }

    @Test func nonBooleanMonitoringValuesAreNotConsent() throws {
        let suite = "local.notchpet.tests.settings." + UUID().uuidString
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        #expect(FeaturePreferences.save([.agents], to: defaults) == .saved)
        for value: Any in ["true", 1, 0] {
            defaults.set(value, forKey: FeaturePreferences.monitoringKey)
            let model = FeatureSettingsModel(defaults: defaults, apply: { _, enabled in
                #expect(!enabled)
                return []
            }, pendingNotices: { 0 })
            model.start()
            #expect(!model.monitoringEnabled)
        }
    }

    @Test func failedMonitoringWriteStaysStoppedAndFactoryRetryKeepsConsent() throws {
        let suite = "local.notchpet.tests.settings." + UUID().uuidString
        let defaults = try #require(FeatureRejectingDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        #expect(FeaturePreferences.save([.pet, .agents], to: defaults) == .saved)
        var missingPet = true
        var monitoring = false
        let model = FeatureSettingsModel(defaults: defaults, apply: { _, enabled in
            monitoring = enabled
            return missingPet ? [.pet] : []
        }, pendingNotices: { 0 })
        model.start()
        defaults.rejectedKey = FeaturePreferences.monitoringKey
        model.setMonitoring(true)
        #expect(!monitoring && model.operationIssue == .monitoringWriteFailed)
        defaults.rejectedKey = nil
        model.start(allowStoredMonitoring: false)
        model.setMonitoring(true)
        #expect(monitoring)
        missingPet = false
        model.retryUnavailable()
        #expect(monitoring && model.monitoringEnabled && model.unavailableFeatures.isEmpty)
    }
}
