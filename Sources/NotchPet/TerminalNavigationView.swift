import SessionState
import SwiftUI

struct TerminalNavigationView: View {
    let controller: TerminalNavigation
    var session: SessionKey? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Return to terminal").font(.subheadline.weight(.semibold))
            HStack {
                Button("Choose Application…", action: controller.chooseApplication)
                if let name = controller.preferredName {
                    Button("Activate \(name)", action: controller.activateApplication)
                }
            }
            .disabled(controller.busy)
            if let session {
                if controller.hasLinkedPane(session) {
                    HStack {
                        Button("Focus Linked Pane") { controller.focusLinkedPane(for: session) }
                        Button("Unlink") { controller.unlink(session) }
                    }
                    .disabled(controller.busy)
                }
                if controller.canLinkPreferredPane {
                    Text("Select the intended pane in your terminal, return here, then link it. This association is made by you; agent-to-pane mapping is unverified.")
                        .font(.caption).foregroundStyle(.secondary)
                    Button("Link Current Pane") { controller.linkCurrentPane(to: session) }.disabled(controller.busy)
                }
            }
            if controller.busy { Button("Cancel Navigation", action: controller.cancel) }
            Text(controller.message).font(.caption).foregroundStyle(.secondary)
            Text("Application activation works independently of pane support. Otherwise return to your existing session manually. Navigation never creates a replacement session.")
                .font(.caption).foregroundStyle(.secondary)
        }
    }
}
