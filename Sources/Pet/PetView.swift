import AppKit
import SwiftUI

public struct PetView: View {
    private let presentation: PetPresentation
    private let pose: PetPose
    private let isVisible: Bool
    private let isSleeping: Bool
    private let onFrameImage: ((NSImage?) -> Void)?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var elapsedSeconds = 0.0

    private struct PlaybackID: Hashable {
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
        return PetArtwork.url(for: frame).flatMap(NSImage.init(contentsOf:))
            ?? PetArtwork.url(for: idle).flatMap(NSImage.init(contentsOf:))
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
                Image(systemName: "pawprint")
                    .foregroundStyle(.secondary)
                    .accessibilityLabel("Pet artwork unavailable")
            }
        }
        .onAppear { onFrameImage?(image) }
        .onChange(of: frame(at: elapsedSeconds, reduceMotion: reduceMotion)) { _, _ in onFrameImage?(image) }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(image == nil ? "Pet artwork unavailable" : "White lionhead rabbit")
        .task(id: PlaybackID(frames: animation.frames, frameDurationMs: animation.frameDurationMs,
                             isVisible: isVisible, isSleeping: isSleeping, reduceMotion: reduceMotion)) {
            await updatePlayback()
        }
    }
}
