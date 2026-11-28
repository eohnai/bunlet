import SwiftUI

/// General: System, Behavior, Visibility, Sessions, Terminal and hook removal.
struct GeneralSettingsPage: View {
    @Bindable var settings: BunletSettings
    let actions: AppSettingsActions
    @State private var confirmRemoval = false

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            SettingsGroup(title: "System") {
                SettingsRow(title: "Launch at login", subtitle: settings.launchAtLoginIssue, last: true) {
                    Toggle("Launch at login", isOn: Binding(get: { settings.launchAtLogin },
                                                            set: { settings.setLaunchAtLogin($0) }))
                        .toggleStyle(.switch).labelsHidden()
                }
            }
            behavior
            visibility
            sessions
            if let navigation = actions.navigation() {
                SettingsGroup(title: "Terminal") {
                    SettingsBlock(last: true) { TerminalNavigationView(controller: navigation) }
                }
            }
            SettingsGroup(title: "Hooks") {
                SettingsRow(title: "Remove all hook configuration",
                            subtitle: "Removes the hooks Bunlet added to Claude Code and Codex. Other hooks are kept.",
                            last: true) {
                    Button("Remove…", role: .destructive) { confirmRemoval = true }
                }
            }
        }
        .onAppear { settings.refreshLaunchAtLogin() }
        .alert("Remove Bunlet's hooks?", isPresented: $confirmRemoval) {
            Button("Cancel", role: .cancel) {}
            Button("Remove", role: .destructive, action: actions.removeAllHooks)
        } message: {
            Text("Session tracking stops until you connect again. Tracked sessions leave the list, and other tools' hooks are unchanged.")
        }
    }

    private var behavior: some View {
        SettingsGroup(title: "Behavior") {
            SettingsToggleRow(title: "Expand when a session ends",
                              subtitle: "Open the panel to show the result when a task completes",
                              isOn: $settings.expandOnSessionEnd)
            SettingsToggleRow(title: "Expand when action is needed",
                              subtitle: "Open the panel when an agent needs your response",
                              isOn: $settings.expandOnActionNeeded)
            SettingsToggleRow(title: "Focus-aware suppression",
                              subtitle: "Don't expand on its own while your terminal app is in front",
                              isOn: $settings.focusAwareSuppression)
            SettingsToggleRow(title: "Open on hover",
                              subtitle: "Open the island when the pointer rests on it. Click still works when off.",
                              isOn: $settings.hoverToOpen)
            SettingsToggleRow(title: "Haptic feedback",
                              subtitle: "Tap the trackpad when the pointer opens the island",
                              isOn: $settings.hapticFeedback)
            SettingsToggleRow(title: "Collapse when the pointer leaves", isOn: $settings.collapseOnMouseLeave)
            SettingsMenuRow(title: "Reminder duration",
                            subtitle: "How long completion and attention reminders stay open. Esc closes early.",
                            last: true, width: 140, selection: $settings.reminderSeconds,
                            options: BunletSettings.reminderChoices.map { ("\($0) seconds", $0) })
        }
    }

    private var visibility: some View {
        SettingsGroup(title: "Visibility") {
            SettingsToggleRow(title: "Always hidden",
                              subtitle: "Keep the island off screen. Shortcuts and the menu bar still open it.",
                              isOn: $settings.alwaysHide)
            SettingsToggleRow(title: "Hide in fullscreen",
                              subtitle: "Hide the island while an app is fullscreen on the same display",
                              isOn: $settings.hideWhenFullscreen)
            SettingsToggleRow(title: "Hide when no sessions",
                              subtitle: "Show the island only while a session is listed",
                              last: true, isOn: $settings.hideWhenNoSessions)
        }
    }

    private var sessions: some View {
        SettingsGroup(title: "Sessions") {
            SettingsMenuRow(title: "Clear quiet sessions after",
                            subtitle: "Sessions leave the list after this long without events, unless they are waiting for you",
                            width: 140, selection: $settings.sessionCleanupMinutes,
                            options: BunletSettings.sessionCleanupChoices.map { (Self.cleanupLabel($0), $0) })
            SettingsSliderRow(title: "Maximum panel height",
                              subtitle: "How tall the open panel may grow (200–700 points)", last: true,
                              value: $settings.panelMaxHeight, range: BunletSettings.panelHeightRange, step: 20,
                              valueText: "\(Int(settings.panelMaxHeight)) pt")
        }
    }

    static func cleanupLabel(_ minutes: Int) -> String {
        switch minutes {
        case ..<60: "\(minutes) minutes"
        case 60: "1 hour"
        case ..<1_440: "\(minutes / 60) hours"
        case 1_440: "1 day"
        default: "\(minutes / 1_440) days"
        }
    }
}
