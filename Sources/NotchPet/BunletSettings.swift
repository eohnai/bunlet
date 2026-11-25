import AppKit
import Foundation
import Observation
import ServiceManagement
import SessionState

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
        case appLaunch, sessionStart, taskComplete, taskFailed, actionNeeded
        var id: String { rawValue }
        var title: String {
            switch self {
            case .appLaunch: "Bunlet opens"
            case .sessionStart: "Session starts"
            case .taskComplete: "Task completes"
            case .taskFailed: "Task fails"
            case .actionNeeded: "Approval or answer needed"
            }
        }
        var systemSound: String {
            switch self {
            case .appLaunch: "Blow"
            case .sessionStart: "Pop"
            case .taskComplete: "Glass"
            case .taskFailed: "Basso"
            case .actionNeeded: "Funk"
            }
        }
    }

    enum Shortcut: String, CaseIterable, Identifiable {
        case toggleIsland, collapse, approve, allowAlways, deny, jump, switchSession
        var id: String { rawValue }
        var title: String {
            switch self {
            case .toggleIsland: "Show or hide the island"
            case .collapse: "Collapse the panel"
            case .approve: "Allow once"
            case .allowAlways: "Always allow"
            case .deny: "Deny"
            case .jump: "Return to session"
            case .switchSession: "Switch session"
            }
        }
        /// The key before any change. Switch session has none until you choose one.
        var defaultKey: ShortcutKey? {
            switch self {
            case .toggleIsland: .i
            case .collapse: .escape
            case .approve: .y
            case .allowAlways: .a
            case .deny: .n
            case .jump: .returnKey
            case .switchSession: nil
            }
        }
        /// Only the island toggle works everywhere; the rest apply while the panel is open.
        var isGlobal: Bool { self == .toggleIsland }
    }

    enum UsageValue: String, CaseIterable, Identifiable {
        case remaining, used
        var id: String { rawValue }
        var title: String { self == .remaining ? "Percent left" : "Percent used" }
    }

    static let reminderChoices = [3, 5, 10, 30]
    /// Minutes an idle or ended session stays listed.
    static let sessionCleanupChoices: [Int] = [30, 60, 240, 1_440, 10_080]
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
    /// Today's Claude tokens beside the limits (decision 0025).
    var showTokenCount: Bool { didSet { defaults.set(showTokenCount, forKey: Key.showTokenCount) } }
    var soundEnabled: Bool { didSet { defaults.set(soundEnabled, forKey: Key.soundEnabled) } }
    var soundVolume: Double { didSet { defaults.set(soundVolume, forKey: Key.soundVolume) } }
    private(set) var soundEvents: Set<SoundEvent>
    /// Sessions removed from the island (decision 0030), with their receipt time at removal. Memory only.
    private(set) var removedSessions: [SessionKey: UInt64?] = [:]
    var hideWhenFullscreen: Bool { didSet { defaults.set(hideWhenFullscreen, forKey: Key.hideFullscreen) } }
    var alwaysHide: Bool { didSet { defaults.set(alwaysHide, forKey: Key.alwaysHide) } }
    var hideWhenNoSessions: Bool { didSet { defaults.set(hideWhenNoSessions, forKey: Key.hideWhenNoSessions) } }
    var hoverToOpen: Bool { didSet { defaults.set(hoverToOpen, forKey: Key.hoverToOpen) } }
    var sessionCleanupMinutes: Int { didSet { defaults.set(sessionCleanupMinutes, forKey: Key.sessionCleanup) } }
    var usageValue: UsageValue { didSet { defaults.set(usageValue.rawValue, forKey: Key.usageValue) } }
    var shortcutModifier: ShortcutModifier { didSet { defaults.set(shortcutModifier.rawValue, forKey: Key.shortcutModifier) } }
    private(set) var shortcutKeys: [Shortcut: ShortcutKey?]
    private(set) var enabledShortcuts: Set<Shortcut>
    private(set) var launchAtLogin = false
    private(set) var launchAtLoginIssue: String?

    init(defaults: UserDefaults) {
        self.defaults = defaults
        func bool(_ key: String, _ fallback: Bool) -> Bool {
            (defaults.object(forKey: key) as? NSNumber).map { CFGetTypeID($0) == CFBooleanGetTypeID() ? $0.boolValue : fallback } ?? fallback
        }
        expandOnSessionEnd = bool(Key.expandOnSessionEnd, true)
        expandOnActionNeeded = bool(Key.expandOnActionNeeded, true)
        focusAwareSuppression = bool(Key.focusAware, true)
        hapticFeedback = bool(Key.haptic, true)
        collapseOnMouseLeave = bool(Key.collapseOnLeave, true)
        let reminder = defaults.integer(forKey: Key.reminderSeconds)
        reminderSeconds = Self.reminderChoices.contains(reminder) ? reminder : 5
        let height = defaults.double(forKey: Key.panelMaxHeight)
        panelMaxHeight = Self.panelHeightRange.contains(height) ? height : Double(IslandMetrics.panelMaxHeight)
        islandDisplay = defaults.string(forKey: Key.islandDisplay).flatMap(IslandDisplay.init(rawValue:)) ?? .main
        showClaudeLimits = bool(Key.showClaudeLimits, true)
        showCodexLimits = bool(Key.showCodexLimits, true)
        showTokenCount = bool(Key.showTokenCount, true)
        soundEnabled = bool(Key.soundEnabled, false)
        let volume = defaults.object(forKey: Key.soundVolume) as? Double ?? 0.7
        soundVolume = (0...1).contains(volume) ? volume : 0.7
        soundEvents = Self.loadSoundEvents(defaults)
        enabledShortcuts = Set((defaults.stringArray(forKey: Key.shortcuts) ?? Shortcut.allCases.filter { $0.defaultKey != nil }.map(\.rawValue))
            .compactMap(Shortcut.init(rawValue:)))
        hideWhenFullscreen = bool(Key.hideFullscreen, true)
        alwaysHide = bool(Key.alwaysHide, false)
        hideWhenNoSessions = bool(Key.hideWhenNoSessions, false)
        hoverToOpen = bool(Key.hoverToOpen, true)
        let cleanup = defaults.integer(forKey: Key.sessionCleanup)
        sessionCleanupMinutes = Self.sessionCleanupChoices.contains(cleanup) ? cleanup : 10_080
        usageValue = defaults.string(forKey: Key.usageValue).flatMap(UsageValue.init(rawValue:)) ?? .remaining
        shortcutModifier = defaults.string(forKey: Key.shortcutModifier).flatMap(ShortcutModifier.init(rawValue:)) ?? .control
        let stored = defaults.dictionary(forKey: Key.shortcutKeys) as? [String: String] ?? [:]
        var keys: [Shortcut: ShortcutKey?] = [:]
        for shortcut in Shortcut.allCases {
            if let raw = stored[shortcut.rawValue] {
                keys[shortcut] = raw.isEmpty ? .some(nil) : ShortcutKey(rawValue: raw).map { .some($0) } ?? .some(shortcut.defaultKey)
            } else {
                keys[shortcut] = .some(shortcut.defaultKey)
            }
        }
        shortcutKeys = keys
        refreshLaunchAtLogin()
    }

    /// Sessions the island lists: decision 0032's rules with the Sessions clean-up limit, minus rows the user removed.
    func visibleSessions(_ sessions: [SessionSnapshot], nowMs: Int64 = Int64(Date().timeIntervalSince1970 * 1_000)) -> [SessionSnapshot] {
        NotchPresentation.withoutRemoved(NotchPresentation.listed(sessions, limitMinutes: sessionCleanupMinutes, nowMs: nowMs),
                                         removed: removedSessions)
    }

    /// Hides these sessions until each reports new activity. Session tracking and pending requests are unchanged.
    /// `current` bounds the record to sessions that still exist.
    func removeFromList(_ removing: [SessionSnapshot], current: [SessionSnapshot]) {
        let existing = Set(current.map(\.key))
        var kept = removedSessions.filter { existing.contains($0.key) }
        for session in removing { kept[session.key] = .some(session.receiptMonotonicNs) }
        removedSessions = kept
    }

    func isSoundOn(_ event: SoundEvent) -> Bool { soundEvents.contains(event) }

    /// The saved list holds only the switches that are on, so an event added after it was saved would read as off.
    /// Events missing from the known list start on, as they do for a new user.
    static func loadSoundEvents(_ defaults: UserDefaults) -> Set<SoundEvent> {
        guard let saved = defaults.stringArray(forKey: Key.soundEvents) else { return Set(SoundEvent.allCases) }
        // Saved before the known list existed: every event except the one added with it was offered then.
        let known = Set(defaults.stringArray(forKey: Key.soundEventsKnown)
            ?? SoundEvent.allCases.filter { $0 != .taskFailed }.map(\.rawValue))
        let added = SoundEvent.allCases.filter { !known.contains($0.rawValue) }
        return Set(saved.compactMap(SoundEvent.init(rawValue:))).union(added)
    }

    func setSound(_ event: SoundEvent, on: Bool) {
        if on { soundEvents.insert(event) } else { soundEvents.remove(event) }
        defaults.set(SoundEvent.allCases.filter(soundEvents.contains).map(\.rawValue), forKey: Key.soundEvents)
        defaults.set(SoundEvent.allCases.map(\.rawValue), forKey: Key.soundEventsKnown)
    }

    func isShortcutOn(_ shortcut: Shortcut) -> Bool { enabledShortcuts.contains(shortcut) && key(for: shortcut) != nil }

    func key(for shortcut: Shortcut) -> ShortcutKey? { shortcutKeys[shortcut] ?? shortcut.defaultKey }

    func label(for shortcut: Shortcut) -> String {
        key(for: shortcut).map { ShortcutRules.label($0, modifier: shortcutModifier) } ?? "Not set"
    }

    /// Shortcuts that currently share a key with another enabled shortcut.
    var shortcutConflicts: Set<Shortcut> {
        ShortcutRules.conflicts(Dictionary(uniqueKeysWithValues: Shortcut.allCases.map { shortcut in
            (shortcut, isShortcutOn(shortcut) ? key(for: shortcut) : nil)
        }))
    }

    func setShortcut(_ shortcut: Shortcut, on: Bool) {
        if on { enabledShortcuts.insert(shortcut) } else { enabledShortcuts.remove(shortcut) }
        defaults.set(Shortcut.allCases.filter(enabledShortcuts.contains).map(\.rawValue), forKey: Key.shortcuts)
    }

    func setKey(_ key: ShortcutKey?, for shortcut: Shortcut) {
        shortcutKeys[shortcut] = .some(key)
        var stored = defaults.dictionary(forKey: Key.shortcutKeys) as? [String: String] ?? [:]
        stored[shortcut.rawValue] = key?.rawValue ?? ""
        defaults.set(stored, forKey: Key.shortcutKeys)
        if key != nil { setShortcut(shortcut, on: true) }
    }

    func restoreDefaultShortcuts() {
        enabledShortcuts = Set(Shortcut.allCases.filter { $0.defaultKey != nil })
        var defaultKeys: [Shortcut: ShortcutKey?] = [:]
        for shortcut in Shortcut.allCases { defaultKeys[shortcut] = .some(shortcut.defaultKey) }
        shortcutKeys = defaultKeys
        shortcutModifier = .control
        defaults.removeObject(forKey: Key.shortcuts)
        defaults.removeObject(forKey: Key.shortcutKeys)
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
        static let showTokenCount = "island.topRow.tokenCount"
        static let soundEnabled = "sound.enabled"
        static let soundVolume = "sound.volume"
        static let soundEvents = "sound.events"
        static let soundEventsKnown = "sound.events.known"
        static let shortcuts = "shortcuts.enabled"
        static let shortcutKeys = "shortcuts.keys"
        static let shortcutModifier = "shortcuts.modifier"
        static let hideFullscreen = "island.hideWhenFullscreen"
        static let alwaysHide = "island.alwaysHide"
        static let hideWhenNoSessions = "island.hideWhenNoSessions"
        static let hoverToOpen = "island.hoverToOpen"
        static let sessionCleanup = "island.sessionCleanupMinutes"
        static let usageValue = "island.usageValue"
    }
}
