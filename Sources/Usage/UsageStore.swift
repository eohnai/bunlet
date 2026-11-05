import Foundation
import Integration
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

@MainActor
@Observable
public final class UsageStore {
    public private(set) var observations: [UsageObservation] = []

    public init() { }

    @discardableResult
    public func apply(_ observation: UsageObservation) -> Bool {
        guard IntegrationAgent(rawValue: observation.provider) != nil,
              !observation.sourceID.isEmpty, observation.sourceID.utf8.count <= 256,
              observation.accountID.map({ !$0.isEmpty && $0.utf8.count <= 256 }) ?? true,
              observation.receivedAtMs >= 0, observation.measuredAtMs.map({ $0 >= 0 }) ?? true,
              observation.windows.count <= 64,
              Set(observation.windows.map(\.id)).count == observation.windows.count,
              observation.windows.allSatisfy({ window in
                  !window.id.isEmpty && window.id.utf8.count <= 256 &&
                  window.usedPercent.isFinite && (0...100).contains(window.usedPercent) &&
                  (window.durationMinutes.map { $0 > 0 } ?? true) &&
                  (window.resetsAtMs.map { $0 >= 0 } ?? true)
              }) else { return false }
        if let index = observations.firstIndex(where: {
            $0.provider == observation.provider && $0.sourceID == observation.sourceID
        }) {
            guard observation.receivedAtMs >= observations[index].receivedAtMs else { return false }
            observations[index] = observation
        } else {
            guard observations.count < 128 else { return false }
            observations.append(observation)
        }
        return true
    }

    public func snapshots(activeProviders: Set<IntegrationAgent>, nowMs: Int64) -> [UsageSnapshot] {
        observations.filter { observation in
            IntegrationAgent(rawValue: observation.provider).map(activeProviders.contains) ?? false
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
