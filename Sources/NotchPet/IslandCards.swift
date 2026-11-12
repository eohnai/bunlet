import SessionState
import SwiftUI

/// Card container: hairline border, faint fill, optional header strip.
struct IslandCard<Header: View, Content: View>: View {
    var cornerRadius: CGFloat = 4
    @ViewBuilder let header: Header
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
                .padding(.vertical, 5)
                .padding(.horizontal, 8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(IslandPalette.cardHeaderFill)
                .overlay(alignment: .bottom) { Rectangle().fill(IslandPalette.cardDivider).frame(height: 1) }
            content
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(IslandPalette.cardFill, in: RoundedRectangle(cornerRadius: cornerRadius))
        .overlay { RoundedRectangle(cornerRadius: cornerRadius).strokeBorder(IslandPalette.cardBorder, lineWidth: 1) }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
    }
}

/// Card buttons: deny, allow, jump, submit and cancel.
struct IslandButtonStyle: ButtonStyle {
    enum Kind { case deny, allow, jump, submit, cancel }
    let kind: Kind
    var cornerRadius: CGFloat = 4
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .medium))
            .lineLimit(1)
            .padding(.vertical, 5)
            .padding(.horizontal, 6)
            .frame(maxWidth: kind == .cancel ? 80 : .infinity)
            .foregroundStyle(foreground)
            .background(background(pressed: configuration.isPressed), in: RoundedRectangle(cornerRadius: cornerRadius))
            .overlay {
                if kind == .cancel {
                    RoundedRectangle(cornerRadius: cornerRadius).strokeBorder(IslandPalette.cardBorder, lineWidth: 1)
                }
            }
            .opacity(isEnabled ? 1 : 0.45)
            .contentShape(RoundedRectangle(cornerRadius: cornerRadius))
    }

    private var foreground: Color {
        switch kind {
        case .deny: IslandPalette.secondaryText
        case .allow, .submit: Color(red: 0x0C / 255, green: 0x0C / 255, blue: 0x0D / 255)
        case .jump: Color(red: 0xF5 / 255, green: 0xF7 / 255, blue: 1)
        case .cancel: IslandPalette.mutedText
        }
    }

    private func background(pressed: Bool) -> Color {
        let base: Color = switch kind {
        case .deny: .white.opacity(0.08)
        case .allow: Color(red: 0xDA / 255, green: 0xDD / 255, blue: 0xE5 / 255)
        case .submit: Color(red: 0xD8 / 255, green: 0xDD / 255, blue: 0xE7 / 255)
        case .jump: .white.opacity(0.14)
        case .cancel: .clear
        }
        return pressed ? base.opacity(0.8) : base
    }
}

/// An observed request without a local reply channel: answer it in the terminal.
struct NotchRequestCard: View {
    let request: SessionRequest
    var onJump: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            IslandCard {
                Text(request.toolName)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(IslandPalette.secondaryText)
                    .lineLimit(1)
                    .truncationMode(.middle)
            } content: {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(request.isConfirmed ? "Pending" : "Unconfirmed") \(request.kind == .questionNeeded ? "question" : "approval")")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(request.isConfirmed ? IslandPalette.attention : IslandPalette.mutedText)
                    Text(request.kind == .questionNeeded ? "Answer it in the terminal." : "Approve or deny it in the terminal.")
                        .font(.system(size: 12))
                        .foregroundStyle(IslandPalette.mutedText)
                }
            }
            if let onJump {
                Button("Jump to terminal", action: onJump).buttonStyle(IslandButtonStyle(kind: .jump))
            }
        }
        .accessibilityElement(children: .contain)
    }
}

/// Completion card for the focused session: prompt, the reply preview, and a way back to the terminal.
struct CompletionCard: View {
    let snapshot: SessionSnapshot
    var onJump: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            IslandCard(cornerRadius: 6) {
                HStack(spacing: 8) {
                    Text("Completed")
                        .font(.system(size: 12))
                        .foregroundStyle(IslandPalette.secondaryText)
                    if let prompt = NotchPresentation.displayText(snapshot.latestPrompt, cwd: snapshot.projectPath) {
                        Text(prompt)
                            .font(.system(size: 12))
                            .foregroundStyle(.white.opacity(0.42))
                            .lineLimit(1)
                    }
                }
            } content: {
                ScrollView {
                    Text(NotchPresentation.displayText(snapshot.lastReply, cwd: snapshot.projectPath) ?? "")
                        .font(.system(size: 12))
                        .lineSpacing(4)
                        .foregroundStyle(.white)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxHeight: 200)
                .fixedSize(horizontal: false, vertical: true)
            }
            if let onJump {
                Button("Jump to terminal", action: onJump)
                    .buttonStyle(IslandButtonStyle(kind: .jump, cornerRadius: 6))
            }
        }
    }
}
