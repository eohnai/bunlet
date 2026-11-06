import CoreGraphics
import Foundation
import ImageIO

public enum PetPackFailure: String, Error, Sendable {
    case missing, unsafePath, unreadable, changed, invalidManifest, invalidPNG, resourceLimit, writeFailed
}

public struct PetPackChoice: Equatable, Sendable, Identifiable {
    public let id: String
    public let name: String

    public init(id: String, name: String) {
        self.id = id
        self.name = name
    }
}

public struct PetPack: Sendable {
    public let choice: PetPackChoice
    public let presentation: PetPresentation
}

struct PetPackManifest: Codable, Equatable {
    struct Animation: Codable, Equatable {
        let frames: [String]
        let frameDurationMs: Int
    }
    let version: Int
    let name: String
    let animations: [String: Animation]

    static let byteLimit = 65_536
    static let frameLimit = 128
    static let imageByteLimit = 2 * 1024 * 1024
    static let encodedLimit = 16 * 1024 * 1024
    static let decodedLimit = 32 * 1024 * 1024

    static func decode(_ data: Data) throws -> Self {
        guard data.count <= byteLimit else { throw PetPackFailure.resourceLimit }
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              Set(root.keys) == Set(["version", "name", "animations"]),
              let manifest = try? JSONDecoder().decode(Self.self, from: data), manifest.version == 1,
              !manifest.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              manifest.name.utf8.count <= 80,
              !manifest.name.unicodeScalars.contains(where: { $0.properties.generalCategory == .control }),
              !manifest.animations.isEmpty, manifest.animations.count <= PetPose.allCases.count,
              manifest.animations["idle"] != nil,
              Set(manifest.animations.keys).isSubset(of: Set(PetPose.allCases.map(\.rawValue))),
              let rawAnimations = root["animations"] as? [String: [String: Any]] else {
            throw PetPackFailure.invalidManifest
        }
        for (name, animation) in manifest.animations {
            guard Set(rawAnimations[name]?.keys.map { $0 } ?? []) == Set(["frames", "frameDurationMs"]),
                  !animation.frames.isEmpty, animation.frames.count <= 64,
                  (40...10_000).contains(animation.frameDurationMs),
                  animation.frames.allSatisfy(validFrame) else { throw PetPackFailure.invalidManifest }
        }
        guard manifest.frames.count <= frameLimit else { throw PetPackFailure.resourceLimit }
        return manifest
    }

    var frames: Set<String> { Set(animations.values.flatMap(\.frames)) }

    static func validFrame(_ name: String) -> Bool {
        !name.isEmpty && name.utf8.count <= 80 && name.utf8.allSatisfy {
            (65...90).contains($0) || (97...122).contains($0) || (48...57).contains($0) || $0 == 45 || $0 == 95
        }
    }

    func presentation(bytes: [String: Data]) throws -> PetPresentation {
        var result: [PetPose: PetAnimation] = [:]
        for (key, record) in animations {
            guard let pose = PetPose(rawValue: key),
                  let animation = PetAnimation(frames: record.frames, frameDurationMs: record.frameDurationMs) else {
                throw PetPackFailure.invalidManifest
            }
            result[pose] = animation
        }
        guard let idle = result[.idle] else { throw PetPackFailure.invalidManifest }
        return PetPresentation(idle: idle, animations: result, frameData: bytes, name: name)
    }

    /// Header bounds precede decompression. A frame is one alpha PNG, never an animated image/container.
    static func validatePNG(_ data: Data) throws -> (width: Int, height: Int) {
        guard data.count <= imageByteLimit else { throw PetPackFailure.resourceLimit }
        guard data.starts(with: [137, 80, 78, 71, 13, 10, 26, 10]),
              let source = CGImageSourceCreateWithData(data as CFData, [kCGImageSourceShouldCache: false] as CFDictionary),
              CGImageSourceGetType(source) as String? == "public.png", CGImageSourceGetCount(source) == 1,
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = (properties[kCGImagePropertyPixelWidth] as? NSNumber)?.intValue,
              let height = (properties[kCGImagePropertyPixelHeight] as? NSNumber)?.intValue,
              (1...1024).contains(width), (1...1024).contains(height) else { throw PetPackFailure.invalidPNG }
        guard let image = CGImageSourceCreateImageAtIndex(source, 0,
                [kCGImageSourceShouldCacheImmediately: true] as CFDictionary),
              image.width == width, image.height == height,
              [CGImageAlphaInfo.first, .last, .premultipliedFirst, .premultipliedLast].contains(image.alphaInfo),
              let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8,
                  bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { throw PetPackFailure.invalidPNG }
        context.draw(image, in: CGRect(x: 0, y: 0, width: CGFloat(width), height: CGFloat(height)))
        return (width, height)
    }
}
