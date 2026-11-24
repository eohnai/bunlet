import EventBridge
import Integration
import SwiftUI

/// The switches control monitoring. Setup and approval controls are available under Advanced.
struct AgentsSettingsPage: View {
    let actions: AppSettingsActions
    @State private var advanced = false
    @State private var expanded: Set<Agent> = []
    private let agents: [Agent] = [.claude, .codex, .cursor]

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            SettingsGroup(title: "Session Monitoring") {
                ForEach(agents, id: \.self) { agent in
                    if let setup = controller(agent), let monitoring = actions.monitoring() {
                        AgentRow(setup: setup, monitoring: monitoring, health: health(agent), last: agent == agents.last)
                    }
                }
            }
            SettingsGroup {
                SettingsBlock(last: true) {
                    DisclosureGroup("Advanced", isExpanded: $advanced) {
                        advancedSettings.padding(.top, 12)
                    }
                    .font(.system(size: 14))
                    .foregroundStyle(.white)
                }
            }
        }
        .onChange(of: advanced) { _, open in
            guard open else { return }
            for agent in agents where controller(agent)?.inspection == nil { controller(agent)?.start(.check) }
        }
    }

    private var advancedSettings: some View {
        VStack(alignment: .leading, spacing: 16) {
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

    private var connected: Bool {
        if case .owned = setup.inspection?.ownership { return true }
        return false
    }

    private var status: String {
        if monitoring.writeIssue == setup.agent { return "Preference could not be saved" }
        if !monitoring.isEnabled(setup.agent) { return "Paused" }
        if setup.operation?.scope == .lifecycle { return "Checking setup…" }
        if setup.inspection?.installationUnavailable == .executableNotFound {
            return setup.agent.desktopBundleIdentifier == nil ? "Agent not found" : "Waiting for local coding runtime"
        }
        if connected {
            if case .failed = health?.receiver { return "Receiver unavailable" }
            return health?.lastDelivery == nil ? "Waiting for a session" : "Receiving sessions"
        }
        return "Setup needed"
    }

    var body: some View {
        SettingsToggleRow(title: setup.providerName, subtitle: status, last: last, isOn: Binding(
            get: { monitoring.isEnabled(setup.agent) },
            set: { monitoring.setEnabled($0, for: setup.agent) }))
            .disabled(setup.operation != nil)
    }
}
