import Testing
@testable import SessionState

struct NotchCardPresentationTests {
    private func snapshot(_ id: String = "fictional-abcdef", agent: String = "codex",
                          status: SessionStatus = .working, path: String? = "/fictional/project",
                          startedAtMs: Int64? = 1_000, stoppedAtMs: Int64? = nil) -> SessionSnapshot {
        SessionSnapshot(key: SessionKey(agent: agent, sessionID: id), status: status,
                        reason: nil, currentTurnID: "fictional-turn", turnStartedAtMs: startedAtMs,
                        responseReadyAtMs: stoppedAtMs, pendingRequests: [],
                        captureWatermarkMs: nil, receiptWallMs: nil, receiptMonotonicNs: nil,
                        expiryMonotonicNs: nil, projectPath: path, paneSelector: nil,
                        hasTerminalRestriction: status == .ended)
    }

    @Test func folderNamesUseTheObservedPath() {
        let cases: [(String?, String)] = [
            ("/fictional/project", "project"), ("/fictional/project/", "project"),
            ("/fictional/project with spaces", "project with spaces"),
            (nil, "Project not observed"), ("", "Project not observed")
        ]
        for (path, expected) in cases {
            let session = snapshot(path: path)
            let card = NotchPresentation.card(for: session, among: [session])
            #expect(card.folderName == expected)
            #expect(card.shortSessionID == nil)
        }
    }

    @Test(arguments: ["codex", "claude"])
    func sharedFoldersShowTheLastSixIDCharacters(agent: String) {
        let session = snapshot(agent: agent)
        let other = snapshot("other-uvwxyz", agent: agent == "codex" ? "claude" : "codex")
        let sessions = [session, other]
        #expect(NotchPresentation.card(for: session, among: sessions).shortSessionID == "abcdef")
        #expect(NotchPresentation.card(for: other, among: sessions).shortSessionID == "uvwxyz")

        let short = snapshot("abc", agent: agent)
        #expect(NotchPresentation.card(for: short, among: [short, other]).shortSessionID == "abc")
    }

    @Test func sharedFolderRequiresAnotherKeyAndTheSameFullPath() {
        let session = snapshot()
        let other = snapshot("other", path: "/another/project")
        #expect(NotchPresentation.card(for: session, among: [session, other]).shortSessionID == nil)
        #expect(NotchPresentation.card(for: session, among: [session, session]).shortSessionID == nil)

        for path: String? in [nil, ""] {
            let missing = snapshot(path: path)
            let otherMissing = snapshot("other", path: path)
            #expect(NotchPresentation.card(for: missing, among: [missing, otherMissing]).shortSessionID == nil)
        }
    }

    @Test(arguments: [SessionStatus.working, .questionNeeded, .approvalNeeded])
    func activeTurnsExposeTheirStartTime(status: SessionStatus) {
        let session = snapshot(status: status)
        #expect(NotchPresentation.card(for: session, among: [session]).timer == .running(startedAtMs: 1_000))
    }

    @Test func responseReadyExposesAFixedDuration() throws {
        let session = snapshot(status: .responseReady, stoppedAtMs: 124_999)
        let timer = try #require(NotchPresentation.card(for: session, among: [session]).timer)
        #expect(timer == .stopped(durationMs: 123_999))
        #expect(timer.elapsedSeconds(at: 125_000) == 123)
        #expect(timer.elapsedSeconds(at: 900_000) == 123)

        let beforeStart = snapshot(status: .responseReady, stoppedAtMs: 500)
        #expect(NotchPresentation.card(for: beforeStart, among: [beforeStart]).timer == .stopped(durationMs: 0))
    }

    @Test(arguments: [SessionStatus.idle, .unknown, .ended])
    func inactiveOrUnconfirmedSessionsHideEvenRetainedTimes(status: SessionStatus) {
        let session = snapshot(status: status, stoppedAtMs: 124_999)
        #expect(NotchPresentation.card(for: session, among: [session]).timer == nil)
    }

    @Test(arguments: [SessionStatus.working, .questionNeeded, .approvalNeeded, .responseReady])
    func missingStartTimesHideTheTimer(status: SessionStatus) {
        let session = snapshot(status: status, startedAtMs: nil, stoppedAtMs: 124_999)
        #expect(NotchPresentation.card(for: session, among: [session]).timer == nil)
    }

    @Test func responseReadyWithoutAStopTimeHidesTheTimer() {
        let session = snapshot(status: .responseReady)
        #expect(NotchPresentation.card(for: session, among: [session]).timer == nil)
    }

    @Test(arguments: [SessionStatus.working, .questionNeeded, .approvalNeeded])
    func promptTimerUpdatesRequireAnExpandedPanel(status: SessionStatus) {
        let sessions = [snapshot(status: status)]
        #expect(NotchPresentation.shouldTickPromptTimers(expanded: true, sessions: sessions))
        #expect(!NotchPresentation.shouldTickPromptTimers(expanded: false, sessions: sessions))
    }

    @Test(arguments: [SessionStatus.idle, .responseReady, .unknown, .ended])
    func stoppedOrHiddenTimersNeedNoUpdates(status: SessionStatus) {
        let session = snapshot(status: status, stoppedAtMs: 124_999)
        #expect(!NotchPresentation.shouldTickPromptTimers(expanded: true, sessions: [session]))
    }

    @Test func promptTimerUpdatesRequireAtLeastOneObservedRunningTurn() {
        #expect(!NotchPresentation.shouldTickPromptTimers(expanded: true, sessions: []))
        let missing = snapshot("missing", startedAtMs: nil)
        let invalid = snapshot("invalid", startedAtMs: -1)
        let stopped = snapshot("stopped", status: .responseReady, stoppedAtMs: 124_999)
        let sessions = [missing, invalid, stopped]
        #expect(!NotchPresentation.shouldTickPromptTimers(expanded: true, sessions: sessions))

        let running = snapshot("running", agent: "claude")
        #expect(NotchPresentation.shouldTickPromptTimers(expanded: true, sessions: sessions + [running]))
        #expect(!NotchPresentation.shouldTickPromptTimers(expanded: false, sessions: sessions + [running]))
    }

    @Test func runningDurationUsesTimestampsAndFloorsPartialSeconds() {
        let timer = PromptTimer.running(startedAtMs: 1_000)
        #expect(timer.elapsedSeconds(at: 1_000) == 0)
        #expect(timer.elapsedSeconds(at: 1_999) == 0)
        #expect(timer.elapsedSeconds(at: 2_000) == 1)
        #expect(timer.elapsedSeconds(at: 46_999) == 45)
        // A missed update does not require catching up an incrementing counter.
        #expect(timer.elapsedSeconds(at: 124_999) == 123)
        #expect(timer.elapsedSeconds(at: 500) == 0)
        #expect(PromptTimer.running(startedAtMs: Int64.max - 1_999).elapsedSeconds(at: Int64.max) == 1)
        #expect(PromptTimer.stopped(durationMs: -1).elapsedSeconds(at: 1_000) == 0)
    }

    @Test func formattingUsesWholeSecondsAndTheSpecifiedUnits() {
        let cases: [(Int64, String)] = [
            (-1, "0s"), (0, "0s"), (1, "1s"), (45, "45s"), (59, "59s"),
            (60, "1m00s"), (123, "2m03s"), (3_599, "59m59s"),
            (3_600, "1h00m"), (3_720, "1h02m"), (90_000, "25h00m")
        ]
        for (seconds, expected) in cases {
            #expect(NotchPresentation.timerText(seconds: seconds) == expected)
        }
    }
}
