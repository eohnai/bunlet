import EventBridge
import Foundation

public enum LocalActionKind: String, Codable, Sendable {
    case permission, question, followUp
}

public struct ActionOption: Codable, Equatable, Sendable {
    public let label: String
    public let description: String
}

public struct ActionQuestion: Codable, Equatable, Sendable {
    public let question: String
    public let header: String
    public let options: [ActionOption]
    public let multiSelect: Bool
}

public struct ActionOffer: Codable, Equatable, Sendable, Identifiable {
    public let version: Int
    public let id: UUID
    public let provider: Agent
    public let sessionID: String
    public let turnID: String
    public let toolUseID: String?
    public let toolName: String?
    public let kind: LocalActionKind
    public let capturedAtMs: Int64
    /// Necessary action content only. Never forwarded to lifecycle observation or diagnostics.
    public let input: Data?
    public let questions: [ActionQuestion]
}

public enum ActionChoice: String, Codable, Sendable {
    case approveOnce, deny, answer, followUp, cancel
}

public struct ActionAnswer: Codable, Equatable, Sendable {
    public let question: String
    public let answer: String

    public init(question: String, answer: String) {
        self.question = question
        self.answer = answer
    }
}

public struct ActionDecision: Codable, Equatable, Sendable {
    public let version: Int
    public let requestID: UUID
    public let decisionID: UUID
    public let choice: ActionChoice
    public let answers: [ActionAnswer]
    public let text: String?

    public init(requestID: UUID, choice: ActionChoice, answers: [ActionAnswer] = [], text: String? = nil) {
        version = 1
        self.requestID = requestID
        decisionID = UUID()
        self.choice = choice
        self.answers = answers
        self.text = text
    }
}

public struct ActionWriteReceipt: Codable, Sendable {
    public let version: Int
    public let requestID: UUID
    public let decisionID: UUID
    public let wroteProviderOutput: Bool
}

public enum ActionProtocol {
    public static let inputLimit = 16_384
    public static let questionLimit = 4
    public static let optionLimit = 4
    public static let answerLimit = 2000
    public static let textLimit = 8192
    public static let identityLimit = 256
    public static let labelLimit = 128
    public static let descriptionLimit = 1024
    public static let offerAgeMs: Int64 = 5000
    public static let futureSkewMs: Int64 = 2000
    public static let evidenceWaitNs: UInt64 = 1_000_000_000
    public static let lifetimeNs: UInt64 = 60_000_000_000
    public static let capacity = 32

    public static func decode<T: Decodable>(_ data: Data, as type: T.Type) throws -> T {
        guard data.count <= ActionSocketIO.frameLimit else { throw BridgeError.invalidMessage }
        _ = try HookConfigurationJSON(data: data)
        return try JSONDecoder().decode(type, from: data)
    }

    public static func frame<T: Encodable>(_ value: T) throws -> Data {
        var data = try JSONEncoder().encode(value)
        data.append(10)
        guard data.count <= ActionSocketIO.frameLimit else { throw BridgeError.invalidMessage }
        return data
    }

    public static func valid(_ offer: ActionOffer, nowMs: Int64) -> Bool {
        guard offer.version == 1, offer.provider == .claude, offer.capturedAtMs >= 0, nowMs >= 0, nowMs <= Int64.max - futureSkewMs,
              offer.capturedAtMs <= nowMs + futureSkewMs, nowMs - offer.capturedAtMs <= offerAgeMs,
              identity(offer.sessionID), identity(offer.turnID),
              offer.toolUseID.map(identity) ?? true,
              offer.toolName.map({ !$0.isEmpty && $0.utf8.count <= identityLimit }) ?? true,
              (offer.input?.count ?? 0) <= inputLimit,
              offer.questions.count <= questionLimit else { return false }
        if let input = offer.input, (try? HookConfigurationJSON(data: input)) == nil { return false }
        switch offer.kind {
        case .permission: return offer.toolName != nil && offer.input != nil && offer.questions.isEmpty
        case .followUp: return offer.toolName == nil && offer.toolUseID == nil && offer.input == nil && offer.questions.isEmpty
        case .question:
            guard offer.toolName == "AskUserQuestion", offer.toolUseID != nil, offer.input != nil,
                  !offer.questions.isEmpty, Set(offer.questions.map(\.question)).count == offer.questions.count else { return false }
            guard let input = offer.input, (try? questions(from: input)) == offer.questions else { return false }
            return offer.questions.allSatisfy {
                !$0.question.isEmpty && $0.question.utf8.count <= answerLimit && $0.header.utf8.count <= labelLimit &&
                (2...optionLimit).contains($0.options.count) && Set($0.options.map(\.label)).count == $0.options.count &&
                $0.options.allSatisfy { !$0.label.isEmpty && $0.label.utf8.count <= labelLimit && $0.description.utf8.count <= descriptionLimit }
            }
        }
    }

    static func questions(from input: Data) throws -> [ActionQuestion] {
        let details = try HookConfigurationJSON(data: input)
        guard details.range(at: [.key("answers")]) == nil,
              let raw = details.rawValue(at: [.key("questions")]) else { throw BridgeError.invalidMessage }
        struct Question: Decodable {
            let question: String
            let header: String
            let options: [ActionOption]
            let multiSelect: Bool?
        }
        return try JSONDecoder().decode([Question].self, from: raw).map {
            ActionQuestion(question: $0.question, header: $0.header, options: $0.options, multiSelect: $0.multiSelect ?? false)
        }
    }

    public static func valid(_ decision: ActionDecision, for offer: ActionOffer) -> Bool {
        guard decision.version == 1, decision.requestID == offer.id,
              decision.answers.count <= questionLimit, (decision.text?.utf8.count ?? 0) <= textLimit else { return false }
        if decision.choice == .cancel { return decision.text == nil && decision.answers.isEmpty }
        switch offer.kind {
        case .permission:
            return (decision.choice == .approveOnce || decision.choice == .deny) && decision.text == nil && decision.answers.isEmpty
        case .followUp:
            return decision.choice == .followUp && decision.answers.isEmpty &&
                decision.text.map { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty } == true
        case .question:
            guard decision.choice == .answer, decision.text == nil, decision.answers.count == offer.questions.count,
                  Set(decision.answers.map(\.question)).count == decision.answers.count else { return false }
            return decision.answers.allSatisfy { answer in
                offer.questions.contains { $0.question.utf8.elementsEqual(answer.question.utf8) } &&
                    !answer.answer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && answer.answer.utf8.count <= answerLimit
            }
        }
    }

    private static func identity(_ value: String) -> Bool {
        !value.isEmpty && value.utf8.count <= identityLimit && !value.unicodeScalars.contains { $0.properties.generalCategory == .control }
    }
}
