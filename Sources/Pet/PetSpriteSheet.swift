import CoreGraphics
import Foundation

/// Normalizes a data-only seven-row sheet into the single existing playback format.
enum PetSpriteSheet {
    static let byteLimit = 16 * 1024 * 1024
    private static let rowOrder: [PetPose] = [.idle, .play, .sleep, .running, .attention, .complete, .drag]
    private static let frameDurationMs = 150

    static func convert(_ data: Data, name: String) throws -> PetPackAssets {
        let source = try PetPNGRaster.decode(data, byteLimit: byteLimit,
            dimensionLimit: 8192, decodedLimit: PetPackManifest.decodedLimit)
        guard source.height % rowOrder.count == 0 else { throw PetPackFailure.invalidSheet }
        let cell = source.height / rowOrder.count
        guard (1...1024).contains(cell), source.width % cell == 0,
              (1...64).contains(source.width / cell) else { throw PetPackFailure.invalidSheet }
        let columns = source.width / cell
        var frames: [String: Data] = [:]
        var animations: [String: PetPackManifest.Animation] = [:]
        var encoded = 0
        var decoded = 0
        for (row, pose) in rowOrder.enumerated() {
            var names: [String] = []
            var padding = false
            for column in 0..<columns {
                try Task.checkCancellation()
                let rect = CGRect(x: CGFloat(column * cell), y: CGFloat(row * cell), width: CGFloat(cell), height: CGFloat(cell))
                guard try source.coverage(in: rect).bounds != nil else {
                    padding = true
                    continue
                }
                guard !padding else { throw PetPackFailure.sheetGap }
                guard frames.count < PetPackManifest.frameLimit else { throw PetPackFailure.resourceLimit }
                decoded += cell * cell * 4
                guard decoded <= PetPackManifest.decodedLimit else { throw PetPackFailure.resourceLimit }
                guard let image = source.image.cropping(to: rect) else { throw PetPackFailure.invalidSheet }
                let bytes = try PetPNGRaster.encode(image)
                encoded += bytes.count
                guard encoded <= PetPackManifest.encodedLimit else { throw PetPackFailure.resourceLimit }
                let key = pose.rawValue + "-" + String(column + 1)
                frames[key] = bytes
                names.append(key)
            }
            if !names.isEmpty {
                animations[pose.rawValue] = PetPackManifest.Animation(frames: names, frameDurationMs: frameDurationMs)
            } else if pose == .idle { throw PetPackFailure.invalidSheet }
        }
        return PetPackAssets(manifest: PetPackManifest(version: 1, name: name, animations: animations), frames: frames)
    }
}
