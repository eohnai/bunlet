import EventBridge
import Integration
import SwiftUI

/// Each row shows the monitoring choice and the connection state.
struct AgentsSettingsPage: View {
    let actions: AppSettingsActions
    @State private var confirmConnect: Agent?
    @State private var expanded: Set<Agent> = []
    private let agents: [Agent] = [.claude, .codex, .cursor]

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            SettingsGroup(title: "Session Monitoring") {
                ForEach(agents, id: \.self) { agent in
                    if let setup = controller(agent), let monitoring = actions.monitoring() {
                        AgentRow(setup: setup, monitoring: monitoring, health: health(agent), last: agent == agents.last) {
                            confirmConnect = agent
                        }
                    }
                }
            }
            if let codex = actions.codex(), let monitoring = actions.monitoring() {
                SettingsGroup(title: "Approvals") {
                    SettingsMenuRow(title: "Codex approval location",
                                    subtitle: codex.operation?.scope == .claudeActions ? codex.message : nil, last: true, width: 170,
                                    selection: Binding(get: { monitoring.actionAgents.contains(.codex) }, set: { inBunlet in
                                        // The approval hook waits for the user's answer in Bunlet.
                                        codex.start(inBunlet ? .connectActions : .removeActions)
                                    }),
                                    options: [("ChatGPT or terminal", false), ("Bunlet", true)])
                        .disabled(codex.operation != nil)
                }
            }
            SettingsGroup(title: "Setup") {
                ForEach(agents, id: \.self) { agent in
                    if let setup = controller(agent), let monitoring = actions.monitoring() {
                        details(agent, setup: setup, monitoring: monitoring, last: agent == agents.last)
                    }
                }
            }
        }
        .onAppear {
            for agent in agents where controller(agent)?.inspection == nil { controller(agent)?.start(.check) }
        }
        .alert("Connect \(confirmConnect?.displayName ?? "agent")?",
               isPresented: Binding(get: { confirmConnect != nil }, set: { if !$0 { confirmConnect = nil } })) {
            Button("Cancel", role: .cancel) {}
            Button("Connect") {
                if let agent = confirmConnect { controller(agent)?.start(.connect) }
            }
        } message: {
            Text("Bunlet installs hooks for session monitoring. Codex may ask you to review its hooks.")
        }
    }

    private func details(_ agent: Agent, setup: ProviderSetupController, monitoring: ProviderMonitoringModel,
                         last: Bool) -> some View {
        SettingsBlock(last: last) {
            DisclosureGroup(isExpanded: Binding(get: { expanded.contains(agent) }, set: { open in
                if open { expanded.insert(agent) } else { expanded.remove(agent) }
            })) {
                ProviderSetupView(controller: setup, health: health(agent),
                                  monitoring: monitoring, quota: actions.quota(),
                                  localActions: actions.localActions())
                    .padding(.top, 8)
            } label: {
                Text(setup.providerName).font(.system(size: 14)).foregroundStyle(.white)
            }
        }
    }

    private func health(_ agent: Agent) -> IntegrationHealthSnapshot? {
        actions.health().first { $0.agent == agent }
    }

    private func controller(_ agent: Agent) -> ProviderSetupController? {
        switch agent {
        case .codex: actions.codex()
        case .claude: actions.claude()
        case .cursor: actions.cursor()
        }
    }
}

/// Monitoring preference and hook status are independent.
private struct AgentRow: View {
    let setup: ProviderSetupController
    let monitoring: ProviderMonitoringModel
    let health: IntegrationHealthSnapshot?
    let last: Bool
    let requestConnect: () -> Void

    private var connected: Bool {
        if case .owned = setup.inspection?.ownership { return true }
        return false
    }

    private var status: String {
        if monitoring.writeIssue == setup.agent { return "Preference could not be saved" }
        if !monitoring.isEnabled(setup.agent) { return "Paused" }
        if setup.operation?.scope == .lifecycle { return "Checking setup…" }
        if setup.inspection?.installationUnavailable == .executableNotFound { return "Agent not found" }
        if connected {
            if case .failed = health?.receiver { return "Receiver unavailable" }
            return health?.lastDelivery == nil ? "Waiting for a session" : "Receiving sessions"
        }
        return "Setup needed"
    }

    var body: some View {
        SettingsToggleRow(title: setup.providerName, subtitle: status, last: last, isOn: Binding(
            get: { monitoring.isEnabled(setup.agent) },
            set: { on in
                if !on || connected {
                    monitoring.setEnabled(on, for: setup.agent)
                } else {
                    requestConnect()
                }
            }))
            .disabled(setup.operation != nil)
    }
}
