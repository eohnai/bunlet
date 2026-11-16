import SwiftUI

/// Shortcuts: one shared modifier, a key per shortcut, and a warning when two enabled shortcuts share a key.
struct ShortcutsSettingsPage: View {
    @Bindable var settings: BunletSettings

    var body: some View {
        let panel = BunletSettings.Shortcut.allCases.filter { !$0.isGlobal }
        VStack(alignment: .leading, spacing: 24) {
            SettingsGroup(title: "Modifier") {
                SettingsMenuRow(title: "Modifier key", subtitle: "Used by every shortcut except Esc",
                                last: true, width: 160, selection: $settings.shortcutModifier,
                                options: ShortcutModifier.allCases.map { ($0.title, $0) })
            }
            SettingsGroup(title: "Global") {
                ForEach(BunletSettings.Shortcut.allCases.filter(\.isGlobal)) { row($0, last: true) }
            }
            SettingsGroup(title: "While the panel is open") {
                ForEach(panel) { row($0, last: $0 == panel.last) }
            }
            HStack(alignment: .top) {
                SettingsFootnote("Panel shortcuts only work while the island is open, so they never override other apps the rest of the time. Always allow appears only when Claude Code offers it for a request.")
                Spacer()
                Button("Restore Defaults", action: settings.restoreDefaultShortcuts)
            }
        }
    }

    private func row(_ shortcut: BunletSettings.Shortcut, last: Bool) -> some View {
        let conflict = settings.shortcutConflicts.contains(shortcut)
        return SettingsRow(title: shortcut.title, subtitle: conflict ? "Another shortcut uses this key, so neither works." : nil,
                           last: last) {
            Text(settings.label(for: shortcut))
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(conflict ? .orange : .white.opacity(0.85))
                .padding(.horizontal, 8).padding(.vertical, 3)
                .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 5))
            Picker("Key for \(shortcut.title)", selection: Binding(get: { settings.key(for: shortcut) },
                                                                      set: { settings.setKey($0, for: shortcut) })) {
                Text("None").tag(ShortcutKey?.none)
                ForEach(ShortcutKey.allCases) { Text($0.title).tag(ShortcutKey?.some($0)) }
            }
            .labelsHidden()
            .frame(width: 90)
            Toggle(shortcut.title, isOn: Binding(get: { settings.isShortcutOn(shortcut) },
                                                 set: { settings.setShortcut(shortcut, on: $0) }))
                .toggleStyle(.switch).labelsHidden()
        }
    }
}
