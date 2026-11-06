import AgentActions
import Foundation
import SwiftUI

/// All drafts are keyed by the offer UUID in ActionStore, not by the currently selected card.
struct LocalActionView: View {
    let snapshot: ActionSnapshot
    let controller: LocalActionController
    let beginInput: () -> Void
    @State private var expanded = false
    private enum Field: Hashable { case reply, question(String) }
    @FocusState private var focused: Field?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.subheadline.weight(.semibold))
            Text(status).font(.caption).foregroundStyle(.secondary)
            if snapshot.phase == .available {
                if !expanded {
                    Button("Respond…") {
                        beginInput()
                        expanded = true
                        focused = snapshot.offer.kind == .followUp ? .reply : snapshot.offer.questions.first.map { .question($0.question) }
                    }
                } else {
                    composer
                    if snapshot.draftWasClipped {
                        Text("Draft exceeded the supported length and was trimmed. Edit it before sending.")
                            .font(.caption).foregroundStyle(.orange)
                    }
                    HStack {
                        Button("Cancel response") {
                            controller.cancel(snapshot.id)
                            focused = nil
                        }
                        Text("Documented channel; runtime unverified").font(.caption2).foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 10))
        .onExitCommand { controller.cancel(snapshot.id) }
    }

    @ViewBuilder private var composer: some View {
        switch snapshot.offer.kind {
        case .permission:
            Text(snapshot.offer.toolName ?? "Tool request").fontWeight(.medium)
            ScrollView {
                Text(details).font(.system(.caption, design: .monospaced)).textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }.frame(maxHeight: 120)
            HStack {
                Button("Approve once") { controller.send(snapshot.id, choice: .approveOnce) }
                Button("Deny") { controller.send(snapshot.id, choice: .deny) }
            }
        case .question:
            ForEach(snapshot.offer.questions, id: \.question) { question in
                VStack(alignment: .leading, spacing: 6) {
                    Text(question.question).fixedSize(horizontal: false, vertical: true)
                    ForEach(question.options, id: \.label) { option in
                        Button {
                            controller.store.toggleOption(option.label, question: question.question, for: snapshot.id)
                        } label: {
                            Label(option.label, systemImage: snapshot.selections[question.question]?.contains(option.label) == true
                                  ? "checkmark.circle.fill" : "circle")
                        }
                        .help(option.description)
                    }
                    TextField("Answer or custom text", text: Binding(get: {
                        snapshot.answers.first { $0.question == question.question }?.answer ?? ""
                    }, set: { controller.store.setAnswer($0, question: question.question, for: snapshot.id) }))
                    .focused($focused, equals: .question(question.question))
                    .accessibilityLabel(question.question)
                }
            }
            Button("Send answers") {
                controller.send(snapshot.id, choice: .answer)
                focused = nil
            }
            .disabled(snapshot.draftWasClipped || snapshot.answers.count != snapshot.offer.questions.count ||
                      snapshot.answers.contains { $0.answer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty })
        case .followUp:
            Text("Sent as feedback to this waiting Stop hook in the existing turn. The reply window closes automatically.")
                .font(.caption).foregroundStyle(.secondary)
            TextEditor(text: Binding(get: { snapshot.text }, set: { controller.store.setText($0, for: snapshot.id) }))
                .font(.body).frame(minHeight: 60, maxHeight: 110).focused($focused, equals: .reply)
                .accessibilityLabel("Follow-up for this session")
            Button("Send follow-up") {
                controller.send(snapshot.id, choice: .followUp)
                focused = nil
            }
            .disabled(snapshot.draftWasClipped || snapshot.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
    }

    private var title: String {
        switch snapshot.offer.kind {
        case .permission: "Local permission decision"
        case .question: "Local question response"
        case .followUp: "Follow-up reply window"
        }
    }

    private var status: String {
        switch snapshot.phase {
        case .awaitingEvidence: "Waiting for matching session evidence."
        case .available: "This exact hook invocation is waiting for your response."
        case .sending: "Sending once. Provider acceptance is not confirmed."
        case .helperAcknowledged: "Helper wrote the response. Provider acceptance and session state remain separate."
        case .cancelled: "Local response closed. Use the terminal if the request remains pending."
        case .expired: "Reply window expired. Return to the existing session."
        case .uncertain: "Delivery is uncertain. Do not replay; check the existing session."
        case .unavailable: "Request identity or session evidence is ambiguous or stale. Return to the terminal."
        }
    }

    private var details: String {
        guard let input = snapshot.offer.input,
              let value = try? JSONSerialization.jsonObject(with: input),
              let formatted = try? JSONSerialization.data(withJSONObject: value, options: [.prettyPrinted, .sortedKeys]) else {
            return "Details unavailable."
        }
        return String(decoding: formatted, as: UTF8.self)
    }
}
