import CoreGraphics
import EventBridge
import Foundation
import Testing
@testable import SessionState

struct NotchPresentationTests {
    private func snapshot(_ id: String, status: SessionStatus = .working) -> SessionSnapshot {
        SessionSnapshot(key: SessionKey(agent: .codex, sessionID: id), status: status,
                        currentTurnID: nil, turnStartedAtMs: nil,
                        responseReadyAtMs: nil, pendingRequests: [],
                        captureWatermarkMs: nil, receiptWallMs: nil, receiptMonotonicNs: nil,
                        projectPath: "/fictional/project", paneSelector: nil,
                        hasTerminalRestriction: status == .ended)
    }

    private func quiet(_ id: String, _ status: SessionStatus, receiptMs: Int64?, prompted: Bool = true,
                       pending: [SessionRequest] = []) -> SessionSnapshot {
        SessionSnapshot(key: SessionKey(agent: .codex, sessionID: id), status: status,
                        currentTurnID: nil, turnStartedAtMs: prompted ? 1_000 : nil,
                        responseReadyAtMs: nil, pendingRequests: pending,
                        captureWatermarkMs: nil, receiptWallMs: receiptMs, receiptMonotonicNs: nil,
                        projectPath: "/fictional/project", paneSelector: nil,
                        hasTerminalRestriction: false)
    }

    /// Decision 0032: the cleanup limit applies to every state except a session waiting for the user.
    @Test func quietSessionsLeaveInEveryStateUnlessWaitingForTheUser() {
        let now: Int64 = 10_000_000
        let old = now - 2 * 60 * 60_000
        let sessions = [quiet("idle-old", .idle, receiptMs: old), quiet("idle-new", .idle, receiptMs: now - 60_000),
                        quiet("working-old", .working, receiptMs: old), quiet("ready-old", .responseReady, receiptMs: old),
                        quiet("approval-old", .approvalNeeded, receiptMs: old),
                        quiet("question-old", .questionNeeded, receiptMs: old), quiet("idle-none", .idle, receiptMs: nil)]
        let kept = NotchPresentation.listed(sessions, limitMinutes: 60, nowMs: now).map(\.key.sessionID)
        #expect(kept == ["idle-new", "approval-old", "question-old", "idle-none"])
    }

    @Test func endedSessionsLeaveAtOnce() {
        let now: Int64 = 10_000_000
        let sessions = [quiet("ended-now", .ended, receiptMs: now), quiet("ended-none", .ended, receiptMs: nil),
                        quiet("ready-now", .responseReady, receiptMs: now)]
        #expect(NotchPresentation.listed(sessions, limitMinutes: 60, nowMs: now).map(\.key.sessionID) == ["ready-now"])
    }

