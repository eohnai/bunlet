import Foundation

public enum ActionDeliveryEvent: Sendable {
    case offer(UUID, ActionOffer)
    case receipt(UUID, ActionWriteReceipt)
    case closed(UUID, Bool)
    case capacity
}

/// A burst of short-lived sockets cannot create an unbounded queue of main-actor tasks.
public final class ActionInbox: @unchecked Sendable {
    public static let capacity = 128
    private let lock = NSLock()
    private var pending: [ActionDeliveryEvent] = []
    private var scheduled = false
    private var overflow = false
    private let onBatch: @MainActor @Sendable ([ActionDeliveryEvent], Bool) -> Void

    public init(onBatch: @escaping @MainActor @Sendable ([ActionDeliveryEvent], Bool) -> Void) {
        self.onBatch = onBatch
    }

    public func receive(_ event: ActionDeliveryEvent) {
        let schedule = lock.withLock {
            if pending.count < Self.capacity { pending.append(event) }
            else { overflow = true }
            guard !scheduled else { return false }
            scheduled = true
            return true
        }
        guard schedule else { return }
        Task { @MainActor [self] in
            let batch = lock.withLock {
                let result = (pending, overflow)
                pending.removeAll(keepingCapacity: true)
                overflow = false
                scheduled = false
                return result
            }
            onBatch(batch.0, batch.1)
        }
    }
}
