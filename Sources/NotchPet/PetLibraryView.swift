import Pet
import SwiftUI

struct PetLibraryView: View {
    let library: PetLibraryModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Picker("Pet artwork", selection: Binding(get: { library.selectedID }, set: library.select)) {
                Text("White lionhead rabbit (built-in)").tag("builtin")
                ForEach(library.choices) { choice in Text(choice.name).tag(choice.id) }
            }
            .disabled(library.busy)
            HStack {
                Button("Animate PNG…", action: library.choosePNG).disabled(library.busy)
                Button("Import Sprite Sheet…", action: library.chooseSpriteSheet).disabled(library.busy)
            }
            Text("Animate PNG adds breathing, bobbing and tilt to your existing image. A sprite sheet supplies its own poses. Everything runs locally.")
                .font(.caption).foregroundStyle(.secondary)
            HStack {
                Button("Import Pet Pack…", action: library.chooseImport).disabled(library.busy)
                Button("Use Built-in Pet") { library.select("builtin") }.disabled(library.busy)
                if library.busy {
                    ProgressView().controlSize(.small)
                    Button("Cancel", action: library.cancel)
                }
            }
            Text(library.message).font(.callout).textSelection(.enabled)
            Text("Folder format: manifest.json plus named PNG frames. Assets only; idle is required. Imports stay in Application Support.")
                .font(.caption).foregroundStyle(.secondary)
        }
    }
}