    /// A session seen only at start-up stays out of the list until its first accepted prompt.
    @Test func idleSessionsWithoutAPromptStayHidden() {
        let now: Int64 = 10_000_000
        let sessions = [quiet("idle-unprompted", .idle, receiptMs: now, prompted: false),
                        quiet("idle-prompted", .idle, receiptMs: now),
                        // Joined mid-turn: no submit was seen, but the session is visibly busy or done.
                        quiet("working-unprompted", .working, receiptMs: now, prompted: false),
                        quiet("ready-unprompted", .responseReady, receiptMs: now, prompted: false),
                        quiet("approval-unprompted", .approvalNeeded, receiptMs: now, prompted: false)]
        #expect(NotchPresentation.listed(sessions, limitMinutes: 60, nowMs: now).map(\.key.sessionID)
                == ["idle-prompted", "working-unprompted", "ready-unprompted", "approval-unprompted"])
    }

    @Test func windowIsFixedAtTopCenter() throws {
        let frame = try #require(IslandGeometry.windowFrame(screen: CGRect(x: 0, y: 0, width: 1470, height: 956),
                                                            safeTop: 38))
        #expect(frame == CGRect(x: 355, y: 644, width: 760, height: 312))
    }

    @Test(arguments: [CGFloat(1), CGFloat(2)])
    func centeredPillEdgesLandOnDisplayPixels(scale: CGFloat) throws {
        let screen = CGRect(x: 0, y: 0, width: 1470.5, height: 956)
        let frame = try #require(IslandGeometry.windowFrame(screen: screen, safeTop: 32, backingScale: scale))
        let width = IslandGeometry.pixelAlignedWidth(262.3, scale: scale)
        let left = (frame.midX - width / 2) * scale
        let right = (frame.midX + width / 2) * scale
        #expect(left == left.rounded())
        #expect(right == right.rounded())
        #expect(width >= 262.3)
        #expect(width - 262.3 < 2 / scale)
        #expect(frame.maxY == screen.maxY)
    }

    @Test func windowUsesScreenCoordinatesAndClamps() throws {
        let screen = CGRect(x: -320, y: 100, width: 320, height: 300)
        let frame = try #require(IslandGeometry.windowFrame(screen: screen, safeTop: 38))
        #expect(frame == CGRect(x: -320, y: 112, width: 320, height: 288))
        #expect(screen.contains(frame))
    }

    @Test func invalidGeometryIsRejected() {
        for width in [Double.nan, Double.infinity, -1, 0, 20] {
            #expect(IslandGeometry.windowFrame(screen: CGRect(x: 0, y: 0, width: width, height: 800), safeTop: 38) == nil)
        }
        #expect(IslandGeometry.windowFrame(screen: CGRect(x: 0, y: 0, width: 1200, height: 800), safeTop: -1) == nil)
    }

    @Test(arguments: [(CGFloat(38), CGFloat(24), CGFloat(38)), (32, 33, 33), (32, 38, 33), (32, 0, 32), (32, 60, 32),
                      (0, 24, 24), (0, 0, 24), (0, 60, 24)])
    func headerFollowsNotchThenMenuBar(safeTop: CGFloat, menuBar: CGFloat, expected: CGFloat) {
        #expect(IslandGeometry.headerHeight(safeTop: safeTop, menuBarHeight: menuBar) == expected)
    }

    @Test func pillWidthAddsRoomForStatus() {
        let width = IslandMetrics.windowWidth
        #expect(IslandGeometry.pillBodyWidth(notchWidth: 200, hasNotch: true, visibleCount: 0,
                                             phase: .idle, windowWidth: width) == 262)
        #expect(IslandGeometry.pillBodyWidth(notchWidth: 200, hasNotch: true, visibleCount: 2,
                                             phase: .running, windowWidth: width) == 272)
        #expect(IslandGeometry.pillBodyWidth(notchWidth: 0, hasNotch: false, visibleCount: 0,
                                             phase: .idle, windowWidth: width) == 198)
        #expect(IslandGeometry.pillBodyWidth(notchWidth: 0, hasNotch: false, visibleCount: 1,
                                             phase: .attention, windowWidth: width) == 234)
        #expect(IslandGeometry.pillBodyWidth(notchWidth: 0, hasNotch: false, visibleCount: 1,
                                             phase: .completed, windowWidth: width) == 238)
        #expect(IslandGeometry.pillBodyWidth(notchWidth: 900, hasNotch: true, visibleCount: 1,
                                             phase: .running, windowWidth: width) == 744)
    }

    @Test func panelWidthTracksScreenWithinBounds() {
        let width = IslandMetrics.windowWidth
        // 1470 × 0.46 = 676.2 is below the 700 minimum.
        #expect(IslandGeometry.panelBodyWidth(screenWidth: 1470, windowWidth: width) == 700)
        #expect(IslandGeometry.panelBodyWidth(screenWidth: 0, windowWidth: width) == 700)
        #expect(IslandGeometry.panelBodyWidth(screenWidth: 3000, windowWidth: width) == 724)
    }

    @Test func openShapeFitsContentWithinWindow() {
        #expect(IslandGeometry.openBottom(contentHeight: 10, headerHeight: 38, windowHeight: 572) == 78)
        #expect(IslandGeometry.openBottom(contentHeight: 300, headerHeight: 38, windowHeight: 572) == 300)
        #expect(IslandGeometry.openBottom(contentHeight: 900, headerHeight: 38, windowHeight: 572) == 562)
    }

    @Test func shapeFlaresOutsideBodyAndContainsCenter() {
        let spec = IslandShapeSpec(bodyWidth: 272, bottom: 38, topRadius: 8, bottomRadius: 10)
        #expect(spec.outerWidth(windowWidth: 740) == 288)
        let path = spec.path(windowWidth: 740)
        #expect(path.contains(CGPoint(x: 370, y: 19)))
        // The top edge spans the flare; just below it, the concave corner leaves the outer edge empty.
        #expect(path.contains(CGPoint(x: 233, y: 0.5)))
        #expect(!path.contains(CGPoint(x: 227, y: 7)))
        #expect(!path.contains(CGPoint(x: 370, y: 40)))
        #expect(!path.contains(CGPoint(x: 100, y: 19)))
    }

    @Test func pillDragOutNeedsMoreThanFiftyPointsDown() {
        let start = CGPoint(x: 700, y: 940)
        #expect(!IslandGeometry.isPillDragOut(from: start, to: CGPoint(x: 700, y: 890)))
        #expect(IslandGeometry.isPillDragOut(from: start, to: CGPoint(x: 760, y: 889.5)))
        // Sideways or upward movement never detaches the pet.
        #expect(!IslandGeometry.isPillDragOut(from: start, to: CGPoint(x: 900, y: 940)))
        #expect(!IslandGeometry.isPillDragOut(from: start, to: CGPoint(x: 700, y: 1000)))
    }

    @Test func dominantPhasePrefersAttentionThenRunningThenCompleted() {
        #expect(IslandPhase.dominant([]) == .idle)
        #expect(IslandPhase.dominant([snapshot("a", status: .responseReady)]) == .completed)
        #expect(IslandPhase.dominant([snapshot("a", status: .responseReady), snapshot("b")]) == .running)
        #expect(IslandPhase.dominant([snapshot("a"), snapshot("b", status: .approvalNeeded)]) == .attention)
        #expect(IslandPhase.dominant([snapshot("a", status: .idle), snapshot("b", status: .ended)]) == .idle)
    }

    @Test func notificationsFireOnlyOnEntry() {
        let working = [snapshot("a")]
        #expect(IslandNotification.next(previous: working, current: working) == nil)
        let asking = [snapshot("a", status: .questionNeeded)]
        #expect(IslandNotification.next(previous: working, current: asking) == .attention(asking[0].key))
        #expect(IslandNotification.next(previous: asking, current: asking) == nil)
        let done = [snapshot("a", status: .responseReady)]
        #expect(IslandNotification.next(previous: working, current: done) == .completed(done[0].key))
        #expect(IslandNotification.next(previous: done, current: done) == nil)
        let mixed = [snapshot("a", status: .responseReady), snapshot("b", status: .approvalNeeded)]
        #expect(IslandNotification.next(previous: [], current: mixed) == .attention(mixed[1].key))
    }
}

