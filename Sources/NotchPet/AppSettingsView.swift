import EventBridge
import Integration
import Pet
import SwiftUI
import Usage

enum AppSettingsPage: String, Hashable {
    case general, features, pet, notch, agents
}

struct AppSettingsActions {
    var resizePet: (Double) -> Void
    var finishPetSetup: () -> Void
    var close: () -> Void
    var showPet: () -> Void
    var showNotch: () -> Void
    var health: () -> [IntegrationHealthSnapshot]
    var selectPage: (String) -> Void
    var codex: () -> ProviderSetupController? = { nil }
    var claude: () -> ProviderSetupController? = { nil }
    var monitoring: () -> ProviderMonitoringModel? = { nil }
    var quota: () -> UsageStore? = { nil }
    var localActions: () -> LocalActionController? = { nil }
    var returnPet: () -> Void = {}
    var petLibrary: () -> PetLibraryModel? = { nil }
    var openSessions: () -> Void = {}
    var navigation: () -> TerminalNavigation? = { nil }
}

struct AppSettingsView: View {
    let features: FeatureSettingsModel
    let actions: AppSettingsActions
    let isVisible: Bool
    let isSleeping: Bool
    @State private var page: AppSettingsPage
    @State private var petSize: Double
    @State private var soundEnabled: Bool
    private let defaults: UserDefaults
    @State private var firstUse: Bool
    @State private var showRemoval = false

    init(features: FeatureSettingsModel, defaults: UserDefaults, actions: AppSettingsActions,
         page: AppSettingsPage, isVisible: Bool, isSleeping: Bool) {
        self.defaults = defaults
        self.features = features
        self.actions = actions
        self.isVisible = isVisible
        self.isSleeping = isSleeping
        let requestedFeature = AppFeature(rawValue: page.rawValue)
        _page = State(initialValue: requestedFeature.map { features.installed.contains($0) } == false ? .features : page)
        _soundEnabled = State(initialValue: PetPreferences(defaults: defaults).soundEnabled)
        _petSize = State(initialValue: PetPreferences(defaults: defaults).size)
        _firstUse = State(initialValue: !defaults.bool(forKey: "pet.setupComplete"))
    }

    private var title: String {
        AppFeature(rawValue: page.rawValue)?.title ?? (page == .general ? "General" : "Features")
    }

