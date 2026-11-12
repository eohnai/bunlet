import AppKit
import SwiftUI

@MainActor
public struct PetView: View {
    private let presentation: PetPresentation
    private let pose: PetPose
    private let isVisible: Bool
    private let isSleeping: Bool
    private let onFrameImage: ((NSImage?) -> Void)?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var elapsedSeconds = 0.0

    private struct PlaybackID: Hashable {
        let presentationID: UUID
        let frames: [String]
        let frameDurationMs: Int
        let isVisible: Bool
        let isSleeping: Bool
        let reduceMotion: Bool
    }

    public init(presentation: PetPresentation, pose: PetPose = .idle,
                isVisible: Bool = true, isSleeping: Bool = false,
                onFrameImage: ((NSImage?) -> Void)? = nil) {
        self.presentation = presentation
        self.pose = pose
        self.isVisible = isVisible
        self.isSleeping = isSleeping
        self.onFrameImage = onFrameImage
    }

    func frame(at elapsedSeconds: Double, reduceMotion: Bool) -> String {
        PetPlaybackPolicy(animation: presentation.animation(for: pose), isVisible: isVisible,
                          isSleeping: isSleeping, reduceMotion: reduceMotion).frame(at: elapsedSeconds)
    }

    private func image(for frame: String) -> NSImage? {
        let idle = presentation.animation(for: .idle).frames[0]
        return PetFrameImages.image(frame: frame, presentation: presentation)
            ?? PetFrameImages.image(frame: idle, presentation: presentation)
    }

    private func updatePlayback() async {
        elapsedSeconds = 0
        let animation = presentation.animation(for: pose)
        let policy = PetPlaybackPolicy(animation: animation, isVisible: isVisible,
                                       isSleeping: isSleeping, reduceMotion: reduceMotion)
        guard policy.shouldAnimate else { return }
        let started = ProcessInfo.processInfo.systemUptime
        while !Task.isCancelled {
            do {
                try await Task.sleep(for: .milliseconds(animation.frameDurationMs))
            } catch {
                return
            }
            guard !Task.isCancelled else { return }
            elapsedSeconds = ProcessInfo.processInfo.systemUptime - started
        }
    }

    public var body: some View {
        let animation = presentation.animation(for: pose)
        let image = image(for: frame(at: elapsedSeconds, reduceMotion: reduceMotion))
        Group {
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
            } else {
                Image(systemName: "hare")
                    .foregroundStyle(.secondary)
                    .accessibilityLabel("Pet artwork unavailable")
            }
        }
        .onAppear { onFrameImage?(image) }
        .onChange(of: presentation.id.uuidString + frame(at: elapsedSeconds, reduceMotion: reduceMotion)) { _, _ in onFrameImage?(image) }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(image == nil ? "Pet artwork unavailable" : presentation.name)
        .task(id: PlaybackID(presentationID: presentation.id, frames: animation.frames, frameDurationMs: animation.frameDurationMs,
                             isVisible: isVisible, isSleeping: isSleeping, reduceMotion: reduceMotion)) {
            await updatePlayback()
        }
    }
}

/// Bounded decoded-frame cache; imported bytes never resolve a source path during playback.
@MainActor
private enum PetFrameImages {
    private static let cache: NSCache<NSString, NSImage> = {
        let value = NSCache<NSString, NSImage>()
        value.totalCostLimit = 32 * 1024 * 1024
        value.countLimit = 128
        return value
    }()

    static func image(frame: String, presentation: PetPresentation) -> NSImage? {
        let key = (presentation.id.uuidString + ":" + frame) as NSString
        if let cached = cache.object(forKey: key) { return cached }
        let image: NSImage?
        if let bytes = presentation.data(for: frame) { image = NSImage(data: bytes) }
        else { image = PetArtwork.url(for: frame).flatMap(NSImage.init(contentsOf:)) }
        guard let image else { return nil }
        let pixels = image.cgImage(forProposedRect: nil, context: nil, hints: nil)
        cache.setObject(image, forKey: key, cost: min(4 * 1024 * 1024, (pixels?.width ?? 1) * (pixels?.height ?? 1) * 4))
        return image
    }
}
