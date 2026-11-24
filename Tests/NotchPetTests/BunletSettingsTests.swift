import Foundation
import Testing
@testable import NotchPet

@MainActor
struct BunletSettingsTests {
    private func settings() -> BunletSettings {
        BunletSettings(defaults: UserDefaults(suiteName: "bunlet-settings-test-\(UUID().uuidString)")!)
    }

    @Test func defaultsMatchTheShippedBehavior() {
        let settings = settings()
        #expect(settings.label(for: .toggleIsland) == "⌃I")
        #expect(settings.label(for: .collapse) == "Esc")
        #expect(settings.label(for: .allowAlways) == "⌃A")
        #expect(settings.label(for: .jump) == "⌃↩")
        #expect(settings.key(for: .switchSession) == nil)
        #expect(!settings.isShortcutOn(.switchSession))
        #expect(settings.hideWhenFullscreen && settings.hoverToOpen)
        #expect(!settings.alwaysHide && !settings.hideWhenNoSessions)
        #expect(settings.usageValue == .remaining)
        #expect(settings.sessionCleanupMinutes == 10_080)
        // Decision 0025: matches the reference island.
        #expect(settings.expandOnSessionEnd && settings.expandOnActionNeeded)
    }

    @Test func rebindingChangesLabelAndPersists() {
        let suite = "bunlet-settings-test-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        let first = BunletSettings(defaults: defaults)
        first.shortcutModifier = .option
        first.setKey(.k, for: .approve)
        first.setKey(.j, for: .switchSession)
        let second = BunletSettings(defaults: defaults)
        #expect(second.label(for: .approve) == "⌥K")
        #expect(second.label(for: .switchSession) == "⌥J")
        #expect(second.isShortcutOn(.switchSession))
        #expect(second.label(for: .collapse) == "Esc")
    }

    @Test func sharedKeysAreFlaggedAndRestoreClearsThem() {
        let settings = settings()
        settings.setKey(.y, for: .deny)
        #expect(settings.shortcutConflicts == [.approve, .deny])
        settings.setShortcut(.deny, on: false)
        #expect(settings.shortcutConflicts.isEmpty)
        settings.restoreDefaultShortcuts()
        #expect(settings.label(for: .deny) == "⌃N")
        #expect(settings.shortcutConflicts.isEmpty)
    }

    @Test func clearingAKeyDisablesItsShortcut() {
        let settings = settings()
        settings.setKey(nil, for: .jump)
        #expect(!settings.isShortcutOn(.jump))
        #expect(settings.label(for: .jump) == "Not set")
    }

    @Test func escapeIgnoresTheModifier() {
        #expect(ShortcutRules.label(.escape, modifier: .command) == "Esc")
        #expect(ShortcutRules.label(.a, modifier: .command) == "⌘A")
    }

    @Test(arguments: [(30, "30 minutes"), (60, "1 hour"), (240, "4 hours"), (1_440, "1 day"), (10_080, "7 days")])
    func cleanupLabelsReadNaturally(minutes: Int, label: String) {
        #expect(GeneralSettingsPage.cleanupLabel(minutes) == label)
    }
}