struct IslandAutoOpenTests {
    private let key = SessionKey(agent: .claude, sessionID: "fictional")

    private func session(_ id: String = "fictional", status: SessionStatus = .working,
                         terminal: HookEnvelopeV1.Terminal? = nil) -> SessionSnapshot {
        var snapshot = SessionSnapshot(key: SessionKey(agent: .claude, sessionID: id), status: status,
                                       currentTurnID: nil, turnStartedAtMs: nil,
                                       responseReadyAtMs: nil, pendingRequests: [],
                                       captureWatermarkMs: nil, receiptWallMs: nil, receiptMonotonicNs: nil,
                                       projectPath: "/fictional/project", paneSelector: nil,
                                       hasTerminalRestriction: false)
        snapshot.terminal = terminal
        return snapshot
    }

    private func open(_ notification: IslandNotification, sessions: [SessionSnapshot] = [], action: Bool = true,
                      end: Bool = true, suppress: Bool = false, frontmost: String? = nil) -> Bool {
        IslandAutoOpen.shouldOpen(notification, sessions: sessions, expandOnActionNeeded: action,
                                  expandOnSessionEnd: end, focusAwareSuppression: suppress,
                                  frontmostBundleID: frontmost)
    }

    @Test func behaviorSwitchesGateEachKind() {
        #expect(open(.attention(key), action: true, end: false))
        #expect(!open(.attention(key), action: false, end: true))
        #expect(open(.completed(key), action: false, end: true))
        #expect(!open(.completed(key), action: true, end: false))
    }

