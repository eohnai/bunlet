import Foundation
import Testing
@testable import EventBridge

extension Agent {
    /// Agents whose hooks use the Claude/Codex payload shape (`session_id`, `hook_event_name`, …).
    static let hookShaped: [Agent] = [.codex, .claude]
}

/// Decision 0025: terminal identity, subagent IDs and Cursor CLI events. Fictional data only.
struct ReferenceAdoptionTests {
    private func raw(_ fields: [String: Any]) throws -> Data {
        try JSONSerialization.data(withJSONObject: fields, options: [.sortedKeys])
    }

    // MARK: Terminal detection

    @Test func tmuxWinsOverTheTerminalItRunsIn() {
        let terminal = TerminalDetection.terminal(environment: [
            "TMUX": "/private/tmp/tmux-501/default,123,0", "TMUX_PANE": "%7",
            "OTTY_PANE_ID": "fictional-pane", "__CFBundleIdentifier": "io.appmakes.otty",
        ], tty: { nil })
        #expect(terminal == HookEnvelopeV1.Terminal(kind: .tmux, paneSelector: "%7",
                                                   socket: "/private/tmp/tmux-501/default", app: "io.appmakes.otty"))
    }

    @Test func ottyAppleTerminalAndEditorsAreRecognized() {
        #expect(TerminalDetection.terminal(environment: ["OTTY_PANE_ID": "fictional-pane"], tty: { nil })?.kind == .otty)
        let apple = TerminalDetection.terminal(environment: ["TERM_PROGRAM": "Apple_Terminal"], tty: { "/dev/ttys004" })
        #expect(apple == HookEnvelopeV1.Terminal(kind: .appleTerminal, paneSelector: "/dev/ttys004"))
        let cursor = TerminalDetection.terminal(environment: ["TERM_PROGRAM": "vscode",
                                                              "__CFBundleIdentifier": "com.todesktop.230313mzl4w4u92"], tty: { nil })
        #expect(cursor == HookEnvelopeV1.Terminal(kind: .editor, paneSelector: "com.todesktop.230313mzl4w4u92"))
    }

    @Test func unusableValuesYieldNoTerminal() {
        // A bad tmux pane falls through to the next hint instead of failing the event.
        #expect(TerminalDetection.terminal(environment: ["TMUX": "/tmp/s,1,0", "TMUX_PANE": "7; rm"], tty: { nil }) == nil)
        #expect(TerminalDetection.terminal(environment: ["TERM_PROGRAM": "Apple_Terminal"], tty: { "/dev/console" }) == nil)
        // An editor Bunlet cannot open folders in is still known as an app (decision 0026).
        #expect(TerminalDetection.terminal(environment: ["TERM_PROGRAM": "vscode", "__CFBundleIdentifier": "com.example.unknown"],
                                           tty: { nil }) == HookEnvelopeV1.Terminal(kind: .app, paneSelector: "com.example.unknown"))
        #expect(TerminalDetection.terminal(environment: ["TERM_PROGRAM": "iTerm.app"], tty: { "/dev/ttys001" }) == nil)
    }

    @Test func terminalSurvivesTheWireAndBadKindsAreRejected() throws {
        let terminal = HookEnvelopeV1.Terminal(kind: .tmux, paneSelector: "%12", socket: "/private/tmp/tmux-501/default")
        let envelope = try HookEnvelopeV1.project(rawHook: raw(["session_id": "fictional", "hook_event_name": "SessionStart"]),
                                                  agent: .claude, terminal: terminal)
        #expect(try HookEnvelopeV1.decode(frame: envelope.frame()).terminal == terminal)
        for bad in [#"{"kind":"tmux","pane_selector":"%1"}"#, #"{"kind":"apple_terminal","pane_selector":"/dev/ttys1x"}"#,
                    #"{"kind":"otty","pane_selector":"p","app":"io.appmakes.otty"}"#, #"{"kind":"iterm","pane_selector":"p"}"#] {
            let frame = Data((#"{"agent":"claude","event_id":"00000000-0000-0000-0000-000000000001","hook_event_name":"SessionStart","observed_at_ms":1,"session_id":"s","terminal":"#
                + bad + "," + #""version":1}"# + "\n").utf8)
            #expect(throws: BridgeError.self) { try HookEnvelopeV1.decode(frame: frame) }
        }
    }

    // MARK: Subagents

    @Test func subagentEventsCarryOnlyTheirID() throws {
        let envelope = try HookEnvelopeV1.project(rawHook: raw([
            "session_id": "fictional", "prompt_id": "turn", "hook_event_name": "SubagentStart",
            "agent_id": "sub-1", "agent_type": "private-marker", "agent_transcript_path": "/private-marker",
        ]), agent: .claude)
        #expect(envelope.hookEventName == .subagentStart && envelope.agentID == "sub-1")
        #expect(!String(decoding: try envelope.frame(), as: UTF8.self).contains("private-marker"))
        // Other events may not carry a subagent ID, and subagent events must.
        let stop = Data(#"{"agent":"claude","agent_id":"sub-1","event_id":"00000000-0000-0000-0000-000000000001","hook_event_name":"Stop","observed_at_ms":1,"session_id":"s","version":1}"#.utf8) + Data([10])
        #expect(throws: BridgeError.self) { try HookEnvelopeV1.decode(frame: stop) }
        #expect(throws: BridgeError.self) {
            try HookEnvelopeV1.project(rawHook: raw(["session_id": "s", "hook_event_name": "SubagentStop"]), agent: .claude)
        }
    }

    @Test func onlyClaudeInstallsSubagentHooks() {
        #expect(HookEvent.lifecycle(for: .claude).contains(.subagentStart))
        #expect(HookEvent.lifecycle(for: .codex) == HookEvent.core)
    }

    // MARK: Cursor CLI

    @Test func cursorPromptBecomesASubmitWithItsGenerationAsTheTurn() throws {
        let envelope = try HookEnvelopeV1.project(rawHook: raw([
            "hook_event_name": "beforeSubmitPrompt", "conversation_id": "conv", "generation_id": "gen",
            "workspace_roots": ["/fictional/project"], "prompt": "Add a test", "attachments": ["private-marker"],
        ]), agent: .cursor)
        #expect(envelope.agent == .cursor && envelope.hookEventName == .userPromptSubmit)
        #expect(envelope.sessionID == "conv" && envelope.turnID == "gen" && envelope.cwd == "/fictional/project")
        #expect(envelope.promptPreview == "Add a test")
        #expect(!String(decoding: try envelope.frame(), as: UTF8.self).contains("private-marker"))
    }

    @Test func cursorToolsKeepOnlyAGenericName() throws {
        let shell = try HookEnvelopeV1.project(rawHook: raw([
            "hook_event_name": "beforeShellExecution", "conversation_id": "conv", "generation_id": "gen",
            "command": "private-marker", "cwd": "/fictional/project",
        ]), agent: .cursor)
        #expect(shell.hookEventName == .preToolUse && shell.toolName == "Shell")
        #expect(!String(decoding: try shell.frame(), as: UTF8.self).contains("private-marker"))
        let stop = try HookEnvelopeV1.project(rawHook: raw(["hook_event_name": "stop", "conversation_id": "conv",
                                                            "generation_id": "gen", "status": "completed"]), agent: .cursor)
        #expect(stop.hookEventName == .stop && stop.replyPreview == nil)
        #expect(throws: BridgeError.self) {
            try HookEnvelopeV1.project(rawHook: raw(["hook_event_name": "afterAgentThought", "conversation_id": "c"]), agent: .cursor)
        }
    }

    @Test func versionsFollowEachAgentsFormat() {
        #expect(Agent.cursor.isVersion("2026.09.18-9a7762b"))
        #expect(!Agent.cursor.isVersion("0.164.0") && !Agent.cursor.isVersion("2026.9.18-9a7762b"))
        #expect(Agent.codex.isVersion("0.169.0") && !Agent.codex.isVersion("2026.09.18-9a7762b"))
    }
}
