import EventBridge
import Foundation
import Observation
import SessionState

public enum ActionPhase: String, Sendable {
    case awaitingEvidence, available, sending, helperAcknowledged, cancelled, expired, uncertain, unavailable
}

public struct ActionSnapshot: Equatable, Sendable, Identifiable {
    public var id: UUID { offer.id }
    public let offer: ActionOffer
    public let phase: ActionPhase
    public let observedRequestID: String?
    public let expiresAtNs: UInt64
    public let text: String
    public let answers: [ActionAnswer]
    public let selections: [String: [String]]
    public let draftWasClipped: Bool
}

/// Transient action state only. Session truth is supplied for validation and never written here.
@MainActor
@Observable
public final class ActionStore {
    public private(set) var snapshots: [ActionSnapshot] = []
    public private(set) var capacityReached = false
    public private(set) var receiverAvailable = false
    private var records: [UUID: Record] = [:]
    private var seen: [UUID: UInt64] = [:]
    private static let historyCapacity = 64
    private static let seenCapacity = 512
    private static let historyNs: UInt64 = 120_000_000_000

    public init() {}

    public func setReceiverAvailable(_ available: Bool) { receiverAvailable = available }

    @discardableResult
    public func receive(_ offer: ActionOffer, link: UUID, nowMs: Int64, nowNs: UInt64) -> Bool {
        guard ActionProtocol.valid(offer, nowMs: nowMs), nowNs <= UInt64.max - Self.historyNs - ActionProtocol.lifetimeNs else { return false }
        prune(at: nowNs)
        guard seen[offer.id] == nil, records[offer.id] == nil,
              !records.values.contains(where: { $0.link == link }) else { return false }
        guard records.count < Self.historyCapacity, seen.count < Self.seenCapacity else {
            capacityReached = true
            return false
        }
        seen[offer.id] = nowNs + Self.historyNs
        records[offer.id] = Record(offer: offer, link: link, receivedAtNs: nowNs,
                                  expiresAtNs: nowNs + ActionProtocol.lifetimeNs)
        capacityReached = false
        publish()
        return true
    }

    /// Returns sockets that must close. Evidence can arrive after the action offer on another endpoint.
    public func reconcile(sessions: [SessionSnapshot], providers: Set<Agent>, nowNs: UInt64) -> [UUID] {
        var close: [UUID] = []
        var groups: [RequestIdentity: [UUID]] = [:]
        // A dispatched response reserves its observed request until lifecycle evidence replaces it.
        // PermissionRequest may lack a tool-use ID, so an old notice must never authorize a new callback.
        let reserved = Set(records.values.compactMap { record -> RequestIdentity? in
            guard record.decisionID != nil else { return nil }
            return RequestIdentity(session: SessionKey(agent: record.offer.provider, sessionID: record.offer.sessionID),
                                   turn: Data(record.offer.turnID.utf8), event: record.observedRequestID.map { Data($0.utf8) })
        })
        for id in Array(records.keys) {
            guard var record = records[id] else { continue }
            if record.phase == .sending {
                if nowNs >= record.expiresAtNs || !providers.contains(record.offer.provider) || matching(record.offer, sessions: sessions) == nil {
                    record.phase = .uncertain
                    records[id] = record
                    close.append(record.link)
                }
                continue
            }
            guard record.phase == .awaitingEvidence || record.phase == .available else { continue }
            if nowNs >= record.expiresAtNs {
                record.phase = .expired
                close.append(record.link)
            } else if !providers.contains(record.offer.provider) {
                record.phase = .cancelled
                close.append(record.link)
            } else if let match = matching(record.offer, sessions: sessions) {
                if record.phase == .available, record.observedRequestID != match.eventID {
                    record.phase = .unavailable
                    close.append(record.link)
                } else {
                    record.phase = .available
                    record.observedRequestID = match.eventID
                    let key = RequestIdentity(session: match.session, turn: Data(record.offer.turnID.utf8),
                                              event: match.eventID.map { Data($0.utf8) })
                    if reserved.contains(key) {
                        record.phase = .unavailable
                        close.append(record.link)
                    } else {
                        groups[key, default: []].append(id)
                    }
                }
            } else if record.phase == .available || nowNs - min(nowNs, record.receivedAtNs) >= ActionProtocol.evidenceWaitNs {
                record.phase = .unavailable
                close.append(record.link)
            }
            records[id] = record
        }
        for ids in groups.values where ids.count > 1 {
            for id in ids {
                guard var record = records[id] else { continue }
                record.phase = .unavailable
                close.append(record.link)
                records[id] = record
            }
        }
        prune(at: nowNs)
        publish()
        return close
    }

    public func setText(_ text: String, for id: UUID) {
        guard var record = records[id], record.phase == .available else { return }
        record.text = bounded(text, limit: ActionProtocol.textLimit)
        record.draftWasClipped = record.text != text
        records[id] = record
        publish()
    }

    public func setAnswer(_ answer: String, question: String, for id: UUID) {
        guard var record = records[id], record.phase == .available,
              record.offer.questions.contains(where: { $0.question.utf8.elementsEqual(question.utf8) }) else { return }
        let value = bounded(answer, limit: ActionProtocol.answerLimit)
        record.draftWasClipped = value != answer
        record.answers.removeAll { $0.question.utf8.elementsEqual(question.utf8) }
        record.answers.append(ActionAnswer(question: question, answer: value))
        record.selections[question] = nil
        records[id] = record
        publish()
    }

