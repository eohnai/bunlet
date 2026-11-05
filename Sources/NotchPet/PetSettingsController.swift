import AppKit
import Integration
import Pet
import SwiftUI

@MainActor
final class PetSettingsController {
    private let window: PetSettingsWindow
    private let defaults: UserDefaults
    private let features: FeatureSettingsModel
    private let onSizeChange: (Double) -> Void
    private let onShowPet: () -> Void
    private let onShowNotch: () -> Void
    private let readHealth: () -> [IntegrationHealthSnapshot]

    init(defaults: UserDefaults, features: FeatureSettingsModel, onSizeChange: @escaping (Double) -> Void,
         onShowPet: @escaping () -> Void, onShowNotch: @escaping () -> Void,
         readHealth: @escaping () -> [IntegrationHealthSnapshot]) {
        self.defaults = defaults
        self.features = features
        self.onSizeChange = onSizeChange
        self.onShowPet = onShowPet
        self.onShowNotch = onShowNotch
        self.readHealth = readHealth
        window = PetSettingsWindow(contentRect: NSRect(x: 0, y: 0, width: 760, height: 520),
                                   styleMask: [.titled, .closable, .resizable], backing: .buffered, defer: false)
        window.contentMinSize = NSSize(width: 660, height: 480)
        window.isReleasedWhenClosed = false
        window.tabbingMode = .disallowed
        window.appearance = NSAppearance(named: .darkAqua)
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
                })
            window.contentView = NSHostingView(rootView: PetWindowPlayback(window: window) { [features, defaults] visible, sleeping in
                AppSettingsView(features: features, defaults: defaults, actions: actions, page: page,
                                isVisible: visible, isSleeping: sleeping)
            })
        }
        if !window.isVisible { window.center() }
        window.orderFrontRegardless()
        if activate {
            NSApplication.shared.activate(ignoringOtherApps: true)
            window.makeKeyAndOrderFront(nil)
        }
    }

    func close() {
        features.cancelUninstall()
        window.close()
    }
}
