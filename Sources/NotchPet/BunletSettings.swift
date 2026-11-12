import AppKit
import Foundation
import Observation
import ServiceManagement

/// Personal settings from decision 0021, stored in UserDefaults.
@MainActor
@Observable
final class BunletSettings {
    enum IslandDisplay: String, CaseIterable, Identifiable {
        case main, automatic
        var id: String { rawValue }
        var title: String { self == .main ? "Main display" : "Automatic (follow the active app)" }
    }

    /// Events with their own sound switch, using macOS's built-in sounds.
    enum SoundEvent: String, CaseIterable, Identifiable {
        case sessionStart, taskComplete, actionNeeded
        var id: String { rawValue }
        var title: String {
            switch self {
            case .sessionStart: "Session starts"
            case .taskComplete: "Task completes"
            case .actionNeeded: "Approval or answer needed"
            }
        }
        var systemSound: String {
            switch self {
            case .sessionStart: "Pop"
            case .taskComplete: "Glass"
            case .actionNeeded: "Funk"
            }
        }
    }

    enum Shortcut: String, CaseIterable, Identifiable {
        case toggleIsland, collapse, approve, deny, jump
        var id: String { rawValue }
        var title: String {
            switch self {
            case .toggleIsland: "Show or hide the island"
            case .collapse: "Collapse the panel"
            case .approve: "Allow once"
            case .deny: "Deny"
            case .jump: "Jump to terminal"
            }
        }
        var keys: String {
            switch self {
            case .toggleIsland: "⌃I"
            case .collapse: "Esc"
            case .approve: "⌃Y"
            case .deny: "⌃N"
            case .jump: "⌃↩"
            }
        }
        /// Only the island toggle works everywhere; the rest apply while the panel is open.
        var isGlobal: Bool { self == .toggleIsland }
    }

    static let reminderChoices = [3, 5, 10, 30]
    static let panelHeightRange: ClosedRange<Double> = 200...700
    static let petPercentRange: ClosedRange<Double> = 50...150
    /// 100% pet size in points; 50–150% stays within PetPreferences.sizeRange (64–256).
    static let petBaseSize = 128.0

    @ObservationIgnored private let defaults: UserDefaults

    var expandOnSessionEnd: Bool { didSet { defaults.set(expandOnSessionEnd, forKey: Key.expandOnSessionEnd) } }
    var expandOnActionNeeded: Bool { didSet { defaults.set(expandOnActionNeeded, forKey: Key.expandOnActionNeeded) } }
    var focusAwareSuppression: Bool { didSet { defaults.set(focusAwareSuppression, forKey: Key.focusAware) } }
    var hapticFeedback: Bool { didSet { defaults.set(hapticFeedback, forKey: Key.haptic) } }
    var collapseOnMouseLeave: Bool { didSet { defaults.set(collapseOnMouseLeave, forKey: Key.collapseOnLeave) } }
    var reminderSeconds: Int { didSet { defaults.set(reminderSeconds, forKey: Key.reminderSeconds) } }
    var panelMaxHeight: Double { didSet { defaults.set(panelMaxHeight, forKey: Key.panelMaxHeight) } }
    var islandDisplay: IslandDisplay { didSet { defaults.set(islandDisplay.rawValue, forKey: Key.islandDisplay) } }
    var showClaudeLimits: Bool { didSet { defaults.set(showClaudeLimits, forKey: Key.showClaudeLimits) } }
    var showCodexLimits: Bool { didSet { defaults.set(showCodexLimits, forKey: Key.showCodexLimits) } }
    var soundEnabled: Bool { didSet { defaults.set(soundEnabled, forKey: Key.soundEnabled) } }
    var soundVolume: Double { didSet { defaults.set(soundVolume, forKey: Key.soundVolume) } }
    private(set) var soundEvents: Set<SoundEvent>
    private(set) var enabledShortcuts: Set<Shortcut>
    private(set) var launchAtLogin = false
    private(set) var launchAtLoginIssue: String?

