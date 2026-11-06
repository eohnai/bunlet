import AppKit
import Foundation
import Observation
import Pet
import UniformTypeIdentifiers

@MainActor
@Observable
final class PetLibraryModel {
    private(set) var choices: [PetPackChoice] = []
    /// Decision 0021: there is no built-in pet. Both stay nil until an imported pet loads.
    private(set) var selectedID: String?
    private(set) var presentation: PetPresentation?
    private(set) var message = "Choose a PNG to create your pet."
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
        let pack: PetPack
    }

    private enum Operation: Sendable {
        case restore(String), select(String), importFolder(URL), animatePNG(URL), importSheet(URL)
    }

    private enum Input: Equatable, Sendable {
        case folder, png, sheet
    }

    init(defaults: UserDefaults, onChange: @escaping (PetPresentation) -> Void) {
        self.defaults = defaults
        self.onChange = onChange
        root = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
            .appendingPathComponent("NotchPet/Pets", isDirectory: true)
    }

    func start() {
        // "builtin" is a selection saved before decision 0021. It is kept, but there is nothing to load.
        guard let saved = defaults.string(forKey: Self.selectionKey), saved != "builtin" else {
            loadChoices()
            return
        }
        perform(.restore(saved))
    }
    func select(_ id: String) { perform(.select(id)) }

    func chooseImport() { choose(.folder) }
    func choosePNG() { choose(.png) }
    func chooseSpriteSheet() { choose(.sheet) }

    private func choose(_ input: Input) {
        guard !busy else { return }
        busy = true
        let panel = NSOpenPanel()
        picker = panel
        panel.canChooseFiles = input != .folder
        panel.canChooseDirectories = input == .folder
        if input != .folder { panel.allowedContentTypes = [.png] }
        panel.allowsMultipleSelection = false
        panel.resolvesAliases = false
        panel.prompt = "Import"
        switch input {
        case .folder: panel.message = "Choose a folder containing manifest.json and its PNG frames."
        case .png: panel.message = "Choose a transparent PNG. Simple movement, tilt and breathing reuse your image; no new poses are drawn."
        case .sheet: panel.message = "Choose a PNG with seven rows: idle, play, sleep, running, attention, complete, drag."
        }
        panel.begin { [weak self, weak panel] response in
            MainActor.assumeIsolated {
                guard let self else { return }
                let source = panel?.url
                self.picker = nil
                self.busy = false
                guard response == .OK, let source else { return }
                switch input {
                case .folder: self.perform(.importFolder(source))
                case .png: self.perform(.animatePNG(source))
                case .sheet: self.perform(.importSheet(source))
                }
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
        guard let root else {
            message = "Pet storage is unavailable. Your selection is unchanged."
            return
        }
        busy = true
        message = "Reading and validating pet assets…"
        let job = Task.detached(priority: .userInitiated) {
            let pack: PetPack
            switch operation {
            case .restore(let saved), .select(let saved): pack = try PetPackLibrary.load(id: saved, at: root)
            case .importFolder(let source): pack = try PetPackLibrary.importPack(from: source, to: root)
            case .animatePNG(let source): pack = try PetPackLibrary.importPNG(from: source, to: root)
            case .importSheet(let source): pack = try PetPackLibrary.importSpriteSheet(from: source, to: root)
            }
            return Result(choices: try PetPackLibrary.choices(at: root), pack: pack)
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
                let presentation = result.pack.presentation
                let id = result.pack.choice.id
                if case .restore = operation {} else {
                    guard self.saveSelection(id) else { return }
                }
                self.choices = result.choices
                self.selectedID = id
                self.presentation = presentation
                self.onChange(presentation)
                self.message = "Pet selection saved. Missing optional animations use idle artwork."
            } catch is CancellationError {
                self.message = "Import or selection cancelled. Your current pet is unchanged. A finished copy may remain available after reopening Settings."
            } catch let failure as PetPackFailure {
                self.message = Self.explanation(failure)
                if case .restore = operation {
                    self.message += " Your saved selection is retained. Choose another pet or import the image again."
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

    /// Lists earlier imports so the person can pick one without importing again.
    private func loadChoices() {
        guard let root else { return }
        task = Task { @MainActor [weak self] in
            let listing = Task.detached(priority: .utility) { try? PetPackLibrary.choices(at: root) }
            let found = await withTaskCancellationHandler(operation: { await listing.value }, onCancel: { listing.cancel() })
            guard let self, !Task.isCancelled, let found else { return }
            self.choices = found
            self.task = nil
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
        case .invalidPNG: "Use a valid single-image PNG with an alpha channel. Pack frames must match dimensions and be at most 1024 × 1024."
        case .transparentPNGRequired: "Use a PNG with visible artwork and a transparent background. Opaque and empty images cannot be animated."
        case .invalidSheet: "The sheet needs seven equal-height rows, square cells, whole columns and a visible idle row."
        case .sheetGap: "A row has a blank cell before a visible frame. Move unused transparent cells to the row’s right edge."
        case .resourceLimit: "The pet exceeds a file, frame, image-memory or library limit."
        case .writeFailed: "Pet assets could not be saved. Your selected pet is unchanged."
        }
    }
}