    @Test(arguments: [SessionStatus.approvalNeeded, .questionNeeded])
    func completionWaitsWhileAnotherSessionNeedsTheUser(_ waiting: SessionStatus) {
        let sessions = [session(status: .responseReady), session("other", status: waiting)]
        #expect(!open(.completed(key), sessions: sessions))
        // The waiting request itself still opens the island.
        #expect(open(.attention(sessions[1].key), sessions: sessions))
    }

    @Test func completionOpensWhenOtherSessionsAreOnlyWorkingOrDone() {
        let sessions = [session(status: .responseReady), session("b"), session("c", status: .responseReady)]
        #expect(open(.completed(key), sessions: sessions))
    }

    @Test func unknownAppKeepsTheAnyTerminalRule() {
        #expect(!open(.attention(key), suppress: true, frontmost: "com.googlecode.iterm2"))
        #expect(open(.attention(key), suppress: false, frontmost: "com.googlecode.iterm2"))
        #expect(open(.attention(key), suppress: true, frontmost: "com.apple.Safari"))
        #expect(open(.attention(key), suppress: true, frontmost: nil))
    }

    @Test func knownAppQuietsOnlyWhenThatAppIsInFront() {
        let sessions = [session(terminal: .init(kind: .appleTerminal, paneSelector: "/dev/ttys001"))]
        #expect(!open(.attention(key), sessions: sessions, suppress: true, frontmost: "com.apple.Terminal"))
        // Another terminal in front no longer hides this session's notification.
        #expect(open(.attention(key), sessions: sessions, suppress: true, frontmost: "com.googlecode.iterm2"))
    }

    @Test func panelHeightSettingSizesTheWindow() throws {
        let screen = CGRect(x: 0, y: 0, width: 1470, height: 956)
        #expect(try #require(IslandGeometry.windowFrame(screen: screen, safeTop: 38, panelMaxHeight: 300)).height == 332)
        #expect(try #require(IslandGeometry.windowFrame(screen: screen, safeTop: 38, panelMaxHeight: 700)).height == 732)
        #expect(try #require(IslandGeometry.windowFrame(screen: screen, safeTop: 38, panelMaxHeight: 50)).height == 232)
    }
}

/// Decision 0030: removed rows stay hidden until their session reports new activity.
struct RemovedSessionTests {
    private func session(_ id: String, receipt: UInt64?) -> SessionSnapshot {
        SessionSnapshot(key: SessionKey(agent: .claude, sessionID: id), status: .responseReady,
                        currentTurnID: nil, turnStartedAtMs: nil, responseReadyAtMs: nil,
                        pendingRequests: [], captureWatermarkMs: nil, receiptWallMs: nil,
                        receiptMonotonicNs: receipt, projectPath: "/fictional/project",
                        paneSelector: nil, hasTerminalRestriction: false)
    }

    @Test func removedSessionsStayHiddenUntilNewActivity() {
        let a = session("a", receipt: 10)
        let b = session("b", receipt: 20)
        let removed: [SessionKey: UInt64?] = [a.key: .some(10)]
        #expect(NotchPresentation.withoutRemoved([a, b], removed: removed).map(\.key) == [b.key])
        let refreshed = session("a", receipt: 11)
        #expect(NotchPresentation.withoutRemoved([refreshed, b], removed: removed).map(\.key) == [refreshed.key, b.key])
    }

    @Test func aSessionWithNoReceiptReturnsOnItsFirstOne() {
        let quiet = session("a", receipt: nil)
        let removed: [SessionKey: UInt64?] = [quiet.key: UInt64?.none]
        #expect(NotchPresentation.withoutRemoved([quiet], removed: removed).isEmpty)
        #expect(NotchPresentation.withoutRemoved([session("a", receipt: 5)], removed: removed).count == 1)
    }
}
