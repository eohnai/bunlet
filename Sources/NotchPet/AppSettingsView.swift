import EventBridge
import Integration
import Pet
import SwiftUI
import Usage

/// Settings pages from decision 0021. Raw values are saved as the last selected page.
enum AppSettingsPage: String, Hashable, CaseIterable {
    case general, agents, display, sound, shortcuts, about

    var title: String {
        switch self {
        case .general: "General"
        case .agents: "Agents"
        case .display: "Display"
        case .sound: "Sound"
        case .shortcuts: "Shortcuts"
        case .about: "About"
        }
    }

    var icon: String {
        switch self {
        case .general: "⚙️"
        case .agents: "🤖"
        case .display: "🖥️"
        case .sound: "🔊"
        case .shortcuts: "⌨️"
        case .about: "ℹ️"
        }
    }
}

struct AppSettingsActions {
    var resizePet: (Double) -> Void
    var close: () -> Void
    var showPet: () -> Void
    var returnPet: () -> Void
    var showNotch: () -> Void
    var openSessions: () -> Void
    var health: () -> [IntegrationHealthSnapshot]
    var selectPage: (AppSettingsPage) -> Void
    var removeAllHooks: () -> Void
    var codex: () -> ProviderSetupController? = { nil }
    var claude: () -> ProviderSetupController? = { nil }
    var monitoring: () -> ProviderMonitoringModel? = { nil }
    var quota: () -> UsageStore? = { nil }
    var localActions: () -> LocalActionController? = { nil }
    var petLibrary: () -> PetLibraryModel? = { nil }
    var navigation: () -> TerminalNavigation? = { nil }
}

/// Settings window colors (decision 0017).
enum SettingsStyle {
    static let sidebar = Color(red: 40 / 255, green: 40 / 255, blue: 44 / 255).opacity(0.95)
    static let content = Color(red: 0x1E / 255, green: 0x1E / 255, blue: 0x22 / 255)
    static let card = Color(red: 0x2C / 255, green: 0x2C / 255, blue: 0x31 / 255)
    static let divider = Color.white.opacity(0.08)
    static let heading = Color.white.opacity(0.55)
    static let subtitle = Color.white.opacity(0.5)
    static let sectionHeader = Color.white.opacity(0.4)
}

struct AppSettingsView: View {
    let features: FeatureSettingsModel
    let settings: BunletSettings
    let defaults: UserDefaults
    let actions: AppSettingsActions
    let isVisible: Bool
    let isSleeping: Bool
    @State private var page: AppSettingsPage

    init(features: FeatureSettingsModel, settings: BunletSettings, defaults: UserDefaults, actions: AppSettingsActions,
         page: AppSettingsPage, isVisible: Bool, isSleeping: Bool) {
        self.features = features
        self.settings = settings
        self.defaults = defaults
        self.actions = actions
        self.isVisible = isVisible
        self.isSleeping = isSleeping
        _page = State(initialValue: page)
    }

    var body: some View {
        HStack(spacing: 0) {
            sidebar
            Rectangle().fill(Color.white.opacity(0.1)).frame(width: 1)
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    Text(page.title)
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(.white.opacity(0.85))
                    if !features.unavailableFeatures.isEmpty {
                        SettingsGroup {
                            SettingsRow(title: "Part of Bunlet could not start",
                                        subtitle: "Retry, or quit and reopen Bunlet.", last: true) {
                                Button("Retry", action: features.retryUnavailable)
                            }
                        }
                    }
                    content
                }
                .padding(.horizontal, 32)
                .padding(.top, 44)
                .padding(.bottom, 32)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(SettingsStyle.content)
        }
        .ignoresSafeArea()
        .frame(minWidth: 680, minHeight: 520)
        .preferredColorScheme(.dark)
        .onAppear { actions.selectPage(page) }
        .onChange(of: page) { _, value in actions.selectPage(value) }
        .onExitCommand(perform: actions.close)
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Room for the window's traffic-light buttons.
            Color.clear.frame(height: 44)
            ForEach([AppSettingsPage.general, .agents, .display, .sound], id: \.self, content: navItem)
            sectionHeader("Advanced")
            navItem(.shortcuts)
            sectionHeader("Bunlet")
            navItem(.about)
            Spacer()
        }
        .padding(.horizontal, 10)
        .frame(width: 220)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(SettingsStyle.sidebar)
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title.uppercased())
            .font(.system(size: 11, weight: .semibold))
            .kerning(0.3)
            .foregroundStyle(SettingsStyle.sectionHeader)
            .padding(.leading, 8)
            .padding(.top, 18)
            .padding(.bottom, 2)
    }

    private func navItem(_ target: AppSettingsPage) -> some View {
        SidebarItem(page: target, selected: page == target) { page = target }
    }

    @ViewBuilder private var content: some View {
        switch page {
        case .general: GeneralSettingsPage(settings: settings, actions: actions)
        case .agents: AgentsSettingsPage(features: features, actions: actions)
        case .display: DisplaySettingsPage(settings: settings, defaults: defaults, actions: actions)
        case .sound: SoundSettingsPage(settings: settings)
        case .shortcuts: ShortcutsSettingsPage(settings: settings)
        case .about: AboutSettingsPage()
        }
    }
}

