import AppKit
import Darwin
import EventBridge
import Observation
import SessionState
import SwiftUI

@main
struct NotchPetApp: App {
    @NSApplicationDelegateAdaptor(PetAppController.self) private var delegate

    var body: some Scene {
        MenuBarExtra("Notch Pet", systemImage: "pawprint.fill") {
            CompanionMenu(controller: delegate)
        }
        .menuBarExtraStyle(.menu)
        .commands {
            CommandGroup(replacing: .appSettings) {
                Button("Settings…", action: delegate.showSettings).keyboardShortcut(",")
            }
        }
    }
}

/// App-owned health evidence. Probes run only when an explicit future Check action calls refresh.
@MainActor
@Observable
private final class IntegrationHealthController {
    private(set) var evidence: [IntegrationAgent: IntegrationHealthEvidence] =
        Dictionary(uniqueKeysWithValues: IntegrationAgent.allCases.map {
            ($0, IntegrationHealthEvidence(agent: $0))
        })
    private var refreshing: Set<IntegrationAgent> = []

    var snapshots: [IntegrationHealthSnapshot] {
        IntegrationAgent.allCases.compactMap { agent in
            evidence[agent].map { IntegrationHealth.evaluate($0) }
        }
    }

    func refresh(agent: IntegrationAgent) async {
        guard !Task.isCancelled, refreshing.insert(agent).inserted else { return }
        ServiceStartLedger.record(.configurationProbe)
        defer { refreshing.remove(agent) }
        let manager = FileManager.default
        // Access only these path settings; do not inventory the environment or read auth files.
        let searchPath = getenv("PATH").map { String(cString: $0) } ?? "/usr/bin:/bin:/usr/sbin:/sbin"
        let executable: URL?
        if searchPath.utf8.count <= 16_384 {
            executable = searchPath.split(separator: ":", omittingEmptySubsequences: false).prefix(64)
                .filter { $0.hasPrefix("/") }
                .map { URL(fileURLWithPath: String($0)).appendingPathComponent(agent.rawValue) }
                .first { manager.isExecutableFile(atPath: $0.path) }
        } else {
            executable = nil
        }
        let directoryOverride = getenv(agent == .codex ? "CODEX_HOME" : "CLAUDE_CONFIG_DIR")
            .map { String(cString: $0) }
        let configurationDirectory: URL?
        if let directoryOverride, !directoryOverride.isEmpty {
            configurationDirectory = directoryOverride.hasPrefix("/") && directoryOverride.utf8.count <= 4096
                ? URL(fileURLWithPath: directoryOverride) : nil
        } else {
            configurationDirectory = manager.homeDirectoryForCurrentUser
                .appendingPathComponent(agent == .codex ? ".codex" : ".claude")
        }
        let configuration = configurationDirectory?
            .appendingPathComponent(agent == .codex ? "hooks.json" : "settings.json")
        let helper = Bundle.main.executableURL?.deletingLastPathComponent()
            .appendingPathComponent("NotchPetHook")
        let result = await IntegrationHealthProbe.inspect(agent: agent, executableURL: executable,
                                                          configurationURL: configuration, helperURL: helper)
        guard !Task.isCancelled, var current = evidence[agent] else { return }
        // Receiver and delivery can change during await; never replace them with a probe's defaults.
        current.version = result.version
        current.configuration = result.configuration
        current.helper = result.helper
        evidence[agent] = current
    }

    func setReceiver(_ state: IntegrationReceiverState) {
        var updated = evidence
        for agent in IntegrationAgent.allCases {
            updated[agent]?.receiver = state
        }
        evidence = updated
    }

    func recordDeliveries(_ observations: [SessionObservationV1]) {
        guard !observations.isEmpty else { return }
        var updated = evidence
        for observation in observations {
            guard let agent = IntegrationAgent(rawValue: observation.envelope.agent) else { continue }
            updated[agent]?.lastDelivery = IntegrationDeliveryReceipt(
                wallMs: observation.receiptWallMs, monotonicNs: observation.receiptMonotonicNs)
        }
        // The inbox's receipt order, not session expiry or wall-clock sorting, determines the last receipt.
        if updated != evidence { evidence = updated }
    }
}

@MainActor
final class AgentServices: NSObject, AppAgentService {
    typealias BatchHandler = @MainActor @Sendable ([SessionObservationV1], Bool) -> Void
    typealias ReceiverStart = (@escaping BatchHandler) throws -> (() -> Void)

    let sessionStore: SessionStore
    let usageStore: UsageStore
    private let integrationHealth = IntegrationHealthController()
    private let bridge: EventBridgeServer
    private let usage: any AppFeatureService
    private let startObserving: ReceiverStart?
    private let readWall: () -> Int64
    private let readMonotonic: () -> UInt64
    private var stopReceiver: (() -> Void)?
    private var generation: UUID?
    private var observers: [(NotificationCenter, NSObjectProtocol)] = []
    private var inbox: SessionEventInbox?
    private var expiryTimer: DispatchSourceTimer?
    private var receiptCutoffNs: UInt64 = 0

