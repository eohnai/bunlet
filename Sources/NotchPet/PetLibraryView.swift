import Pet
import SwiftUI

/// The built-in rabbit is the default; choosing an image, sprite sheet or pack replaces it (decision 0020).
struct PetLibraryView: View {
    let library: PetLibraryModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Picker("Pet", selection: Binding(get: { library.selectedID }, set: { library.select($0) })) {
                Text("White lionhead rabbit (built-in)").tag("builtin")
                ForEach(library.choices) { choice in Text(choice.name).tag(choice.id) }
            }
            .frame(maxWidth: 320)
            .disabled(library.busy)
            HStack {
                Button("Choose Image…", action: library.choosePNG).disabled(library.busy)
                Button("Import Sprite Sheet…", action: library.chooseSpriteSheet).disabled(library.busy)
                Button("Import Pet Pack…", action: library.chooseImport).disabled(library.busy)
                if library.busy {
                    ProgressView().controlSize(.small)
                    Button("Cancel", action: library.cancel)
                }
            }
            Text(library.message).font(.system(size: 12)).foregroundStyle(.white.opacity(0.7)).textSelection(.enabled)
            Text("Choose Image animates a transparent PNG with gentle breathing and bobbing. A sprite sheet is a PNG with seven rows of square frames (idle, play, sleep, running, attention, complete, drag). A pet pack is a folder with manifest.json and PNG frames. Everything stays on this Mac.")
                .font(.system(size: 11)).foregroundStyle(SettingsStyle.subtitle)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