private struct SidebarItem: View {
    let page: AppSettingsPage
    let selected: Bool
    let select: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: select) {
            HStack(spacing: 10) {
                Text(page.icon).font(.system(size: 15)).frame(width: 22).accessibilityHidden(true)
                Text(page.title).font(.system(size: 14)).foregroundStyle(selected ? .white : .white.opacity(0.85))
                Spacer()
            }
            .padding(.horizontal, 10)
            .frame(height: 34)
            .background(selected ? Color.accentColor : (hovering ? Color.white.opacity(0.08) : .clear),
                        in: RoundedRectangle(cornerRadius: 8))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .accessibilityLabel(page.title)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

// MARK: - Building blocks

/// A gray heading over a rounded card of rows.
struct SettingsGroup<Content: View>: View {
    var title: String?
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let title {
                Text(title).font(.system(size: 15, weight: .semibold)).foregroundStyle(SettingsStyle.heading)
            }
            VStack(spacing: 0) { content }
                .background(SettingsStyle.card, in: RoundedRectangle(cornerRadius: 12))
        }
    }
}

/// A title, optional gray subtitle and trailing control, with an inset divider below unless it is the last row.
struct SettingsRow<Trailing: View>: View {
    let title: String
    var subtitle: String?
    var last = false
    @ViewBuilder let trailing: Trailing

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center, spacing: 16) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(title).font(.system(size: 14)).foregroundStyle(.white)
                    if let subtitle {
                        Text(subtitle).font(.system(size: 12)).foregroundStyle(SettingsStyle.subtitle)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                trailing
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            if !last { Rectangle().fill(SettingsStyle.divider).frame(height: 1).padding(.horizontal, 16) }
        }
    }
}

/// A switch row bound to a setting.
struct SettingsToggleRow: View {
    let title: String
    var subtitle: String?
    var last = false
    let isOn: Binding<Bool>

    var body: some View {
        SettingsRow(title: title, subtitle: subtitle, last: last) {
            Toggle(title, isOn: isOn).toggleStyle(.switch).labelsHidden()
        }
    }
}

/// Free-form content inside a card, padded like a row.
struct SettingsBlock<Content: View>: View {
    var last = false
    @ViewBuilder let content: Content

    var body: some View {
        VStack(spacing: 0) {
            content
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
            if !last { Rectangle().fill(SettingsStyle.divider).frame(height: 1).padding(.horizontal, 16) }
        }
    }
}

// MARK: - General

private struct GeneralSettingsPage: View {
    @Bindable var settings: BunletSettings
    let actions: AppSettingsActions
    @State private var confirmRemoval = false

