import Foundation

/// Projects the seven Claude hook shapes covered by the recorded investigation.
/// Hook installation and interactive coverage remain separate workflow checks.
public enum ClaudeEventAdapter {
    public static func project(rawHook: Data, paneSelector: String? = nil) throws -> HookEnvelopeV1 {
        try project(rawHook: rawHook, terminal: HookEnvelopeV1.ottyTerminal(paneSelector), deadline: nil)
    }

    static func project(rawHook: Data, paneSelector: String?, deadline: UInt64?) throws -> HookEnvelopeV1 {
        try project(rawHook: rawHook, terminal: HookEnvelopeV1.ottyTerminal(paneSelector), deadline: deadline)
    }

    static func project(rawHook: Data, terminal: HookEnvelopeV1.Terminal?, deadline: UInt64?) throws -> HookEnvelopeV1 {
        let observed = wallMilliseconds()
        let source = try HookEnvelopeV1.rawFields(rawHook, deadline: deadline)
        var fields: [String: JSONValue] = [:]
        for name in ["session_id", "hook_event_name", "tool_use_id", "tool_name", "cwd"] {
            fields[name] = source[name]
        }
        // Missing IDs remain missing. Claude's source turn identity is prompt_id, not turn_id.
        fields["turn_id"] = source["prompt_id"]
        // Only the two display previews from decision 0019; tool input and transcripts stay excluded.
        switch source["hook_event_name"]?.string {
        case HookEvent.userPromptSubmit.rawValue: fields["prompt_preview"] = HookEnvelopeV1.preview(source["prompt"])
        case HookEvent.stop.rawValue: fields["reply_preview"] = HookEnvelopeV1.preview(source["last_assistant_message"])
        // Only the subagent's ID, to pair its start and stop (decision 0025). Its type and transcript stay out.
        case HookEvent.subagentStart.rawValue, HookEvent.subagentStop.rawValue: fields["agent_id"] = source["agent_id"]
        default: break
        }
        return try HookEnvelopeV1.projected(fields, agent: .claude, observedAtMs: observed,
                                            terminal: terminal)
    }
}
