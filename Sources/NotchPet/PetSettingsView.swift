import Pet
import SwiftUI

struct PetSettingsView: View {
    private let presentation: PetPresentation
    @State private var size: Double
    private let firstUse: Bool
    private let isVisible: Bool
    private let isSleeping: Bool
    private let onSizeChange: (Double) -> Void
    private let onDone: () -> Void
    private let onClose: () -> Void

    init(presentation: PetPresentation, size: Double, firstUse: Bool,
         isVisible: Bool, isSleeping: Bool,
         onSizeChange: @escaping (Double) -> Void, onDone: @escaping () -> Void,
         onClose: @escaping () -> Void) {
        self.presentation = presentation
        _size = State(initialValue: size)
        self.firstUse = firstUse
        self.isVisible = isVisible
        self.isSleeping = isSleeping
        self.onSizeChange = onSizeChange
        self.onDone = onDone
        self.onClose = onClose
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 5) {
                Text(firstUse ? "Meet your pet" : "Your pet")
                    .font(.title2.weight(.semibold))
                Text(presentation.name)
                    .foregroundStyle(.secondary)
            }

            HStack {
                Spacer()
                PetView(presentation: presentation, isVisible: isVisible, isSleeping: isSleeping)
                    .frame(width: 144, height: 144)
                Spacer()
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Size")
                    Spacer()
                    Text("\(Int(size)) pt")
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
                Slider(value: $size, in: PetPreferences.sizeRange, step: 8) {
                    Text("Pet size")
                }
                .labelsHidden()
                .accessibilityValue("\(Int(size)) points")
                Text("Changes are saved automatically.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack {
                Spacer()
                Button(firstUse ? "Start" : "Done", action: onDone)
                    .keyboardShortcut(.defaultAction)
                    .controlSize(.large)
            }
        }
        .padding(24)
        .frame(width: 360, height: 400)
        .preferredColorScheme(.dark)
        .onChange(of: size) { _, newSize in onSizeChange(newSize) }
        .onExitCommand(perform: onClose)
    }
}
