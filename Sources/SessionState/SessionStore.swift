import CryptoKit
import EventBridge
import Foundation
import Observation

/// One in-memory authority. Main-actor isolation serializes changes and publication.
/// The latest event decides a session's state (decision 0035). There is no unknown state.
@MainActor
@Observable
public final class SessionStore {
    public private(set) var sessions: [SessionSnapshot] = []
    public private(set) var capacityIssue: SessionApplyResult?
    public private(set) var deliveryOverflowed = false

    public static let sessionLimit = 128
    public static let eventIDLimit = 4096
    public static let turnIDLimit = 256
    public static let requestLimit = 64
    public static let subagentLimit = 32

    private var records: [SessionKey: Record] = [:]
    private var receiptClock = ClockHistory()
    private var runtimeClock = ClockHistory()
    private var horizonNs: UInt64 = 0

    public init() {}

    @discardableResult
    public func apply(_ observation: SessionObservationV1) -> SessionApplyResult {
        let result = reduce(observation)
        recordIntake(result)
        publish()
        return result
    }

    /// Process one bounded bridge batch, then publish once.
    public func applyBatch(_ batch: [SessionObservationV1], observationsLost: Bool,
                           wallMs: Int64, monotonicNs: UInt64) {
        observeRuntimeClock(wallMs: wallMs, monotonicNs: monotonicNs)
        for observation in batch { recordIntake(reduce(observation)) }
        // Lost events leave each session in its last state until its next event corrects it.
        if observationsLost { deliveryOverflowed = true }
        horizonNs = max(horizonNs, monotonicNs)
        publish()
    }

    public func advance(monotonicNs: UInt64) {
        advanceClock(monotonicNs: monotonicNs)
        publish()
    }

    /// Check wall/monotonic continuity independently of queued receipt samples.
    public func checkClocks(wallMs: Int64, monotonicNs: UInt64) {
        observeRuntimeClock(wallMs: wallMs, monotonicNs: monotonicNs)
        publish()
    }

    public func invalidateClocks() {
        forgetCaptureTimes()
        receiptClock = ClockHistory()
        runtimeClock = ClockHistory()
        horizonNs = 0
        publish()
    }

    /// Stop showing sessions that can no longer update. Paused or stopped monitoring would otherwise freeze them.
    public func suspendMonitoring(agent: Agent? = nil) {
        if let agent {
            records = records.filter { $0.key.agent != agent }
        } else {
            records.removeAll()
        }
        publish()
    }

    private func recordIntake(_ result: SessionApplyResult) {
        switch result {
        case .sessionCapacity, .requestCapacity: capacityIssue = result
        default: break
        }
    }

