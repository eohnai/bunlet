import EventBridge
import Foundation
import SessionState
import Testing

/// Decision 0025: subagent counts, terminal identity and when Bunlet may type into a pane. Fictional data only.
@MainActor
struct ReferenceAdoptionSessionTests {
    private func observation(_ number: Int, hook: String, agent: String = "claude", turnID: String? = "a",
                             toolUseID: String? = nil, toolName: String? = nil, agentID: String? = nil,
                             terminal: [String: String]? = nil) throws -> SessionObservationV1 {
        let observed = 1_000_000 + Int64(number)
        var fields: [String: Any] = [
            "version": 1, "event_id": String(format: "00000000-0000-0000-0000-%012x", number),
            "agent": agent, "session_id": "fictional", "hook_event_name": hook, "observed_at_ms": observed,
        ]
        fields["turn_id"] = turnID
        fields["tool_use_id"] = toolUseID
        fields["tool_name"] = toolName
        fields["agent_id"] = agentID
        fields["terminal"] = terminal
        let frame = try JSONSerialization.data(withJSONObject: fields, options: [.sortedKeys]) + Data([10])
        return SessionObservationV1(envelope: try HookEnvelopeV1.decode(frame: frame), receiptWallMs: observed,
                                    receiptMonotonicNs: UInt64(observed) * 1_000_000)
    }

    @Test func subagentsAreCountedWithoutChangingTheParent() throws {
        let store = SessionStore()
        #expect(store.apply(try observation(1, hook: "UserPromptSubmit")) == .applied)
        #expect(store.apply(try observation(2, hook: "SubagentStart", agentID: "one")) == .applied)
        #expect(store.apply(try observation(3, hook: "SubagentStart", agentID: "two")) == .applied)
        #expect(store.apply(try observation(4, hook: "SubagentStart", agentID: "two")) == .noChange)
        #expect(store.sessions.first?.runningSubagents == 2)
        #expect(store.sessions.first?.status == .working)
        #expect(store.apply(try observation(5, hook: "SubagentStop", agentID: "one")) == .applied)
        #expect(store.apply(try observation(6, hook: "SubagentStop", agentID: "unknown")) == .noChange)
        #expect(store.sessions.first?.runningSubagents == 1)
        // Subagent events leave the parent's lifecycle evidence untouched, so its next tool event still applies.
        #expect(store.apply(try observation(7, hook: "PreToolUse", toolUseID: "t", toolName: "Task")) == .applied)
        #expect(store.sessions.first?.status == .working && store.sessions.first?.reason == nil)
        #expect(store.apply(try observation(8, hook: "Stop")) == .applied)
        #expect(store.sessions.first?.runningSubagents == 0)
    }

    @Test(arguments: [Agent.codex, .claude])
    func desktopSessionPreservesItsHostAcrossAttentionAndCompletion(agent: Agent) throws {
        let host = try #require(agent.desktopBundleIdentifier)
        let terminal = ["kind": "app", "pane_selector": host]
        let store = SessionStore()
        let key = SessionKey(agent: agent, sessionID: "fictional")
        _ = store.apply(try observation(1, hook: "SessionStart", agent: agent.rawValue, turnID: nil, terminal: terminal))
        _ = store.apply(try observation(2, hook: "UserPromptSubmit", agent: agent.rawValue))
        let working = store.sessions
        #expect(working.first?.status == .working)

        _ = store.apply(try observation(3, hook: "PermissionRequest", agent: agent.rawValue, toolUseID: "tool", toolName: "Bash"))
        #expect(IslandNotification.next(previous: working, current: store.sessions) == .attention(key))

        _ = store.apply(try observation(4, hook: "PostToolUse", agent: agent.rawValue, toolUseID: "tool", toolName: "Bash"))
        let beforeStop = store.sessions
        _ = store.apply(try observation(5, hook: "Stop", agent: agent.rawValue))
        #expect(IslandNotification.next(previous: beforeStop, current: store.sessions) == .completed(key))
        #expect(store.sessions.first?.terminal?.hostApp == host)
    }

    @Test func theLastReportedTerminalIsKept() throws {
        let store = SessionStore()
        let tmux = ["kind": "tmux", "pane_selector": "%3", "socket": "/private/tmp/tmux-501/default"]
        #expect(store.apply(try observation(1, hook: "UserPromptSubmit", terminal: tmux)) == .applied)
        let session = try #require(store.sessions.first)
        #expect(session.terminal == HookEnvelopeV1.Terminal(kind: .tmux, paneSelector: "%3", socket: "/private/tmp/tmux-501/default"))
        // The older Otty-only field keeps its meaning.
        #expect(session.paneSelector == nil)
        #expect(TerminalPolicy.canJump(session))
    }

    @Test func typingNeedsAnAddressablePaneAtItsPrompt() throws {
        let store = SessionStore()
        let otty = ["kind": "otty", "pane_selector": "fictional-pane"]
        #expect(store.apply(try observation(1, hook: "UserPromptSubmit", terminal: otty)) == .applied)
        #expect(!TerminalPolicy.canType(into: try #require(store.sessions.first)))
        #expect(store.apply(try observation(2, hook: "Stop")) == .applied)
        #expect(TerminalPolicy.canType(into: try #require(store.sessions.first)))

        let apple = SessionStore()
        let tab = ["kind": "apple_terminal", "pane_selector": "/dev/ttys002"]
        #expect(apple.apply(try observation(1, hook: "UserPromptSubmit", terminal: tab)) == .applied)
        #expect(apple.apply(try observation(2, hook: "Stop")) == .applied)
        let session = try #require(apple.sessions.first)
        #expect(TerminalPolicy.canJump(session) && !TerminalPolicy.canType(into: session))
    }

    @Test func repliesBecomeOneLine() {
        #expect(TerminalPolicy.singleLine("  fix it\nthen run tests\r\n") == "fix it then run tests")
        #expect(TerminalPolicy.singleLine("\u{3}stop") == "stop")
        #expect(TerminalPolicy.singleLine(" \n ") == nil)
        #expect(TerminalPolicy.singleLine(String(repeating: "a", count: TerminalPolicy.textLimit + 1)) == nil)
    }
}
