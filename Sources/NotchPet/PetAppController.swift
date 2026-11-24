import AgentActions
import AppKit
import Darwin
import EventBridge
import Integration
import Observation
import Pet
import SessionState
import Usage

/// Presentation and optional service lifetime belong to the app, not its views.
@MainActor
@Observable
final class PetAppController: NSObject, NSApplicationDelegate {
    var installed: Set<AppFeature> { features.installed }
    var monitoringEnabled: Bool { features.monitoringEnabled }
    var healthSnapshots: [IntegrationHealthSnapshot] { agents?.healthSnapshots ?? [] }
    private let defaults = getenv("NOTCH_PET_PREFERENCES_SUITE")
        .flatMap { UserDefaults(suiteName: String(cString: $0)) } ?? .standard
    private let sessions = SessionStore()
    private let usage = UsageStore()
    private let updater = BunletUpdater()
    private let actionStore = ActionStore()
    @ObservationIgnored private lazy var localActions: LocalActionController = LocalActionController(store: actionStore, sessions: sessions, consented: providerMonitoring.actionAgents)
    private(set) var codexSetup: ProviderSetupController?
    private(set) var claudeSetup: ProviderSetupController?
    private(set) var cursorSetup: ProviderSetupController?
    @ObservationIgnored private(set) lazy var providerMonitoring: ProviderMonitoringModel = ProviderMonitoringModel(defaults: defaults) { [weak self] enabled in
        guard let self else { return }
        self.agents?.setEnabledProviders(enabled)
        self.localActions.setConsent(self.providerMonitoring.actionAgents)
    }
    @ObservationIgnored private lazy var navigation = TerminalNavigation(defaults: defaults, sessions: sessions)
    @ObservationIgnored private lazy var replies = TerminalReplyController(sessions: sessions)
    /// Daily Claude token totals from status-line readings (decision 0025).
    @ObservationIgnored private lazy var tokens = TokenLedger(defaults: defaults)
    @ObservationIgnored private var tokenObservation: ObservationLoop<[UsageObservation]>?
    @ObservationIgnored private lazy var petLibrary = PetLibraryModel(defaults: defaults) { [weak self] presentation in
        self?.pet?.setArtwork(presentation)
    }
    @ObservationIgnored private var islandHiddenForPet = false
    /// The pet session panel, opened from the pet's speech bubble.
    @ObservationIgnored private lazy var petSessions = PetSessionPanelController(
        sessions: sessions, features: features, actions: localActions, navigation: navigation,
        onOpenFeatures: { [weak self] in self?.showFeatures() }, anchor: { [weak self] in self?.pet?.frameOnScreen })
    @ObservationIgnored private lazy var petReactions = PetSessionAdapter(sessions: sessions) { [weak self] mood, cue in
        self?.pet?.setReaction(mood, cue: cue)
    }
    @ObservationIgnored private weak var pet: PetPanelController?
    @ObservationIgnored private weak var notch: NotchPanelController?
    @ObservationIgnored private weak var agents: AgentServices?
    @ObservationIgnored private var settings: PetSettingsController?
    /// Personal settings (decision 0021), shared by the settings window and the island.
    @ObservationIgnored private(set) lazy var preferences = BunletSettings(defaults: defaults)
    @ObservationIgnored lazy var features = FeatureSettingsModel(apply: { [weak self] installed, monitoring in
        self?.applyRuntimes(installed, monitoring: monitoring) ?? installed
    })
    @ObservationIgnored private lazy var runtimes = FeatureRuntimeOwner(factories: [
        .pet: { [weak self] in
            guard let self else { return nil }
            let panel = PetPanelController(size: PetPreferences(defaults: self.defaults).size, defaults: self.defaults, presentation: self.petLibrary.presentation,
                onDragBegan: { [weak self] in
                    self?.petSessions.close()
                    self?.islandHiddenForPet = true
                    self?.notch?.setHiddenForPet(true)
                }, returnTarget: { [weak self] in self?.notch?.returnTarget },
                onReturn: { [weak self] in
                    self?.islandHiddenForPet = false
                    self?.notch?.setHiddenForPet(false)
                }, onBadgeClick: { [weak self] in self?.petSessions.toggle() },
                onHide: { [weak self] in self?.petSessions.close() })
            panel.setReaction(self.petReactions.mood, cue: false)
            self.pet = panel
            return panel
        },
        .notch: { [weak self] in
            guard let self else { return nil }
            let panel = NotchPanelController(sessionStore: self.sessions, usageStore: self.usage,
                features: self.features, onOpenFeatures: { [weak self] in self?.showFeatures() }, actions: self.localActions, navigation: self.navigation,
                replies: self.replies, tokens: self.tokens, settings: self.preferences, onOpenSettings: { [weak self] in self?.showSettings() },
                onPillDragOut: { [weak self] in self?.pet?.beginPointerDrag() ?? false })
            self.notch = panel
            return panel
        },
        .agents: { [weak self] in
            guard let self else { return nil }
            let service = AgentServices(sessionStore: self.sessions, usageStore: self.usage, enabledProviders: self.providerMonitoring.enabledProviders, actions: self.localActions)
            self.agents = service
            return service
        }
    ])
    @ObservationIgnored private var runtimeMonitoring = false
    private var focusBefore: pid_t = -1

