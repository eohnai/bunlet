import Foundation
import Testing
@testable import EventBridge

struct ClaudeEventAdapterTests {
    private func raw(_ fields: [String: Any]) throws -> Data {
        try JSONSerialization.data(withJSONObject: fields, options: [.sortedKeys])
    }

    @Test func reconstructedClaudeExamplesPreserveSourceFields() throws {
        let fixture = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().appendingPathComponent("docs/notes/agent-event-examples.json")
        let document = try #require(JSONSerialization.jsonObject(with: Data(contentsOf: fixture)) as? [String: Any])
        let examples = try #require(document["examples"] as? [[String: Any]])
            .filter { $0["agent"] as? String == "claude" }
        #expect(examples.count == 8)
        for example in examples {
            let payload = try #require(example["payload"] as? [String: Any])
            let input = try raw(payload)
            let direct = try ClaudeEventAdapter.project(rawHook: input, paneSelector: "fictional-pane")
            let routed = try HookEnvelopeV1.project(rawHook: input, agent: .claude, paneSelector: "fictional-pane")
            for envelope in [direct, routed] {
                #expect(envelope.agent == .claude)
                #expect(envelope.sessionID == payload["session_id"] as? String)
                #expect(envelope.hookEventName.rawValue == payload["hook_event_name"] as? String)
                #expect(envelope.turnID == payload["prompt_id"] as? String)
                #expect(envelope.toolUseID == payload["tool_use_id"] as? String)
                #expect(envelope.toolName == payload["tool_name"] as? String)
                #expect(envelope.cwd == payload["cwd"] as? String)
                #expect(envelope.terminal?.paneSelector == "fictional-pane")
                #expect(try HookEnvelopeV1.decode(frame: envelope.frame()).sessionID == envelope.sessionID)
            }
            #expect(direct.eventID != routed.eventID)
        }
    }