    var body: some View {
        VStack(alignment: .leading, spacing: 28) {
            SettingsGroup(title: "System") {
                SettingsRow(title: "Launch at login", subtitle: settings.launchAtLoginIssue, last: true) {
                    Toggle("Launch at login", isOn: Binding(get: { settings.launchAtLogin },
                                                            set: { settings.setLaunchAtLogin($0) }))
                        .toggleStyle(.switch).labelsHidden()
                }
            }
            behavior
            SettingsGroup(title: "Panel") {
                SettingsRow(title: "Maximum panel height",
                            subtitle: "How tall the open panel may grow (200–700 points)", last: true) {
                    HStack(spacing: 12) {
                        Slider(value: $settings.panelMaxHeight, in: BunletSettings.panelHeightRange, step: 20)
                            .frame(width: 180)
                        Text("\(Int(settings.panelMaxHeight)) pt").monospacedDigit().foregroundStyle(SettingsStyle.subtitle)
                            .frame(width: 54, alignment: .trailing)
                    }
                }
            }
            if let navigation = actions.navigation() {
                SettingsGroup(title: "Terminal") {
                    SettingsBlock(last: true) { TerminalNavigationView(controller: navigation) }
                }
            }
            SettingsGroup(title: "Hooks") {
                SettingsRow(title: "Remove all hook configuration",
                            subtitle: "Remove the hooks Bunlet added to Claude Code and Codex. Other hooks are kept.",
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
            Text("Session tracking stops until you connect again. Pending requests stay unconfirmed, and other tools' hooks are unchanged.")
        }
    }

    private var behavior: some View {
        SettingsGroup(title: "Behavior") {
            SettingsToggleRow(title: "Expand panel when a session ends",
                              subtitle: "Auto-expand the panel to show results when a task completes",
                              isOn: $settings.expandOnSessionEnd)
            SettingsToggleRow(title: "Expand when action is needed",
                              subtitle: "Auto-expand the panel when an agent needs your response",
                              isOn: $settings.expandOnActionNeeded)
            SettingsToggleRow(title: "Focus-aware suppression",
                              subtitle: "Don't expand automatically while your terminal app is in front",
                              isOn: $settings.focusAwareSuppression)
            SettingsToggleRow(title: "Haptic feedback",
                              subtitle: "Tap the trackpad when the pointer opens the island",
                              isOn: $settings.hapticFeedback)
            SettingsToggleRow(title: "Collapse when the pointer leaves", isOn: $settings.collapseOnMouseLeave)
            SettingsRow(title: "Reminder duration",
                        subtitle: "How long completion and attention reminders stay open. Press Esc to close early.",
                        last: true) {
                Picker("Reminder duration", selection: $settings.reminderSeconds) {
                    ForEach(BunletSettings.reminderChoices, id: \.self) { Text("\($0) seconds").tag($0) }
                }
                .labelsHidden()
                .frame(width: 140)
            }
        }
    }
}

// MARK: - Agents

private struct AgentsSettingsPage: View {
    let features: FeatureSettingsModel
    let actions: AppSettingsActions
    @State private var confirmConnect: Agent?
    @State private var expanded: Set<Agent> = []

    var body: some View {
        VStack(alignment: .leading, spacing: 28) {
            SettingsGroup(title: "CLI Hooks") {
                ForEach(Agent.allCases, id: \.self) { agent in
                    if let setup = controller(agent), let monitoring = actions.monitoring() {
                        AgentRow(setup: setup, monitoring: monitoring, last: agent == Agent.allCases.last) {
                            confirmConnect = agent
                        }
                    }
                }
            }
            Text("Connecting adds Bunlet's hooks to the agent's settings and keeps every other hook. Sessions started before connecting are not tracked until they restart. Turning a switch off pauses tracking without removing hooks.")
                .font(.system(size: 12)).foregroundStyle(SettingsStyle.subtitle)
                .fixedSize(horizontal: false, vertical: true)
            ForEach(Agent.allCases, id: \.self) { agent in
                if let setup = controller(agent), let monitoring = actions.monitoring() {
                    details(agent, setup: setup, monitoring: monitoring)
                }
            }
        }
        .onAppear {
            // A read-only check, so the rows can say whether each agent is connected.
            for agent in Agent.allCases where controller(agent)?.inspection == nil { controller(agent)?.start(.check) }
        }
        .alert(connectTitle, isPresented: Binding(get: { confirmConnect != nil }, set: { if !$0 { confirmConnect = nil } })) {
            Button("Cancel", role: .cancel) {}
            Button("Connect") {
                if let agent = confirmConnect { controller(agent)?.start(.connect) }
            }
        } message: {
            Text("Bunlet adds its own hooks to this agent's settings so it can track sessions. Existing hooks stay unchanged. Codex may ask you to review the new hook.")
        }
    }

    private var connectTitle: String {
        "Connect \(confirmConnect == .codex ? "Codex" : "Claude Code")?"
    }

    private func details(_ agent: Agent, setup: ProviderSetupController, monitoring: ProviderMonitoringModel) -> some View {
        SettingsGroup(title: "\(setup.providerName) details") {
            SettingsBlock(last: true) {
                DisclosureGroup(isExpanded: Binding(get: { expanded.contains(agent) }, set: { open in
                    if open { expanded.insert(agent) } else { expanded.remove(agent) }
                })) {
                    ProviderSetupView(controller: setup, features: features,
                                      health: actions.health().first { $0.agent == agent },
                                      monitoring: monitoring, quota: actions.quota(),
                                      localActions: actions.localActions(),
                                      showFeatures: {}, showNotch: actions.showNotch)
                        .padding(.top, 8)
                } label: {
                    Text("Setup, repair, usage limits and replies").font(.system(size: 13))
                }
            }
        }
    }

    private func controller(_ agent: Agent) -> ProviderSetupController? {
        agent == .codex ? actions.codex() : actions.claude()
    }
}

/// One agent: name, status dot and word, switch.
private struct AgentRow: View {
    let setup: ProviderSetupController
    let monitoring: ProviderMonitoringModel
    let last: Bool
    let requestConnect: () -> Void

    private var connected: Bool {
        if case .owned = setup.inspection?.ownership { return true }
        return false
    }

    private var status: (word: String, color: Color) {
        if setup.operation != nil { return ("Working…", .gray) }
        guard let inspection = setup.inspection else { return ("Checking…", .gray) }
        if connected { return monitoring.isEnabled(setup.agent) ? ("Active", .green) : ("Paused", .yellow) }
        if inspection.installationUnavailable == .executableNotFound { return ("Not found", .orange) }
        return ("Not connected", .gray)
    }

    var body: some View {
        let status = status
        VStack(alignment: .leading, spacing: 0) {
            SettingsRow(title: setup.providerName, last: last) {
                HStack(spacing: 8) {
                    Circle().fill(status.color).frame(width: 8, height: 8).accessibilityHidden(true)
                    Text(status.word).font(.system(size: 13))
                        .foregroundStyle(status.color == .gray ? SettingsStyle.subtitle : status.color)
                }
                Toggle(setup.providerName, isOn: Binding(
                    get: { connected && monitoring.isEnabled(setup.agent) },
                    set: { on in
                        if !on {
                            monitoring.setEnabled(false, for: setup.agent)
                        } else if connected {
                            monitoring.setEnabled(true, for: setup.agent)
                        } else {
                            requestConnect()
                        }
                    }))
                    .toggleStyle(.switch).labelsHidden()
                    .disabled(setup.operation != nil)
            }
            Text(setup.message)
                .font(.system(size: 12))
                .foregroundStyle(SettingsStyle.subtitle)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
        }
        .accessibilityElement(children: .combine)
        .accessibilityValue(status.word)
    }
}

// MARK: - Display

private struct DisplaySettingsPage: View {
    @Bindable var settings: BunletSettings
    let actions: AppSettingsActions
    @State private var petPercent: Double

    init(settings: BunletSettings, defaults: UserDefaults, actions: AppSettingsActions) {
        self.settings = settings
        self.actions = actions
        let percent = PetPreferences(defaults: defaults).size / BunletSettings.petBaseSize * 100
        _petPercent = State(initialValue: min(max(percent, BunletSettings.petPercentRange.lowerBound),
                                              BunletSettings.petPercentRange.upperBound))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 28) {
            SettingsGroup(title: "Island Location") {
                SettingsRow(title: "Display preference") {
                    Picker("Display preference", selection: $settings.islandDisplay) {
                        ForEach(BunletSettings.IslandDisplay.allCases) { Text($0.title).tag($0) }
                    }
                    .labelsHidden()
                    .frame(width: 260)
                }
                SettingsBlock(last: true) {
                    Text(settings.islandDisplay == .main
                         ? "The island stays on the main display (where the menu bar is)."
                         : "The island moves to the screen of the app you are using.")
                        .font(.system(size: 12)).foregroundStyle(SettingsStyle.subtitle)
                }
            }
            pet
            SettingsGroup(title: "Top Info Items") {
                SettingsToggleRow(title: "Claude Code usage limits", isOn: $settings.showClaudeLimits)
                SettingsToggleRow(title: "Codex usage limits", last: true, isOn: $settings.showCodexLimits)
            }
        }
    }

    private var pet: some View {
        SettingsGroup(title: "Desktop Pet") {
            SettingsRow(title: "Pet size", subtitle: "Adjust the pet's display size (50–150%)") {
                HStack(spacing: 12) {
                    Slider(value: $petPercent, in: BunletSettings.petPercentRange, step: 5).frame(width: 180)
                        .onChange(of: petPercent) { _, value in actions.resizePet(value / 100 * BunletSettings.petBaseSize) }
                    Text("\(Int(petPercent))%").monospacedDigit().foregroundStyle(SettingsStyle.subtitle)
                        .frame(width: 44, alignment: .trailing)
                }
            }
            SettingsRow(title: "Pet mode",
                        subtitle: "Drag the island pill down to take the pet out; drop it on the island to put it back.",
                        last: actions.petLibrary() == nil) {
                HStack {
                    Button("Show Pet", action: actions.showPet)
                    Button("Return Pet", action: actions.returnPet)
                }
            }
            if let library = actions.petLibrary() {
                SettingsBlock(last: true) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Desktop pet customization").font(.system(size: 14)).foregroundStyle(.white)
                        PetLibraryView(library: library)
                    }
                }
            }
        }
    }
}

