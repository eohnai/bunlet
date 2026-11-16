import Integration
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
                VStack(alignment: .leading, spacing: 24) {
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
