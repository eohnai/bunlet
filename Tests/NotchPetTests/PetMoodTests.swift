import Pet
@testable import SessionState
import Testing
@testable import NotchPet

/// The pet's mood describes the sessions the island and pet panel list (decision 0032).
@MainActor
struct PetMoodTests {
    private func session(_ id: String, _ status: SessionStatus, failed: Bool = false) -> SessionSnapshot {
        SessionSnapshot(key: SessionKey(agent: .claude, sessionID: id), status: status,
                        currentTurnID: nil, turnStartedAtMs: 1_000,
                        responseReadyAtMs: nil, pendingRequests: [],
                        captureWatermarkMs: nil, receiptWallMs: nil, receiptMonotonicNs: nil,
                        projectPath: "/fictional/project", paneSelector: nil,
                        hasTerminalRestriction: false, turnFailed: failed)
    }

    @Test func aSessionTheListHidesDoesNotSetTheMood() {
        let hidden = session("hidden", .approvalNeeded)
        let shown = session("shown", .working)
        #expect(PetSessionAdapter.mood(all: [hidden, shown], listed: [shown]) == .working)
    }

    @Test func moodFollowsTheMostUrgentListedSession() {
        let waiting = session("waiting", .approvalNeeded)
        let working = session("working", .working)
        let failed = session("failed", .responseReady, failed: true)
        let ready = session("ready", .responseReady)
        #expect(PetSessionAdapter.mood(all: [], listed: [ready, failed, working, waiting]) == .attention)
        #expect(PetSessionAdapter.mood(all: [], listed: [ready, failed, working]) == .working)
        #expect(PetSessionAdapter.mood(all: [], listed: [ready, failed]) == .failed)
        #expect(PetSessionAdapter.mood(all: [], listed: [ready]) == .responseReady)
    }

    @Test func endedShowsOnceEverySessionHasEnded() {
        let all = [session("a", .ended), session("b", .ended)]
        #expect(PetSessionAdapter.mood(all: all, listed: []) == .ended)
    }

    @Test func idleWhenOnlySomeHiddenSessionsHaveEnded() {
        let all = [session("a", .ended), session("b", .idle)]
        #expect(PetSessionAdapter.mood(all: all, listed: []) == .idle)
    }

    @Test func noSessionsIsIdle() {
        #expect(PetSessionAdapter.mood(all: [], listed: []) == .idle)
    }
}
