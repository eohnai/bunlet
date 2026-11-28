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

/// A session's cumulative token totals as its agent reports them (decision 0025). Never an allowance.
public struct TokenTotals: Codable, Equatable, Sendable {
    public let input: Int64
    public let output: Int64

    public init(input: Int64, output: Int64) {
        self.input = input
        self.output = output
    }

    public static let limit: Int64 = 1_000_000_000_000
    var isValid: Bool { (0...Self.limit).contains(input) && (0...Self.limit).contains(output) }
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
    /// Claude status-line session totals only. Absent for Codex, which reports none to Bunlet.
    public var tokens: TokenTotals? = nil
}

/// A source's latest reading as the badge shows it (decision 0036). There is no stale state: the last reading stays
/// until a newer one replaces it. `failure` names a read that failed after the kept reading, if any.
public struct UsageSnapshot: Equatable, Sendable {
    public let observation: UsageObservation
    public var failure: UsageFailure? = nil

    public init(observation: UsageObservation, failure: UsageFailure? = nil) {
        self.observation = observation
        self.failure = failure
    }
}

public enum UsageReceiverState: Equatable, Sendable {
    case stopped, listening, unavailable
}

@MainActor
@Observable
public final class UsageStore {
    public private(set) var observations: [UsageObservation] = []
    /// A failed or empty read after a kept reading, by source. A later reading with windows clears it.
    private var failures: [String: UsageFailure] = [:]
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
        // Expire only on intake; inactive apps need no cleanup timer.
        observations.removeAll {
            observation.receivedAtMs >= $0.receivedAtMs &&
                observation.receivedAtMs - $0.receivedAtMs >= 86_400_000
        }
        let key = Self.key(observation)
        failures = failures.filter { entry in observations.contains { Self.key($0) == entry.key } }
        if let index = observations.firstIndex(where: { Self.key($0) == key }) {
            guard observation.receivedAtMs >= observations[index].receivedAtMs else { return false }
            if observation.windows.isEmpty, !observations[index].windows.isEmpty {
                // Decision 0036: a failed or empty read never hides the last good reading.
                failures[key] = observation.failure ?? .awaitingSource
            } else {
                observations[index] = observation
                failures[key] = nil
            }
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

    public func snapshots(activeProviders: Set<Agent>) -> [UsageSnapshot] {
        observations.filter { observation in
            Agent(rawValue: observation.provider).map(activeProviders.contains) ?? false
        }.sorted {
            $0.provider == $1.provider ? $0.sourceID < $1.sourceID : $0.provider < $1.provider
        }.map { UsageSnapshot(observation: $0, failure: failures[Self.key($0)]) }
    }

    /// Agents with any kept reading. Their badges stay after their sessions leave the list (decision 0036).
    public var providersWithReadings: Set<Agent> {
        Set(observations.compactMap { Agent(rawValue: $0.provider) })
    }

    private static func key(_ observation: UsageObservation) -> String {
        "\(observation.provider)\u{1F}\(observation.sourceID)"
    }
}
