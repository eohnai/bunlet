import SessionState
import SwiftUI

struct NotchSessionCard: View {
    let snapshot: SessionSnapshot
    let presentation: NotchCardPresentation
    let nowMs: Int64
    @Binding var selection: SessionKey?

    private var status: String {
        switch snapshot.status {
        case .idle: "Observed idle"
        case .working: "Working"
        case .questionNeeded: "Answer needed"
        case .approvalNeeded: "Approval needed"
        case .responseReady: "Response ready"
        case .unknown: "Unknown"
        case .ended: "Ended"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button {
                selection = selection == snapshot.key ? nil : snapshot.key
            } label: {
                HStack(spacing: 10) {
                    Text(snapshot.key.agent == "codex" ? "Codex" : "Claude Code")
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 6))
                        .fixedSize()

                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 4) {
                            Text(presentation.folderName)
                                .fontWeight(.medium)
                                .lineLimit(1)
                                .truncationMode(.middle)
                            Text("· \(status)")
                                .foregroundStyle(snapshot.status == .unknown ? .orange : .white.opacity(0.8))
                                .fixedSize()
                        }
                        if let shortID = presentation.shortSessionID {
                            Text(shortID)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    if let timer = presentation.timer {
                        let timerText = NotchPresentation.timerText(seconds: timer.elapsedSeconds(at: nowMs))
                        Text(timerText)
                            .monospacedDigit()
                            .fixedSize()
                            .accessibilityLabel("Prompt duration: \(timerText)")
                    }
                    Image(systemName: selection == snapshot.key ? "chevron.up" : "chevron.down")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .accessibilityHidden(true)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityHint(selection == snapshot.key ? "Hide session details" : "Show session details")

            if selection == snapshot.key {
                VStack(alignment: .leading, spacing: 6) {
                    Text(snapshot.projectPath.flatMap { $0.isEmpty ? nil : $0 } ?? "Project not observed")
                    Text("Session: \(snapshot.key.sessionID)")
                    if snapshot.status == .unknown {
                        Text("Current activity is unconfirmed. Fresh session evidence is needed.")
                            .foregroundStyle(.secondary)
                    }
                    if let receipt = snapshot.receiptWallMs {
                        Text("State refreshed: \(Date(timeIntervalSince1970: Double(receipt) / 1000).formatted())")
                            .foregroundStyle(.secondary)
                    }
                }
                .font(.caption)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .font(.callout)
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 12))
    }
}
