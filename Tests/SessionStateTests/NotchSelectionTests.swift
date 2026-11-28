import EventBridge
import Testing
@testable import SessionState

struct NotchSelectionTests {
    private func snapshot(_ id: String, agent: Agent = .codex, status: SessionStatus = .working,
                          pending: [SessionRequest] = []) -> SessionSnapshot {
        SessionSnapshot(key: SessionKey(agent: agent, sessionID: id), status: status,
                        currentTurnID: nil, turnStartedAtMs: nil,
                        responseReadyAtMs: nil, pendingRequests: pending,
                        captureWatermarkMs: nil, receiptWallMs: nil, receiptMonotonicNs: nil,
                        projectPath: "/fictional/shared", paneSelector: nil,
                        hasTerminalRestriction: status == .ended)
    }

    @Test func activeProvidersFollowObservedSessionsOnly() {
        #expect(NotchPresentation.activeProviders([]).isEmpty)
        #expect(NotchPresentation.activeProviders([snapshot("a")]) == [.codex])
        #expect(NotchPresentation.activeProviders([snapshot("a", agent: .claude)]) == [.claude])
        #expect(NotchPresentation.activeProviders([snapshot("a"), snapshot("b", agent: .claude)]) == [.codex, .claude])
    }

    @Test func inactiveProvidersDoNotAppear() {
        #expect(NotchPresentation.activeProviders([snapshot("a", status: .ended),
                                                   snapshot("b", agent: .claude, status: .ended)]).isEmpty)
        #expect(NotchPresentation.activeProviders([snapshot("a"), snapshot("b")]).count == 1)
    }

    @Test(arguments: Agent.allCases)
    func providerVisibilityRequiresItsOwnActiveSession(provider: Agent) {
        let other: Agent = provider == .codex ? .claude : .codex
        let inactive = [snapshot("ended", agent: other, status: .ended)]
        #expect(NotchPresentation.activeProviders(inactive).isEmpty)
        for status in [SessionStatus.idle, .working, .questionNeeded, .approvalNeeded, .responseReady] {
            let active = snapshot("active", agent: provider, status: status)
            #expect(NotchPresentation.activeProviders(inactive + [active]) == [provider])
        }
        #expect(NotchPresentation.activeProviders(inactive + [
            snapshot("inactive", agent: provider, status: .ended)
        ]).isEmpty)
    }

    @Test func waitingRequestsPrecedeResponseAndWork() {
        let request = SessionRequest(eventID: "event", turnID: "turn", toolUseID: "tool",
                                     toolName: "Bash", kind: .approvalNeeded)
        let question = SessionRequest(eventID: "other", turnID: "other", toolUseID: "other",
                                      toolName: "AskUserQuestion", kind: .questionNeeded)
        let sessions = [snapshot("idle", status: .idle), snapshot("question", status: .questionNeeded, pending: [question]),
                        snapshot("working"), snapshot("ready", status: .responseReady),
                        snapshot("approval", status: .approvalNeeded, pending: [request])]
        let ordered = NotchPresentation.ordered(sessions)
        #expect(ordered.map(\.key.sessionID) == ["approval", "question", "ready", "working", "idle"])
    }

    @Test func validSelectionSurvivesPriorityChanges() {
        let chosen = snapshot("selected", agent: .claude)
        let ready = snapshot("ready", status: .responseReady)
        #expect(NotchPresentation.selection(chosen.key, sessions: [ready, chosen]) == chosen.key)
        #expect(NotchPresentation.selection(nil, sessions: [chosen, ready]) == ready.key)
    }

    @Test func removedSelectionFallsBackAndTiesAreDeterministic() {
        let a = snapshot("a"), b = snapshot("b")
        #expect(NotchPresentation.ordered([b, a]).map(\.key) == [a.key, b.key])
        #expect(NotchPresentation.selection(SessionKey(agent: .claude, sessionID: "a"), sessions: [b, a]) == a.key)
        #expect(NotchPresentation.selection(a.key, sessions: []) == nil)
    }
}
