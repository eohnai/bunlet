import EventBridge

extension Agent {
    /// Agents whose hooks use the Claude/Codex configuration and version shapes.
    static let hookShaped: [Agent] = [.codex, .claude]
}
