import AgentActions
import Foundation
import SwiftUI

/// Approval, question and follow-up cards for a verified local channel.
/// All drafts are keyed by the offer UUID in ActionStore, not by the currently selected card.
struct LocalActionView: View {
    let snapshot: ActionSnapshot
    let controller: LocalActionController
    let beginInput: () -> Void
    @State private var editing = false
    private enum Field: Hashable { case reply, question(String) }
    @FocusState private var focused: Field?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            switch snapshot.offer.kind {
            case .permission: permission
            case .question: question
            case .followUp: followUp
            }
            footer
        }
        .onExitCommand { controller.cancel(snapshot.id) }
    }

    // MARK: Approval

    private var permission: some View {
        VStack(alignment: .leading, spacing: 10) {
            IslandCard {
                Text(snapshot.offer.toolName ?? "Tool request")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(IslandPalette.secondaryText)
                    .lineLimit(1)
            } content: {
                ScrollView {
                    Text(details)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(IslandPalette.secondaryText)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxHeight: 120)
                .fixedSize(horizontal: false, vertical: true)
            }
            if snapshot.phase == .available {
                HStack(spacing: 8) {
                    Button("Deny") { controller.send(snapshot.id, choice: .deny) }
                        .buttonStyle(IslandButtonStyle(kind: .deny))
                    Button("Allow once") { controller.send(snapshot.id, choice: .approveOnce) }
                        .buttonStyle(IslandButtonStyle(kind: .allow))
                }
            }
        }
    }

    // MARK: Question

    private var question: some View {
        VStack(alignment: .leading, spacing: 12) {
            IslandCard {
                HStack {
                    Text(snapshot.offer.questions.count == 1 ? "Question" : "\(snapshot.offer.questions.count) questions")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white)
                    Spacer()
                }
            } content: {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(Array(snapshot.offer.questions.enumerated()), id: \.element.question) { index, item in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(snapshot.offer.questions.count > 1 ? "\(index + 1). \(item.question)" : item.question)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(.white)
                                .fixedSize(horizontal: false, vertical: true)
                            ForEach(item.options, id: \.label) { option in
                                optionRow(option, question: item)
                            }
                            if editing {
                                TextField("Answer or custom text", text: Binding(get: {
                                    snapshot.answers.first { $0.question == item.question }?.answer ?? ""
                                }, set: { controller.store.setAnswer($0, question: item.question, for: snapshot.id) }))
                                .textFieldStyle(.plain)
                                .font(.system(size: 12))
                                .padding(6)
                                .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 4))
                                .focused($focused, equals: .question(item.question))
                                .accessibilityLabel(item.question)
                            }
                        }
                    }
                }
            }
            if snapshot.phase == .available {
                HStack(spacing: 8) {
                    Button("Submit") {
                        controller.send(snapshot.id, choice: .answer)
                        focused = nil
                    }
                    .buttonStyle(IslandButtonStyle(kind: .submit, cornerRadius: 6))
                    .disabled(snapshot.draftWasClipped || snapshot.answers.count != snapshot.offer.questions.count ||
                              snapshot.answers.contains { $0.answer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty })
                    if !editing {
                        Button("Type answer") {
                            beginInput()
                            editing = true
                            focused = snapshot.offer.questions.first.map { .question($0.question) }
                        }
                        .buttonStyle(IslandButtonStyle(kind: .cancel, cornerRadius: 6))
                    }
                    Button("Cancel") {
                        controller.cancel(snapshot.id)
                        focused = nil
                    }
                    .buttonStyle(IslandButtonStyle(kind: .cancel, cornerRadius: 6))
                }
            }
        }
    }

    private func optionRow(_ option: ActionOption, question: ActionQuestion) -> some View {
        let selected = snapshot.selections[question.question]?.contains(option.label) == true
        return Button {
            controller.store.toggleOption(option.label, question: question.question, for: snapshot.id)
        } label: {
            HStack(spacing: 6) {
                Image(systemName: question.multiSelect
                      ? (selected ? "checkmark.square.fill" : "square")
                      : (selected ? "largecircle.fill.circle" : "circle"))
                    .font(.system(size: 11))
                Text(option.label).font(.system(size: 12))
            }
            .foregroundStyle(selected ? IslandPalette.secondaryText : IslandPalette.mutedText)
            .frame(minHeight: 18)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(snapshot.phase != .available)
        .help(option.description)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    // MARK: Follow-up

    private var followUp: some View {
        VStack(alignment: .leading, spacing: 8) {
            if snapshot.phase == .available, !editing {
                Button("💬 Follow up") {
                    beginInput()
                    editing = true
                    focused = .reply
                }
                .buttonStyle(IslandButtonStyle(kind: .jump, cornerRadius: 6))
            } else if snapshot.phase == .available {
                VStack(alignment: .leading, spacing: 6) {
                    TextEditor(text: Binding(get: { snapshot.text }, set: { controller.store.setText($0, for: snapshot.id) }))
                        .font(.system(size: 12))
                        .foregroundStyle(Color(white: 0xEE / 255))
                        .scrollContentBackground(.hidden)
                        .frame(minHeight: 40, maxHeight: 76)
                        .focused($focused, equals: .reply)
                        .accessibilityLabel("Follow-up for this session")
                    HStack {
                        Text("Sent as feedback to this waiting turn. The reply window closes automatically.")
                            .font(.system(size: 11))
                            .foregroundStyle(IslandPalette.mutedText)
                        Spacer()
                        Button("Cancel") {
                            controller.cancel(snapshot.id)
                            focused = nil
                        }
                        .buttonStyle(.plain)
                        .font(.system(size: 12))
                        .foregroundStyle(IslandPalette.mutedText)
                        Button("Send") {
                            controller.send(snapshot.id, choice: .followUp)
                            focused = nil
                        }
                        .buttonStyle(IslandButtonStyle(kind: .submit, cornerRadius: 6))
                        .frame(width: 64)
                        .keyboardShortcut(.return, modifiers: .command)
                        .disabled(snapshot.draftWasClipped
                                  || snapshot.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
                .padding(.horizontal, 4)
            }
        }
    }

    // MARK: Status

    @ViewBuilder private var footer: some View {
        if snapshot.draftWasClipped {
            Text("Draft exceeded the supported length and was trimmed. Edit it before sending.")
                .font(.system(size: 11)).foregroundStyle(.orange)
        }
        HStack(spacing: 6) {
            Text(status)
            if snapshot.phase == .available { Text("· Documented channel; runtime unverified") }
        }
        .font(.system(size: 11))
        .foregroundStyle(IslandPalette.mutedText)
        .fixedSize(horizontal: false, vertical: true)
    }

    private var status: String {
        switch snapshot.phase {
        case .awaitingEvidence: "Waiting for matching session evidence."
        case .available: "Waiting for your response."
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