// MARK: - Sound

private struct SoundSettingsPage: View {
    @Bindable var settings: BunletSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 28) {
            SettingsGroup(title: "Sound") {
                SettingsToggleRow(title: "Enable sounds", subtitle: "A sound does not mean the task succeeded.",
                                  isOn: $settings.soundEnabled)
                SettingsRow(title: "Volume", last: true) {
                    HStack(spacing: 12) {
                        Slider(value: $settings.soundVolume, in: 0...1).frame(width: 180)
                        Text("\(Int(settings.soundVolume * 100))%").monospacedDigit().foregroundStyle(SettingsStyle.subtitle)
                            .frame(width: 44, alignment: .trailing)
                    }
                }
            }
            SettingsGroup(title: "Events") {
                ForEach(BunletSettings.SoundEvent.allCases) { event in
                    eventRow(event)
                }
            }
            .disabled(!settings.soundEnabled)
            .opacity(settings.soundEnabled ? 1 : 0.5)
        }
    }

    private func eventRow(_ event: BunletSettings.SoundEvent) -> some View {
        SettingsRow(title: event.title, last: event == BunletSettings.SoundEvent.allCases.last) {
            Button {
                let sound = NSSound(named: NSSound.Name(event.systemSound))
                sound?.volume = Float(settings.soundVolume)
                sound?.play()
            } label: {
                Image(systemName: "play.circle")
            }
            .buttonStyle(.plain)
            .foregroundStyle(SettingsStyle.subtitle)
            .accessibilityLabel("Preview \(event.title)")
            Toggle(event.title, isOn: Binding(get: { settings.isSoundOn(event) },
                                              set: { settings.setSound(event, on: $0) }))
                .toggleStyle(.switch).labelsHidden()
        }
    }
}

