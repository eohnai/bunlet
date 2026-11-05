import Foundation
import Testing
@testable import EventBridge

struct EventIdentityTests {
    @Test func identityCasesMatchTheVersionOneAllowlist() {
        #expect(Agent.allCases.map(\.rawValue) == ["codex", "claude"])
        #expect(HookEvent.allCases.map(\.rawValue) == [
            "SessionStart", "UserPromptSubmit", "PreToolUse", "PermissionRequest",
            "PostToolUse", "Stop", "SessionEnd"
        ])
        for name in ["", "Codex", "unsupported"] {
            #expect(Agent(rawValue: name) == nil)
        }
        for name in ["", "sessionStart", "SubagentStop", "StopFailure"] {
            #expect(HookEvent(rawValue: name) == nil)
        }
    }

    @Test(arguments: ["codex", "claude"], [
        "SessionStart", "UserPromptSubmit", "PreToolUse", "PermissionRequest",
        "PostToolUse", "Stop", "SessionEnd"
    ])
    func typedDecodePreservesExactWireBytes(agentName: String, hookName: String) throws {
        let agent = try #require(Agent(rawValue: agentName))
        let hook = try #require(HookEvent(rawValue: hookName))
        let toolField = ["PreToolUse", "PermissionRequest", "PostToolUse"].contains(hookName)
            ? ",\"tool_name\":\"Bash\"" : ""
        let wire = Data(("{\"agent\":\"\(agentName)\",\"event_id\":\"00000000-0000-4000-8000-000000000001\","
            + "\"hook_event_name\":\"\(hookName)\",\"observed_at_ms\":1000000,\"session_id\":\"fictional\""
            + toolField + ",\"version\":1}\n").utf8)
        let envelope = try HookEnvelopeV1.decode(frame: wire)
        let decodedAgent: Agent = envelope.agent
        let decodedHook: HookEvent = envelope.hookEventName
        #expect(decodedAgent == agent)
        #expect(decodedHook == hook)
        #expect(try envelope.frame() == wire)

        let raw = Data(("{\"session_id\":\"fictional\",\"hook_event_name\":\"\(hookName)\""
            + toolField + "}").utf8)
        let projected = try HookEnvelopeV1.project(rawHook: raw, agent: agent)
        #expect(projected.agent == agent)
        #expect(projected.hookEventName == hook)
    }

    @Test(arguments: ["codex", "claude"])
    func typedDecodeRejectsUnknownWireIdentities(agentName: String) throws {
        for (agent, hook) in [("unsupported", "SessionStart"), (agentName, "StopFailure")] {
            let wire = Data(("{\"version\":1,\"event_id\":\"00000000-0000-4000-8000-000000000001\","
                + "\"agent\":\"\(agent)\",\"session_id\":\"fictional\","
                + "\"hook_event_name\":\"\(hook)\",\"observed_at_ms\":1000000}\n").utf8)
            #expect(throws: BridgeError.invalidMessage) { try HookEnvelopeV1.decode(frame: wire) }
        }
    }
}
