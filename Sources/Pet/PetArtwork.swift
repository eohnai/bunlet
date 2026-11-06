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

    private static let bundled = load()

    public static func presentation() -> PetPresentation? { bundled }

    private static func load() -> PetPresentation? {
        guard let manifestURL = Bundle.module.url(forResource: "manifest", withExtension: "json"),
              let data = try? Data(contentsOf: manifestURL),
              let manifest = try? JSONDecoder().decode(Manifest.self, from: data), manifest.version == 1,
              let record = manifest.animations["idle"],
              let idle = PetAnimation(frames: record.frames, frameDurationMs: record.frameDurationMs),
              idle.frames.allSatisfy({ url(for: $0) != nil }) else { return nil }
        let animations = manifest.animations.reduce(into: [PetPose: PetAnimation]()) { result, entry in
            guard let pose = PetPose(rawValue: entry.key),
                  let animation = PetAnimation(frames: entry.value.frames,
                                               frameDurationMs: entry.value.frameDurationMs),
                  animation.frames.allSatisfy({ url(for: $0) != nil }) else { return }
            result[pose] = animation
        }
        return PetPresentation(idle: idle, animations: animations)
    }

    public static func url(for frame: String) -> URL? {
        guard frame.range(of: "^[A-Za-z0-9_-]+$", options: .regularExpression) != nil else { return nil }
        return Bundle.module.url(forResource: frame, withExtension: "png")
    }
}
