import EventBridge
import AgentActions
import Integration
import SwiftUI
import Usage

@MainActor
struct ProviderSetupView: View {
    let controller: ProviderSetupController
    let features: FeatureSettingsModel
    let health: IntegrationHealthSnapshot?
    let monitoring: ProviderMonitoringModel
    let quota: UsageStore?
    let localActions: LocalActionController?
    let showFeatures: () -> Void
    let showNotch: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(controller.providerName).font(.headline)
            Text("Connect adds this app’s lifecycle hooks. Finish other configuration edits before connecting or removing hooks.")
                .font(.callout).foregroundStyle(.secondary)
            Text("Documented integration; runtime verification has not run. Setup does not enable hooks, change permissions or grant trust.")
                .font(.callout).foregroundStyle(.secondary)
            HStack {
                Button("Connect…") { controller.requestConfirmation(.connect) }
                Button("Check") { controller.start(.check) }
                Button("Repair…") { controller.requestConfirmation(.repair) }
                Button("Remove hooks…") { controller.requestConfirmation(.remove) }
                if controller.operation != nil {
                    ProgressView().controlSize(.small)
                }
            }
            .disabled(controller.operation != nil)
            HStack {
                Button(isMonitoring ? "Pause" : "Resume") {
                    let resume = !isMonitoring
                    monitoring.setEnabled(resume, for: controller.agent)
                }
                Button("Disconnect…") { controller.requestConfirmation(.disconnect) }
                Text(isMonitoring ? "Monitoring enabled" : "Monitoring paused")
                    .font(.caption).foregroundStyle(.secondary)
            }
            .disabled(controller.operation != nil)
            if monitoring.writeIssue == controller.agent {
                Text("Monitoring is paused for this run; its preference could not be saved. Retry before reopening.")
                    .font(.caption).foregroundStyle(.red)
            }
            if controller.operation != nil {
                Button("Cancel", action: controller.cancel)
            }
            Text(controller.message).font(.callout).textSelection(.enabled)
            if let inspection = controller.inspection {
                LabeledContent("Version", value: version(inspection.health.version))
                LabeledContent("Configuration", value: configuration(inspection.health.configuration))
                LabeledContent("Helper", value: helper(inspection.health.helper))
                LabeledContent("Owned hooks", value: ownership(inspection.ownership))
                LabeledContent("Hook policy", value: policy(inspection.policy))
                LabeledContent("Runtime qualification", value: inspection.runtimeQualified ? "Recorded" : "Not run")
                if let reason = inspection.installationUnavailable {
                    Text(ProviderSetupController.explanation(reason, agent: controller.agent)).font(.caption).foregroundStyle(.secondary)
                }
            }
            LabeledContent("Receiver", value: receiver)
            LabeledContent("Last delivery", value: health?.lastDelivery.map {
                Date(timeIntervalSince1970: Double($0.wallMs) / 1000).formatted(date: .abbreviated, time: .shortened)
            } ?? "Not observed")
            Text("Installation does not grant hook/workspace trust or prove that an event arrived.")
                .font(.caption).foregroundStyle(.secondary)
            if controller.agent == .claude, let quota {
                Text("Quota forwarding").font(.subheadline.weight(.semibold))
                HStack {
                    Button("Connect quota…") { controller.requestConfirmation(.connectQuota) }
                    Button("Check quota") { controller.start(.checkQuota) }
                    Button("Remove forwarding…") { controller.requestConfirmation(.removeQuota) }
                }
                .disabled(controller.operation != nil)
                Text("Wraps your existing status line and preserves its output. Lifecycle hooks are separate.")
                    .font(.caption).foregroundStyle(.secondary)
                if let inspection = controller.quotaInspection {
                    LabeledContent("Owned forwarding", value: ownership(inspection.ownership))
                    LabeledContent("Status-line helper", value: helper(inspection.health.helper))
                    if let reason = inspection.installationUnavailable {
                        Text(ProviderSetupController.explanation(reason, agent: .claude))
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
                LabeledContent("Quota receiver", value: quota.receiverState == .listening ? "Listening" :
                    (quota.receiverState == .unavailable ? "Unavailable; pause and resume to retry" : "Stopped"))
                LabeledContent("Last quota receipt", value: quota.lastClaudeReceiptMs.map {
                    Date(timeIntervalSince1970: Double($0) / 1000).formatted(date: .abbreviated, time: .shortened)
                } ?? "Not observed")
                if quota.intakeLost || quota.capacityReached || quota.invalidIntake {
                    Text("Quota intake rejected or lost data. A later valid reading is needed.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            if controller.agent == .claude { responseControls }
            Button("Show Notch", action: showNotch)
        }
        .alert("\(confirmationTitle) \(controller.providerName)?",
               isPresented: confirmation) {
            Button("Cancel", role: .cancel) {}
            if let action = controller.confirmation {
                Button(confirmationTitle, role: removing ? .destructive : nil) {
                    controller.start(action)
                }
            }
        } message: {
            if controller.confirmation?.scope == .claudeActions {
                Text(removing
                     ? "Disable local responses and remove only unchanged owned interactive hooks. Lifecycle monitoring and quota forwarding stay configured. Pending responses fall back to the terminal."
                     : "Add three owned interactive hooks and enable local responses. Each finished response can wait up to 60 seconds for follow-up feedback in the same prompt, including while you open Settings. Nothing is sent without your explicit decision. Normal trust/policy applies; runtime support is unverified.")
            } else if controller.confirmation?.scope == .claudeQuota {
                Text(removing
                     ? "Restore the exact original status-line value only if the owned wrapper is unchanged. Lifecycle hooks stay in place."
                     : "Wrap the existing status-line command while preserving its input and output, or install a silent forwarder if none exists. Creating a status line may hide Claude’s built-in footer hints. Runtime compatibility is unverified.")
            } else if removing {
                Text("Only unchanged, uniquely owned entries can be removed. Finish other configuration edits first. Disconnect pauses this provider before removal; retained requests stay unconfirmed.")
            } else {
                Text("This installs or checks seven owned hooks and resumes monitoring after success. Repair recovers only known saved states and preserves conflicting edits. Finish other configuration edits first. Runtime support is unverified and normal trust review still applies.")
            }
        }
    }

    private var responseControls: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Local responses").font(.subheadline.weight(.semibold))
            HStack {
                Button("Connect actions…") { controller.requestConfirmation(.connectActions) }
                Button("Check actions") { controller.start(.checkActions) }
                Button("Remove actions…") { controller.requestConfirmation(.removeActions) }
            }
            .disabled(controller.operation != nil)
            Text("Approve once, answer structured questions, or send feedback through a waiting Stop hook. Reply windows last at most 60 seconds and can delay returning to the terminal prompt.")
                .font(.caption).foregroundStyle(.secondary)
            Button(monitoring.actionsEnabled ? "Pause local responses" : "Resume local responses") {
                monitoring.setActionsEnabled(!monitoring.actionsEnabled)
            }
            .disabled(controller.operation != nil)
            Text(monitoring.actionsEnabled ? "Local response consent enabled; Claude monitoring must also be on." : "Local response consent off.")
                .font(.caption).foregroundStyle(.secondary)
            if monitoring.actionWriteIssue {
                Text("Local responses are disabled for this run; their preference could not be saved. Retry before reopening.")
                    .font(.caption).foregroundStyle(.red)
            }
            if let inspection = controller.actionInspection {
                LabeledContent("Owned interactive hooks", value: ownership(inspection.ownership))
                LabeledContent("Interactive helper", value: helper(inspection.health.helper))
                if let reason = inspection.installationUnavailable {
                    Text(ProviderSetupController.explanation(reason, agent: .claude)).font(.caption).foregroundStyle(.secondary)
                }
            }
            if let localActions {
                Text(localActions.status).font(.caption).foregroundStyle(.secondary)
                ForEach(localActions.store.snapshots) { action in
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Session: \(action.offer.sessionID)").font(.caption).textSelection(.enabled)
                        LocalActionView(snapshot: action, controller: localActions, beginInput: {})
                    }
                }
            }
        }
    }

