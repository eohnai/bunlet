import Foundation

public enum PetArtwork {
    private struct Manifest: Decodable {
        struct Animation: Decodable {
            let frames: [String]
            let frameDurationMs: Int
        }
        let version: Int
        let animations: [String: Animation]
    }

    private static let directory = AppResourceDirectory.locate("NotchPet_Pet.bundle", in: .main,
                                                               otherwise: Bundle.module.resourceURL)
    private static let bundled = load(from: directory)

    public static func presentation() -> PetPresentation? { bundled }

    static func load(from directory: URL?) -> PetPresentation? {
        guard let manifestURL = file("manifest.json", in: directory),
              let data = try? Data(contentsOf: manifestURL),
              let manifest = try? JSONDecoder().decode(Manifest.self, from: data), manifest.version == 1,
              let record = manifest.animations["idle"],
              let idle = PetAnimation(frames: record.frames, frameDurationMs: record.frameDurationMs),
              idle.frames.allSatisfy({ url(for: $0, in: directory) != nil }) else { return nil }
        let animations = manifest.animations.reduce(into: [PetPose: PetAnimation]()) { result, entry in
            guard let pose = PetPose(rawValue: entry.key),
                  let animation = PetAnimation(frames: entry.value.frames,
                                               frameDurationMs: entry.value.frameDurationMs),
                  animation.frames.allSatisfy({ url(for: $0, in: directory) != nil }) else { return }
            result[pose] = animation
        }
        return PetPresentation(idle: idle, animations: animations)
    }

    public static func url(for frame: String) -> URL? { url(for: frame, in: directory) }

    static func url(for frame: String, in directory: URL?) -> URL? {
        guard frame.range(of: "^[A-Za-z0-9_-]+$", options: .regularExpression) != nil else { return nil }
        return file("\(frame).png", in: directory)
    }

    private static func file(_ name: String, in directory: URL?) -> URL? {
        guard let url = directory?.appendingPathComponent(name),
              FileManager.default.fileExists(atPath: url.path) else { return nil }
        return url
    }
}