// MARK: - Shortcuts

private struct ShortcutsSettingsPage: View {
    let settings: BunletSettings

    var body: some View {
        let panel = BunletSettings.Shortcut.allCases.filter { !$0.isGlobal }
        VStack(alignment: .leading, spacing: 28) {
            SettingsGroup(title: "Global") {
                ForEach(BunletSettings.Shortcut.allCases.filter(\.isGlobal)) { row($0, last: true) }
            }
            SettingsGroup(title: "While the panel is open") {
                ForEach(panel) { row($0, last: $0 == panel.last) }
            }
            HStack(alignment: .top) {
                Text("Panel shortcuts only work while the island is open, so they don't override other apps the rest of the time.")
                    .font(.system(size: 12)).foregroundStyle(SettingsStyle.subtitle)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer()
                Button("Restore Defaults", action: settings.restoreDefaultShortcuts)
            }
        }
    }

    private func row(_ shortcut: BunletSettings.Shortcut, last: Bool) -> some View {
        SettingsRow(title: shortcut.title, last: last) {
            Text(shortcut.keys)
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(.white.opacity(0.85))
                .padding(.horizontal, 8).padding(.vertical, 3)
                .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 5))
            Toggle(shortcut.title, isOn: Binding(get: { settings.isShortcutOn(shortcut) },
                                                 set: { settings.setShortcut(shortcut, on: $0) }))
                .toggleStyle(.switch).labelsHidden()
        }
    }
}

// MARK: - About

private struct AboutSettingsPage: View {
    private var version: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "Development build"
        let build = info?["CFBundleVersion"] as? String
        return build.map { "\(short) (\($0))" } ?? short
    }

    var body: some View {
        SettingsGroup {
            SettingsRow(title: "Bunlet", subtitle: "A notch companion for your coding agents") {
                Text(version).font(.system(size: 13)).foregroundStyle(SettingsStyle.subtitle).textSelection(.enabled)
            }
            SettingsBlock(last: true) {
                Text("Settings are stored on this Mac. Bunlet does not send session content anywhere.")
                    .font(.system(size: 12)).foregroundStyle(SettingsStyle.subtitle)
            }
        }
    }
}
