import CryptoKit
import EventBridge
import Foundation
import Observation

/// One in-memory authority. Main-actor isolation serializes changes and publication.
@MainActor
@Observable
public final class SessionStore {
    public private(set) var sessions: [SessionSnapshot] = []

    public static let sessionLimit = 128
    public static let eventIDLimit = 4096
    public static let turnIDLimit = 256
    public static let requestLimit = 64
    public static let freshnessNs: UInt64 = 120_000_000_000

    private var records: [SessionKey: Record] = [:]
    private var receiptClock = ClockHistory()
    private var runtimeClock = ClockHistory()
    private var horizonNs: UInt64 = 0

    public init() {}

    @discardableResult
    public func apply(_ observation: SessionObservationV1) -> SessionApplyResult {
        let result = reduce(observation)
        expire(at: horizonNs)
        publish()
        return result
    }

    /// Process one bounded bridge batch, then expire before publishing any snapshots.
    public func applyBatch(_ batch: [SessionObservationV1], observationsLost: Bool,
                           wallMs: Int64, monotonicNs: UInt64) {
        observeRuntimeClock(wallMs: wallMs, monotonicNs: monotonicNs)
        for observation in batch { _ = reduce(observation) }
        if observationsLost { invalidate(reason: .deliveryOverflow) }
        horizonNs = max(horizonNs, monotonicNs)
        expire(at: horizonNs)
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
        invalidate(reason: .clockOrWake)
        receiptClock = ClockHistory()
        runtimeClock = ClockHistory()
        horizonNs = 0
        publish()
    }

    public var nextExpiryMonotonicNs: UInt64? {
        records.values.compactMap { record in
            !record.terminal && record.status != .unknown ? record.deadlineNs : nil
        }.min()
    }

    private func reduce(_ observation: SessionObservationV1) -> SessionApplyResult {
        let event = observation.envelope
        // Validate public receipt inputs as well as delivery age before recording identities.
        guard (0...9_007_199_254_740_991).contains(observation.receiptWallMs),
              observation.receiptMonotonicNs <= UInt64.max - Self.freshnessNs,
              let canonical = try? event.frame() else { return .invalidObservation }
        horizonNs = max(horizonNs, observation.receiptMonotonicNs)
        expire(at: horizonNs)
        let age = observation.receiptWallMs - event.observedAtMs
        guard age <= 30_000, age >= -2000 else { return .deliveryTime }
        let monotonicReset = receiptClock.previous.map { observation.receiptMonotonicNs < $0.monotonic } ?? false
        if receiptClock.observe(wallMs: observation.receiptWallMs, monotonicNs: observation.receiptMonotonicNs) {
            invalidate(reason: .clockOrWake)
            // Deadlines for new evidence must use the new monotonic clock range.
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
            guard previous == digest else {
                record.unknown(.eventIDConflict)
                return .eventIDConflict
            }
            return .duplicate
        }
        let turn = event.turnID.map { SourceIdentity(value: $0) }
        let knownTurn = turn.map { record.turns.contains($0) } ?? false
        guard !record.saturated, record.seen.count < Self.eventIDLimit,
              turn == nil || knownTurn || record.turns.count < Self.turnIDLimit else {
            record.saturated = true
            record.unknown(.identityCapacity)
            return .identityCapacity
        }
        record.seen[event.eventID] = digest
        if let turn { record.turns.insert(turn) }

        if case .sessionEnded = observation.kind {
            record.terminal = true
            record.status = .ended
            record.reason = nil
            record.pending.removeAll()
            record.deadlineNs = nil
            return .ended
        }
        if record.terminal {
            if case .sessionStarted = observation.kind { record.unknown(.reusedSessionID) }
            return .terminalRestriction
        }
        if let watermark = record.watermarkMs, event.observedAtMs <= watermark {
            record.unknown(.ambiguousCaptureOrder)
            return .ambiguousCaptureOrder
        }
        if let turn, record.retired.contains(turn) { return .retiredTurn }

        switch observation.kind {
        case .sessionStarted:
            guard record.seen.count == 1 else { return .repeatedStart }
            record.status = .idle
            record.reason = nil
            record.refresh(observation)
            return .applied

        case .turnSubmitted:
            if record.baseline && turn == record.turn { return .repeatedSubmit }
            if record.baseline && turn == nil {
                record.unknown(.missingTurnIdentity)
                return .conflict
            }
            // A previously conflicting turn is not new lifecycle evidence.
            if record.baseline && knownTurn {
                record.unknown(.overlappingTurns)
                return .conflict
            }
            guard record.pending.isEmpty, !(record.baseline && record.status == .working) else {
                record.unknown(.overlappingTurns)
                return .conflict
            }
            if let previous = record.turn { record.retired.insert(previous) }
            record.turn = turn
            record.turnStartedAtMs = event.observedAtMs
            record.responseReadyAtMs = nil
            record.baseline = true
            record.stopped = false
            record.status = .working
            record.reason = nil
            record.refresh(observation)
            return .applied

        case .responseReady:
            guard record.baseline, let turn, turn == record.turn else {
                record.unknown(.uncorrelatedStop)
                return .conflict
            }
            record.pending = record.pending.filter { $0.value.turn != turn }
            if record.responseReadyAtMs == nil { record.responseReadyAtMs = event.observedAtMs }
            record.stopped = true
            if record.status == .unknown { return .resolvedButUnknown }
            if record.status == .responseReady { return .repeatedStop }
            record.status = .responseReady
            record.reason = nil
            record.refresh(observation)
            return .applied

        case .toolObserved, .toolFinished, .requestOpened:
            return applyTool(observation, record: record, turn: turn)

        case .sessionEnded:
            return .ended // Handled before timestamp and turn checks.
        }
    }

