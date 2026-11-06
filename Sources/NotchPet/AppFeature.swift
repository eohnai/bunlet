enum AppFeature: String, CaseIterable, Codable, Sendable {
    case pet, notch, agents

    var title: String {
        switch self {
        case .pet: "Desktop Pet"
        case .notch: "Notch"
        case .agents: "Agents"
        }
    }

    var symbol: String {
        switch self {
        case .pet: "pawprint"
        case .notch: "rectangle.topthird.inset.filled"
        case .agents: "terminal"
        }
    }

    var purpose: String {
        switch self {
        case .pet: "A desktop companion that works on its own."
        case .notch: "A compact island for sessions and requests."
        case .agents: "Observe coding sessions and supported usage limits."
        }
    }
}
