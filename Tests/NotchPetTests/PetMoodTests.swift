import Pet
@testable import SessionState
import Testing
@testable import NotchPet

/// The pet's mood describes the sessions the island and pet panel list (decision 0032).
@MainActor
struct PetMoodTests {
    private func session(_ id: String, _ status: SessionStatus) -> SessionSnapshot {
        SessionSnapshot(key: SessionKey(agent: .claude, sessionID: id), status: status,
                        reason: nil, currentTurnID: nil, turnStartedAtMs: 1_000,
                        responseReadyAtMs: nil, pendingRequests: [],
                        captureWatermarkMs: nil, receiptWallMs: nil, receiptMonotonicNs: nil,
                        projectPath: "/fictional/project", paneSelector: nil,
                        hasTerminalRestriction: false)
    }

    @Test func aSessionTheListHidesDoesNotSetTheMood() {
        let hidden = session("hidden", .unknown)
        let shown = session("shown", .working)
        #expect(PetSessionAdapter.mood(all: [hidden, shown], listed: [shown]) == .working)
    }

    @Test func endedShowsOnceEverySessionHasEnded() {
        let all = [session("a", .ended), session("b", .ended)]
        #expect(PetSessionAdapter.mood(all: all, listed: []) == .ended)
    }

    @Test func idleWhenOnlySomeHiddenSessionsHaveEnded() {
        let all = [session("a", .ended), session("b", .unknown)]
        #expect(PetSessionAdapter.mood(all: all, listed: []) == .idle)
    }

    @Test func noSessionsIsIdle() {
        #expect(PetSessionAdapter.mood(all: [], listed: []) == .idle)
    }
}