    private func applyTool(_ observation: SessionObservationV1, record: Record,
                           turn: SourceIdentity?) -> SessionApplyResult {
        guard !record.stopped else {
            record.unknown(.activityAfterStop)
            return .conflict
        }
        let event = observation.envelope
        let correlated = record.baseline && turn != nil && turn == record.turn
        let toolID = event.toolUseID.map { SourceIdentity(value: $0) }
        guard let toolName = event.toolName else { return .invalidObservation }
        let name = SourceIdentity(value: toolName)
        let requestKey: RequestKey
        if let turn, let toolID { requestKey = .correlated(turn, toolID) }
        else { requestKey = .uncorrelated(event.eventID) }

        switch observation.kind {
        case .requestOpened(let kind):
            if let existing = record.pending[requestKey] {
                guard existing.name == name && existing.kind == kind else {
                    record.unknown(.requestConflict)
                    return .conflict
                }
                return .mergedRequest
            }
            guard record.pending.count < Self.requestLimit else {
                record.unknown(.requestCapacity)
                return .requestCapacity
            }
            record.pending[requestKey] = Pending(eventID: event.eventID, turn: turn,
                                                  toolID: toolID, name: name, kind: kind)
            guard correlated else {
                record.unknown(.uncorrelatedActivity)
                return .conflict
            }
            if record.status == .unknown { return .retainedButUnknown }
            record.showPending()
            record.refresh(observation)
            return .applied

        case .toolFinished:
            if correlated, let request = record.pending[requestKey], request.name == name {
                record.pending.removeValue(forKey: requestKey)
                if record.status == .unknown { return .resolvedButUnknown }
                record.showPending()
                record.refresh(observation)
                return .applied
            }
            if !record.pending.isEmpty {
                record.unknown(.uncorrelatedResolution)
                return .conflict
            }
            return .unmatchedCompletion

        default:
            guard correlated else {
                record.unknown(.uncorrelatedActivity)
                return .conflict
            }
            if record.status == .unknown || !record.pending.isEmpty { return .noChange }
            record.status = .working
            record.reason = nil
            record.refresh(observation)
            return .applied
        }
    }

