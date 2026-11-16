import EventBridge
import Integration
import SwiftUI

/// Agents: one row per agent, then one collapsed details row per agent for setup, repair and replies.
struct AgentsSettingsPage: View {
    let features: FeatureSettingsModel
    let actions: AppSettingsActions
    @State private var confirmConnect: Agent?
    @State private var expanded: Set<Agent> = []

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            SettingsGroup(title: "CLI Hooks") {
                ForEach(Agent.allCases, id: \.self) { agent in
                    if let setup = controller(agent), let monitoring = actions.monitoring() {
                        AgentRow(setup: setup, monitoring: monitoring, last: agent == Agent.allCases.last) {
                            confirmConnect = agent
                        }
                    }
                }
            }
            SettingsFootnote("Connecting adds Bunlet's hooks to the agent's settings and keeps every other hook. Sessions started before connecting are tracked after they restart. Turning a switch off pauses tracking without removing hooks.")
            SettingsGroup(title: "Setup and diagnostics") {
                ForEach(Agent.allCases, id: \.self) { agent in
                    if let setup = controller(agent), let monitoring = actions.monitoring() {
                        details(agent, setup: setup, monitoring: monitoring, last: agent == Agent.allCases.last)
                    }
                }
            }
        }
        .onAppear {
            // A read-only check, so the rows can say whether each agent is connected.
            for agent in Agent.allCases where controller(agent)?.inspection == nil { controller(agent)?.start(.check) }
        }
        .alert(connectTitle, isPresented: Binding(get: { confirmConnect != nil }, set: { if !$0 { confirmConnect = nil } })) {
            Button("Cancel", role: .cancel) {}
            Button("Connect") {
                if let agent = confirmConnect { controller(agent)?.start(.connect) }
            }
        } message: {
            Text("Bunlet adds its own hooks to this agent's settings so it can track sessions. Existing hooks stay unchanged. Codex may ask you to review the new hook.")
        }
    }

    private var connectTitle: String {
        "Connect \(confirmConnect == .codex ? "Codex" : "Claude Code")?"
    }

    private func details(_ agent: Agent, setup: ProviderSetupController, monitoring: ProviderMonitoringModel,
                         last: Bool) -> some View {
        SettingsBlock(last: last) {
            DisclosureGroup(isExpanded: Binding(get: { expanded.contains(agent) }, set: { open in
                if open { expanded.insert(agent) } else { expanded.remove(agent) }
            })) {
                ProviderSetupView(controller: setup, features: features,
                                  health: actions.health().first { $0.agent == agent },
                                  monitoring: monitoring, quota: actions.quota(),
                                  localActions: actions.localActions(),
                                  showFeatures: {}, showNotch: actions.showNotch)
                    .padding(.top, 8)
            } label: {
                Text(setup.providerName).font(.system(size: 14)).foregroundStyle(.white)
            }
        }
    }

    private func controller(_ agent: Agent) -> ProviderSetupController? {
        agent == .codex ? actions.codex() : actions.claude()
    }
}

/// One agent: name, current message as the subtitle, status dot and word, switch.
private struct AgentRow: View {
    let setup: ProviderSetupController
    let monitoring: ProviderMonitoringModel
    let last: Bool
    let requestConnect: () -> Void

    private var connected: Bool {
        if case .owned = setup.inspection?.ownership { return true }
        return false
    }

    private var status: (word: String, color: Color) {
        if setup.operation != nil { return ("Working…", .gray) }
        guard let inspection = setup.inspection else { return ("Checking…", .gray) }
        if connected { return monitoring.isEnabled(setup.agent) ? ("Active", .green) : ("Paused", .yellow) }
        if inspection.installationUnavailable == .executableNotFound { return ("Not found", .orange) }
        return ("Not connected", .gray)
    }

    var body: some View {
        let status = status
        SettingsRow(title: setup.providerName, subtitle: setup.message, last: last) {
            HStack(spacing: 8) {
                Circle().fill(status.color).frame(width: 8, height: 8).accessibilityHidden(true)
                Text(status.word).font(.system(size: 13))
                    .foregroundStyle(status.color == .gray ? SettingsStyle.subtitle : status.color)
            }
            Toggle(setup.providerName, isOn: Binding(
                get: { connected && monitoring.isEnabled(setup.agent) },
                set: { on in
                    if !on {
                        monitoring.setEnabled(false, for: setup.agent)
                    } else if connected {
                        monitoring.setEnabled(true, for: setup.agent)
                    } else {
                        requestConnect()
                    }
                }))
                .toggleStyle(.switch).labelsHidden()
                .disabled(setup.operation != nil)
        }
        .accessibilityElement(children: .combine)
        .accessibilityValue(status.word)
    }
}
