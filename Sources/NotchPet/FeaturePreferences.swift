import CoreFoundation
import Foundation

enum FeaturePreferenceOrigin: Equatable, Sendable {
    case stored, freshDefault, legacyOptIn
}

enum FeaturePreferenceIssue: Equatable, Sendable {
    case invalidStoredType, invalidRecord, unsupportedVersion, invalidLegacyValue
}

enum FeaturePreferenceRead: Equatable, Sendable {
    case ready(Set<AppFeature>, origin: FeaturePreferenceOrigin)
    case recoveryRequired(FeaturePreferenceIssue)
}

enum FeaturePreferenceSaveResult: Equatable, Sendable {
    case saved
    case recoveryRequired(FeaturePreferenceIssue)
    case writeFailed
}

private struct FeatureAvailabilityRecord: Codable {
    let version: Int
    let installed: [String]
}

@MainActor
enum FeaturePreferences {
    static let key = "features.availability"
    static let monitoringKey = "agentMonitoringEnabled"
    static let maximumBytes = 4_096

    static func read(from defaults: UserDefaults) -> FeaturePreferenceRead {
        if let raw = defaults.object(forKey: key) { return decode(raw) }
        guard let legacy = defaults.object(forKey: monitoringKey) else {
            return .ready([.pet], origin: .freshDefault)
        }
        // NSNumber also bridges integers to Bool; only an actual saved boolean is consent.
        guard let value = legacy as? NSNumber, CFGetTypeID(value) == CFBooleanGetTypeID() else {
            return .recoveryRequired(.invalidLegacyValue)
        }
        return value.boolValue ? .ready(Set(AppFeature.allCases), origin: .legacyOptIn)
            : .ready([.pet], origin: .freshDefault)
    }

    static func save(_ installed: Set<AppFeature>, to defaults: UserDefaults) -> FeaturePreferenceSaveResult {
        if case .recoveryRequired(let issue) = read(from: defaults) { return .recoveryRequired(issue) }
        let record = FeatureAvailabilityRecord(version: 1,
            installed: AppFeature.allCases.filter(installed.contains).map(\.rawValue))
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        guard let data = try? encoder.encode(record) else { return .writeFailed }
        defaults.set(data, forKey: key)
        return defaults.object(forKey: key) as? Data == data ? .saved : .writeFailed
    }

    private static func decode(_ raw: Any) -> FeaturePreferenceRead {
        guard let data = raw as? Data else { return .recoveryRequired(.invalidStoredType) }
        guard data.count <= maximumBytes,
              let record = try? JSONDecoder().decode(FeatureAvailabilityRecord.self, from: data) else {
            return .recoveryRequired(.invalidRecord)
        }
        guard record.version == 1 else { return .recoveryRequired(.unsupportedVersion) }
        let features = record.installed.compactMap(AppFeature.init(rawValue:))
        guard features.count <= AppFeature.allCases.count, features.count == record.installed.count,
              Set(features).count == features.count else { return .recoveryRequired(.invalidRecord) }
        return .ready(Set(features), origin: .stored)
    }
}