    private var isMonitoring: Bool { features.monitoringEnabled && monitoring.isEnabled(controller.agent) }
    private var removing: Bool { controller.confirmation?.removes == true }
    private var confirmationTitle: String {
        switch controller.confirmation {
        case .remove: "Remove owned hooks for"
        case .disconnect: "Disconnect"
        case .repair: "Repair"
        case .connectQuota: "Connect quota for"
        case .removeQuota: "Remove quota forwarding for"
        case .connectActions: "Connect local responses for"
        case .removeActions: "Remove local responses for"
        default: "Connect"
        }
    }

    private func policy(_ value: ProviderHookEnablement) -> String {
        switch value {
        case .enabled: "Enabled in the inspected configuration"
        case .disabled: "Disabled in the inspected policy/settings"
        case .managedOnly: "Managed hooks only"
        case .unverified: "Unverified; project or managed policy may prevent hooks"
        }
    }

    private var confirmation: Binding<Bool> {
        Binding(get: { controller.confirmation != nil }, set: { visible in
            if !visible { controller.dismissConfirmation() }
        })
    }

    private var receiver: String {
        guard isMonitoring else { return "Monitoring paused" }
        switch health?.receiver {
        case .listening: return "Ready"
        case .failed: return "Unavailable"
        case .stopped, .notStarted, nil: return "Not started"
        }
    }

    private func version(_ evidence: IntegrationVersionEvidence) -> String {
        switch evidence {
        case .notChecked: "Not checked"
        case .reported(let version): version
        case .unavailable: "Unavailable"
        }
    }

    private func configuration(_ evidence: IntegrationConfigurationEvidence) -> String {
        switch evidence {
        case .notChecked: "Not checked"
        case .missing: "No configuration file"
        case .recognizedShape(let events, let commands): "\(events) event groups, \(commands) commands"
        case .unavailable: "Unavailable or unsupported"
        }
    }

    private func helper(_ evidence: IntegrationHelperAvailability) -> String {
        switch evidence {
        case .notChecked: "Not checked"
        case .available: "Available"
        case .missing, .notExecutable, .unavailable: "Unavailable"
        }
    }

    private func ownership(_ evidence: OwnedProviderHooks) -> String {
        switch evidence {
        case .notOwned: "Not installed"
        case .owned: "Entries match"
        case .conflict: "Conflict"
        case .recoveryRequired: "Recovery needed"
        }
    }
}