    init(sessionStore: SessionStore? = nil, usageStore: UsageStore? = nil, endpoint: BridgeEndpoint = .standard,
         usage: (any AppFeatureService)? = nil, startObserving: ReceiverStart? = nil,
         wall: @escaping () -> Int64 = { Int64(Date().timeIntervalSince1970 * 1000) },
         monotonic: @escaping () -> UInt64 = { DispatchTime.now().uptimeNanoseconds }) {
        let sessions = sessionStore ?? SessionStore()
        let limits = usageStore ?? UsageStore()
        self.sessionStore = sessions
        bridge = EventBridgeServer(endpoint: endpoint)
        self.usageStore = limits
        self.usage = usage ?? AgentUsageController(store: limits, sessions: sessions)
        self.startObserving = startObserving
        readWall = wall
        readMonotonic = monotonic
        super.init()
    }

    var healthSnapshots: [IntegrationHealthSnapshot] { integrationHealth.snapshots }

    func start() {
        guard generation == nil else { return }
        let current = UUID()
        generation = current
        let deliver: BatchHandler = { [weak self] batch, lost in
            guard let self, self.generation == current else { return }
            // Delivery happened even when a clock cutoff prevents it from restoring session freshness.
            self.integrationHealth.recordDeliveries(batch)
            // Evidence queued before sleep or a clock change cannot establish a fresh baseline.
            let eligible = batch.filter { $0.receiptMonotonicNs >= self.receiptCutoffNs }
            self.sessionStore.applyBatch(eligible, observationsLost: lost,
                                         wallMs: self.wallMs(), monotonicNs: self.monotonicNs())
            self.scheduleExpiry()
        }
        do {
            ServiceStartLedger.record(.eventReceiver)
            if let startObserving {
                stopReceiver = try startObserving(deliver)
            } else {
                let inbox = SessionEventInbox(onBatch: deliver)
                self.inbox = inbox
                try bridge.start { inbox.receive($0) }
                stopReceiver = { [weak self] in self?.bridge.stop() }
            }
            integrationHealth.setReceiver(.listening)
            usage.start()
        } catch BridgeError.unsafeEndpoint {
            integrationHealth.setReceiver(.failed(.unsafeEndpoint))
        } catch {
            integrationHealth.setReceiver(.failed(.receiverUnavailable))
        }
        let workspace = NSWorkspace.shared.notificationCenter
        for (center, name) in [(workspace, NSWorkspace.willSleepNotification),
                               (workspace, NSWorkspace.didWakeNotification),
                               (NotificationCenter.default, .NSSystemClockDidChange)] {
            let observer = center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated {
                    guard let self, self.generation == current else { return }
                    self.invalidateObservations()
                }
            }
            observers.append((center, observer))
        }
    }

    func stop() {
        guard generation != nil else { return }
        generation = nil
        stopReceiver?()
        stopReceiver = nil
        inbox = nil
        usage.stop()
        sessionStore.suspendMonitoring()
        integrationHealth.setReceiver(.stopped)
        expiryTimer?.cancel()
        expiryTimer = nil
        for (center, observer) in observers { center.removeObserver(observer) }
        observers.removeAll()
    }

    private func invalidateObservations() {
        receiptCutoffNs = monotonicNs()
        sessionStore.invalidateClocks()
        expiryTimer?.cancel()
        expiryTimer = nil
    }

    private func scheduleExpiry() {
        expiryTimer?.cancel()
        expiryTimer = nil
        guard let current = generation, let next = sessionStore.nextExpiryMonotonicNs else { return }
        let now = monotonicNs()
        // Check clock continuity once per second while fresh observations exist.
        // An empty or entirely unknown store has no timer.
        let delay = min(next > now ? next - now : 0, 1_000_000_000)
        let timer = DispatchSource.makeTimerSource(queue: .main)
        timer.schedule(deadline: .now() + .nanoseconds(Int(delay)), leeway: .milliseconds(5))
        timer.setEventHandler { [weak self] in
            Task { @MainActor in
                guard let self, self.generation == current else { return }
                self.sessionStore.checkClocks(wallMs: self.wallMs(), monotonicNs: self.monotonicNs())
                self.scheduleExpiry()
            }
        }
        expiryTimer = timer
        timer.resume()
    }

    private func wallMs() -> Int64 { readWall() }
    private func monotonicNs() -> UInt64 { readMonotonic() }
}

private struct CompanionMenu: View {
    let controller: PetAppController

    var body: some View {
        if controller.installed.contains(.pet) { Button("Show Pet", action: controller.showPet) }
        if controller.installed.contains(.notch) { Button("Show Notch", action: controller.showNotch) }
        Button("Settings…", action: controller.showSettings)
            .keyboardShortcut(",")
        Divider()
        Button("Quit Notch Pet") {
            NSApplication.shared.terminate(nil)
        }
        .keyboardShortcut("q")
    }
}
