import EventBridge
import Integration
import Foundation
import Testing
@testable import NotchPet

@MainActor
struct AgentDefaultsTests {
    private func defaults() -> UserDefaults { UserDefaults(suiteName: "bunlet-agent-defaults-\(UUID().uuidString)")! }

    @Test func allAgentsStartOn() {
        let model = ProviderMonitoringModel(defaults: defaults(), onChange: { _ in })
        #expect(model.enabledProviders == Set(Agent.allCases))
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

@MainActor
struct AutoConnectRulesTests {
    @Test(arguments: [(OwnedProviderHooks.notOwned, true), (.owned, true), (.conflict, false), (.recoveryRequired, false)])
    func onlyCleanStatesConnectAutomatically(state: OwnedProviderHooks, expected: Bool) {
        #expect(ProviderSetupController.canConnectAutomatically(state) == expected)
    }

    @Test func quotaForwardingIsAutomaticUntilRemovedByHand() {
        let defaults = UserDefaults(suiteName: "bunlet-quota-auto-\(UUID().uuidString)")!
        let model = ProviderMonitoringModel(defaults: defaults, onChange: { _ in })
        #expect(model.quotaAutoConnect)
        model.setQuotaAutoConnect(false)
        #expect(!ProviderMonitoringModel(defaults: defaults, onChange: { _ in }).quotaAutoConnect)
    }


}
