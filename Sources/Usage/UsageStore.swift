import EventBridge
import Foundation
import Observation

public enum UsageFailure: String, Codable, Sendable {
    case awaitingSource, signedOut, unsupportedAccount, sourceUnavailable, malformed, timedOut
}

public struct UsageWindow: Codable, Equatable, Sendable {
    public let id: String
    public let usedPercent: Double
    public let durationMinutes: Int?
    public let resetsAtMs: Int64?
}

/// Source identity distinguishes anonymous observations; it never asserts account identity.
public struct UsageObservation: Codable, Equatable, Sendable {
    public let provider: String
    public let sourceID: String
    public let accountID: String?
    public let receivedAtMs: Int64
    public let measuredAtMs: Int64?
    public let windows: [UsageWindow]
    public let failure: UsageFailure?
}

public struct UsageSnapshot: Equatable, Sendable {
    public let observation: UsageObservation
    public let isStale: Bool
}

public enum UsageReceiverState: Equatable, Sendable {
    case stopped, listening, unavailable
}

@MainActor
@Observable
public final class UsageStore {
    public private(set) var observations: [UsageObservation] = []
    public private(set) var receiverState: UsageReceiverState = .stopped
    public private(set) var lastClaudeReceiptMs: Int64?
    public private(set) var intakeLost = false
    public private(set) var invalidIntake = false
    public private(set) var capacityReached = false

    public func setReceiverState(_ state: UsageReceiverState) { receiverState = state }

    public func receiveClaudeBatch(_ batch: [UsageObservation], lost: Bool, rejected: Bool) {
        intakeLost = intakeLost || lost
        invalidIntake = invalidIntake || rejected
        for observation in batch where UsageValidation.acceptsClaudeIngress(observation) {
            if apply(observation) { lastClaudeReceiptMs = observation.receivedAtMs }
        }
    }

    public init() { }

    @discardableResult
    public func apply(_ observation: UsageObservation) -> Bool {
        guard UsageValidation.accepts(observation) else { return false }
        // Expire only on intake; inactive apps need no cleanup timer. Future timestamps are retained as stale.
        observations.removeAll {
            observation.receivedAtMs >= $0.receivedAtMs &&
                observation.receivedAtMs - $0.receivedAtMs >= 86_400_000
        }
        if let index = observations.firstIndex(where: {
            $0.provider == observation.provider && $0.sourceID == observation.sourceID
        }) {
            guard observation.receivedAtMs >= observations[index].receivedAtMs else { return false }
            observations[index] = observation
        } else {
            guard observations.count < 128 else {
                capacityReached = true
                return false
            }
            observations.append(observation)
        }
        capacityReached = false
        return true
    }

    public func snapshots(activeProviders: Set<Agent>, nowMs: Int64) -> [UsageSnapshot] {
        observations.filter { observation in
            Agent(rawValue: observation.provider).map(activeProviders.contains) ?? false
        }.sorted {
            $0.provider == $1.provider ? $0.sourceID < $1.sourceID : $0.provider < $1.provider
        }.map { observation in
            let clockInvalid = nowMs < observation.receivedAtMs
            let aged = !clockInvalid && nowMs - observation.receivedAtMs >= 300_000
            let resetPassed = observation.windows.contains { $0.resetsAtMs.map { $0 <= nowMs } ?? false }
            return UsageSnapshot(observation: observation,
                                 isStale: clockInvalid || aged || resetPassed || observation.failure != nil)
        }
    }
}
