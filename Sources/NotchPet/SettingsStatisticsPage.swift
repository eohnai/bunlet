import SwiftUI
import Usage

/// Statistics (decision 0025): Claude token totals per day from the status line. Codex reports none.
struct StatisticsSettingsPage: View {
    let ledger: TokenLedger?
    @State private var confirmReset = false

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            if let ledger {
                let now = Date()
                let week = ledger.recent(7, endingAt: now)
                let month = ledger.recent(30, endingAt: now)
                SettingsGroup(title: "Claude Code tokens") {
                    SettingsRow(title: "Today") { value(ledger.total(on: now)) }
                    SettingsRow(title: "Last 7 days") { value(week.reduce(0) { $0 + $1.total }) }
                    SettingsRow(title: "Last 30 days", last: true) { value(month.reduce(0) { $0 + $1.total }) }
                }
                SettingsGroup(title: "Last 14 days") {
                    SettingsBlock(last: true) { chart(ledger.recent(14, endingAt: now)) }
                }
                SettingsFootnote("Counted from the totals Claude Code reports to its status line, so Bunlet's quota forwarding must be connected. Input and output tokens are added together. Codex sends no token counts to Bunlet. Totals are kept on this Mac for 90 days.")
                Button("Reset statistics…") { confirmReset = true }
                    .alert("Reset token statistics?", isPresented: $confirmReset) {
                        Button("Cancel", role: .cancel) {}
                        Button("Reset", role: .destructive) { ledger.reset() }
                    } message: {
                        Text("This clears the daily totals. It does not change anything in Claude Code.")
                    }
            } else {
                SettingsFootnote("Statistics start when agent services run.")
            }
        }
    }

    private func value(_ tokens: Int64) -> some View {
        Text(Self.format(tokens)).monospacedDigit().foregroundStyle(SettingsStyle.subtitle)
    }

    private func chart(_ days: [TokenLedger.Day]) -> some View {
        let peak = max(1, days.map(\.total).max() ?? 1)
        return HStack(alignment: .bottom, spacing: 6) {
            ForEach(days) { day in
                VStack(spacing: 4) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.accentColor.opacity(day.total > 0 ? 0.85 : 0.2))
                        .frame(height: max(2, 96 * CGFloat(Double(day.total) / Double(peak))))
                    Text(String(day.day.suffix(2))).font(.system(size: 10)).foregroundStyle(SettingsStyle.subtitle)
                }
                .frame(maxWidth: .infinity)
                .help("\(day.day): \(Self.format(day.total)) tokens")
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(day.day), \(Self.format(day.total)) tokens")
            }
        }
        .frame(height: 120, alignment: .bottom)
    }

    /// 950, 12.3K, 4.5M, 1.2B.
    static func format(_ tokens: Int64) -> String {
        let value = Double(tokens)
        switch tokens {
        case ..<1_000: return "\(tokens)"
        case ..<1_000_000: return String(format: "%.1fK", value / 1_000)
        case ..<1_000_000_000: return String(format: "%.1fM", value / 1_000_000)
        default: return String(format: "%.1fB", value / 1_000_000_000)
        }
    }
}
