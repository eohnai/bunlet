import Foundation

/// Projects the seven Claude hook shapes covered by the recorded investigation.
/// Hook installation and interactive coverage remain separate workflow checks.
public enum ClaudeEventAdapter {
    public static func project(rawHook: Data, paneSelector: String? = nil) throws -> HookEnvelopeV1 {
        try project(rawHook: rawHook, paneSelector: paneSelector, deadline: nil)
    }

    static func project(rawHook: Data, paneSelector: String?, deadline: UInt64?) throws -> HookEnvelopeV1 {
        let observed = wallMilliseconds()
        let source = try HookEnvelopeV1.rawFields(rawHook, deadline: deadline)
        var fields: [String: JSONValue] = [:]
        for name in ["session_id", "hook_event_name", "tool_use_id", "tool_name", "cwd"] {
            fields[name] = source[name]
        }
        // Missing IDs remain missing. Claude's source turn identity is prompt_id, not turn_id.
        fields["turn_id"] = source["prompt_id"]
        return try HookEnvelopeV1.projected(fields, agent: .claude, observedAtMs: observed,
                                            paneSelector: paneSelector)
    }
}
