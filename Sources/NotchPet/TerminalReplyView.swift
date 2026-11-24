import SessionState
import SwiftUI

/// "Reply in terminal" under a session that is waiting at its prompt (decision 0025).
struct TerminalReplyView: View {
    let session: SessionSnapshot
    let controller: TerminalReplyController
    let beginInput: () -> Void
    @State private var editing = false
    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if !editing {
                Button("💬 Reply in terminal") {
                    beginInput()
                    editing = true
                    focused = true
                }
                .buttonStyle(IslandButtonStyle(kind: .jump, cornerRadius: 6))
            } else {
                TextField("Message for this session", text: Binding(get: { controller.draft(for: session.key) },
                                                                   set: { controller.setDraft($0, for: session.key) }))
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
                    .padding(6)
                    .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 4))
                    .focused($focused)
                    .onSubmit { controller.send(session.key) }
                    .accessibilityLabel("Reply typed into this session's terminal")
                HStack {
                    Text(status)
                        .font(.system(size: 11))
                        .foregroundStyle(controller.phases[session.key] == .failed ? .orange : IslandPalette.mutedText)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer()
                    Button("Cancel") {
                        controller.discard(session.key)
                        editing = false
                        focused = false
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 12))
                    .foregroundStyle(IslandPalette.mutedText)
                    Button("Send") { controller.send(session.key) }
                        .buttonStyle(IslandButtonStyle(kind: .submit, cornerRadius: 6))
                        .frame(width: 64)
                        .disabled(!controller.canSend(session.key))
                }
            }
        }
        .padding(.horizontal, 4)
        .onExitCommand {
            editing = false
            focused = false
        }
    }

    private var status: String {
        switch controller.phases[session.key] {
        case .sending: "Typing into the pane…"
        case .sent: "Typed into the pane and pressed Return."
        case .failed: "Could not reach the pane. Nothing was retried; return to the terminal."
        case nil: "Typed into this session's own pane as one line, then Return."
        }
    }
}