    private func reduce(_ observation: SessionObservationV1) -> SessionApplyResult {
        let event = observation.envelope
        // Validate public receipt inputs as well as delivery age before recording identities.
        guard (0...9_007_199_254_740_991).contains(observation.receiptWallMs),
              let canonical = try? event.frame() else { return .invalidObservation }
        horizonNs = max(horizonNs, observation.receiptMonotonicNs)
        let age = observation.receiptWallMs - event.observedAtMs
        guard age <= 30_000, age >= -2000 else { return .deliveryTime }
        let monotonicReset = receiptClock.previous.map { observation.receiptMonotonicNs < $0.monotonic } ?? false
        if receiptClock.observe(wallMs: observation.receiptWallMs, monotonicNs: observation.receiptMonotonicNs) {
            forgetCaptureTimes()
            // Later clock checks must use the new monotonic clock range.
            if monotonicReset { horizonNs = observation.receiptMonotonicNs }
        }

        let key = SessionKey(agent: event.agent, sessionID: event.sessionID)
        let record: Record
        if let existing = records[key] {
            record = existing
        } else {
            guard records.count < Self.sessionLimit else { return .sessionCapacity }
            record = Record()
            records[key] = record
        }
        let digest = Data(SHA256.hash(data: canonical))
        if let previous = record.seen[event.eventID] {
            // Two different events with one ID cannot both be right, so the second one changes nothing.
            return previous == digest ? .duplicate : .eventIDConflict
        }
        let turn = event.turnID.map { SourceIdentity(value: $0) }
        let knownTurn = turn.map { record.turns.contains($0) } ?? false
        if record.seen.count >= Self.eventIDLimit || (!knownTurn && turn != nil && record.turns.count >= Self.turnIDLimit) {
            // A full session forgets old identities instead of refusing events and freezing in its last state.
            // The 30-second delivery limit keeps a forgotten event from arriving again in practice.
            record.forgetIdentities()
        }
        record.seen[event.eventID] = digest
        if let turn { record.turns.insert(turn) }

        switch observation.kind {
        case .subagentStarted, .subagentStopped:
            // Subagent hooks fire alongside the parent's own, so they never change its status, order or freshness.
            guard !record.terminal, let id = event.agentID.map({ SourceIdentity(value: $0) }) else { return .noChange }
            if case .subagentStarted = observation.kind {
                guard record.subagents.count < Self.subagentLimit, record.subagents.insert(id).inserted else { return .noChange }
            } else {
                guard record.subagents.remove(id) != nil else { return .noChange }
            }
            return .applied
        default:
            break
        }

        if case .sessionEnded = observation.kind {
            record.subagents.removeAll()
            record.terminal = true
            record.status = .ended
            record.pending.removeAll()
            return .ended
        }
        // Agents resume a session with the same ID, so a new start or prompt after an end reopens it.
        // Any other event after an end is a late copy from before the end.
        var reopened = false
        if record.terminal {
            switch observation.kind {
            case .sessionStarted, .turnSubmitted:
                record.reopen()
                reopened = true
            default:
                return .terminalRestriction
            }
        }
        // An event captured before the latest applied one is out of date. One from the same millisecond applies.
        if let watermark = record.watermarkMs, event.observedAtMs < watermark { return .outOfOrder }
        if let turn, record.retired.contains(turn) { return .retiredTurn }

        switch observation.kind {
        case .sessionStarted:
            // A later start in a live session, for example after compacting, must not hide a running turn.
            guard record.seen.count == 1 || reopened else { return .repeatedStart }
            record.status = .idle
            record.refresh(observation)
            return .applied

        case .turnSubmitted:
            if record.baseline, turn != nil, turn == record.turn { return .repeatedSubmit }
            // The latest prompt always starts a new turn, even when the previous turn never reported a stop.
            // An interrupted turn sends no stop, so waiting for one would freeze the session.
            if let previous = record.turn { record.retired.insert(previous) }
            record.turn = turn
            record.turnStartedAtMs = event.observedAtMs
            record.responseReadyAtMs = nil
            record.baseline = true
            record.stopped = false
            record.status = .working
            record.pending.removeAll()
            record.latestPrompt = event.promptPreview
            record.lastReply = nil
            record.failed = false
            record.currentTool = nil
            record.subagents.removeAll()
            record.refresh(observation)
            return .applied

        case .responseReady, .turnFailed:
            let failed = if case .turnFailed = observation.kind { true } else { false }
            // A failure without the turn's identity may belong to another turn or a subagent, so it changes nothing.
            if failed, turn == nil { return .noChange }
            // The agent waits for the user after a stop, so no request can still be open.
            record.pending.removeAll()
            // The parent's turn is over; a subagent that never reported stopping is no longer shown as running.
            record.subagents.removeAll()
            if record.responseReadyAtMs == nil { record.responseReadyAtMs = event.observedAtMs }
            record.stopped = true
            if record.status == .responseReady { return .repeatedStop }
            record.status = .responseReady
            record.failed = failed
            record.lastReply = event.replyPreview
            record.currentTool = nil
            record.refresh(observation)
            return .applied

        case .toolObserved, .toolFinished, .requestOpened:
            return applyTool(observation, record: record, turn: turn)

        case .sessionEnded:
            return .ended // Handled before timestamp and turn checks.

        case .subagentStarted, .subagentStopped:
            return .noChange // Handled before timestamp and turn checks.
        }
    }

