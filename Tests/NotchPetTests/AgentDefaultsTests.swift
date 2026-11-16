import EventBridge
import Foundation
import Testing
@testable import NotchPet

@MainActor
struct AgentDefaultsTests {
    private func defaults() -> UserDefaults { UserDefaults(suiteName: "bunlet-agent-defaults-\(UUID().uuidString)")! }

    @Test func bothAgentsStartOn() {
        let model = ProviderMonitoringModel(defaults: defaults(), onChange: { _ in })
        #expect(model.isEnabled(.claude))
        #expect(model.isEnabled(.codex))
    }

    @Test func pausingOneAgentSurvivesRelaunch() {
        let store = defaults()
        let first = ProviderMonitoringModel(defaults: store, onChange: { _ in })
        first.setEnabled(false, for: .codex)
        let second = ProviderMonitoringModel(defaults: store, onChange: { _ in })
        #expect(!second.isEnabled(.codex))
        #expect(second.isEnabled(.claude))
    }

    @Test func anEarlierGlobalOffChoiceIsKept() {
        let store = defaults()
        store.set(false, forKey: "agentMonitoringEnabled")
        let model = ProviderMonitoringModel(defaults: store, onChange: { _ in })
        #expect(!model.isEnabled(.claude))
        #expect(!model.isEnabled(.codex))
    }
}
