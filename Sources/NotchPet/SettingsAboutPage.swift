import SwiftUI

struct AboutSettingsPage: View {
    private var version: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "Development build"
        let build = info?["CFBundleVersion"] as? String
        return build.map { "\(short) (\($0))" } ?? short
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            SettingsGroup {
                SettingsRow(title: "Bunlet", subtitle: "A notch companion for your coding agents", last: true) {
                    Text(version).font(.system(size: 13)).foregroundStyle(SettingsStyle.subtitle).textSelection(.enabled)
                }
            }
            SettingsFootnote("Settings are stored on this Mac. Bunlet does not send session content anywhere.")
        }
    }
}
