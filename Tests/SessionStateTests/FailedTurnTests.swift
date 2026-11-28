import EventBridge
import Foundation
import SessionState
import Testing

/// Decision 0030: Claude's `StopFailure` ends the turn and marks it failed. Fictional data only.
@MainActor
struct FailedTurnTests {
    private func observation(_ number: Int, hook: String, turnID: String? = "a") throws -> SessionObservationV1 {
        let observed = 1_000_000 + Int64(number)
        var fields: [String: Any] = [
            "version": 1, "event_id": String(format: "00000000-0000-0000-0000-%012x", number),
            "agent": "claude", "session_id": "fictional", "hook_event_name": hook, "observed_at_ms": observed,
        ]
        fields["turn_id"] = turnID
        let frame = try JSONSerialization.data(withJSONObject: fields, options: [.sortedKeys]) + Data([10])
        return SessionObservationV1(envelope: try HookEnvelopeV1.decode(frame: frame), receiptWallMs: observed,
                                    receiptMonotonicNs: UInt64(observed) * 1_000_000)
    }

    @Test func failureEndsTheTurnAndNotifiesAsACompletion() throws {
        let store = SessionStore()
        _ = store.apply(try observation(1, hook: "UserPromptSubmit"))
        let working = store.sessions
        #expect(store.apply(try observation(2, hook: "StopFailure")) == .applied)
        let session = try #require(store.sessions.first)
        #expect(session.status == .responseReady)
        #expect(session.turnFailed)
        #expect(IslandNotification.next(previous: working, current: store.sessions) == .completed(session.key))
    }

    @Test func theNextTurnClearsTheFailure() throws {
        let store = SessionStore()
        _ = store.apply(try observation(1, hook: "UserPromptSubmit"))
        _ = store.apply(try observation(2, hook: "StopFailure"))
        #expect(store.apply(try observation(3, hook: "UserPromptSubmit", turnID: "b")) == .applied)
        #expect(store.sessions.first?.turnFailed == false)
        _ = store.apply(try observation(4, hook: "Stop", turnID: "b"))
        #expect(store.sessions.first?.status == .responseReady)
        #expect(store.sessions.first?.turnFailed == false)
    }

    @Test func aFailureWithoutTurnIdentityChangesNothing() throws {
        let store = SessionStore()
        _ = store.apply(try observation(1, hook: "UserPromptSubmit"))
        #expect(store.apply(try observation(2, hook: "StopFailure", turnID: nil)) == .noChange)
        #expect(store.sessions.first?.status == .working)
    }

    @Test func onlyClaudeInstallsTheFailureHook() {
        #expect(HookEvent.lifecycle(for: .claude).contains(.stopFailure))
        #expect(!HookEvent.lifecycle(for: .codex).contains(.stopFailure))
        #expect(!HookEvent.lifecycle(for: .cursor).contains(.stopFailure))
    }
}
