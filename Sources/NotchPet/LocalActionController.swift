import AgentActions
import EventBridge
import Foundation
import Observation
import SessionState

@MainActor
@Observable
final class LocalActionController: AppFeatureService {
    let store: ActionStore
    private(set) var status = "Local response receiver stopped."
    @ObservationIgnored private let sessions: SessionStore
    @ObservationIgnored private let transport: ActionTransport
    @ObservationIgnored private var providers: Set<Agent> = []
    @ObservationIgnored private var generation: UUID?
    @ObservationIgnored private var observation: ObservationLoop<[SessionSnapshot]>?
    @ObservationIgnored private var timer: DispatchSourceTimer?

    init(store: ActionStore, sessions: SessionStore, endpoint: BridgeEndpoint = .standard) {
        self.store = store
        self.sessions = sessions
        transport = ActionTransport(endpoint: endpoint)
    }

    func start() {
        guard generation == nil else { return }
        let current = UUID()
        generation = current
        let inbox = ActionInbox { [weak self] batch, overflow in
            guard let self, self.generation == current else { return }
            if overflow {
                self.stop()
                self.status = "Local response intake overflowed. Pause and resume Agents before responding."
                return
            }
            for event in batch {
                switch event {
                case .offer(let link, let offer):
                    if !self.store.receive(offer, link: link, nowMs: self.wallMs(), nowNs: self.nowNs()) {
                        self.transport.close(link: link)
                    }
                case .receipt(let link, let receipt): self.store.acknowledge(link: link, receipt: receipt)
                case .closed(let link, let dispatched): self.store.closed(link: link, dispatched: dispatched)
                case .capacity: self.status = "Local response connection capacity reached. Return to the terminal for that request."
                }
            }
            self.refreshEvidence()
        }
        do {
            try transport.start(onOffer: { inbox.receive(.offer($0, $1)) },
                                onReceipt: { inbox.receive(.receipt($0, $1)) },
                                onClose: { inbox.receive(.closed($0, $1)) },
                                onCapacity: { inbox.receive(.capacity) })
            store.setReceiverAvailable(true)
            status = "Documented Claude hook channel listening; runtime support unverified."
            observation = ObservationLoop({ [sessions] in sessions.sessions }) { [weak self] _ in self?.refreshEvidence() }
            refreshEvidence()
        } catch {
            generation = nil
            store.setReceiverAvailable(false)
            status = "Local response receiver unavailable. Pause and resume Agents to retry."
        }
    }

    func stop() {
        generation = nil
        observation?.cancel()
        observation = nil
        timer?.cancel()
        timer = nil
        transport.stop()
        store.stop()
        status = "Local response receiver stopped. Retained requests are not resolved."
    }

    func setEnabledProviders(_ providers: Set<Agent>) {
        self.providers = providers
        refreshEvidence()
    }

    func refreshEvidence() {
        let allowed = generation == nil ? Set<Agent>() : providers
        let close = store.reconcile(sessions: sessions.sessions, providers: allowed, nowNs: nowNs())
        for link in close { transport.close(link: link) }
        scheduleExpiry()
    }

    func send(_ id: UUID, choice: ActionChoice) {
        guard generation != nil, store.receiverAvailable else { return }
        refreshEvidence()
        guard let (link, decision) = store.prepare(id, choice: choice) else { return }
        transport.respond(link: link, decision: decision)
        scheduleExpiry()
    }

    func cancel(_ id: UUID) {
        if let link = store.cancel(id) { transport.close(link: link) }
        scheduleExpiry()
    }

    private func scheduleExpiry() {
        timer?.cancel()
        timer = nil
        guard let current = generation, let next = store.nextDeadlineNs else { return }
        let now = nowNs()
        let delay = min(next > now ? next - now : 0, ActionProtocol.lifetimeNs)
        let source = DispatchSource.makeTimerSource(queue: .main)
        source.schedule(deadline: .now() + .nanoseconds(Int(delay)), leeway: .milliseconds(5))
        source.setEventHandler { [weak self] in
            MainActor.assumeIsolated {
                guard let self, self.generation == current else { return }
                self.refreshEvidence()
            }
        }
        timer = source
        source.resume()
    }

    private func nowNs() -> UInt64 { DispatchTime.now().uptimeNanoseconds }
    private func wallMs() -> Int64 { Int64(Date().timeIntervalSince1970 * 1000) }
}
