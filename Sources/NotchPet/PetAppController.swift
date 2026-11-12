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
    private let actionStore = ActionStore()
    @ObservationIgnored private lazy var localActions: LocalActionController = LocalActionController(store: actionStore, sessions: sessions, consentEnabled: providerMonitoring.actionsEnabled)
    private(set) var codexSetup: ProviderSetupController?
    private(set) var claudeSetup: ProviderSetupController?
    @ObservationIgnored private(set) lazy var providerMonitoring: ProviderMonitoringModel = ProviderMonitoringModel(defaults: defaults) { [weak self] enabled in
        guard let self else { return }
        self.agents?.setEnabledProviders(enabled)
        self.localActions.setConsent(self.providerMonitoring.actionsEnabled)
    }
    @ObservationIgnored private lazy var navigation = TerminalNavigation(defaults: defaults, sessions: sessions)
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
    @ObservationIgnored lazy var features = FeatureSettingsModel(defaults: defaults, apply: { [weak self] installed, monitoring in
        self?.applyRuntimes(installed, monitoring: monitoring) ?? installed
    }, pendingNotices: { [weak self] in
        self?.sessions.sessions.reduce(0) { $0 + $1.pendingRequests.count } ?? 0
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
            panel?.setReaction(self.petReactions.mood, cue: false)
            self.pet = panel
            return panel
        },
        .notch: { [weak self] in
            guard let self else { return nil }
            let panel = NotchPanelController(sessionStore: self.sessions, usageStore: self.usage,
                features: self.features, onOpenFeatures: { [weak self] in self?.showFeatures() }, actions: self.localActions, navigation: self.navigation,
                onOpenSettings: { [weak self] in self?.showSettings() },
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
        focusBefore = NSWorkspace.shared.frontmostApplication?.processIdentifier ?? -1
        navigation.start()
        petLibrary.start()
        petReactions.start()
        features.start()
        settings = PetSettingsController(defaults: defaults, features: features, onSizeChange: { [weak self] size in
            self?.pet?.setSize(size)
        }, onShowPet: { [weak self] in self?.showPet() }, onShowNotch: { [weak self] in self?.showNotch() },
            readHealth: { [weak self] in self?.healthSnapshots ?? [] },
            readCodex: { [weak self] in self?.codexSetup },
            readClaude: { [weak self] in self?.claudeSetup },
            readMonitoring: { [weak self] in self?.providerMonitoring },
            readQuota: { [weak self] in self?.usage },
            readLocalActions: { [weak self] in self?.localActions },
            onReturnPet: { [weak self] in self?.returnPet() },
            readPetLibrary: { [weak self] in self?.petLibrary },
            onOpenSessions: { [weak self] in self?.openSessions() },
            readNavigation: { [weak self] in self?.navigation })
        if installed.contains(.pet) && !defaults.bool(forKey: "pet.setupComplete") {
            settings?.show(page: .pet, activate: false)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
            guard let self else { return }
            self.pet?.writeEvidence(phase: "launched", agentsEnabled: self.monitoringEnabled,
                                    focusBefore: self.focusBefore)
        }
    }

    func showPet() {
        guard installed.contains(.pet) else { return }
        pet?.show()
    }

    func returnPet() {
        guard installed.contains(.pet) else { return }
        pet?.returnPet()
    }

    func showNotch() {
        guard installed.contains(.notch) else { return }
        islandHiddenForPet = false
        notch?.show()
    }

    func openSessions() {
        guard installed.contains(.notch) else { return }
        islandHiddenForPet = false
        notch?.openSessions()
    }

    private func applyRuntimes(_ installed: Set<AppFeature>, monitoring: Bool) -> Set<AppFeature> {
        if runtimeMonitoring && !monitoring {
            codexSetup?.cancel()
            claudeSetup?.cancel()
        }
        runtimeMonitoring = monitoring && installed.contains(.agents)
        if installed.contains(.agents) {
            if codexSetup == nil { codexSetup = makeProviderSetup(.codex) }
            if claudeSetup == nil { claudeSetup = makeProviderSetup(.claude) }
        } else {
            codexSetup?.cancel()
            claudeSetup?.cancel()
            codexSetup = nil
            claudeSetup = nil
        }
        var active = installed
        if !monitoring { active.remove(.agents) }
        runtimes.apply(active)
        notch?.setHiddenForPet(islandHiddenForPet)
        return runtimes.unavailableFeatures
    }

    private func makeProviderSetup(_ agent: Agent) -> ProviderSetupController {
        ProviderSetupController(agent: agent, onConnected: { [weak self] in
            guard let self, self.installed.contains(.agents) else { return }
            self.providerMonitoring.setEnabled(true, for: agent)
            if self.providerMonitoring.isEnabled(agent) { self.features.setMonitoring(true) }
        }, onPaused: { [weak self] in
            self?.providerMonitoring.setEnabled(false, for: agent)
        }, onActionsConsent: { [weak self] enabled in
            self?.providerMonitoring.setActionsEnabled(enabled)
        }, onInspection: { [weak self] evidence in
            self?.agents?.recordInspection(evidence)
        })
    }

    func requestSetup(_ action: ProviderSetupAction, agent: Agent) {
        guard installed.contains(.agents) else { return }
        settings?.show(page: .agents)
        let setup = agent == .codex ? codexSetup : claudeSetup
        if action.isCheck { setup?.start(action) }
        else { setup?.requestConfirmation(action) }
    }

    func toggleProviderMonitoring(_ agent: Agent) {
        guard installed.contains(.agents) else { return }
        let resume = !(monitoringEnabled && providerMonitoring.isEnabled(agent))
        if !resume { (agent == .codex ? codexSetup : claudeSetup)?.cancel() }
        providerMonitoring.setEnabled(resume, for: agent)
        if resume, providerMonitoring.isEnabled(agent) { features.setMonitoring(true) }
    }

    func showSettings() {
        settings?.show()
    }

    func showFeatures() { settings?.show(page: .features) }

    func applicationWillTerminate(_ notification: Notification) {
        codexSetup?.cancel()
        claudeSetup?.cancel()
        let pet = self.pet
        navigation.stop()
        petLibrary.cancel()
        petReactions.stop()
        runtimes.apply([])
        pet?.writeEvidence(phase: "terminated", agentsEnabled: false, focusBefore: focusBefore)
    }
}
