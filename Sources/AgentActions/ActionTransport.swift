import Darwin
import EventBridge
import Foundation

/// Event-driven while waiting for the user. At most 32 live sockets; no polling loop per idle request.
public final class ActionTransport: @unchecked Sendable {
    public typealias OfferHandler = @Sendable (UUID, ActionOffer) -> Void
    public typealias ReceiptHandler = @Sendable (UUID, ActionWriteReceipt) -> Void
    public typealias CloseHandler = @Sendable (UUID, Bool) -> Void
    private let lock = NSLock()
    private let endpoint: BridgeEndpoint
    private let queue = DispatchQueue(label: "notch-pet.actions.accept")
    private var generation: UUID?
    private var source: DispatchSourceRead?
    private var connections: [UUID: ActionConnection] = [:]

    public init(endpoint: BridgeEndpoint = .standard) { self.endpoint = endpoint }

    public func start(onOffer: @escaping OfferHandler, onReceipt: @escaping ReceiptHandler,
                      onClose: @escaping CloseHandler, onCapacity: @escaping @Sendable () -> Void) throws {
        lock.lock()
        defer { lock.unlock() }
        guard generation == nil else { throw BridgeError.unavailable }
        let listener = try ActionSocketListener(endpoint: endpoint)
        let current = UUID()
        let reader = DispatchSource.makeReadSource(fileDescriptor: listener.descriptor, queue: queue)
        reader.setEventHandler { [weak self, listener] in
            guard let self else { return }
            for _ in 0..<8 {
                guard self.lock.withLock({ self.generation == current }) else { return }
                guard let fd = try? ActionSocketIO.accept(listener.descriptor) else { return }
                let id = UUID()
                let connection = ActionConnection(id: id, descriptor: fd, onOffer: onOffer, onReceipt: onReceipt) {
                    [weak self] id, dispatched in
                    guard let self else { return }
                    let live = self.lock.withLock {
                        self.connections.removeValue(forKey: id)
                        return self.generation == current
                    }
                    if live { onClose(id, dispatched) }
                }
                let accepted = self.lock.withLock {
                    guard self.generation == current, self.connections.count < ActionProtocol.capacity else { return false }
                    self.connections[id] = connection
                    return true
                }
                if accepted { connection.start() }
                else {
                    connection.close()
                    onCapacity()
                }
            }
        }
        reader.setCancelHandler { _ = listener }
        generation = current
        source = reader
        reader.resume()
    }

    public func respond(link: UUID, decision: ActionDecision) {
        let connection = lock.withLock { connections[link] }
        connection?.respond(decision)
    }

    public func close(link: UUID) { lock.withLock { connections[link] }?.close() }

    public func stop() {
        let old = lock.withLock {
            generation = nil
            let old = (source, Array(connections.values))
            source = nil
            connections.removeAll()
            return old
        }
        old.0?.cancel()
        for connection in old.1 { connection.close() }
    }
}

private final class ActionConnection: @unchecked Sendable {
    private enum Phase { case offer, waiting, acknowledgement, closed }
    private let id: UUID
    private let descriptor: Int32
    private let queue: DispatchQueue
    private let onOffer: ActionTransport.OfferHandler
    private let onReceipt: ActionTransport.ReceiptHandler
    private let onClose: ActionTransport.CloseHandler
    private var phase: Phase = .offer
    private var dispatched = false
    private var reader: DispatchSourceRead?
    private var timer: DispatchSourceTimer?

    init(id: UUID, descriptor: Int32, onOffer: @escaping ActionTransport.OfferHandler,
         onReceipt: @escaping ActionTransport.ReceiptHandler, onClose: @escaping ActionTransport.CloseHandler) {
        self.id = id
        self.descriptor = descriptor
        self.onOffer = onOffer
        self.onReceipt = onReceipt
        self.onClose = onClose
        queue = DispatchQueue(label: "notch-pet.actions.\(id.uuidString)")
    }

    func start() {
        queue.async { [self] in
            guard phase == .offer else { return }
            let fd = descriptor
            let source = DispatchSource.makeReadSource(fileDescriptor: fd, queue: queue)
            source.setEventHandler { [weak self] in self?.readable() }
            source.setCancelHandler { Darwin.close(fd) }
            reader = source
            let expiry = DispatchSource.makeTimerSource(queue: queue)
            expiry.schedule(deadline: .now() + .seconds(60))
            expiry.setEventHandler { [weak self] in self?.finish() }
            timer = expiry
            source.resume()
            expiry.resume()
        }
    }

    func respond(_ decision: ActionDecision) {
        queue.async { [self] in
            guard phase == .waiting else { return }
            dispatched = true
            phase = .acknowledgement
            do { try ActionSocketIO.write(descriptor, frame: ActionProtocol.frame(decision)) }
            catch { finish() }
        }
    }

    func close() { queue.async { [self] in finish() } }

    private func readable() {
        guard phase != .closed else { return }
        do {
            let frame = try ActionSocketIO.read(descriptor, timeoutMs: ActionSocketIO.handshakeMs)
            switch phase {
            case .offer:
                let offer = try ActionProtocol.decode(frame, as: ActionOffer.self)
                guard ActionProtocol.valid(offer, nowMs: Int64(Date().timeIntervalSince1970 * 1000)) else { throw BridgeError.invalidMessage }
                phase = .waiting
                onOffer(id, offer)
            case .acknowledgement:
                let receipt = try ActionProtocol.decode(frame, as: ActionWriteReceipt.self)
                onReceipt(id, receipt)
                finish()
            case .waiting, .closed: finish()
            }
        } catch { finish() }
    }

    private func finish() {
        guard phase != .closed else { return }
        phase = .closed
        if let reader { reader.cancel() }
        else { Darwin.close(descriptor) }
        timer?.cancel()
        timer = nil
        onClose(id, dispatched)
    }
}