    init(defaults: UserDefaults) {
        self.defaults = defaults
        func bool(_ key: String, _ fallback: Bool) -> Bool {
            (defaults.object(forKey: key) as? NSNumber).map { CFGetTypeID($0) == CFBooleanGetTypeID() ? $0.boolValue : fallback } ?? fallback
        }
        expandOnSessionEnd = bool(Key.expandOnSessionEnd, false)
        expandOnActionNeeded = bool(Key.expandOnActionNeeded, true)
        focusAwareSuppression = bool(Key.focusAware, true)
        hapticFeedback = bool(Key.haptic, true)
        collapseOnMouseLeave = bool(Key.collapseOnLeave, true)
        let reminder = defaults.integer(forKey: Key.reminderSeconds)
        reminderSeconds = Self.reminderChoices.contains(reminder) ? reminder : 5
        let height = defaults.double(forKey: Key.panelMaxHeight)
        panelMaxHeight = Self.panelHeightRange.contains(height) ? height : 540
        islandDisplay = defaults.string(forKey: Key.islandDisplay).flatMap(IslandDisplay.init(rawValue:)) ?? .main
        showClaudeLimits = bool(Key.showClaudeLimits, true)
        showCodexLimits = bool(Key.showCodexLimits, true)
        soundEnabled = bool(Key.soundEnabled, false)
        let volume = defaults.object(forKey: Key.soundVolume) as? Double ?? 0.7
        soundVolume = (0...1).contains(volume) ? volume : 0.7
        soundEvents = Set((defaults.stringArray(forKey: Key.soundEvents) ?? SoundEvent.allCases.map(\.rawValue))
            .compactMap(SoundEvent.init(rawValue:)))
        enabledShortcuts = Set((defaults.stringArray(forKey: Key.shortcuts) ?? Shortcut.allCases.map(\.rawValue))
            .compactMap(Shortcut.init(rawValue:)))
        refreshLaunchAtLogin()
    }

    func isSoundOn(_ event: SoundEvent) -> Bool { soundEvents.contains(event) }

    func setSound(_ event: SoundEvent, on: Bool) {
        if on { soundEvents.insert(event) } else { soundEvents.remove(event) }
        defaults.set(SoundEvent.allCases.filter(soundEvents.contains).map(\.rawValue), forKey: Key.soundEvents)
    }

    func isShortcutOn(_ shortcut: Shortcut) -> Bool { enabledShortcuts.contains(shortcut) }

    func setShortcut(_ shortcut: Shortcut, on: Bool) {
        if on { enabledShortcuts.insert(shortcut) } else { enabledShortcuts.remove(shortcut) }
        defaults.set(Shortcut.allCases.filter(enabledShortcuts.contains).map(\.rawValue), forKey: Key.shortcuts)
    }

    func restoreDefaultShortcuts() {
        enabledShortcuts = Set(Shortcut.allCases)
        defaults.removeObject(forKey: Key.shortcuts)
    }

    /// Plays the event's sound if sounds and that event are on.
    func play(_ event: SoundEvent) {
        guard soundEnabled, soundEvents.contains(event), let sound = NSSound(named: NSSound.Name(event.systemSound)) else { return }
        sound.volume = Float(soundVolume)
        sound.play()
    }

    // MARK: Launch at login

    /// The system owns this setting; Bunlet only reads and requests it.
    func refreshLaunchAtLogin() {
        launchAtLogin = SMAppService.mainApp.status == .enabled
    }

    func setLaunchAtLogin(_ on: Bool) {
        do {
            if on { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
            launchAtLoginIssue = nil
        } catch {
            launchAtLoginIssue = on
                ? "macOS did not allow Bunlet to open at login. Move Bunlet to Applications, then try again."
                : "macOS did not remove Bunlet from login items. Check System Settings → General → Login Items."
        }
        refreshLaunchAtLogin()
        if SMAppService.mainApp.status == .requiresApproval {
            launchAtLoginIssue = "Approve Bunlet in System Settings → General → Login Items."
        }
    }

    private enum Key {
        static let expandOnSessionEnd = "island.expandOnSessionEnd"
        static let expandOnActionNeeded = "island.expandOnActionNeeded"
        static let focusAware = "island.focusAwareSuppression"
        static let haptic = "island.hapticFeedback"
        static let collapseOnLeave = "island.collapseOnMouseLeave"
        static let reminderSeconds = "island.reminderSeconds"
        static let panelMaxHeight = "island.panelMaxHeight"
        static let islandDisplay = "island.display"
        static let showClaudeLimits = "island.topRow.claudeLimits"
        static let showCodexLimits = "island.topRow.codexLimits"
        static let soundEnabled = "sound.enabled"
        static let soundVolume = "sound.volume"
        static let soundEvents = "sound.events"
        static let shortcuts = "shortcuts.enabled"
    }
}
