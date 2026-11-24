import SessionState
import SwiftUI

/// Colors used across the island (decision 0017).
enum IslandPalette {
    static let secondaryText = Color(red: 0xD1 / 255, green: 0xD3 / 255, blue: 0xDB / 255)
    static let mutedText = Color(red: 0x95 / 255, green: 0x99 / 255, blue: 0xA6 / 255)
    static let dimText = Color(red: 0x64 / 255, green: 0x6B / 255, blue: 0x77 / 255)
    static let chipFill = Color(red: 224 / 255, green: 230 / 255, blue: 242 / 255).opacity(0.06)
    static let cardFill = Color(red: 224 / 255, green: 230 / 255, blue: 242 / 255).opacity(0.04)
    static let cardHeaderFill = Color(red: 221 / 255, green: 230 / 255, blue: 244 / 255).opacity(0.04)
    static let cardBorder = Color(red: 224 / 255, green: 226 / 255, blue: 242 / 255).opacity(0.16)
    static let cardDivider = Color(red: 224 / 255, green: 226 / 255, blue: 242 / 255).opacity(0.1)
    static let divider = Color.white.opacity(0.07)
    static let attention = Color(red: 1, green: 0xD6 / 255, blue: 0x0A / 255)
    static let workingHare = Color(red: 0x65 / 255, green: 0xAE / 255, blue: 1)
    static let attentionHare = Color(red: 1, green: 0x9F / 255, blue: 0x43 / 255)
    static let completed = Color(red: 0x42 / 255, green: 0xE8 / 255, blue: 0x6B / 255)
    static let unknown = Color.orange
    static let claude = Color(red: 0xDA / 255, green: 0x72 / 255, blue: 0x50 / 255)
    static let codex = Color(red: 0x8E / 255, green: 0xA1 / 255, blue: 0xFF / 255)
    static let cursor = Color(red: 0xD4 / 255, green: 0xD4 / 255, blue: 0xD8 / 255)
}

/// Bunlet's own phase artwork. Running animates only when motion is allowed.
struct IslandPhaseIcon: View {
    enum Kind: Equatable { case idle, running, attention, completed, unknown, ended }
    let kind: Kind
    let size: CGFloat
    let animates: Bool
    private var alignment: Alignment = .center
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            switch kind {
            case .idle:
                hare(.white.opacity(0.9))
            case .running:
                hare(IslandPalette.workingHare)
                    .modifier(WorkingHarePulse(enabled: animates && !reduceMotion))
            case .attention:
                hare(IslandPalette.attentionHare)
            case .completed:
                hare(IslandPalette.completed)
            case .unknown:
                Image(systemName: "questionmark.circle").resizable().scaledToFit()
                    .padding(size * 0.14).foregroundStyle(IslandPalette.unknown)
            case .ended:
                Image(systemName: "stop.circle").resizable().scaledToFit()
                    .padding(size * 0.14).foregroundStyle(IslandPalette.mutedText)
            }
        }
        .frame(width: size, height: size, alignment: alignment)
        .accessibilityHidden(true)
    }

    private func hare(_ color: Color) -> some View {
        Image(systemName: "hare.fill")
            .resizable()
            .scaledToFit()
            .frame(width: size * 0.6, height: size * 0.6)
            .foregroundStyle(color)
    }

    init(kind: Kind, size: CGFloat, animates: Bool = true) {
        self.animates = animates
        self.kind = kind
        self.size = size
    }

    init(phase: IslandPhase, size: CGFloat, animates: Bool = true, alignment: Alignment = .center) {
        self.animates = animates
        self.alignment = alignment
        switch phase {
        case .idle: kind = .idle
        case .running: kind = .running
        case .attention: kind = .attention
        case .completed: kind = .completed
        }
        self.size = size
    }

    init(status: SessionStatus, hasConfirmedRequest: Bool, size: CGFloat, animates: Bool = true) {
        self.animates = animates
        if hasConfirmedRequest {
            kind = .attention
        } else {
            switch status {
            case .working: kind = .running
            case .approvalNeeded, .questionNeeded: kind = .attention
            case .responseReady: kind = .completed
            case .idle: kind = .idle
            case .unknown: kind = .unknown
            case .ended: kind = .ended
            }
        }
        self.size = size
    }
}

/// Keeps the working hare distinguishable in motion while honoring Reduce Motion and visibility.
private struct WorkingHarePulse: ViewModifier {
    let enabled: Bool

    func body(content: Content) -> some View {
        TimelineView(.animation(minimumInterval: 1.0 / 24, paused: !enabled)) { context in
            let cycle = context.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 2)
            content.opacity(enabled ? 0.9 + 0.1 * cos(cycle * .pi) : 1)
        }
    }
}

/// The closed island: phase icon, optional label (no-notch screens only), visible session count.
struct IslandPillView: View {
    let sessions: [SessionSnapshot]
    let hasNotch: Bool
    let latestPrompt: String?
    var animates = true

    var body: some View {
        let phase = IslandPhase.dominant(sessions)
        HStack(spacing: 6) {
            IslandPhaseIcon(phase: phase, size: 28, animates: animates, alignment: .leading)
            if let label = label(phase: phase) {
                label
                    .font(.system(size: 12, weight: .semibold))
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: .infinity, alignment: sessions.isEmpty ? .trailing : .leading)
            } else {
                Spacer(minLength: 0)
            }
            if !sessions.isEmpty {
                Text("\(sessions.count)")
                    .font(.system(size: 12, weight: .semibold))
                    .kerning(-0.2)
                    .monospacedDigit()
                    .foregroundStyle(.white.opacity(0.9))
            }
        }
        .padding(.horizontal, 10)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
    }

    private func label(phase: IslandPhase) -> Text? {
        // A notched screen has no room beside the cutout for words.
        guard !hasNotch else { return nil }
        if sessions.isEmpty { return Text("Bunlet").foregroundColor(.white.opacity(0.9)) }
        switch phase {
        case .attention:
            return Text("Please note").foregroundColor(IslandPalette.attention)
        case .completed:
            let count = sessions.filter { $0.status == .responseReady }.count
            return Text("\(count) Completed").foregroundColor(IslandPalette.completed)
        case .running:
            if let latestPrompt, !latestPrompt.isEmpty {
                return Text("You: \(latestPrompt)").foregroundColor(.white.opacity(0.9))
            }
            return Text("In Progress").foregroundColor(.white.opacity(0.9))
        case .idle:
            return nil
        }
    }
}
