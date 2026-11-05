import Integration
import Pet
import SwiftUI

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
}

struct AppSettingsView: View {
    let features: FeatureSettingsModel
    let actions: AppSettingsActions
    let isVisible: Bool
    let isSleeping: Bool
    @State private var page: AppSettingsPage
    @State private var petSize: Double
    @State private var firstUse: Bool
    @State private var showRemoval = false

    init(features: FeatureSettingsModel, defaults: UserDefaults, actions: AppSettingsActions,
         page: AppSettingsPage, isVisible: Bool, isSleeping: Bool) {
        self.features = features
        self.actions = actions
        self.isVisible = isVisible
        self.isSleeping = isSleeping
        let requestedFeature = AppFeature(rawValue: page.rawValue)
        _page = State(initialValue: requestedFeature.map { features.installed.contains($0) } == false ? .features : page)
        _petSize = State(initialValue: PetPreferences(defaults: defaults).size)
        _firstUse = State(initialValue: !defaults.bool(forKey: "pet.setupComplete"))
    }

    private var title: String {
        AppFeature(rawValue: page.rawValue)?.title ?? (page == .general ? "General" : "Features")
    }

    var body: some View {
        NavigationSplitView {
            List(selection: $page) {
                Section("Settings") {
                    Label("General", systemImage: "gearshape").tag(AppSettingsPage.general)
                    Label("Features", systemImage: "square.grid.2x2").tag(AppSettingsPage.features)
                }
                if !features.installed.isEmpty {
                    Section("Installed") {
                        ForEach(AppFeature.allCases.filter(features.installed.contains), id: \.self) { feature in
                            if let target = AppSettingsPage(rawValue: feature.rawValue) {
                                Label(feature.title, systemImage: feature.symbol).tag(target)
                            }
                        }
                    }
                }
            }
            .listStyle(.sidebar)
            .navigationSplitViewColumnWidth(min: 150, ideal: 170, max: 210)
        } detail: {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if page != .pet { Text(title).font(.title2.weight(.semibold)) }
                    if let issue = features.preferenceIssue {
                        Text(issue == .unsupportedVersion
                             ? "Your feature choices were saved by a newer version. Update Notch Pet, then retry."
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
            Text("Keep the parts of Notch Pet you use. Pet, Notch and Agents can be managed independently.")
            Button("Manage Features") { page = .features }
            Text("Settings stays available even when every optional feature is uninstalled.")
                .font(.callout).foregroundStyle(.secondary)
        case .features:
            Text("Install only what you use. Uninstalling stops a feature and keeps its preferences for later.")
                .foregroundStyle(.secondary)
            featureRows
        case .pet:
            if features.installed.contains(.pet), let presentation = PetArtwork.presentation() {
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
                Button("Show Pet", action: actions.showPet)
            } else { Text("Pet artwork is unavailable. Your saved pet preferences are unchanged.") }
        case .notch:
            Text("Inspect sessions and requests in the island without opening a separate app window.")
            Button("Show Notch", action: actions.showNotch)
            if !features.installed.contains(.agents) {
                Text("Agents is not installed. You can add it from Features when you want session monitoring.")
                    .foregroundStyle(.secondary)
            }
        case .agents:
            agentControls
        }
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

    private var agentControls: some View {
        VStack(alignment: .leading, spacing: 16) {
            LabeledContent("Monitoring") {
                // Swift 6.3.2 crashes when Binding receives the main-actor method reference directly.
                Toggle("Monitoring", isOn: Binding(get: { features.monitoringEnabled }, set: { features.setMonitoring($0) }))
                    .toggleStyle(.switch).labelsHidden()
                    .disabled(features.preferenceIssue != nil || features.operationIssue != nil)

            }
            Text("Monitoring uses agent connections you have already configured. Automatic agent setup is not available yet.")
                .font(.callout).foregroundStyle(.secondary)
            ForEach(IntegrationAgent.allCases, id: \.self) { provider in
                let evidence = actions.health().first { $0.agent == provider }
                VStack(alignment: .leading, spacing: 5) {
                    Text(provider == .codex ? "Codex" : "Claude Code").fontWeight(.medium)
                    Text(receiverSummary(evidence?.receiver))
                    Text(evidence?.lastDelivery == nil ? "Session delivery not observed" : "Session delivery observed")
                        .font(.callout).foregroundStyle(.secondary)
                    Text("Setup and version checks have not run.").font(.caption).foregroundStyle(.secondary)
                }
            }
            Text("Disabling monitoring keeps unresolved requests unconfirmed. Existing agent configuration is unchanged.")
                .font(.callout).foregroundStyle(.secondary)
        }
    }

    private func receiverSummary(_ state: IntegrationReceiverState?) -> String {
        guard features.monitoringEnabled else { return "Monitoring is off" }
        switch state {
        case .listening: return "Receiver ready for events"
        case .failed: return "Receiver unavailable. Turn monitoring off and on to retry."
        case .stopped, .notStarted, nil: return "Receiver has not started"
        }
    }
}
