import Pet
import SwiftUI

/// Display: where the island sits, what it shows on top, and the desktop pet.
struct DisplaySettingsPage: View {
    @Bindable var settings: BunletSettings
    let actions: AppSettingsActions
    @State private var petPercent: Double
    @State private var customizing = false

    init(settings: BunletSettings, defaults: UserDefaults, actions: AppSettingsActions) {
        self.settings = settings
        self.actions = actions
        let percent = PetPreferences(defaults: defaults).size / BunletSettings.petBaseSize * 100
        _petPercent = State(initialValue: min(max(percent, BunletSettings.petPercentRange.lowerBound),
                                              BunletSettings.petPercentRange.upperBound))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            SettingsGroup(title: "Island Location") {
                SettingsMenuRow(title: "Display preference", last: true, width: 260, selection: $settings.islandDisplay,
                                options: BunletSettings.IslandDisplay.allCases.map { ($0.title, $0) })
            }
            SettingsFootnote(settings.islandDisplay == .main
                             ? "The island stays on the main display, where the menu bar is."
                             : "The island moves to the screen of the app you are using.")
            SettingsGroup(title: "Top Info Items") {
                SettingsToggleRow(title: "Claude Code usage limits", isOn: $settings.showClaudeLimits)
                SettingsToggleRow(title: "Codex usage limits", isOn: $settings.showCodexLimits)
                SettingsMenuRow(title: "Usage shown as", subtitle: "Colors always follow the percent left.",
                                last: true, width: 160, selection: $settings.usageValue,
                                options: BunletSettings.UsageValue.allCases.map { ($0.title, $0) })
            }
            pet
        }
    }

    private var pet: some View {
        SettingsGroup(title: "Desktop Pet") {
            SettingsSliderRow(title: "Pet size", subtitle: "50–150%", value: $petPercent,
                              range: BunletSettings.petPercentRange, step: 5, valueText: "\(Int(petPercent))%")
                .onChange(of: petPercent) { _, value in actions.resizePet(value / 100 * BunletSettings.petBaseSize) }
            SettingsRow(title: "Pet mode",
                        subtitle: "Drag the island pill down to take the pet out. Drop it on the island to put it back.",
                        last: actions.petLibrary() == nil) {
                HStack {
                    Button("Show Pet", action: actions.showPet)
                    Button("Return Pet", action: actions.returnPet)
                }
            }
            if let library = actions.petLibrary() {
                SettingsBlock(last: true) {
                    DisclosureGroup(isExpanded: $customizing) {
                        PetLibraryView(library: library).padding(.top, 8)
                    } label: {
                        Text("Customize pet").font(.system(size: 14)).foregroundStyle(.white)
                    }
                }
            }
        }
    }
}
