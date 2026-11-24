import EventBridge
import Testing
@testable import Integration

/// Decision 0026: any well-formed version at or above the floor connects; untested ones say so.
struct AnyVersionTests {
    @Test func versionsAtOrAboveTheFloorAreAccepted() {
        #expect(ProviderHookPolicy.supportsDocumented("0.169.0", agent: .codex))
        #expect(ProviderHookPolicy.supportsDocumented("0.169.0-alpha.11.1", agent: .codex))
        #expect(!ProviderHookPolicy.supportsDocumented("0.129.0-alpha.1", agent: .codex))
        #expect(!ProviderHookPolicy.supportsDocumented("0.169.0-alpha..1", agent: .codex))
        #expect(ProviderHookPolicy.supportsDocumented("0.129.0", agent: .codex))
        #expect(ProviderHookPolicy.supportsDocumented("1.0.0", agent: .codex))
        #expect(!ProviderHookPolicy.supportsDocumented("0.128.9", agent: .codex))
        #expect(ProviderHookPolicy.supportsDocumented("2.1.318", agent: .claude))
        #expect(ProviderHookPolicy.supportsDocumented("0.0.1", agent: .claude))
        #expect(ProviderHookPolicy.supportsDocumented("2026.10.01-0000000", agent: .cursor))
        #expect(!ProviderHookPolicy.supportsDocumented("2.1", agent: .claude))
        #expect(!ProviderHookPolicy.supportsDocumented("2.1.318-beta", agent: .claude))
    }

    @Test func comparisonIsNumeric() {
        #expect(ProviderHookPolicy.compare("0.130.0", "0.129.0") == .orderedDescending)
        #expect(ProviderHookPolicy.compare("0.99.0", "0.129.0") == .orderedAscending)
        #expect(ProviderHookPolicy.compare("0.129.0", "0.129.0") == .orderedSame)
    }

    @Test func untestedVersionsAreLabelledNotRefused() {
        let tested = IntegrationHealth.evaluate(IntegrationHealthEvidence(agent: .claude, version: .reported("2.1.306")))
        #expect(tested.version == .recordedCompatibility("2.1.306"))
        let newer = IntegrationHealth.evaluate(IntegrationHealthEvidence(agent: .claude, version: .reported("2.1.318")))
        #expect(newer.version == .unverified("2.1.318"))
        #expect(ProviderHookPolicy.installationFailure(.documented(version: "2.1.318", helperAvailable: true), agent: .claude) == nil)
        #expect(ProviderHookPolicy.installationFailure(.documented(version: "0.100.0", helperAvailable: true), agent: .codex)
                == .unsupportedVersion)
    }
}
