import EventBridge
import SessionState
import SwiftUI

/// A session row (decision 0017), with visible status words for ended and failed (decisions 0030, 0035).
struct NotchSessionCard: View {
    let snapshot: SessionSnapshot
    let presentation: NotchCardPresentation
    let nowMs: Int64
    let isActive: Bool
    let detailsOpen: Bool
    var animates = true
    var onJump: (() -> Void)? = nil
    /// Hides the row until the session reports new activity (decision 0030).
    var onRemove: (() -> Void)? = nil
    let onToggleDetails: () -> Void
    @State private var hovering = false

    private var statusWord: (String, Color)? {
        switch snapshot.status {
        case .ended: ("Ended", IslandPalette.mutedText)
        case .responseReady where snapshot.turnFailed: ("Failed", IslandPalette.failed)
        case .idle, .working, .questionNeeded, .approvalNeeded, .responseReady: nil
        }
    }

    private var spokenStatus: String {
        switch snapshot.status {
        case .idle: "Observed idle"
        case .working: "Working"
        case .questionNeeded: "Answer needed"
        case .approvalNeeded: "Approval needed"
        case .responseReady: snapshot.turnFailed ? "Turn failed" : "Response ready"
        case .ended: "Ended"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 8) {
                IslandPhaseIcon(status: snapshot.status, failed: snapshot.turnFailed,
                                size: 32, animates: animates)
                VStack(alignment: .leading, spacing: 2) {
                    headline
                    if let prompt = NotchPresentation.displayText(snapshot.latestPrompt, cwd: snapshot.projectPath) {
                        Text("You: \(prompt)")
                            .font(.system(size: 12))
                            .foregroundStyle(isActive ? IslandPalette.secondaryText : IslandPalette.mutedText)
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }
                    if let activity = activity {
                        Text(activity)
                            .font(.system(size: 12))
                            .foregroundStyle(isActive ? IslandPalette.secondaryText : IslandPalette.dimText)
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .contentShape(Rectangle())
            .onTapGesture { (onJump ?? onToggleDetails)() }
            .onHover { hovering = $0 }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(accessibilityLabel)
            .accessibilityAddTraits(.isButton)
            .accessibilityHint(onJump == nil ? "Shows session details" : "Returns to the session")
            .accessibilityAction(named: detailsOpen ? "Hide details" : "Show details", onToggleDetails)
            .accessibilityAction(named: "Remove from list") { onRemove?() }

            if detailsOpen { details }
        }
    }

    private var headline: some View {
        HStack(spacing: 8) {
            HStack(spacing: 8) {
                ProviderBadge(agent: snapshot.key.agent)
                Text(presentation.folderName)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .truncationMode(.middle)
                if let shortID = presentation.shortSessionID {
                    IslandChip(text: shortID, size: 10)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            HStack(spacing: 8) {
                if let (word, color) = statusWord {
                    IslandChip(text: word, color: color)
                }
                if snapshot.runningSubagents > 0 {
                    IslandChip(text: snapshot.runningSubagents == 1 ? "1 subagent" : "\(snapshot.runningSubagents) subagents")
                        .help("Subagents running in this turn")
                }
                if let timer = presentation.timer {
                    IslandChip(text: NotchPresentation.timerText(seconds: timer.elapsedSeconds(at: nowMs)), monospaced: true)
                }
                Button(action: onToggleDetails) {
                    IslandChip(text: "⋯", color: detailsOpen ? IslandPalette.secondaryText : IslandPalette.mutedText,
                               fill: .white.opacity(detailsOpen ? 0.14 : 0.06))
                }
                .buttonStyle(.plain)
                .opacity(hovering || detailsOpen || isActive ? 1 : 0.5)
                .accessibilityLabel(detailsOpen ? "Hide session details" : "Show session details")
                if let onRemove {
                    Button(action: onRemove) {
                        IslandChip(text: "✕", color: IslandPalette.mutedText, fill: .white.opacity(0.06))
                    }
                    .buttonStyle(.plain)
                    // Shown with the pointer or selection, like the reference; the row action keeps it reachable otherwise.
                    .opacity(hovering || isActive ? 1 : 0)
                    .help("Remove from list until it has new activity")
                    .accessibilityLabel("Remove session from list")
                }
            }
            .fixedSize()
        }
    }

    /// Current activity, else the last reply. The only activity evidence is the tool name.
    private var activity: String? {
        if snapshot.status == .working, let tool = snapshot.currentTool { return "Using \(tool)" }
        return NotchPresentation.displayText(snapshot.lastReply, cwd: snapshot.projectPath)
    }

    private var details: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(snapshot.projectPath.flatMap { $0.isEmpty ? nil : $0 } ?? "Project not observed")
            Text("Session: \(snapshot.key.sessionID)")
            if let receipt = snapshot.receiptWallMs {
                Text("State refreshed: \(Date(timeIntervalSince1970: Double(receipt) / 1000).formatted())")
            }
        }
        .font(.system(size: 11))
        .foregroundStyle(IslandPalette.mutedText)
        .textSelection(.enabled)
        .padding(.leading, 40)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var accessibilityLabel: String {
        var parts = [snapshot.key.agent.displayName, presentation.folderName, spokenStatus]
        if let timer = presentation.timer {
            parts.append("Prompt duration \(NotchPresentation.timerText(seconds: timer.elapsedSeconds(at: nowMs)))")
        }
        if snapshot.runningSubagents > 0 { parts.append("\(snapshot.runningSubagents) subagents running") }
        return parts.joined(separator: ", ")
    }
}

/// Provider name in its color on a 16% fill.
struct ProviderBadge: View {
    let agent: Agent

    var body: some View {
        let color = switch agent {
        case .codex: IslandPalette.codex
        case .claude: IslandPalette.claude
        case .cursor: IslandPalette.cursor
        }
        Text(agent.displayName)
            .font(.system(size: 12))
            .foregroundStyle(color)
            .padding(.horizontal, 4)
            .background(color.opacity(0.16), in: RoundedRectangle(cornerRadius: 4))
            .fixedSize()
    }
}

/// A small metadata chip.
struct IslandChip: View {
    let text: String
    var color: Color = IslandPalette.mutedText
    var fill: Color = IslandPalette.chipFill
    var size: CGFloat = 12
    var monospaced = false

    var body: some View {
        Text(text)
            .font(.system(size: size))
            .monospacedDigit()
            .foregroundStyle(color)
            .padding(.horizontal, 4)
            .background(fill, in: RoundedRectangle(cornerRadius: 4))
            .lineLimit(1)
            .fixedSize()
    }
}
