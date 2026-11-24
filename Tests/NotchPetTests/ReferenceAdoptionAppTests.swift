import EventBridge
import Foundation
import SessionState
import Testing
@testable import AgentActions
@testable import NotchPet

/// Decision 0025 app behavior: Codex approvals, consent per agent and typed follow-ups. Fictional data only.
@MainActor
struct ReferenceAdoptionAppTests {
    private let now: Int64 = 1_000_000

    private func codexRequest(_ extra: String = "") -> Data {
        Data("""
        {"session_id":"s1","turn_id":"t1","hook_event_name":"PermissionRequest","tool_name":"Bash",
         "tool_use_id":"u1","tool_input":{"command":"ls"}\(extra)}
        """.utf8)
    }

    // MARK: Codex approvals

    @Test func codexOffersAllowOnceAndDenyOnly() throws {
        let offer = try #require(try CodexHookActionAdapter.offer(raw: codexRequest(), nowMs: now))
        #expect(offer.provider == .codex && offer.kind == .permission && offer.turnID == "t1" && !offer.canAllowAlways)
        let allow = try #require(try CodexHookActionAdapter.providerOutput(
            for: ActionDecision(requestID: offer.id, choice: .approveOnce), offer: offer))
        let object = try #require(JSONSerialization.jsonObject(with: allow) as? [String: Any])
        let hook = try #require(object["hookSpecificOutput"] as? [String: Any])
        #expect(hook["hookEventName"] as? String == "PermissionRequest")
        #expect((hook["decision"] as? [String: Any])?["behavior"] as? String == "allow")
        #expect(!ActionProtocol.valid(ActionDecision(requestID: offer.id, choice: .allowAlways), for: offer))
    }

    @Test func codexRequestsCodexWouldNotAskAboutAreLeftAlone() throws {
        #expect(try CodexHookActionAdapter.offer(raw: codexRequest(#","permission_mode":"bypassPermissions""#), nowMs: now) == nil)
        let question = Data(#"{"session_id":"s1","turn_id":"t1","hook_event_name":"Stop"}"#.utf8)
        #expect(try CodexHookActionAdapter.offer(raw: question, nowMs: now) == nil)
    }

    @Test func codexQuestionsAndFollowUpsAreNotValidOffers() {
        let followUp = ActionOffer(version: 1, id: UUID(), provider: .codex, sessionID: "s", turnID: "t", toolUseID: nil,
                                   toolName: nil, kind: .followUp, capturedAtMs: now, input: nil, questions: [])
        #expect(!ActionProtocol.valid(followUp, nowMs: now))
    }

    @Test func consentIsPerAgentAndCodexDefaultsToTheTerminal() {
        let defaults = UserDefaults(suiteName: "bunlet-consent-\(UUID().uuidString)")!
        let model = ProviderMonitoringModel(defaults: defaults) { _ in }
        #expect(model.actionAgents.isEmpty)
        model.setActionsEnabled(true, for: .codex)
        #expect(model.actionAgents == [.codex] && !model.actionsEnabled)
        #expect(ProviderMonitoringModel(defaults: defaults) { _ in }.actionAgents == [.codex])
        #expect(model.isEnabled(.cursor))
    }

    // MARK: Follow-ups typed into a pane

    private func store(at status: String, kind: String = "otty") throws -> SessionStore {
        let store = SessionStore()
        let selector = kind == "otty" ? "fictional-pane" : "/dev/ttys003"
        let hooks = status == "ready" ? ["UserPromptSubmit", "Stop"] : ["UserPromptSubmit"]
        for (index, hook) in hooks.enumerated() {
            let observed = 1_000_000 + Int64(index)
            let fields: [String: Any] = ["version": 1, "event_id": String(format: "00000000-0000-0000-0000-%012x", index + 1),
                "agent": "claude", "session_id": "fictional", "hook_event_name": hook, "observed_at_ms": observed,
                "turn_id": "a", "terminal": ["kind": kind, "pane_selector": selector]]
            let frame = try JSONSerialization.data(withJSONObject: fields, options: [.sortedKeys]) + Data([10])
            store.apply(SessionObservationV1(envelope: try HookEnvelopeV1.decode(frame: frame), receiptWallMs: observed,
                                             receiptMonotonicNs: UInt64(observed) * 1_000_000))
        }
        return store
    }

    private let key = SessionKey(agent: .claude, sessionID: "fictional")

    @Test func aReplyIsTypedOnceAsOneLine() async throws {
        let sent = SentLines()
        let replies = TerminalReplyController(sessions: try store(at: "ready")) { text, _ in
            await sent.append(text)
            return true
        }
        replies.setDraft("run the\ntests", for: key)
        #expect(replies.canSend(key))
        replies.send(key)
        replies.send(key)
        while replies.phases[key] == .sending { await Task.yield() }
        #expect(replies.phases[key] == .sent && replies.draft(for: key).isEmpty)
        #expect(await sent.lines == ["run the tests"])
    }

    @Test func aFailedSendKeepsTheDraftAndIsNotRetried() async throws {
        let sent = SentLines()
        let replies = TerminalReplyController(sessions: try store(at: "ready")) { text, _ in
            await sent.append(text)
            return false
        }
        replies.setDraft("continue", for: key)
        replies.send(key)
        while replies.phases[key] == .sending { await Task.yield() }
        #expect(replies.phases[key] == .failed && replies.draft(for: key) == "continue")
        #expect(await sent.lines.count == 1)
    }

    @Test func nothingIsTypedWhileWorkingOrIntoAnUnaddressableTab() throws {
        let working = TerminalReplyController(sessions: try store(at: "working")) { _, _ in true }
        working.setDraft("hello", for: key)
        #expect(!working.canSend(key))
        let tab = TerminalReplyController(sessions: try store(at: "ready", kind: "apple_terminal")) { _, _ in true }
        tab.setDraft("hello", for: key)
        #expect(!tab.canSend(key))
    }
}

/// Decision 0026: jump helpers that need no running terminal. Fictional data only.
struct AnyTerminalAppTests {
    @Test func tmuxClientsAreOrderedByActivity() {
        #expect(TerminalTargets.tmuxClients("100 501\n300 502\nbad line\n200 1\n250 503\n") == [502, 503, 501])
        #expect(TerminalTargets.tmuxClients("").isEmpty)
    }

    @Test func selectionScriptsAcceptOnlyValidatedAddresses() {
        let session = "6A0E2F4C-1B3D-4E5F-8A9B-0C1D2E3F4A5B"
        #expect(TerminalTargets.itermSelect(session: session)?.contains(session) == true)
        #expect(TerminalTargets.itermSelect(session: "\" & (do shell script \"x\") & \"") == nil)
        #expect(TerminalTargets.appleTerminalSelect(tty: "/dev/ttys004") != nil)
        #expect(TerminalTargets.appleTerminalSelect(tty: "/dev/ttys004\"") == nil)
    }
}

private actor SentLines {
    private(set) var lines: [String] = []
    func append(_ line: String) { lines.append(line) }
}
