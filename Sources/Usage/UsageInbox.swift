import Foundation

/// One pending main-actor handoff, with bounded metadata and observable loss.
public final class UsageInbox: @unchecked Sendable {
    public static let capacity = 128
    private let lock = NSLock()
    private var pending: [UsageObservation] = []
    private var scheduled = false
    private var lost = false
    private var rejected = false
    private let onBatch: @MainActor @Sendable ([UsageObservation], Bool, Bool) -> Void

    public init(onBatch: @escaping @MainActor @Sendable ([UsageObservation], Bool, Bool) -> Void) {
        self.onBatch = onBatch
    }

    public func receive(_ observation: UsageObservation) { enqueue(observation, invalid: false) }
    public func reject() { enqueue(nil, invalid: true) }

    private func enqueue(_ observation: UsageObservation?, invalid: Bool) {
        let schedule = lock.withLock {
            rejected = rejected || invalid
            if let observation {
                if pending.count < Self.capacity { pending.append(observation) }
                else { lost = true }
            }
            if scheduled { return false }
            scheduled = true
            return true
        }
        guard schedule else { return }
        Task { @MainActor [self] in
            let batch = lock.withLock {
                let result = (pending, lost, rejected)
                pending.removeAll(keepingCapacity: true)
                lost = false
                rejected = false
                scheduled = false
                return result
            }
            onBatch(batch.0, batch.1, batch.2)
        }
    }
}