    func applicationDidFinishLaunching(_ notification: Notification) {
        updater.start()
        focusBefore = NSWorkspace.shared.frontmostApplication?.processIdentifier ?? -1
        navigation.start()
        tokenObservation = ObservationLoop({ [usage] in usage.observations }) { [weak self] observations in
            guard let self else { return }
            for observation in observations { self.tokens.record(observation) }
        }
        petLibrary.start()
        petReactions.start()
        features.start()
        settings = PetSettingsController(defaults: defaults, features: features, settings: preferences, updater: updater,
            onRemoveAllHooks: { [weak self] in self?.removeAllHooks() }, onSizeChange: { [weak self] size in
            self?.pet?.setSize(size)
        }, onShowPet: { [weak self] in self?.showPet() }, onShowNotch: { [weak self] in self?.showNotch() },
            readHealth: { [weak self] in self?.healthSnapshots ?? [] },
            readCodex: { [weak self] in self?.codexSetup },
            readClaude: { [weak self] in self?.claudeSetup },
            readCursor: { [weak self] in self?.cursorSetup },
            readMonitoring: { [weak self] in self?.providerMonitoring },
            readQuota: { [weak self] in self?.usage },
            readLocalActions: { [weak self] in self?.localActions },
            onReturnPet: { [weak self] in self?.returnPet() },
            readPetLibrary: { [weak self] in self?.petLibrary },
            readNavigation: { [weak self] in self?.navigation },
            readTokens: { [weak self] in self?.tokens })
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
            guard let self else { return }
            self.pet?.writeEvidence(phase: "launched", agentsEnabled: self.monitoringEnabled,
                                    focusBefore: self.focusBefore)
        }
    }

    func showPet() {
        pet?.reveal()
    }

    func returnPet() {
        pet?.returnPet()
    }

    func showNotch() {
        islandHiddenForPet = false
        notch?.show()
    }

    /// The setup controller for each agent, while agent services are installed.
    func setup(for agent: Agent) -> ProviderSetupController? {
        switch agent {
        case .codex: codexSetup
        case .claude: claudeSetup
        case .cursor: cursorSetup
        }
    }

    private var allSetups: [ProviderSetupController] { Agent.allCases.compactMap(setup(for:)) }

    private func applyRuntimes(_ installed: Set<AppFeature>, monitoring: Bool) -> Set<AppFeature> {
        if runtimeMonitoring && !monitoring {
            for setup in allSetups { setup.cancel() }
        }
        runtimeMonitoring = monitoring && installed.contains(.agents)
        if installed.contains(.agents) {
            if codexSetup == nil { codexSetup = makeProviderSetup(.codex) }
            if claudeSetup == nil { claudeSetup = makeProviderSetup(.claude) }
            if cursorSetup == nil { cursorSetup = makeProviderSetup(.cursor) }
            if monitoring {
                for agent in Agent.allCases where providerMonitoring.isEnabled(agent) {
                    setup(for: agent)?.connectAutomatically()
                }
            }
        } else {
            for setup in allSetups { setup.cancel() }
            codexSetup = nil
            claudeSetup = nil
            cursorSetup = nil
        }
        var active = installed
        if !monitoring { active.remove(.agents) }
        runtimes.apply(active)
        notch?.setHiddenForPet(islandHiddenForPet)
        // Once the island exists, a returned pet docks inside it.
        pet?.show()
        return runtimes.unavailableFeatures
    }

    private func makeProviderSetup(_ agent: Agent) -> ProviderSetupController {
        ProviderSetupController(agent: agent, onConnected: { [weak self] in
            self?.providerMonitoring.setEnabled(true, for: agent)
        }, onPaused: { [weak self] in
            self?.providerMonitoring.setEnabled(false, for: agent)
        }, onActionsConsent: { [weak self] enabled in
            self?.providerMonitoring.setActionsEnabled(enabled, for: agent)
        }, onQuotaChoice: { [weak self] on in
            self?.providerMonitoring.setQuotaAutoConnect(on)
        }, quotaAutomatic: { [weak self] in
            self?.providerMonitoring.quotaAutoConnect ?? false
        }, onInspection: { [weak self] evidence in
            self?.agents?.recordInspection(evidence)
        })
    }

    func showSettings() {
        settings?.show()
    }

    func showFeatures() { settings?.show(page: .agents) }

    /// General → Remove all hook configuration: disconnect every provider, which removes every hook scope Bunlet owns.
    private func removeAllHooks() {
        for setup in allSetups { setup.start(.disconnect) }
    }

    func applicationWillTerminate(_ notification: Notification) {
        for setup in allSetups { setup.cancel() }
        let pet = self.pet
        navigation.stop()
        replies.stop()
        tokenObservation?.cancel()
        petLibrary.cancel()
        petReactions.stop()
        runtimes.apply([])
        pet?.writeEvidence(phase: "terminated", agentsEnabled: false, focusBefore: focusBefore)
    }
}
