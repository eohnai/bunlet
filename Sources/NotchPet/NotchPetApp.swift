import AppKit
import Darwin
import EventBridge
import Integration
import Observation
import SessionState
import SwiftUI
import Usage

@main
struct NotchPetApp: App {
    @NSApplicationDelegateAdaptor(PetAppController.self) private var delegate

    var body: some Scene {
        MenuBarExtra("Bunlet", systemImage: "hare.fill") {
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
    private(set) var evidence: [Agent: IntegrationHealthEvidence] =
        Dictionary(uniqueKeysWithValues: Agent.allCases.map {
            ($0, IntegrationHealthEvidence(agent: $0))
        })
    private var refreshing: Set<Agent> = []

    var snapshots: [IntegrationHealthSnapshot] {
        Agent.allCases.compactMap { agent in
            evidence[agent].map { IntegrationHealth.evaluate($0) }
        }
    }

    func refresh(agent: Agent) async {
        guard !Task.isCancelled, refreshing.insert(agent).inserted else { return }
        ServiceStartLedger.record(.configurationProbe)
        defer { refreshing.remove(agent) }
        let manager = FileManager.default
        // Access only these path settings; do not inventory the environment or read auth files.
        let searchPath = getenv("PATH").map { String(cString: $0) }
        let executable: URL?
        switch AgentPathLocator.executable(agent: agent, policy: .health, searchPath: searchPath,
                                          homeDirectory: manager.homeDirectoryForCurrentUser,
                                          desktopApplication: NSWorkspace.shared.urlForApplication(withBundleIdentifier:)) {
        case .found(let url):
            executable = url
        case .notFound, .invalidSearchPath:
            executable = nil
        }
        let directoryOverride = agent.configurationOverrideVariable.flatMap { getenv($0) }
            .map { String(cString: $0) }
        let configurationDirectory = AgentPathLocator.configurationDirectory(
            agent: agent, override: directoryOverride, homeDirectory: manager.homeDirectoryForCurrentUser)
        let configuration = configurationDirectory?
            .appendingPathComponent(agent.hookConfigurationName)
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

    func setReceiver(_ state: IntegrationReceiverState, agents: Set<Agent> = Set(Agent.allCases)) {
        var updated = evidence
        for agent in agents {
            updated[agent]?.receiver = state
        }
        evidence = updated
    }

    func recordProbe(_ result: IntegrationHealthEvidence) {
        guard var current = evidence[result.agent] else { return }
        current.version = result.version
        current.configuration = result.configuration
        current.helper = result.helper
        evidence[result.agent] = current
    }

    func recordDeliveries(_ observations: [SessionObservationV1]) {
        guard !observations.isEmpty else { return }
        var updated = evidence
        for observation in observations {
            let agent = observation.envelope.agent
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
    private let actions: LocalActionController?
    private let usageReceiver = UsageReceiver()
    private let startObserving: ReceiverStart?
    private let readWall: () -> Int64
    private let readMonotonic: () -> UInt64
    private var stopReceiver: (() -> Void)?
    private var generation: UUID?
    private var observers: [(NotificationCenter, NSObjectProtocol)] = []
    private var inbox: SessionEventInbox?
    private var usageInbox: UsageInbox?
    private var quotaGeneration: UUID?
    private var enabledProviders: Set<Agent>
    private var providerCutoffs: [Agent: (monotonic: UInt64, wall: Int64)] = [:]
    private var eventReceiverState: IntegrationReceiverState = .notStarted
    private var receiptCutoffNs: UInt64 = 0

    init(sessionStore: SessionStore? = nil, usageStore: UsageStore? = nil, endpoint: BridgeEndpoint = .standard,
         usage: (any AppFeatureService)? = nil, startObserving: ReceiverStart? = nil,
         enabledProviders: Set<Agent> = Set(Agent.allCases),
         actions: LocalActionController? = nil,
         wall: @escaping () -> Int64 = { Int64(Date().timeIntervalSince1970 * 1000) },
         monotonic: @escaping () -> UInt64 = { DispatchTime.now().uptimeNanoseconds }) {
        let sessions = sessionStore ?? SessionStore()
        let limits = usageStore ?? UsageStore()
        self.sessionStore = sessions
        bridge = EventBridgeServer(endpoint: endpoint)
        self.usageStore = limits
        self.usage = usage ?? AgentUsageController(store: limits, sessions: sessions)
        self.startObserving = startObserving
        self.enabledProviders = enabledProviders
        self.actions = actions
        readWall = wall
        readMonotonic = monotonic
        super.init()
    }

    var healthSnapshots: [IntegrationHealthSnapshot] { integrationHealth.snapshots }

    func recordInspection(_ evidence: IntegrationHealthEvidence) {
        integrationHealth.recordProbe(evidence)
    }

    func setEnabledProviders(_ providers: Set<Agent>) {
        let changed = enabledProviders.symmetricDifference(providers)
        for agent in changed {
            providerCutoffs[agent] = (monotonicNs(), wallMs())
            if !providers.contains(agent) { sessionStore.suspendMonitoring(agent: agent) }
        }
        enabledProviders = providers
        actions?.setEnabledProviders(providers)
        (usage as? AgentUsageController)?.setEnabledProviders(providers)
        guard let current = generation else { return }
        updateReceiverEvidence()
        if providers.contains(.claude) { startClaudeQuota(current: current) }
        else { stopClaudeQuota() }
    }

    func start() {
        guard generation == nil else { return }
        let current = UUID()
        generation = current
        for agent in Agent.allCases { providerCutoffs[agent] = (monotonicNs(), wallMs()) }
        let deliver: BatchHandler = { [weak self] batch, lost in
            guard let self, self.generation == current else { return }
            let monitored = batch.filter { self.enabledProviders.contains($0.envelope.agent) }
            // Delivery happened even when a clock cutoff keeps it out of session state.
            self.integrationHealth.recordDeliveries(monitored)
            // Evidence queued before sleep or a clock change cannot establish a fresh baseline.
            let eligible = monitored.filter {
                let cutoff = self.providerCutoffs[$0.envelope.agent]
                return $0.receiptMonotonicNs >= max(self.receiptCutoffNs, cutoff?.monotonic ?? 0) &&
                    $0.envelope.observedAtMs >= (cutoff?.wall ?? 0)
            }
            self.sessionStore.applyBatch(eligible, observationsLost: lost,
                                         wallMs: self.wallMs(), monotonicNs: self.monotonicNs())
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
            eventReceiverState = .listening
        } catch BridgeError.unsafeEndpoint {
            eventReceiverState = .failed(.unsafeEndpoint)
        } catch {
            eventReceiverState = .failed(.receiverUnavailable)
        }
        updateReceiverEvidence()
        (usage as? AgentUsageController)?.setEnabledProviders(enabledProviders)
        if enabledProviders.contains(.claude) { startClaudeQuota(current: current) }
        usage.start()
        actions?.setEnabledProviders(enabledProviders)
        actions?.start()
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
        actions?.stop()
        stopClaudeQuota()
        sessionStore.suspendMonitoring()
        integrationHealth.setReceiver(.stopped)
        eventReceiverState = .stopped
        for (center, observer) in observers { center.removeObserver(observer) }
        observers.removeAll()
    }

    private func invalidateObservations() {
        receiptCutoffNs = monotonicNs()
        for agent in Agent.allCases { providerCutoffs[agent] = (receiptCutoffNs, wallMs()) }
        sessionStore.invalidateClocks()
        actions?.refreshEvidence()
    }

    private func updateReceiverEvidence() {
        for agent in Agent.allCases {
            integrationHealth.setReceiver(enabledProviders.contains(agent) ? eventReceiverState : .stopped, agents: [agent])
        }
    }

    private func startClaudeQuota(current: UUID) {
        guard quotaGeneration == nil else { return }
        let quotaID = UUID()
        quotaGeneration = quotaID
        let quotaInbox = UsageInbox { [weak self] batch, lost, rejected in
            guard let self, self.generation == current, self.quotaGeneration == quotaID,
                  self.enabledProviders.contains(.claude) else { return }
            self.usageStore.receiveClaudeBatch(batch, lost: lost, rejected: rejected)
        }
        usageInbox = quotaInbox
        do {
            try usageReceiver.start(onRejected: { quotaInbox.reject() }) { quotaInbox.receive($0) }
            usageStore.setReceiverState(.listening)
        } catch {
            usageStore.setReceiverState(.unavailable)
        }
    }

    private func stopClaudeQuota() {
        quotaGeneration = nil
        usageReceiver.stop()
        usageInbox = nil
        usageStore.setReceiverState(.stopped)
    }

    private func wallMs() -> Int64 { readWall() }
    private func monotonicNs() -> UInt64 { readMonotonic() }
}

private struct CompanionMenu: View {
    let controller: PetAppController

    var body: some View {
        Button("Settings…", action: controller.showSettings)
            .keyboardShortcut(",")
        Divider()
        Button("Quit Bunlet") {
            NSApplication.shared.terminate(nil)
        }
        .keyboardShortcut("q")
    }
}
