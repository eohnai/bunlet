import Foundation

public enum PetPose: String, CaseIterable, Sendable {
    case idle, play, sleep, running, attention, complete, drag
}

public struct PetAnimation: Equatable, Sendable {
    public let frames: [String]
    public let frameDurationMs: Int

    public init?(frames: [String], frameDurationMs: Int) {
        guard !frames.isEmpty, frames.allSatisfy({ !$0.isEmpty }), frameDurationMs > 0 else { return nil }
        self.frames = frames
        self.frameDurationMs = frameDurationMs
    }
}

public struct PetPresentation: Sendable {
    public let id = UUID()
    public let name: String
    private let frameData: [String: Data]
    private let idle: PetAnimation
    private let animations: [PetPose: PetAnimation]

    public init(idle: PetAnimation, animations: [PetPose: PetAnimation] = [:],
                frameData: [String: Data] = [:], name: String = "White lionhead rabbit") {
        self.name = name
        self.frameData = frameData
        self.idle = idle
        self.animations = animations
    }

    public func data(for frame: String) -> Data? { frameData[frame] }

    public func animation(for pose: PetPose) -> PetAnimation {
        pose == .idle ? idle : animations[pose] ?? idle
    }
}

/// Selects frames without owning a clock, scheduler, window or agent service.
public struct PetPlaybackPolicy: Sendable {
    private let animation: PetAnimation
    private let isVisible: Bool
    private let isSleeping: Bool
    private let reduceMotion: Bool

    public init(animation: PetAnimation, isVisible: Bool, isSleeping: Bool, reduceMotion: Bool) {
        self.animation = animation
        self.isVisible = isVisible
        self.isSleeping = isSleeping
        self.reduceMotion = reduceMotion
    }

    /// The caller should schedule updates only while this is true.
    public var shouldAnimate: Bool {
        animation.frames.count > 1 && isVisible && !isSleeping && !reduceMotion
    }

    /// The caller supplies monotonic elapsed seconds since playback started or resumed.
    /// Inactive playback and invalid elapsed values retain a stable first frame.
    public func frame(at elapsedSeconds: Double) -> String {
        guard shouldAnimate, elapsedSeconds.isFinite, elapsedSeconds >= 0 else {
            return animation.frames[0]
        }
        let frameDuration = Double(animation.frameDurationMs) / 1000
        let cycleDuration = frameDuration * Double(animation.frames.count)
        // Reduce to one cycle before integer conversion, even for very large elapsed values.
        let position = elapsedSeconds.truncatingRemainder(dividingBy: cycleDuration) / frameDuration
        let index = min(Int(position), animation.frames.count - 1)
        return animation.frames[index]
    }
}
