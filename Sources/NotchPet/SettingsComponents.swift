import SwiftUI

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

/// A gray heading over a rounded card of rows.
struct SettingsGroup<Content: View>: View {
    var title: String?
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
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
            .padding(.vertical, 10)
            .frame(minHeight: 48)
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

/// A row with a pop-up menu on the right.
struct SettingsMenuRow<Value: Hashable>: View {
    let title: String
    var subtitle: String?
    var last = false
    var width: CGFloat = 200
    @Binding var selection: Value
    let options: [(label: String, value: Value)]

    var body: some View {
        SettingsRow(title: title, subtitle: subtitle, last: last) {
            Picker(title, selection: $selection) {
                ForEach(options, id: \.value) { Text($0.label).tag($0.value) }
            }
            .labelsHidden()
            .frame(width: width)
        }
    }
}

/// A row with a slider and its value on the right.
struct SettingsSliderRow: View {
    let title: String
    var subtitle: String?
    var last = false
    @Binding var value: Double
    let range: ClosedRange<Double>
    var step: Double = 1
    let valueText: String

    var body: some View {
        SettingsRow(title: title, subtitle: subtitle, last: last) {
            HStack(spacing: 12) {
                Slider(value: $value, in: range, step: step).frame(width: 180)
                Text(valueText).monospacedDigit().foregroundStyle(SettingsStyle.subtitle)
                    .frame(width: 54, alignment: .trailing)
            }
        }
    }
}

/// Small gray explanation under a group.
struct SettingsFootnote: View {
    let text: String

    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text)
            .font(.system(size: 12))
            .foregroundStyle(SettingsStyle.subtitle)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 4)
    }
}