    private func applyTool(_ observation: SessionObservationV1, record: Record,
                           turn: SourceIdentity?) -> SessionApplyResult {
        let event = observation.envelope
        guard let toolName = event.toolName else { return .invalidObservation }
        if record.stopped {
            // A tool that finishes after the stop is a late copy. New tool activity means the agent works again.
            if case .toolFinished = observation.kind { return .noChange }
            record.stopped = false
            record.responseReadyAtMs = nil
        }
        let toolID = event.toolUseID.map { SourceIdentity(value: $0) }
        let name = SourceIdentity(value: toolName)
        let requestKey: RequestKey
        if let turn, let toolID { requestKey = .identified(turn, toolID) }
        else { requestKey = .unidentified(event.eventID) }

        switch observation.kind {
        case .requestOpened(let kind):
            if let existing = record.pending[requestKey], existing.name == name, existing.kind == kind {
                return .mergedRequest
            }
            guard record.pending[requestKey] != nil || record.pending.count < Self.requestLimit else {
                return .requestCapacity
            }
            // A changed opening for the same tool call replaces the old one: the latest event wins.
            record.pending[requestKey] = Pending(eventID: event.eventID, turn: turn,
                                                  toolID: toolID, name: name, kind: kind)
            record.showPending()
            record.refresh(observation)
            return .applied

        case .toolFinished:
            if let request = record.pending[requestKey], request.name == name {
                record.pending.removeValue(forKey: requestKey)
            } else if let match = record.pending.filter({ $0.key.isUnidentified && $0.value.name == name })
                .min(by: { $0.value.eventID < $1.value.eventID }) {
                // A request without a tool-call ID cannot be matched exactly. A finished tool with the same name
                // most likely answers it, and leaving it would show a waiting request after the agent moved on.
                record.pending.removeValue(forKey: match.key)
            } else if !record.pending.isEmpty {
                return .unmatchedCompletion
            }
            record.showPending()
            record.refresh(observation)
            return .applied

        default:
            // Waiting requests keep priority. Another tool can run while one waits for approval.
            if !record.pending.isEmpty { return .noChange }
            record.status = .working
            record.currentTool = toolName
            record.refresh(observation)
            return .applied
        }
    }

    private func observeRuntimeClock(wallMs: Int64, monotonicNs: UInt64) {
        if runtimeClock.observe(wallMs: wallMs, monotonicNs: monotonicNs) {
            forgetCaptureTimes()
        }
        advanceClock(monotonicNs: monotonicNs)
    }

    private func advanceClock(monotonicNs: UInt64) {
        if monotonicNs < horizonNs {
            forgetCaptureTimes()
            horizonNs = monotonicNs
        } else {
            horizonNs = max(horizonNs, monotonicNs)
        }
    }

    /// After a clock jump, capture times before and after it cannot be compared. Without this, a clock moved
    /// backward would make every new event look out of date and freeze each session.
    private func forgetCaptureTimes() {
        for record in records.values { record.watermarkMs = nil }
    }

    private func publish() {
        let updated = records.map { key, record in record.snapshot(key: key) }.sorted {
            if $0.key.agent != $1.key.agent { return $0.key.agent.rawValue < $1.key.agent.rawValue }
            return $0.key.sessionID.utf8.lexicographicallyPrecedes($1.key.sessionID.utf8)
        }
        if sessions != updated { sessions = updated }
    }
}

private enum RequestKey: Hashable {
    /// Turn and tool-call IDs from the source.
    case identified(SourceIdentity, SourceIdentity)
    /// No tool-call ID, so the request is keyed by its own event ID.
    case unidentified(String)

    var isUnidentified: Bool {
        if case .unidentified = self { return true }
        return false
    }
}

private struct Pending {
    let eventID: String
    let turn: SourceIdentity?
    let toolID: SourceIdentity?
    let name: SourceIdentity
    let kind: SessionRequestKind
}

