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

    @Test(arguments: [Agent.codex, .claude], [false, true])
    func waitsForDesktopRuntimeAndHonorsPause(agent: Agent, pauseBeforeInstall: Bool) async throws {
        let files = FileManager.default
        let root = URL(fileURLWithPath: "/private/tmp/bunlet-desktop-discovery-\(UUID().uuidString)", isDirectory: true)
        try files.createDirectory(at: root, withIntermediateDirectories: false, attributes: [.posixPermissions: 0o700])
        defer { try? files.removeItem(at: root) }
        let runtime = root.appendingPathComponent("runtime")
        let version = agent == .codex ? "codex-cli 0.169.0" : "2.1.325 (Claude Code)"
        try "#!/bin/sh\n[ \"$1\" = --version ] || exit 1\nprintf '%s\\n' '\(version)'\n"
            .write(to: runtime, atomically: true, encoding: .utf8)
        try files.setAttributes([.posixPermissions: 0o700], ofItemAtPath: runtime.path)
        let helper = root.appendingPathComponent("NotchPetHook")
        try files.copyItem(at: runtime, to: helper)
        let configuration = root.appendingPathComponent("configuration", isDirectory: true)
        try files.createDirectory(at: configuration, withIntermediateDirectories: false, attributes: [.posixPermissions: 0o700])
        let hookFile = configuration.appendingPathComponent(agent.hookConfigurationName)
        let original = Data(#"{"hooks":{"Stop":[{"hooks":[{"type":"command","command":"/usr/bin/true"}]}]}}"#.utf8)
        try original.write(to: hookFile)
        var installed = false
        let controller = ProviderSetupController(agent: agent,
            onConnected: { Issue.record("Automatic setup should not change the monitoring preference") },
            onInspection: { _ in }, desktopCheckInterval: .milliseconds(10),
            contextOverride: { needsExecutable, scope in
                ProviderSetupContext(configurationDirectory: configuration,
                    ownershipDirectory: root.appendingPathComponent("ownership"), helperURL: helper,
                    executableURL: needsExecutable && installed ? runtime : nil, agent: agent, scope: scope)
            })
        defer { controller.setAutomaticSetupEnabled(false) }
        controller.setAutomaticSetupEnabled(true)
        try await waitUntil(controller) {
            controller.operation == nil && controller.inspection?.installationUnavailable == .executableNotFound
        }
        if pauseBeforeInstall { controller.setAutomaticSetupEnabled(false) }
        installed = true
        if pauseBeforeInstall {
            try await Task.sleep(for: .milliseconds(60))
            #expect(try Data(contentsOf: hookFile) == original)
            controller.setAutomaticSetupEnabled(true)
        }
        try await waitUntil(controller) { controller.operation == nil && controller.inspection?.ownership == .owned }
        #expect(try String(contentsOf: hookFile, encoding: .utf8).contains("NotchPetHook"))
    }

    private func waitUntil(_ controller: ProviderSetupController, _ ready: () -> Bool) async throws {
        let clock = ContinuousClock()
        let deadline = clock.now + .seconds(5)
        while !ready(), clock.now < deadline {
            try await Task.sleep(for: .milliseconds(10))
        }
        try #require(ready(), "\(controller.message)")
    }
}
