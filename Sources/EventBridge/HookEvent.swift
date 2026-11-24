public enum HookEvent: String, Codable, CaseIterable, Sendable {
    case sessionStart = "SessionStart"
    case userPromptSubmit = "UserPromptSubmit"
    case preToolUse = "PreToolUse"
    case permissionRequest = "PermissionRequest"
    case postToolUse = "PostToolUse"
    case stop = "Stop"
    case sessionEnd = "SessionEnd"
    /// Claude only (decision 0025). Carries `agent_id` so the count can pair starts with stops.
    case subagentStart = "SubagentStart"
    case subagentStop = "SubagentStop"

    /// The original seven events every supported agent reports.
    public static let core: [HookEvent] = [.sessionStart, .userPromptSubmit, .preToolUse, .permissionRequest,
                                           .postToolUse, .stop, .sessionEnd]

    /// The hooks Bunlet installs for an agent's lifecycle observation.
    public static func lifecycle(for agent: Agent) -> [HookEvent] {
        agent == .claude ? allCases : core
    }

    public var isSubagent: Bool { self == .subagentStart || self == .subagentStop }

    var requiresToolName: Bool {
        switch self {
        case .preToolUse, .permissionRequest, .postToolUse: true
        case .sessionStart, .userPromptSubmit, .stop, .sessionEnd, .subagentStart, .subagentStop: false
        }
    }
}
