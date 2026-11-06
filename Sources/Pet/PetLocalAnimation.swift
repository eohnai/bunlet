import CoreGraphics
import Foundation

/// Offline artwork transforms only; this type never creates new character poses or sends requests.
enum PetLocalAnimation {
    static let frameSize = 256
    static let framesPerPose = 6
    static let frameDurationMs = 150

    static func convert(_ data: Data, name: String) throws -> PetPackAssets {
        let source = try PetPNGRaster.decode(data, byteLimit: PetPackManifest.imageByteLimit,
            dimensionLimit: 1024, decodedLimit: 4 * 1024 * 1024)
        let coverage = try source.coverage()
        guard let visible = coverage.bounds, coverage.hasTransparency,
              let subject = source.image.cropping(to: visible) else { throw PetPackFailure.transparentPNGRequired }
        let scale = Double(frameSize) * 0.72 / Double(max(subject.width, subject.height))
        let width = Double(subject.width) * scale
        let height = Double(subject.height) * scale
        var frames: [String: Data] = [:]
        var animations: [String: PetPackManifest.Animation] = [:]
        var encoded = 0
        for pose in PetPose.allCases {
            var names: [String] = []
            for index in 0..<framesPerPose {
                try Task.checkCancellation()
                let motion = transform(for: pose, phase: Double(index) / Double(framesPerPose) * 2 * .pi)
                let context = try PetPNGRaster.makeContext(width: frameSize, height: frameSize)
                context.translateBy(x: CGFloat(Double(frameSize) / 2 + motion.x), y: CGFloat(Double(frameSize) / 2 + motion.y))
                context.rotate(by: CGFloat(motion.rotation))
                context.scaleBy(x: CGFloat(motion.scaleX), y: CGFloat(motion.scaleY))
                context.draw(subject, in: CGRect(x: CGFloat(-width / 2), y: CGFloat(-height / 2), width: CGFloat(width), height: CGFloat(height)))
                guard let image = context.makeImage() else { throw PetPackFailure.invalidPNG }
                let bytes = try PetPNGRaster.encode(image)
                encoded += bytes.count
                guard encoded <= PetPackManifest.encodedLimit else { throw PetPackFailure.resourceLimit }
                let key = pose.rawValue + "-" + String(index + 1)
                frames[key] = bytes
                names.append(key)
            }
            animations[pose.rawValue] = PetPackManifest.Animation(frames: names, frameDurationMs: frameDurationMs)
        }
        return PetPackAssets(manifest: PetPackManifest(version: 1, name: name, animations: animations), frames: frames)
    }

    private struct Transform {
        var x = 0.0
        var y = 0.0
        var scaleX = 1.0
        var scaleY = 1.0
        var rotation = 0.0
    }

    private static func transform(for pose: PetPose, phase: Double) -> Transform {
        let wave = sin(phase)
        let lift = (1 - cos(phase)) / 2
        var value = Transform()
        switch pose {
        case .idle:
            value.scaleX += wave * 0.012
            value.scaleY += wave * 0.025
        case .play:
            value.rotation = wave * 0.10
            value.y = lift * 8
        case .sleep:
            value.scaleX += wave * 0.008
            value.scaleY += wave * 0.016
        case .running:
            value.x = wave * 3
            value.y = lift * 4
            value.rotation = wave * 0.035
        case .attention:
            value.y = lift * 10
            value.rotation = wave * 0.055
        case .complete:
            value.y = lift * 12
            value.scaleX += lift * 0.035
            value.scaleY += lift * 0.035
        case .drag:
            value.rotation = wave * 0.07
            value.y = lift * 3
        }
        return value
    }
}