@MainActor
private final class Record {
    /// A session first seen in the middle of a turn, for example after an app restart, takes its state from
    /// that event. Idle is only the starting value.
    var status: SessionStatus = .idle
    var turn: SourceIdentity?
    var turnStartedAtMs: Int64?
    var responseReadyAtMs: Int64?
    var baseline = false
    var stopped = false
    var terminal = false
    var watermarkMs: Int64?
    var receiptWallMs: Int64?
    var receiptMonotonicNs: UInt64?
    var projectPath: String?
    var paneSelector: String?
    var location: HookEnvelopeV1.Terminal?
    var subagents: Set<SourceIdentity> = []
    var failed = false
    var latestPrompt: String?
    var lastReply: String?
    var currentTool: String?
    var seen: [String: Data] = [:]
    var turns: Set<SourceIdentity> = []
    var retired: Set<SourceIdentity> = []
    var pending: [RequestKey: Pending] = [:]

    func refresh(_ observation: SessionObservationV1) {
        watermarkMs = observation.envelope.observedAtMs
        receiptWallMs = observation.receiptWallMs
        receiptMonotonicNs = observation.receiptMonotonicNs
        if let cwd = observation.envelope.cwd { projectPath = cwd }
        if let terminal = observation.envelope.terminal {
            location = terminal
            // The legacy field keeps its Otty-only meaning.
            paneSelector = terminal.kind == .otty ? terminal.paneSelector : nil
        }
    }

    func showPending() {
        if pending.values.contains(where: { $0.kind == .questionNeeded }) { status = .questionNeeded }
        else if !pending.isEmpty { status = .approvalNeeded }
        else { status = .working }
    }

    /// Keep the current turn's identity so its late events still count as part of it.
    func forgetIdentities() {
        seen.removeAll()
        retired.removeAll()
        turns = turn.map { [$0] } ?? []
    }

    /// The previous lifecycle's turn is retired, so its late events cannot change the reopened session.
    func reopen() {
        terminal = false
        status = .idle
        if let turn { retired.insert(turn) }
        turn = nil
        baseline = false
        stopped = false
        responseReadyAtMs = nil
        turnStartedAtMs = nil
    }

    func snapshot(key: SessionKey) -> SessionSnapshot {
        let requests = pending.values.map {
            SessionRequest(eventID: $0.eventID, turnID: $0.turn?.value, toolUseID: $0.toolID?.value,
                           toolName: $0.name.value, kind: $0.kind)
        }.sorted {
            if $0.kind != $1.kind { return $0.kind == .questionNeeded }
            return $0.eventID < $1.eventID
        }
        return SessionSnapshot(key: key, status: status, currentTurnID: turn?.value,
                               turnStartedAtMs: turnStartedAtMs, responseReadyAtMs: responseReadyAtMs,
                               pendingRequests: requests, captureWatermarkMs: watermarkMs,
                               receiptWallMs: receiptWallMs, receiptMonotonicNs: receiptMonotonicNs,
                               projectPath: projectPath,
                               paneSelector: paneSelector, hasTerminalRestriction: terminal,
                               latestPrompt: latestPrompt, lastReply: lastReply, currentTool: currentTool,
                               terminal: location, runningSubagents: subagents.count, turnFailed: failed)
    }
}

private struct ClockHistory {
    var previous: (wall: Int64, monotonic: UInt64)?

    mutating func observe(wallMs: Int64, monotonicNs: UInt64) -> Bool {
        defer { previous = (wallMs, monotonicNs) }
        guard let previous else { return false }
        guard wallMs >= previous.wall, monotonicNs >= previous.monotonic else { return true }
        let (wallDelta, overflow) = wallMs.subtractingReportingOverflow(previous.wall)
        if overflow { return true }
        let monotonicDelta = Int64((monotonicNs - previous.monotonic) / 1_000_000)
        // Ignore sub-second clock sampling noise; jumps beyond the contract's skew are discontinuous.
        let (difference, differenceOverflow) = wallDelta.subtractingReportingOverflow(monotonicDelta)
        return differenceOverflow || difference > 2000 || difference < -2000
    }
}
