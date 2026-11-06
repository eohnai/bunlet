import CoreFoundation
import Foundation
import Observation

enum FeatureOperationIssue: Equatable {
    case featureWriteFailed, monitoringWriteFailed
}

@MainActor
@Observable
final class FeatureSettingsModel {
    private(set) var installed: Set<AppFeature> = []
    private(set) var monitoringEnabled = false
    private(set) var preferenceIssue: FeaturePreferenceIssue?
    private(set) var operationIssue: FeatureOperationIssue?
    private(set) var unavailableFeatures: Set<AppFeature> = []
    private(set) var pendingRemoval: AppFeature?
    private let defaults: UserDefaults
    private let apply: (Set<AppFeature>, Bool) -> Set<AppFeature>
    private let pendingNotices: () -> Int

    init(defaults: UserDefaults,
         apply: @escaping (Set<AppFeature>, Bool) -> Set<AppFeature>, pendingNotices: @escaping () -> Int) {
        self.defaults = defaults
        self.apply = apply
        self.pendingNotices = pendingNotices
    }

    /// App launch calls this explicitly; opening Settings reuses this model without restarting services.
    func start(allowStoredMonitoring: Bool = true) {
        operationIssue = nil
        pendingRemoval = nil
        switch FeaturePreferences.read(from: defaults) {
        case .ready(let selected, let origin):
            installed = selected
            preferenceIssue = nil
            monitoringEnabled = allowStoredMonitoring && selected.contains(.agents) && storedMonitoringConsent()
            if origin != .stored, FeaturePreferences.save(selected, to: defaults) != .saved {
                operationIssue = .featureWriteFailed
                monitoringEnabled = false
            }
        case .recoveryRequired(let issue):
            installed = []
            monitoringEnabled = false
            preferenceIssue = issue
        }
        unavailableFeatures = apply(installed, monitoringEnabled)
    }

    func install(_ feature: AppFeature) {
        guard preferenceIssue == nil, operationIssue == nil, !installed.contains(feature) else { return }
        if feature == .agents {
            defaults.set(false, forKey: FeaturePreferences.monitoringKey)
            guard !storedMonitoringConsent() else {
                operationIssue = .monitoringWriteFailed
                return
            }
            monitoringEnabled = false
        }
        persist(installed.union([feature]))
    }

    func requestUninstall(_ feature: AppFeature) {
        guard preferenceIssue == nil, operationIssue == nil, installed.contains(feature) else { return }
        if feature == .agents && pendingNotices() > 0 { pendingRemoval = feature }
        else { remove(feature) }
    }

    func confirmUninstall() {
        guard let feature = pendingRemoval else { return }
        pendingRemoval = nil
        remove(feature)
    }

    func cancelUninstall() { pendingRemoval = nil }

    func retryUnavailable() { unavailableFeatures = apply(installed, monitoringEnabled) }

    func setMonitoring(_ enabled: Bool) {
        guard preferenceIssue == nil, operationIssue == nil, installed.contains(.agents) else { return }
        defaults.set(enabled, forKey: FeaturePreferences.monitoringKey)
        monitoringEnabled = enabled && storedMonitoringConsent()
        if storedMonitoringConsent() != enabled {
            monitoringEnabled = false
            operationIssue = .monitoringWriteFailed
        }
        unavailableFeatures = apply(installed, monitoringEnabled)
    }

    private func remove(_ feature: AppFeature) {
        if feature == .agents {
            // Stop immediately even if saving the uninstall choice subsequently fails.
            monitoringEnabled = false
            unavailableFeatures = apply(installed, false)
            defaults.set(false, forKey: FeaturePreferences.monitoringKey)
            guard !storedMonitoringConsent() else {
                operationIssue = .monitoringWriteFailed
                return
            }
        }
        persist(installed.subtracting([feature]))
    }

    private func persist(_ selected: Set<AppFeature>) {
        switch FeaturePreferences.save(selected, to: defaults) {
        case .saved:
            installed = selected
            operationIssue = nil
        case .recoveryRequired(let issue):
            installed = []
            preferenceIssue = issue
            monitoringEnabled = false
        case .writeFailed:
            operationIssue = .featureWriteFailed
        }
        unavailableFeatures = apply(installed, monitoringEnabled)
    }

    private func storedMonitoringConsent() -> Bool {
        guard let value = defaults.object(forKey: FeaturePreferences.monitoringKey) as? NSNumber,
              CFGetTypeID(value) == CFBooleanGetTypeID() else { return false }
        return value.boolValue
    }
}
