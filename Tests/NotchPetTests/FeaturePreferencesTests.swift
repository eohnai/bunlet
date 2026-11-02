import Foundation
import Testing
@testable import NotchPet

@MainActor
struct FeaturePreferencesTests {
    @Test func defaultsAndLegacyReadsNeverWrite() throws {
        let suite = "local.notchpet.tests.features." + UUID().uuidString
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let values: [Any?] = [nil, false, true, "true", 1, 0]
        let expected: [FeaturePreferenceRead] = [
            .ready([.pet], origin: .freshDefault), .ready([.pet], origin: .freshDefault),
            .ready(Set(AppFeature.allCases), origin: .legacyOptIn),
            .recoveryRequired(.invalidLegacyValue), .recoveryRequired(.invalidLegacyValue),
            .recoveryRequired(.invalidLegacyValue)
        ]
        for (index, value) in values.enumerated() {
            if let value { defaults.set(value, forKey: "agentMonitoringEnabled") }
            else { defaults.removeObject(forKey: "agentMonitoringEnabled") }
            let before = defaults.persistentDomain(forName: suite) ?? [:]
            #expect(FeaturePreferences.read(from: defaults) == expected[index])
            #expect(FeaturePreferences.read(from: defaults) == expected[index])
            #expect((defaults.persistentDomain(forName: suite) ?? [:]) as NSDictionary == before as NSDictionary)
        }
    }

    @Test(arguments: 0..<8) func everyFeatureSetOverridesLegacyAndHasStableOrdering(mask: Int) throws {
        let suite = "local.notchpet.tests.features." + UUID().uuidString
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set(true, forKey: "agentMonitoringEnabled")
        let selected = Set(AppFeature.allCases.enumerated().compactMap { index, feature in
            mask & (1 << index) != 0 ? feature : nil
        })
        #expect(FeaturePreferences.save(selected, to: defaults) == .saved)
        let reopened = try #require(UserDefaults(suiteName: suite))
        #expect(FeaturePreferences.read(from: reopened) == .ready(selected, origin: .stored))
        let first = try #require(defaults.data(forKey: FeaturePreferences.key))
        let json = try #require(JSONSerialization.jsonObject(with: first) as? [String: Any])
        #expect(json["installed"] as? [String] == AppFeature.allCases.filter(selected.contains).map(\.rawValue))
        #expect(json["version"] as? Int == 1)
        #expect(FeaturePreferences.save(selected, to: reopened) == .saved)
        #expect(reopened.data(forKey: FeaturePreferences.key) == first)
        #expect(reopened.bool(forKey: "agentMonitoringEnabled"))
    }

    @Test func invalidAndFutureRecordsCannotBeOverwritten() throws {
        let suite = "local.notchpet.tests.features." + UUID().uuidString
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let fixtures: [(Any, FeaturePreferenceIssue)] = [
            ("invalid", .invalidStoredType), (true, .invalidStoredType),
            (Data("{".utf8), .invalidRecord),
            (Data(repeating: 32, count: FeaturePreferences.maximumBytes + 1), .invalidRecord),
            (Data(#"{"version":1,"installed":["pet","pet"]}"#.utf8), .invalidRecord),
            (Data(#"{"version":1,"installed":["unknown"]}"#.utf8), .invalidRecord),
            (Data(#"{"version":true,"installed":[]}"#.utf8), .invalidRecord),
            (Data(#"{"version":1,"installed":"pet"}"#.utf8), .invalidRecord),
            (Data(#"{"version":1}"#.utf8), .invalidRecord),
            (Data(#"{"version":2,"installed":["pet"]}"#.utf8), .unsupportedVersion),
            (Data(#"{"version":0,"installed":[]}"#.utf8), .unsupportedVersion)
        ]
        defaults.set(true, forKey: "agentMonitoringEnabled")
        defaults.set("keep", forKey: "fixture.unrelated")
        for (raw, issue) in fixtures {
            defaults.set(raw, forKey: FeaturePreferences.key)
            let before = defaults.persistentDomain(forName: suite) ?? [:]
            #expect(FeaturePreferences.read(from: defaults) == .recoveryRequired(issue))
            #expect(FeaturePreferences.save([.pet], to: defaults) == .recoveryRequired(issue))
            #expect((defaults.persistentDomain(forName: suite) ?? [:]) as NSDictionary == before as NSDictionary)
        }
    }

    @Test func explicitMigrationSurvivesReopenAndLegacyChanges() throws {
        let suite = "local.notchpet.tests.features." + UUID().uuidString
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set(true, forKey: "agentMonitoringEnabled")
        #expect(FeaturePreferences.read(from: defaults) == .ready(Set(AppFeature.allCases), origin: .legacyOptIn))
        #expect(defaults.object(forKey: FeaturePreferences.key) == nil)
        #expect(FeaturePreferences.save(Set(AppFeature.allCases), to: defaults) == .saved)
        #expect(defaults.bool(forKey: "agentMonitoringEnabled"))
        defaults.set(false, forKey: "agentMonitoringEnabled")
        let reopened = try #require(UserDefaults(suiteName: suite))
        #expect(FeaturePreferences.read(from: reopened) == .ready(Set(AppFeature.allCases), origin: .stored))
        #expect(!reopened.bool(forKey: "agentMonitoringEnabled"))
    }

    @Test func removeAndReinstallPreserveOtherPreferences() throws {
        let suite = "local.notchpet.tests.features." + UUID().uuidString
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set(184.0, forKey: "pet.size")
        defaults.set(true, forKey: "pet.setupComplete")
        defaults.set(false, forKey: "agentMonitoringEnabled")
        defaults.set("keep", forKey: "fixture.unrelated")
        for selected: Set<AppFeature> in [[.pet], [], [.pet]] {
            #expect(FeaturePreferences.save(selected, to: defaults) == .saved)
            let reopened = try #require(UserDefaults(suiteName: suite))
            #expect(FeaturePreferences.read(from: reopened) == .ready(selected, origin: .stored))
            #expect(reopened.double(forKey: "pet.size") == 184)
            #expect(reopened.bool(forKey: "pet.setupComplete"))
            #expect(!reopened.bool(forKey: "agentMonitoringEnabled"))
            #expect(reopened.string(forKey: "fixture.unrelated") == "keep")
        }
    }
}
