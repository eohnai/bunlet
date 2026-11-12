import Foundation

/// Projects the seven Codex hook shapes covered by the recorded investigation.
/// Interactive coverage and hook installation are separate verification and setup tasks.
public enum CodexEventAdapter {
    public static func project(rawHook: Data, paneSelector: String? = nil) throws -> HookEnvelopeV1 {
        try project(rawHook: rawHook, paneSelector: paneSelector, deadline: nil)
    }

    static func project(rawHook: Data, paneSelector: String?, deadline: UInt64?) throws -> HookEnvelopeV1 {
        let observed = wallMilliseconds()
        let source = try HookEnvelopeV1.rawFields(rawHook, deadline: deadline)
        var fields: [String: JSONValue] = [:]
        for name in ["session_id", "hook_event_name", "turn_id", "tool_use_id", "tool_name", "cwd"] {
            fields[name] = source[name]
        }
        // Missing IDs remain missing. Never read a transcript or infer a turn from another field.
        // Only the two display previews from decision 0019; tool input and transcripts stay excluded.
        switch source["hook_event_name"]?.string {
        case HookEvent.userPromptSubmit.rawValue: fields["prompt_preview"] = HookEnvelopeV1.preview(source["prompt"])
        case HookEvent.stop.rawValue: fields["reply_preview"] = HookEnvelopeV1.preview(source["last_assistant_message"])
        default: break
        }
        return try HookEnvelopeV1.projected(fields, agent: .codex, observedAtMs: observed,
                                            paneSelector: paneSelector)
    }
}