    private func observeRuntimeClock(wallMs: Int64, monotonicNs: UInt64) {
        if runtimeClock.observe(wallMs: wallMs, monotonicNs: monotonicNs) {
            invalidate(reason: .clockOrWake)
        }
        advanceClock(monotonicNs: monotonicNs)
    }

    private func advanceClock(monotonicNs: UInt64) {
        if monotonicNs < horizonNs {
            invalidate(reason: .clockOrWake)
            horizonNs = monotonicNs
        } else {
            horizonNs = max(horizonNs, monotonicNs)
        }
        expire(at: horizonNs)
    }

    private func expire(at now: UInt64) {
        for record in records.values where !record.terminal && record.status != .unknown {
            if let deadline = record.deadlineNs, now >= deadline { record.unknown(.expired) }
        }
    }

    private func invalidate(reason: SessionUnknownReason) {
        for record in records.values where !record.terminal { record.unknown(reason) }
    }

    private func publish() {
        let updated = records.map { key, record in record.snapshot(key: key) }.sorted {
            if $0.key.agent != $1.key.agent { return $0.key.agent < $1.key.agent }
            return $0.key.sessionID.utf8.lexicographicallyPrecedes($1.key.sessionID.utf8)
        }
        if sessions != updated { sessions = updated }
    }
}

private enum RequestKey: Hashable {
    case correlated(SourceIdentity, SourceIdentity)
    case uncorrelated(String)
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
    var status: SessionStatus = .unknown
    var reason: SessionUnknownReason? = .noBaseline
    var turn: SourceIdentity?
    var turnStartedAtMs: Int64?
    var responseReadyAtMs: Int64?
    var baseline = false
    var stopped = false
    var terminal = false
    var saturated = false
    var watermarkMs: Int64?
    var deadlineNs: UInt64?
    var receiptWallMs: Int64?
    var receiptMonotonicNs: UInt64?
    var projectPath: String?
    var paneSelector: String?
    var seen: [String: Data] = [:]
    var turns: Set<SourceIdentity> = []
    var retired: Set<SourceIdentity> = []
    var pending: [RequestKey: Pending] = [:]

    func unknown(_ reason: SessionUnknownReason) {
        status = .unknown
        self.reason = reason
    }

    func refresh(_ observation: SessionObservationV1) {
        watermarkMs = observation.envelope.observedAtMs
        let age = max(0, observation.receiptWallMs - observation.envelope.observedAtMs)
        deadlineNs = observation.receiptMonotonicNs + SessionStore.freshnessNs - UInt64(age) * 1_000_000
        receiptWallMs = observation.receiptWallMs
        receiptMonotonicNs = observation.receiptMonotonicNs
        if let cwd = observation.envelope.cwd { projectPath = cwd }
        if let terminal = observation.envelope.terminal { paneSelector = terminal.paneSelector }
    }

    func showPending() {
        reason = nil
        if pending.values.contains(where: { $0.kind == .questionNeeded }) { status = .questionNeeded }
        else if !pending.isEmpty { status = .approvalNeeded }
        else { status = .working }
    }

    func snapshot(key: SessionKey) -> SessionSnapshot {
        let requests = pending.values.map {
            SessionRequest(eventID: $0.eventID, turnID: $0.turn?.value, toolUseID: $0.toolID?.value,
                           toolName: $0.name.value, kind: $0.kind, isConfirmed: status != .unknown)
        }.sorted {
            if $0.kind != $1.kind { return $0.kind == .questionNeeded }
            return $0.eventID < $1.eventID
        }
        return SessionSnapshot(key: key, status: status, reason: reason, currentTurnID: turn?.value,
                               turnStartedAtMs: turnStartedAtMs, responseReadyAtMs: responseReadyAtMs,
                               pendingRequests: requests, captureWatermarkMs: watermarkMs,
                               receiptWallMs: receiptWallMs, receiptMonotonicNs: receiptMonotonicNs,
                               expiryMonotonicNs: deadlineNs, projectPath: projectPath,
                               paneSelector: paneSelector, hasTerminalRestriction: terminal)
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
