import Foundation
import Testing
@testable import EventBridge

/// Decision 0019: only bounded prompt/reply previews enter the envelope, and only on their own hooks.
struct PreviewProjectionTests {
    private func raw(_ fields: [String: Any]) throws -> Data {
        try JSONSerialization.data(withJSONObject: fields, options: [.sortedKeys])
    }

    private func project(_ agent: Agent, _ fields: [String: Any]) throws -> HookEnvelopeV1 {
        var fields = fields
        fields["session_id"] = "fictional"
        fields[agent == .claude ? "prompt_id" : "turn_id"] = "turn"
        return try HookEnvelopeV1.project(rawHook: raw(fields), agent: agent)
    }

    @Test(arguments: Agent.allCases)
    func submitCarriesPromptPreviewOnly(agent: Agent) throws {
        let envelope = try project(agent, ["hook_event_name": "UserPromptSubmit", "prompt": "Fix the\n\tlogin  bug",
                                           "last_assistant_message": "private-marker",
                                           "tool_input": ["command": "private-marker"]])
        #expect(envelope.promptPreview == "Fix the login bug")
        #expect(envelope.replyPreview == nil)
        let wire = String(decoding: try envelope.frame(), as: UTF8.self)
        #expect(!wire.contains("private-marker"))
        #expect(try HookEnvelopeV1.decode(frame: envelope.frame()).promptPreview == "Fix the login bug")
    }

    @Test(arguments: Agent.allCases)
    func stopCarriesReplyPreviewOnly(agent: Agent) throws {
        let envelope = try project(agent, ["hook_event_name": "Stop", "prompt": "private-marker",
                                           "last_assistant_message": "Updated 3 files."])
        #expect(envelope.replyPreview == "Updated 3 files.")
        #expect(envelope.promptPreview == nil)
        #expect(!String(decoding: try envelope.frame(), as: UTF8.self).contains("private-marker"))
    }

    @Test(arguments: Agent.allCases)
    func otherHooksCarryNoPreview(agent: Agent) throws {
        let envelope = try project(agent, ["hook_event_name": "PreToolUse", "tool_name": "Bash",
                                           "prompt": "private-marker", "last_assistant_message": "private-marker"])
        #expect(envelope.promptPreview == nil && envelope.replyPreview == nil)
    }

    @Test func longTextIsCutToCharacterThenByteLimits() throws {
        let long = try #require(HookEnvelopeV1.preview(.string(String(repeating: "a", count: 500)))?.string)
        #expect(long.count == HookEnvelopeV1.previewCharacterLimit)
        #expect(long.hasSuffix("…"))
        let wide = try #require(HookEnvelopeV1.preview(.string(String(repeating: "🐇", count: 500)))?.string)
        #expect(wide.utf8.count <= HookEnvelopeV1.previewByteLimit)
        #expect(wide.hasSuffix("…"))
    }

    @Test func emptyOrNonTextSourcesAreOmitted() {
        #expect(HookEnvelopeV1.preview(.string(" \n\t ")) == nil)
        #expect(HookEnvelopeV1.preview(.number("1")) == nil)
        #expect(HookEnvelopeV1.preview(.null) == nil)
        #expect(HookEnvelopeV1.preview(nil) == nil)
        #expect(HookEnvelopeV1.preview(.string("a\u{202E}b\u{0007}c"))?.string == "ab c")
    }

    @Test func previewOnWrongHookIsRejectedOnTheWire() {
        let frame = Data("""
        {"agent":"codex","event_id":"00000000-0000-4000-8000-000000000001","hook_event_name":"Stop",\
        "observed_at_ms":1,"prompt_preview":"x","session_id":"s","version":1}

        """.utf8)
        #expect(throws: BridgeError.invalidMessage) { try HookEnvelopeV1.decode(frame: frame) }
    }
}
