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
    private(set) var actionsEnabled: Bool
    private(set) var actionWriteIssue = false
    private static let actionsKey = "agents.claude.localResponsesEnabled"
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let onChange: (Set<Agent>) -> Void

    init(defaults: UserDefaults, onChange: @escaping (Set<Agent>) -> Void) {
        self.defaults = defaults
        self.onChange = onChange
        let actionConsent = defaults.object(forKey: Self.actionsKey) as? NSNumber
        actionsEnabled = actionConsent.map { CFGetTypeID($0) == CFBooleanGetTypeID() && $0.boolValue } ?? false
        let consent = defaults.object(forKey: "agentMonitoringEnabled") as? NSNumber
        let legacyEnabled = consent.map { CFGetTypeID($0) == CFBooleanGetTypeID() && $0.boolValue } ?? false
        enabledProviders = Set(Agent.allCases.filter { agent in
            let value = defaults.object(forKey: Self.key(agent))
            // Preserve the earlier global monitoring choice until a per-provider choice is saved.
            guard let value else { return legacyEnabled }
            guard let boolean = value as? NSNumber, CFGetTypeID(boolean) == CFBooleanGetTypeID() else { return false }
            return boolean.boolValue
        })
    }

    func isEnabled(_ agent: Agent) -> Bool { enabledProviders.contains(agent) }

    func setActionsEnabled(_ enabled: Bool) {
        if !enabled {
            actionsEnabled = false
            onChange(enabledProviders)
        }
        defaults.set(enabled, forKey: Self.actionsKey)
        guard let value = defaults.object(forKey: Self.actionsKey) as? NSNumber,
              CFGetTypeID(value) == CFBooleanGetTypeID(), value.boolValue == enabled else {
            actionsEnabled = false
            actionWriteIssue = true
            onChange(enabledProviders)
            return
        }
        actionsEnabled = enabled
        actionWriteIssue = false
        onChange(enabledProviders)
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