    public func toggleOption(_ label: String, question: String, for id: UUID) {
        guard var record = records[id], record.phase == .available,
              let source = record.offer.questions.first(where: { $0.question.utf8.elementsEqual(question.utf8) }),
              source.options.contains(where: { $0.label.utf8.elementsEqual(label.utf8) }) else { return }
        var selected = record.selections[question] ?? []
        if selected.contains(label) { selected.removeAll { $0 == label } }
        else if source.multiSelect { selected.append(label) }
        else { selected = [label] }
        record.selections[question] = selected
        record.answers.removeAll { $0.question.utf8.elementsEqual(question.utf8) }
        record.answers.append(ActionAnswer(question: question, answer: selected.joined(separator: ", ")))
        records[id] = record
        publish()
    }

    /// Caller reconciles against current sessions immediately before dispatch. No replay after this point.
    public func prepare(_ id: UUID, choice: ActionChoice) -> (UUID, ActionDecision)? {
        guard var record = records[id], record.phase == .available, !record.draftWasClipped, choice != .cancel else { return nil }
        let decision = ActionDecision(requestID: id, choice: choice,
            answers: choice == .answer ? record.answers : [], text: choice == .followUp ? record.text : nil)
        guard ActionProtocol.valid(decision, for: record.offer) else { return nil }
        record.phase = .sending
        record.decisionID = decision.decisionID
        records[id] = record
        publish()
        return (record.link, decision)
    }

    public func acknowledge(link: UUID, receipt: ActionWriteReceipt) {
        guard var record = records[receipt.requestID], record.link == link, receipt.version == 1,
              receipt.wroteProviderOutput, record.decisionID == receipt.decisionID else { return }
        record.phase = .helperAcknowledged
        records[receipt.requestID] = record
        publish()
    }

    public func closed(link: UUID, dispatched: Bool) {
        guard let id = records.first(where: { $0.value.link == link })?.key, var record = records[id],
              record.phase != .helperAcknowledged else { return }
        if record.phase == .sending || dispatched { record.phase = .uncertain }
        else if record.phase == .available || record.phase == .awaitingEvidence { record.phase = .cancelled }
        records[id] = record
        publish()
    }

    public func cancel(_ id: UUID) -> UUID? {
        guard var record = records[id] else { return nil }
        if record.phase == .sending { record.phase = .uncertain }
        else if record.phase == .available || record.phase == .awaitingEvidence { record.phase = .cancelled }
        records[id] = record
        publish()
        return record.link
    }

    public func stop() {
        receiverAvailable = false
        for (id, var record) in records {
            if record.phase == .sending { record.phase = .uncertain }
            else if record.phase == .available || record.phase == .awaitingEvidence { record.phase = .cancelled }
            records[id] = record
        }
        publish()
    }

    public var nextDeadlineNs: UInt64? {
        records.values.compactMap { record in
            if record.phase == .awaitingEvidence { return min(record.expiresAtNs, record.receivedAtNs + ActionProtocol.evidenceWaitNs) }
            return record.phase == .available || record.phase == .sending ? record.expiresAtNs : nil
        }.min()
    }

    private func matching(_ offer: ActionOffer, sessions: [SessionSnapshot]) -> (session: SessionKey, eventID: String?)? {
        let key = SessionKey(agent: offer.provider, sessionID: offer.sessionID)
        guard let session = sessions.first(where: { $0.key == key }), !session.hasTerminalRestriction,
              session.status != .unknown, session.status != .ended,
              session.currentTurnID?.utf8.elementsEqual(offer.turnID.utf8) == true else { return nil }
        if offer.kind == .followUp {
            return session.status == .responseReady && session.pendingRequests.isEmpty ? (key, nil) : nil
        }
        let kind: SessionRequestKind = offer.kind == .question ? .questionNeeded : .approvalNeeded
        let requests = session.pendingRequests.filter { request in
            request.isConfirmed && request.kind == kind && request.turnID?.utf8.elementsEqual(offer.turnID.utf8) == true &&
            request.toolName.utf8.elementsEqual((offer.toolName ?? "").utf8) &&
            (offer.toolUseID.map { tool in request.toolUseID?.utf8.elementsEqual(tool.utf8) == true } ?? (request.toolUseID == nil))
        }
        guard requests.count == 1, let request = requests.first else { return nil }
        return (key, request.eventID)
    }

    private func prune(at now: UInt64) {
        records = records.filter { _, value in
            value.expiresAtNs > now || now - value.expiresAtNs < Self.historyNs
        }
        seen = seen.filter { $0.value > now }
    }

    private func publish() {
        snapshots = records.values.map {
            ActionSnapshot(offer: $0.offer, phase: $0.phase, observedRequestID: $0.observedRequestID,
                           expiresAtNs: $0.expiresAtNs, text: $0.text, answers: $0.answers,
                           selections: $0.selections, draftWasClipped: $0.draftWasClipped)
        }.sorted { $0.offer.capturedAtMs == $1.offer.capturedAtMs
            ? $0.id.uuidString < $1.id.uuidString : $0.offer.capturedAtMs < $1.offer.capturedAtMs }
    }

    private func bounded(_ text: String, limit: Int) -> String {
        var data = Data(text.utf8.prefix(limit))
        while !data.isEmpty {
            if let value = String(data: data, encoding: .utf8) { return value }
            data.removeLast()
        }
        return ""
    }
}

private struct RequestIdentity: Hashable {
    let session: SessionKey
    let turn: Data
    let event: Data?
}

private struct Record {
    let offer: ActionOffer
    let link: UUID
    let receivedAtNs: UInt64
    let expiresAtNs: UInt64
    var phase: ActionPhase = .awaitingEvidence
    var observedRequestID: String?
    var decisionID: UUID?
    var text = ""
    var answers: [ActionAnswer] = []
    var selections: [String: [String]] = [:]
    var draftWasClipped = false
}
