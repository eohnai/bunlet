import Foundation

struct PetPackAssets {
    let manifest: PetPackManifest
    let frames: [String: Data]
}

/// Asset-only persistence. Call off the main actor; returned frames are immutable bounded bytes.
public enum PetPackLibrary {
    public static func choices(at root: URL) throws -> [PetPackChoice] {
        let directory: PetPackDirectory
        do { directory = try PetPackDirectory(url: root, privateFiles: true) }
        catch PetPackFailure.missing { return [] }
        return try choices(in: directory)
    }

    private static func choices(in directory: PetPackDirectory) throws -> [PetPackChoice] {
        var choices: [PetPackChoice] = []
        for id in try directory.names().sorted() where validID(id) {
            guard choices.count < 32 else { throw PetPackFailure.resourceLimit }
            // One invalid saved pack cannot conceal recovery/selection of other packs.
            guard let child = try? directory.child(id),
                  let bytes = try? child.read("manifest.json", limit: PetPackManifest.byteLimit),
                  let manifest = try? PetPackManifest.decode(bytes) else { continue }
            choices.append(PetPackChoice(id: id, name: manifest.name))
        }
        return choices
    }

    public static func load(id: String, at root: URL) throws -> PetPack {
        guard validID(id) else { throw PetPackFailure.unsafePath }
        let directory = try PetPackDirectory(url: root, privateFiles: true)
        let validated = try validate(try directory.child(id))
        return PetPack(choice: PetPackChoice(id: id, name: validated.manifest.name),
                       presentation: try validated.manifest.presentation(bytes: validated.frames))
    }

    public static func importPack(from source: URL, to root: URL) throws -> PetPack {
        try install(validate(PetPackDirectory(url: source)), at: root)
    }

    public static func importPNG(from source: URL, to root: URL) throws -> PetPack {
        let directory = try PetPackDirectory(url: source.deletingLastPathComponent())
        let data = try directory.read(source.lastPathComponent, limit: PetPackManifest.imageByteLimit)
        return try install(PetLocalAnimation.convert(data, name: displayName(source)), at: root)
    }

    public static func importSpriteSheet(from source: URL, to root: URL) throws -> PetPack {
        let directory = try PetPackDirectory(url: source.deletingLastPathComponent())
        let data = try directory.read(source.lastPathComponent, limit: PetSpriteSheet.byteLimit)
        return try install(PetSpriteSheet.convert(data, name: displayName(source)), at: root)
    }

    private static func install(_ validated: PetPackAssets, at root: URL) throws -> PetPack {
        try Task.checkCancellation()
        let directory = try PetPackDirectory(url: root, create: true, privateFiles: true)
        guard try choices(in: directory).count < 32 else { throw PetPackFailure.resourceLimit }
        let id = UUID().uuidString.lowercased()
        let stageName = ".import-" + id
        let stage = try directory.child(stageName, create: true)
        var written = [String]()
        var committed = false
        defer { if !committed { directory.discardStage(stageName, files: written) } }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        written.append("manifest.json")
        try stage.write("manifest.json", data: encoder.encode(validated.manifest))
        for name in validated.frames.keys.sorted() {
            guard let data = validated.frames[name] else { throw PetPackFailure.invalidPNG }
            let filename = name + ".png"
            written.append(filename)
            try stage.write(filename, data: data)
        }
        let saved = try validate(stage)
        guard saved.manifest == validated.manifest, saved.frames == validated.frames else { throw PetPackFailure.changed }
        try Task.checkCancellation()
        try stage.synchronize()
        try directory.commit(stage: stageName, id: id)
        committed = true
        return PetPack(choice: PetPackChoice(id: id, name: validated.manifest.name),
                       presentation: try validated.manifest.presentation(bytes: validated.frames))
    }

    private static func validate(_ directory: PetPackDirectory) throws -> PetPackAssets {
        let manifest = try PetPackManifest.decode(directory.read("manifest.json", limit: PetPackManifest.byteLimit))
        var frames: [String: Data] = [:]
        var encoded = 0
        var decoded = 0
        var dimensions: (width: Int, height: Int)?
        for name in manifest.frames.sorted() {
            try Task.checkCancellation()
            let data = try directory.read(name + ".png", limit: PetPackManifest.imageByteLimit)
            encoded += data.count
            guard encoded <= PetPackManifest.encodedLimit else { throw PetPackFailure.resourceLimit }
            let size = try PetPackManifest.validatePNG(data)
            decoded += size.width * size.height * 4
            guard decoded <= PetPackManifest.decodedLimit else { throw PetPackFailure.resourceLimit }
            if let dimensions, dimensions.width != size.width || dimensions.height != size.height {
                throw PetPackFailure.invalidPNG
            }
            dimensions = size
            frames[name] = data
        }
        return PetPackAssets(manifest: manifest, frames: frames)
    }

    private static func displayName(_ source: URL) -> String {
        let name = source.deletingPathExtension().lastPathComponent.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, name.utf8.count <= 80,
              !name.unicodeScalars.contains(where: { $0.properties.generalCategory == .control }) else { return "Custom pet" }
        return name
    }

    private static func validID(_ id: String) -> Bool {
        guard id.utf8.count == 36, let uuid = UUID(uuidString: id) else { return false }
        return uuid.uuidString.lowercased() == id
    }
}
