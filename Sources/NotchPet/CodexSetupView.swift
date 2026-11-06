import EventBridge
import Integration
import SwiftUI

@MainActor
struct CodexSetupView: View {
    let controller: CodexSetupController
    let features: FeatureSettingsModel
    let health: IntegrationHealthSnapshot?
    let showFeatures: () -> Void
    let showNotch: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Codex").font(.headline)
            Text("Connect adds this app’s lifecycle hooks. Finish other configuration edits before connecting or removing hooks.")
                .font(.callout).foregroundStyle(.secondary)
            if CodexSetupService.qualifiedReleases.isEmpty {
                Text("Automatic connection is awaiting Codex release qualification. Check and owned-hook removal remain available.")
                    .font(.callout).foregroundStyle(.secondary)
            }
            HStack {
                Button("Connect…") { controller.requestConfirmation(.connect) }
                Button("Check") { controller.start(.check) }
                Button("Remove hooks…") { controller.requestConfirmation(.remove) }
                if controller.operation != nil {
                    ProgressView().controlSize(.small)
                }
            }
            .disabled(controller.operation != nil)
            if controller.operation != nil {
                Button("Cancel", action: controller.cancel)
            }
            Text(controller.message).font(.callout).textSelection(.enabled)
            if let inspection = controller.inspection {
                LabeledContent("Version", value: version(inspection.health.version))
                LabeledContent("Configuration", value: configuration(inspection.health.configuration))
                LabeledContent("Helper", value: helper(inspection.health.helper))
                LabeledContent("Owned hooks", value: ownership(inspection.ownership))
                if let reason = inspection.installationUnavailable {
                    Text(CodexSetupController.explanation(reason)).font(.caption).foregroundStyle(.secondary)
                }
            }
            LabeledContent("Receiver", value: receiver)
            LabeledContent("Last delivery", value: health?.lastDelivery.map {
                Date(timeIntervalSince1970: Double($0.wallMs) / 1000).formatted(date: .abbreviated, time: .shortened)
            } ?? "Not observed")
            Text("Installation does not grant Codex’s hook trust or prove that an event arrived.")
                .font(.caption).foregroundStyle(.secondary)
            if !features.installed.contains(.notch) {
                Text("Notch is not installed. Monitoring can run independently; add Notch from Features to see session cards and limits.")
                    .font(.callout).foregroundStyle(.secondary)
                Button("Manage Features", action: showFeatures)
            } else {
                Button("Show Notch", action: showNotch)
            }
        }
        .alert(controller.confirmation == .remove ? "Remove owned Codex hooks?" : "Connect Codex?",
               isPresented: confirmation) {
            Button("Cancel", role: .cancel) {}
            if let action = controller.confirmation {
                Button(action == .remove ? "Remove hooks" : "Connect",
                       role: action == .remove ? .destructive : nil) {
                    controller.start(action)
                }
            }
        } message: {
            if controller.confirmation == .remove {
                Text("Only unchanged, uniquely owned entries can be removed. Finish other configuration edits first. Monitoring and unresolved requests are managed separately.")
            } else {
                Text("This adds seven owned hooks and enables monitoring when setup succeeds. Finish other Codex configuration edits first. Codex’s normal trust review still applies.")
            }
        }
    }

    private var confirmation: Binding<Bool> {
        Binding(get: { controller.confirmation != nil }, set: { visible in
            if !visible { controller.dismissConfirmation() }
        })
    }

    private var receiver: String {
        guard features.monitoringEnabled else { return "Monitoring off" }
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
        case .missing: "No hooks file"
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

    private func ownership(_ evidence: CodexOwnedHooks) -> String {
        switch evidence {
        case .notOwned: "Not installed"
        case .owned: "Entries match"
        case .conflict: "Conflict"
        case .recoveryRequired: "Recovery needed"
        }
    }
}