    var body: some View {
        NavigationSplitView {
            // Emoji icons, a plain first section, then a titled one.
            List(selection: $page) {
                Section {
                    navItem("General", icon: "⚙️", page: .general)
                    ForEach(AppFeature.allCases.filter(features.installed.contains), id: \.self) { feature in
                        if let target = AppSettingsPage(rawValue: feature.rawValue) {
                            navItem(feature.title, icon: feature.emoji, page: target)
                        }
                    }
                }
                Section("Bunlet") {
                    navItem("Features", icon: "🧩", page: .features)
                }
            }
            .listStyle(.sidebar)
            .navigationSplitViewColumnWidth(min: 200, ideal: 220, max: 240)
        } detail: {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // The pet page has its own "Meet your pet" heading.
                    if page != .pet { Text(title).font(.system(size: 22, weight: .bold)).padding(.bottom, -4) }
                    if let issue = features.preferenceIssue {
                        Text(issue == .unsupportedVersion
                             ? "Your feature choices were saved by a newer version. Update Bunlet, then retry."
                             : "Your saved feature choices need recovery. They have been left unchanged.")
                        Button("Retry Reading Choices") { features.start(allowStoredMonitoring: false) }
                    } else if let issue = features.operationIssue {
                        Text(issue == .monitoringWriteFailed
                             ? "Monitoring is stopped for this run, but its preference could not be saved. Retry before reopening the app."
                             : "The change could not be saved. Check your saved choices, then retry.")
                            .foregroundStyle(.red)
                        Button("Retry Reading Choices") { features.start(allowStoredMonitoring: false) }
                    }
                    content
                }
                .padding(24)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(minWidth: 440)
        }
        .frame(minWidth: 660, minHeight: 480)
        .onAppear { actions.selectPage(page.rawValue) }
        .onChange(of: page) { _, value in actions.selectPage(value.rawValue) }
        .onChange(of: features.installed) { _, selected in
            if let feature = AppFeature(rawValue: page.rawValue), !selected.contains(feature) { page = .features }
        }
        .onChange(of: features.pendingRemoval) { _, value in showRemoval = value != nil }
        .onChange(of: isVisible) { _, visible in
            if !visible {
                features.cancelUninstall()
                showRemoval = false
            }
        }
        .onExitCommand(perform: actions.close)
        .alert("Uninstall Agents?", isPresented: $showRemoval) {
            Button("Cancel", role: .cancel, action: features.cancelUninstall)
            Button("Uninstall Agents", role: .destructive, action: features.confirmUninstall)
        } message: {
            Text("Monitoring will stop. Pending requests will remain unconfirmed, and existing agent configuration will stay unchanged.")
        }
    }

    @ViewBuilder private var content: some View {
        switch page {
        case .general:
            Text("Keep the parts of Bunlet you use. Pet, Notch and Agents can be managed independently.")
            Button("Manage Features") { page = .features }
            if let navigation = actions.navigation() { TerminalNavigationView(controller: navigation) }
            Text("Settings stays available even when every optional feature is uninstalled.")
                .font(.callout).foregroundStyle(.secondary)
        case .features:
            Text("Install only what you use. Uninstalling stops a feature and keeps its preferences for later.")
                .foregroundStyle(.secondary)
            featureRows
        case .pet:
            if features.installed.contains(.pet), let presentation = actions.petLibrary()?.presentation ?? PetArtwork.presentation() {
                PetSettingsView(presentation: presentation, size: petSize, firstUse: firstUse,
                    isVisible: isVisible, isSleeping: isSleeping,
                    onSizeChange: {
                        petSize = $0
                        actions.resizePet($0)
                    },
                    onDone: {
                        firstUse = false
                        actions.finishPetSetup()
                    }, onClose: actions.close)
                    .frame(maxWidth: .infinity)
                if let library = actions.petLibrary() { PetLibraryView(library: library) }
                Toggle("Sound for a newly observed response", isOn: $soundEnabled)
                    .onChange(of: soundEnabled) { _, value in
                        var preferences = PetPreferences(defaults: defaults)
                        preferences.soundEnabled = value
                    }
                Text("A response cue does not mean the task succeeded. Sounds are off by default.")
                    .font(.caption).foregroundStyle(.secondary)
                Button("Show Pet", action: actions.showPet)
                Button("Return Pet", action: actions.returnPet)
            } else { Text("Pet artwork is unavailable. Your saved pet preferences are unchanged.") }
        case .notch:
            Text("Inspect sessions and requests in the island without opening a separate app window.")
            Button("Show Notch", action: actions.showNotch)
            Button("Open Sessions", action: actions.openSessions)
            Text("Open Sessions enables keyboard controls. Escape collapses the island and returns editing focus.")
                .font(.caption).foregroundStyle(.secondary)
            if !features.installed.contains(.agents) {
                Text("Agents is not installed. You can add it from Features when you want session monitoring.")
                    .foregroundStyle(.secondary)
            }
        case .agents:
            agentControls
        }
    }

    private func navItem(_ title: String, icon: String, page: AppSettingsPage) -> some View {
        HStack(spacing: 8) {
            Text(icon).font(.system(size: 14)).frame(width: 20).accessibilityHidden(true)
            Text(title).font(.system(size: 13))
        }
        .tag(page)
        .accessibilityLabel(title)
    }

    private var featureRows: some View {
        VStack(spacing: 0) {
            ForEach(AppFeature.allCases, id: \.self) { feature in
                HStack(alignment: .center, spacing: 12) {
                    Image(systemName: feature.symbol).font(.title3).frame(width: 28)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(feature.title).fontWeight(.medium)
                        Text(feature.purpose).font(.callout).foregroundStyle(.secondary)
                        Text(features.installed.contains(feature) ? "Installed" : "Not installed")
                            .font(.caption).foregroundStyle(.secondary)
                        if features.unavailableFeatures.contains(feature) {
                            Text("Could not start. Check this feature's settings and retry.")
                                .font(.caption).foregroundStyle(.red)
                            Button("Retry Starting Feature", action: features.retryUnavailable)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    if features.installed.contains(feature) {
                        Button("Settings") { page = AppSettingsPage(rawValue: feature.rawValue) ?? .features }
                            .accessibilityLabel("\(feature.title) settings")

                        Button("Uninstall") { features.requestUninstall(feature) }
                            .accessibilityLabel("Uninstall \(feature.title)")

                    } else {
                        Button("Install") { features.install(feature) }
                            .accessibilityLabel("Install \(feature.title)")

                    }
                }
                .padding(14)
                if feature != AppFeature.allCases.last { Divider().padding(.leading, 54) }
            }
        }
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 10))
        .disabled(features.preferenceIssue != nil || features.operationIssue != nil)
    }

    /// The agent list: one row per agent with a status dot, status word and switch.
    /// "Monitoring" is Bunlet's per-provider consent; setup and delivery evidence stay in the details below (D7).
    @ViewBuilder private var agentList: some View {
        if let monitoring = actions.monitoring() {
            VStack(spacing: 0) {
                ForEach(Agent.allCases, id: \.self) { provider in
                    let on = features.monitoringEnabled && monitoring.isEnabled(provider)
                    HStack(spacing: 10) {
                        Text(provider == .codex ? "Codex" : "Claude Code").font(.system(size: 13, weight: .medium))
                        Circle().fill(on ? Color.green : Color.gray).frame(width: 7, height: 7).accessibilityHidden(true)
                        Text(!features.monitoringEnabled ? "Monitoring off" : on ? "Active" : "Paused")
                            .font(.system(size: 12)).foregroundStyle(.secondary)
                        Spacer()
                        Toggle(provider == .codex ? "Codex" : "Claude Code", isOn: Binding(
                            get: { monitoring.isEnabled(provider) },
                            set: { monitoring.setEnabled($0, for: provider) }))
                            .toggleStyle(.switch).labelsHidden().controlSize(.small)
                            .disabled(!features.monitoringEnabled)
                    }
                    .padding(.vertical, 10)
                    .padding(.horizontal, 14)
                    if provider != Agent.allCases.last { Divider().padding(.leading, 14) }
                }
            }
            .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 10))
        }
    }

    private var agentControls: some View {
        VStack(alignment: .leading, spacing: 16) {
            agentList
            LabeledContent("Monitoring") {
                // Swift 6.3.2 crashes when Binding receives the main-actor method reference directly.
                Toggle("Monitoring", isOn: Binding(get: { features.monitoringEnabled }, set: { features.setMonitoring($0) }))
                    .toggleStyle(.switch).labelsHidden()
                    .disabled(features.preferenceIssue != nil || features.operationIssue != nil)

            }
            Text("Monitoring uses configured agent connections. Setup, trust and observed session delivery are separate.")
                .font(.callout).foregroundStyle(.secondary)
            ForEach(Agent.allCases, id: \.self) { provider in
                let setup = provider == .codex ? actions.codex() : actions.claude()
                if let setup, let monitoring = actions.monitoring() {
                    ProviderSetupView(controller: setup, features: features,
                        health: actions.health().first { $0.agent == provider },
                        monitoring: monitoring, quota: actions.quota(), localActions: actions.localActions(),
                        showFeatures: { page = .features }, showNotch: actions.showNotch)
                } else {
                    Text(provider == .codex ? "Codex setup unavailable" : "Claude Code setup unavailable")
                        .foregroundStyle(.secondary)
                }
                if provider != Agent.allCases.last { Divider() }
            }
            Text("Disabling monitoring keeps unresolved requests unconfirmed. Existing agent configuration is unchanged.")
                .font(.callout).foregroundStyle(.secondary)
        }
    }

}