    @Test func contentAndSourceMetadataCannotEnterEnvelope() throws {
        let input = try raw([
            "session_id": "fictional", "hook_event_name": "PreToolUse", "prompt_id": "prompt",
            "turn_id": "source-controlled", "tool_use_id": "call", "tool_name": "AskUserQuestion", "cwd": "/example",
            "agent": "codex", "event_id": "source-controlled", "observed_at_ms": 1, "version": 99,
            "terminal": ["kind": "otty", "pane_selector": "source-controlled"],
            "prompt": "private-marker", "last_assistant_message": "private-marker",
            "tool_input": ["questions": [["question": "private-marker"]]],
            "tool_response": "private-marker", "transcript_path": "/private-marker/missing.jsonl",
            "credentials": "fictional-private-marker", "background_tasks": ["private-marker"]
        ])
        let before = Int64(Date().timeIntervalSince1970 * 1000)
        let envelope = try ClaudeEventAdapter.project(rawHook: input)
        let after = Int64(Date().timeIntervalSince1970 * 1000)
        #expect(envelope.version == 1 && envelope.agent == .claude && envelope.turnID == "prompt")
        #expect(envelope.observedAtMs >= before && envelope.observedAtMs <= after)
        #expect(UUID(uuidString: envelope.eventID)?.uuidString.lowercased() == envelope.eventID)
        #expect(envelope.terminal == nil)
        let frame = try envelope.frame()
        let fields = try #require(JSONSerialization.jsonObject(with: frame) as? [String: Any])
        #expect(Set(fields.keys) == ["version", "event_id", "agent", "observed_at_ms", "session_id",
                                     "hook_event_name", "turn_id", "tool_use_id", "tool_name", "cwd"])
        #expect(!String(decoding: frame, as: UTF8.self).contains("private-marker"))
        #expect(!String(decoding: frame, as: UTF8.self).contains("source-controlled"))
    }

    @Test func missingIdentitiesAreNotInferredFromOtherFields() throws {
        let envelope = try ClaudeEventAdapter.project(rawHook: raw([
            "session_id": "fictional", "hook_event_name": "PermissionRequest", "tool_name": "Write",
            "turn_id": "not-a-claude-prompt", "id": "not-a-call", "cwd": "/example"
        ]))
        #expect(envelope.turnID == nil && envelope.toolUseID == nil && envelope.terminal == nil)
        let minimal = try ClaudeEventAdapter.project(rawHook: raw([
            "session_id": "fictional", "hook_event_name": "SessionStart"
        ]))
        #expect(minimal.cwd == nil && minimal.turnID == nil)
        #expect(minimal.toolName == nil && minimal.toolUseID == nil)
    }

    @Test(arguments: ["StopFailure", "Notification", "Elicitation", "ElicitationResult", "Interrupt",
                      "SubagentStart", "SubagentStop", "PreCompact", "PostCompact", "sessionStart"])
    func unverifiedHooksAreRejected(hook: String) throws {
        let input = try raw(["session_id": "fictional", "hook_event_name": hook])
        #expect(throws: BridgeError.invalidMessage) { try ClaudeEventAdapter.project(rawHook: input) }
        #expect(throws: BridgeError.invalidMessage) { try HookEnvelopeV1.project(rawHook: input, agent: .claude) }
    }

    @Test func invalidSourceFieldsAreRejectedWithoutGuessing() throws {
        let invalid: [[String: Any]] = [
            ["hook_event_name": "SessionStart"],
            ["session_id": "fictional"],
            ["session_id": "", "hook_event_name": "SessionStart"],
            ["session_id": NSNull(), "hook_event_name": "SessionStart"],
            ["session_id": 1, "hook_event_name": "SessionStart"],
            ["session_id": "fictional", "hook_event_name": true],
            ["session_id": "fictional", "hook_event_name": "SessionStart", "prompt_id": NSNull()],
            ["session_id": "fictional", "hook_event_name": "Stop", "prompt_id": 1, "turn_id": "no-fallback"],
            ["session_id": "fictional", "hook_event_name": "SessionStart", "cwd": "relative"],
            ["session_id": "fictional", "hook_event_name": "SessionStart", "tool_name": "Write"],
            ["session_id": "fictional", "hook_event_name": "Stop", "tool_use_id": "call"],
            ["session_id": "fictional", "hook_event_name": "PreToolUse"],
            ["session_id": "fictional", "hook_event_name": "PermissionRequest", "tool_name": NSNull()],
            ["session_id": "fictional", "hook_event_name": "PostToolUse", "tool_name": "Write", "tool_use_id": 1],
            ["session_id": "fictional\n", "hook_event_name": "SessionStart"]
        ]
        for fields in invalid {
            #expect(throws: BridgeError.invalidMessage) { try ClaudeEventAdapter.project(rawHook: raw(fields)) }
        }
        let input = try raw(["session_id": "fictional", "hook_event_name": "SessionStart"])
        #expect(throws: BridgeError.invalidMessage) {
            try ClaudeEventAdapter.project(rawHook: input, paneSelector: "invalid\npane")
        }
    }

    @Test func rawInputAndIdentityLimitsApplyToDirectAdapter() throws {
        let minimal = try raw(["session_id": "fictional", "hook_event_name": "SessionStart"])
        let boundary = minimal + Data(repeating: 32, count: HookEnvelopeV1.rawHookLimit - minimal.count)
        #expect(try ClaudeEventAdapter.project(rawHook: boundary).sessionID == "fictional")
        #expect(throws: BridgeError.invalidMessage) { try ClaudeEventAdapter.project(rawHook: boundary + Data([32])) }
        let atLimit = String(repeating: "é", count: 128)
        #expect(try ClaudeEventAdapter.project(rawHook: raw([
            "session_id": "fictional", "hook_event_name": "UserPromptSubmit", "prompt_id": atLimit
        ])).turnID == atLimit)
        #expect(throws: BridgeError.invalidMessage) {
            try ClaudeEventAdapter.project(rawHook: raw([
                "session_id": "fictional", "hook_event_name": "UserPromptSubmit", "prompt_id": atLimit + "a"
            ]))
        }
        for input in [Data([255]), Data("[]".utf8), minimal + minimal,
                      Data(#"{"session_id":"a","session_id":"b","hook_event_name":"SessionStart"}"#.utf8),
                      Data(#"{"session_id":"a","hook_event_name":"SessionStart","ignored":{"x":1,"x":2}}"#.utf8)] {
            #expect(throws: (any Error).self) { try ClaudeEventAdapter.project(rawHook: input) }
        }
        let nested = minimal.dropLast() + Data((",\"ignored\":" + String(repeating: "[", count: 64) + "0"
                               + String(repeating: "]", count: 64) + "}").utf8)
        #expect(throws: BridgeError.invalidMessage) { try ClaudeEventAdapter.project(rawHook: Data(nested)) }
    }

    @Test func helperDeadlineReachesClaudeParser() throws {
        let input = try raw(["session_id": "fictional", "hook_event_name": "SessionStart"])
        #expect(throws: BridgeError.timeout) {
            try ClaudeEventAdapter.project(rawHook: input, paneSelector: nil, deadline: 0)
        }
        #expect(throws: BridgeError.timeout) {
            try HookEnvelopeV1.project(rawHook: input, agent: .claude, paneSelector: nil, deadline: 0)
        }
    }
}
