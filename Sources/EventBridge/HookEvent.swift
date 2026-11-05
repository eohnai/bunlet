public enum HookEvent: String, Codable, CaseIterable, Sendable {
    case sessionStart = "SessionStart"
    case userPromptSubmit = "UserPromptSubmit"
    case preToolUse = "PreToolUse"
    case permissionRequest = "PermissionRequest"
    case postToolUse = "PostToolUse"
    case stop = "Stop"
    case sessionEnd = "SessionEnd"

    var requiresToolName: Bool {
        switch self {
        case .preToolUse, .permissionRequest, .postToolUse: true
        case .sessionStart, .userPromptSubmit, .stop, .sessionEnd: false
        }
    }
}
