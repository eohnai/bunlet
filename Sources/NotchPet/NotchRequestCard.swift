import SessionState
import SwiftUI

struct NotchRequestCard: View {
    let request: SessionRequest

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: request.kind == .questionNeeded ? "questionmark.circle" : "hand.raised")
                .foregroundStyle(request.isConfirmed ? .orange : .secondary)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text(request.toolName)
                    .fontWeight(.medium)
                    .fixedSize(horizontal: false, vertical: true)
                Text("\(request.isConfirmed ? "Pending" : "Unconfirmed") \(request.kind == .questionNeeded ? "question" : "approval")")
                    .font(.caption)
                    .foregroundStyle(request.isConfirmed ? .orange : .secondary)
                Text("Answer in the terminal")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .font(.callout)
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 12))
    }
}
