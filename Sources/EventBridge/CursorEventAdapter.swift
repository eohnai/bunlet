import Foundation

/// Cursor CLI hooks (`~/.cursor/hooks.json`, decision 0025), translated into the shared lifecycle events.
/// Observation only: Bunlet's helper prints nothing back, so Cursor's own permission flow is unchanged.
/// Command text, file paths, tool input and transcripts are never forwarded.
public enum CursorEventAdapter {
    /// The Cursor events Bunlet installs, and the shared event and tool name each one becomes.
    public static let events: [String: (HookEvent, tool: String?)] = [
        "sessionStart": (.sessionStart, nil),
        "beforeSubmitPrompt": (.userPromptSubmit, nil),
        "beforeShellExecution": (.preToolUse, "Shell"),
        "afterShellExecution": (.postToolUse, "Shell"),
        "beforeMCPExecution": (.preToolUse, "MCP"),
        "afterMCPExecution": (.postToolUse, "MCP"),
        "beforeReadFile": (.preToolUse, "Read"),
        // Cursor reports edits only afterwards; it still shows what the agent is doing.
        "afterFileEdit": (.preToolUse, "Edit"),
        "stop": (.stop, nil),
        "sessionEnd": (.sessionEnd, nil),
    ]

    public static func project(rawHook: Data, terminal: HookEnvelopeV1.Terminal? = nil) throws -> HookEnvelopeV1 {
        try project(rawHook: rawHook, terminal: terminal, deadline: nil)
    }

    static func project(rawHook: Data, terminal: HookEnvelopeV1.Terminal?, deadline: UInt64?) throws -> HookEnvelopeV1 {
        let observed = wallMilliseconds()
        let source = try HookEnvelopeV1.rawFields(rawHook, deadline: deadline)
        guard let name = source["hook_event_name"]?.string, let (event, tool) = events[name] else {
            throw BridgeError.invalidMessage
        }
        var fields: [String: JSONValue] = [:]
        fields["hook_event_name"] = .string(event.rawValue)
        // The conversation is Cursor's session; a generation is one prompt's turn.
        fields["session_id"] = source["conversation_id"] ?? source["session_id"]
        fields["turn_id"] = source["generation_id"]
        if let tool { fields["tool_name"] = .string(tool) }
        if let cwd = source["cwd"]?.string, cwd.hasPrefix("/") {
            fields["cwd"] = .string(cwd)
        } else if case .array(let roots) = source["workspace_roots"], let root = roots.first?.string, root.hasPrefix("/") {
            fields["cwd"] = .string(root)
        }
        if event == .userPromptSubmit { fields["prompt_preview"] = HookEnvelopeV1.preview(source["prompt"]) }
        return try HookEnvelopeV1.projected(fields, agent: .cursor, observedAtMs: observed, terminal: terminal)
    }
}
