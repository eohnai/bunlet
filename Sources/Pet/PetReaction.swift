/// Presentation input only. Provider identities and session rules belong to the app adapter.
public enum PetMood: String, Sendable {
    case idle, working, attention, responseReady, failed, ended

    public var label: String {
        switch self {
        case .idle: ""
        case .working: "Working"
        case .attention: "Needs your attention"
        case .responseReady: "Response ready"
        case .failed: "Turn failed"
        case .ended: "Session ended"
        }
    }

    public var symbol: String {
        switch self {
        case .idle: "hare"
        case .working: "ellipsis"
        case .attention: "exclamationmark.bubble"
        case .responseReady: "bubble.left"
        case .failed: "xmark.circle"
        case .ended: "stop.circle"
        }
    }

    public var pose: PetPose {
        switch self {
        case .working: .running
        case .attention: .attention
        case .idle, .responseReady, .failed, .ended: .idle
        }
    }
}
