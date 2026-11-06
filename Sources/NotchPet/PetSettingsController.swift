import AppKit
import Combine
import Integration
import Pet
import SwiftUI
import Usage

@MainActor
final class PetSettingsController {
    private let window: PetSettingsWindow
    private let defaults: UserDefaults
    private let features: FeatureSettingsModel
    private let onSizeChange: (Double) -> Void
    private let onShowPet: () -> Void
    private let onShowNotch: () -> Void
    private let readHealth: () -> [IntegrationHealthSnapshot]
    private let readCodex: () -> ProviderSetupController?
    private let readClaude: () -> ProviderSetupController?
    private let readMonitoring: () -> ProviderMonitoringModel?
    private let readQuota: () -> UsageStore?
    private var subscriptions: Set<AnyCancellable> = []
    private let readNavigation: () -> TerminalNavigation?
    private let onOpenSessions: () -> Void
    private let readPetLibrary: () -> PetLibraryModel?
    private let onReturnPet: () -> Void
    private let readLocalActions: () -> LocalActionController?

    init(defaults: UserDefaults, features: FeatureSettingsModel, onSizeChange: @escaping (Double) -> Void,
         onShowPet: @escaping () -> Void, onShowNotch: @escaping () -> Void,
         readHealth: @escaping () -> [IntegrationHealthSnapshot],
         readCodex: @escaping () -> ProviderSetupController? = { nil },
         readClaude: @escaping () -> ProviderSetupController? = { nil },
         readMonitoring: @escaping () -> ProviderMonitoringModel? = { nil },
         readQuota: @escaping () -> UsageStore? = { nil },
         readLocalActions: @escaping () -> LocalActionController? = { nil },
         onReturnPet: @escaping () -> Void = {},
         readPetLibrary: @escaping () -> PetLibraryModel? = { nil },
         onOpenSessions: @escaping () -> Void = {},
         readNavigation: @escaping () -> TerminalNavigation? = { nil }) {
        self.defaults = defaults
        self.features = features
        self.onSizeChange = onSizeChange
        self.onShowPet = onShowPet
        self.onShowNotch = onShowNotch
        self.readHealth = readHealth
        self.readCodex = readCodex
        self.readClaude = readClaude
        self.readMonitoring = readMonitoring
        self.readQuota = readQuota
        self.readLocalActions = readLocalActions
        self.onReturnPet = onReturnPet
        self.readPetLibrary = readPetLibrary
        self.onOpenSessions = onOpenSessions
        self.readNavigation = readNavigation
        window = PetSettingsWindow(contentRect: NSRect(x: 0, y: 0, width: 760, height: 520),
                                   styleMask: [.titled, .closable, .resizable], backing: .buffered, defer: false)
        window.contentMinSize = NSSize(width: 660, height: 480)
        window.isReleasedWhenClosed = false
        window.tabbingMode = .disallowed
        window.appearance = NSAppearance(named: .darkAqua)
        Publishers.Merge(NotificationCenter.default.publisher(for: NSApplication.didChangeScreenParametersNotification),
                         NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.didWakeNotification))
            .receive(on: DispatchQueue.main).sink { [weak self] _ in
                MainActor.assumeIsolated {
                    guard let self, self.window.isVisible else { return }
                    self.clampPlacement()
                }
            }.store(in: &subscriptions)
    }

    func show(page requested: AppSettingsPage? = nil, activate: Bool = true) {
        if !window.isVisible || requested != nil {
            let page = requested ?? AppSettingsPage(rawValue: defaults.string(forKey: "settings.selectedPane") ?? "features") ?? .features
            let actions = AppSettingsActions(resizePet: { [weak self] size in
                guard let self else { return }
                var preferences = PetPreferences(defaults: self.defaults)
                preferences.size = size
                self.onSizeChange(preferences.size)
            }, finishPetSetup: { [weak self] in
                guard let self else { return }
                self.defaults.set(true, forKey: "pet.setupComplete")
                self.close()
            }, close: { [weak self] in self?.close() }, showPet: onShowPet, showNotch: onShowNotch,
                health: readHealth, selectPage: { [weak self] raw in
                    guard let self else { return }
                    self.defaults.set(raw, forKey: "settings.selectedPane")
                    self.window.title = AppFeature(rawValue: raw)?.title ?? raw.capitalized
                }, codex: readCodex, claude: readClaude, monitoring: readMonitoring, quota: readQuota, localActions: readLocalActions, returnPet: onReturnPet, petLibrary: readPetLibrary, openSessions: onOpenSessions, navigation: readNavigation)
            window.contentView = NSHostingView(rootView: PetWindowPlayback(window: window) { [features, defaults] visible, sleeping in
                AppSettingsView(features: features, defaults: defaults, actions: actions, page: page,
                                isVisible: visible, isSleeping: sleeping)
            })
        }
        if !window.isVisible { window.center() }
        clampPlacement()
        window.orderFrontRegardless()
        if activate {
            NSApplication.shared.activate(ignoringOtherApps: true)
            window.makeKeyAndOrderFront(nil)
        }
    }

    private func clampPlacement() {
        let screens = NSScreen.screens
        let visible = window.screen.flatMap { old in screens.first(where: { $0 === old }) } ?? NSScreen.main
        guard let visible else { return }
        window.setFrame(PetPlacement.clamped(window.frame, in: visible.visibleFrame), display: true)
    }

    func close() {
        features.cancelUninstall()
        window.close()
    }
}
