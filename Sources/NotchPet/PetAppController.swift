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
            let panel = PetPanelController(size: PetPreferences(defaults: self.defaults).size)
            self.pet = panel
            return panel
        },
        .notch: { [weak self] in
            guard let self else { return nil }
            let panel = NotchPanelController(sessionStore: self.sessions, usageStore: self.usage,
                features: self.features, onOpenFeatures: { [weak self] in self?.showFeatures() })
            self.notch = panel
            return panel
        },
        .agents: { [weak self] in
            guard let self else { return nil }
            let service = AgentServices(sessionStore: self.sessions, usageStore: self.usage)
            self.agents = service
            return service
        }
    ])
    private var focusBefore: pid_t = -1

    func applicationDidFinishLaunching(_ notification: Notification) {
        focusBefore = NSWorkspace.shared.frontmostApplication?.processIdentifier ?? -1
        features.start()
        settings = PetSettingsController(defaults: defaults, features: features, onSizeChange: { [weak self] size in
            self?.pet?.setSize(size)
        }, onShowPet: { [weak self] in self?.showPet() }, onShowNotch: { [weak self] in self?.showNotch() },
            readHealth: { [weak self] in self?.healthSnapshots ?? [] })
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

    func showNotch() {
        guard installed.contains(.notch) else { return }
        notch?.show()
    }

    private func applyRuntimes(_ installed: Set<AppFeature>, monitoring: Bool) -> Set<AppFeature> {
        var active = installed
        if !monitoring { active.remove(.agents) }
        runtimes.apply(active)
        return runtimes.unavailableFeatures
    }

    func showSettings() {
        settings?.show()
    }

    func showFeatures() { settings?.show(page: .features) }

    func applicationWillTerminate(_ notification: Notification) {
        let pet = self.pet
        runtimes.apply([])
        pet?.writeEvidence(phase: "terminated", agentsEnabled: false, focusBefore: focusBefore)
    }
}
