import AppKit
import Foundation
import Observation
import Pet

@MainActor
@Observable
final class PetLibraryModel {
    private(set) var choices: [PetPackChoice] = []
    private(set) var selectedID = "builtin"
    private(set) var presentation = PetArtwork.presentation()
    private(set) var message = "Choose a manifest/PNG pack folder to import your own pet."
    private(set) var busy = false
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let root: URL?
    @ObservationIgnored private let onChange: (PetPresentation) -> Void
    @ObservationIgnored private var task: Task<Void, Never>?
    @ObservationIgnored private var worker: Task<Result, Error>?
    @ObservationIgnored private var picker: NSOpenPanel?
    private static let selectionKey = "pet.selectedPack.v1"

    private struct Result: Sendable {
        let choices: [PetPackChoice]
        let pack: PetPack?
        let id: String
    }

    private enum Operation: Sendable {
        case restore(String), select(String), importFolder(URL)
    }

    init(defaults: UserDefaults, onChange: @escaping (PetPresentation) -> Void) {
        self.defaults = defaults
        self.onChange = onChange
        root = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
            .appendingPathComponent("NotchPet/Pets", isDirectory: true)
    }

    func start() { perform(.restore(defaults.string(forKey: Self.selectionKey) ?? "builtin")) }
    func select(_ id: String) { perform(.select(id)) }

    func chooseImport() {
        guard !busy else { return }
        busy = true
        let panel = NSOpenPanel()
        picker = panel
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.resolvesAliases = false
        panel.prompt = "Import"
        panel.message = "Choose a folder containing manifest.json and its PNG frames."
        panel.begin { [weak self, weak panel] response in
            MainActor.assumeIsolated {
                guard let self else { return }
                let source = panel?.url
                self.picker = nil
                self.busy = false
                if response == .OK, let source { self.perform(.importFolder(source)) }
            }
        }
    }

    func cancel() {
        picker?.cancel(nil)
        task?.cancel()
        worker?.cancel()
    }

    private func perform(_ operation: Operation) {
        guard !busy else { return }
        if case .select(let id) = operation, id == "builtin" {
            guard let builtIn = PetArtwork.presentation(), saveSelection("builtin") else { return }
            selectedID = "builtin"
            presentation = builtIn
            onChange(builtIn)
            message = "Built-in pet selected. Imported packs are retained."
            return
        }
        guard let root else {
            message = "Pet storage is unavailable. Your selection is unchanged."
            return
        }
        busy = true
        message = "Reading and validating pet assets…"
        let job = Task.detached(priority: .userInitiated) {
            let pack: PetPack?
            let id: String
            switch operation {
            case .restore(let saved), .select(let saved):
                id = saved
                pack = saved == "builtin" ? nil : try PetPackLibrary.load(id: saved, at: root)
            case .importFolder(let source):
                pack = try PetPackLibrary.importPack(from: source, to: root)
                id = pack?.choice.id ?? "builtin"
            }
            return Result(choices: try PetPackLibrary.choices(at: root), pack: pack, id: id)
        }
        worker = job
        task = Task { @MainActor [weak self] in
            guard let self else { return }
            defer {
                self.busy = false
                self.task = nil
                self.worker = nil
            }
            do {
                let result = try await withTaskCancellationHandler(operation: { try await job.value }, onCancel: { job.cancel() })
                try Task.checkCancellation()
                guard let presentation = result.pack?.presentation ?? PetArtwork.presentation() else {
                    self.message = "Built-in pet artwork is unavailable. Your selection is unchanged."
                    return
                }
                if case .restore = operation {} else {
                    guard self.saveSelection(result.id) else { return }
                }
                self.choices = result.choices
                self.selectedID = result.id
                self.presentation = presentation
                self.onChange(presentation)
                self.message = "Pet selection saved. Missing optional animations use idle artwork."
            } catch is CancellationError {
                self.message = "Import or selection cancelled. Your current pet is unchanged. A finished copy may remain available after reopening Settings."
            } catch let failure as PetPackFailure {
                self.message = Self.explanation(failure)
                if case .restore = operation {
                    self.message += " Showing the built-in pet; your saved selection is retained. Choose the built-in pet to reset it."
                    // Keep recovery choices usable even if one selected pack is invalid/missing.
                    let recovery = Task.detached { try? PetPackLibrary.choices(at: root) }
                    let recovered = await withTaskCancellationHandler(operation: { await recovery.value }, onCancel: { recovery.cancel() })
                    if !Task.isCancelled, let recovered { self.choices = recovered }
                }
            } catch {
                self.message = "Pet assets could not be read or saved. Your current pet is unchanged."
            }
        }
    }

    private func saveSelection(_ id: String) -> Bool {
        let previous = defaults.object(forKey: Self.selectionKey)
        defaults.set(id, forKey: Self.selectionKey)
        guard defaults.string(forKey: Self.selectionKey) == id else {
            if let previous { defaults.set(previous, forKey: Self.selectionKey) }
            else { defaults.removeObject(forKey: Self.selectionKey) }
            message = "Pet selection could not be saved. Your current pet is unchanged."
            return false
        }
        return true
    }

    private static func explanation(_ failure: PetPackFailure) -> String {
        switch failure {
        case .missing: "A required pet asset is missing."
        case .unsafePath: "Choose an ordinary pack folder with regular files and no links."
        case .unreadable: "Pet assets could not be read."
        case .changed: "Pet files changed while reading. Finish edits, then retry."
        case .invalidManifest: "The version-1 manifest needs a name, idle animation and valid frame names/timing."
        case .invalidPNG: "Frames must be single-image alpha PNGs with matching dimensions up to 1024 × 1024."
        case .resourceLimit: "The pet exceeds a file, frame, image-memory or library limit."
        case .writeFailed: "Pet assets could not be saved. Your selected pet is unchanged."
        }
    }
}
