import AppKit
import SwiftUI

/// Sound: one master switch and volume, then a switch per event.
struct SoundSettingsPage: View {
    @Bindable var settings: BunletSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            SettingsGroup(title: "Sound") {
                SettingsToggleRow(title: "Enable sounds", subtitle: "A sound does not mean the task succeeded.",
                                  isOn: $settings.soundEnabled)
                SettingsSliderRow(title: "Volume", last: true, value: $settings.soundVolume, range: 0...1,
                                  valueText: "\(Int(settings.soundVolume * 100))%")
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
