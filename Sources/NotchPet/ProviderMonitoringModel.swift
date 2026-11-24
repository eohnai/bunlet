import CoreFoundation
import EventBridge
import Foundation
import Observation

/// Consent is separate from hook installation and the master Agents runtime switch.
@MainActor
@Observable
final class ProviderMonitoringModel {
    private(set) var enabledProviders: Set<Agent>
    private(set) var writeIssue: Agent?
    /// Agents whose requests are answered in Bunlet. Claude: local responses. Codex: "Approve in Bunlet" (decision 0025).
    private(set) var actionAgents: Set<Agent>
    var actionsEnabled: Bool { actionAgents.contains(.claude) }
    private(set) var actionWriteIssue = false
    private static let quotaKey = "agents.claude.quotaAutoConnect"
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let onChange: (Set<Agent>) -> Void

    init(defaults: UserDefaults, onChange: @escaping (Set<Agent>) -> Void) {
        self.defaults = defaults
        self.onChange = onChange
        // Both default off: Claude needs explicit consent, and Codex approves in its terminal unless chosen otherwise.
        actionAgents = Set(Agent.allCases.filter { agent in
            (defaults.object(forKey: Self.actionsKey(agent)) as? NSNumber)
                .map { CFGetTypeID($0) == CFBooleanGetTypeID() && $0.boolValue } ?? false
        })
        let consent = defaults.object(forKey: "agentMonitoringEnabled") as? NSNumber
        // Agents start on (decision 0023). An earlier saved global choice, and any per-provider choice, still wins.
        let legacyEnabled = consent.map { CFGetTypeID($0) == CFBooleanGetTypeID() && $0.boolValue } ?? true
        enabledProviders = Set(Agent.allCases.filter { agent in
            let value = defaults.object(forKey: Self.key(agent))
            // Preserve the earlier global monitoring choice until a per-provider choice is saved.
            guard let value else { return legacyEnabled }
            guard let boolean = value as? NSNumber, CFGetTypeID(boolean) == CFBooleanGetTypeID() else { return false }
            return boolean.boolValue
        })
    }

    func isEnabled(_ agent: Agent) -> Bool { enabledProviders.contains(agent) }

    /// Whether launch may add or repair Claude's quota forwarding. Removing it by hand turns this off (decision 0024).
    var quotaAutoConnect: Bool {
        guard let value = defaults.object(forKey: Self.quotaKey) as? NSNumber, CFGetTypeID(value) == CFBooleanGetTypeID() else { return true }
        return value.boolValue
    }

    func setQuotaAutoConnect(_ on: Bool) { defaults.set(on, forKey: Self.quotaKey) }

    func setActionsEnabled(_ enabled: Bool, for agent: Agent = .claude) {
        if !enabled {
            actionAgents.remove(agent)
            onChange(enabledProviders)
        }
        defaults.set(enabled, forKey: Self.actionsKey(agent))
        guard let value = defaults.object(forKey: Self.actionsKey(agent)) as? NSNumber,
              CFGetTypeID(value) == CFBooleanGetTypeID(), value.boolValue == enabled else {
            actionAgents.remove(agent)
            actionWriteIssue = true
            onChange(enabledProviders)
            return
        }
        if enabled { actionAgents.insert(agent) }
        actionWriteIssue = false
        onChange(enabledProviders)
    }

    /// Claude keeps its original key so existing consent carries over.
    private static func actionsKey(_ agent: Agent) -> String {
        agent == .claude ? "agents.claude.localResponsesEnabled" : "agents.\(agent.rawValue).approveInBunlet"
    }

    func setEnabled(_ enabled: Bool, for agent: Agent) {
        // A failed pause preference still stops intake for this run.
        if !enabled {
            enabledProviders.remove(agent)
            onChange(enabledProviders)
        }
        defaults.set(enabled, forKey: Self.key(agent))
        guard let value = defaults.object(forKey: Self.key(agent)) as? NSNumber,
              CFGetTypeID(value) == CFBooleanGetTypeID(), value.boolValue == enabled else {
            enabledProviders.remove(agent)
            writeIssue = agent
            onChange(enabledProviders)
            return
        }
        if enabled { enabledProviders.insert(agent) }
        writeIssue = nil
        onChange(enabledProviders)
    }

    private static func key(_ agent: Agent) -> String { "agents.monitoring.\(agent.rawValue).enabled" }
}
