import CoreGraphics
import EventBridge
import Foundation
import Testing
@testable import SessionState

struct NotchPresentationTests {
    private func snapshot(_ id: String, status: SessionStatus = .working) -> SessionSnapshot {
        SessionSnapshot(key: SessionKey(agent: .codex, sessionID: id), status: status,
                        reason: nil, currentTurnID: nil, turnStartedAtMs: nil,
                        responseReadyAtMs: nil, pendingRequests: [],
                        captureWatermarkMs: nil, receiptWallMs: nil, receiptMonotonicNs: nil,
                        expiryMonotonicNs: nil, projectPath: "/fictional/project", paneSelector: nil,
                        hasTerminalRestriction: status == .ended)
    }

    @Test func windowIsFixedAtTopCenter() throws {
        let frame = try #require(IslandGeometry.windowFrame(screen: CGRect(x: 0, y: 0, width: 1470, height: 956),
                                                            safeTop: 38))
        #expect(frame == CGRect(x: 365, y: 384, width: 740, height: 572))
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

    @Test(arguments: [(CGFloat(38), CGFloat(24), CGFloat(38)), (0, 24, 24), (0, 0, 24), (0, 60, 24)])
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
                                             phase: .running, windowWidth: width) == 724)
    }

    @Test func panelWidthTracksScreenWithinBounds() {
        let width = IslandMetrics.windowWidth
        #expect(IslandGeometry.panelBodyWidth(screenWidth: 1470, windowWidth: width) == 676.2.clamped680)
        #expect(IslandGeometry.panelBodyWidth(screenWidth: 0, windowWidth: width) == 680)
        #expect(IslandGeometry.panelBodyWidth(screenWidth: 3000, windowWidth: width) == 704)
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
        #expect(IslandPhase.dominant([snapshot("a", status: .unknown), snapshot("b", status: .ended)]) == .idle)
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

private extension Double {
    /// 1470 × 0.46 = 676.2 is below the 680 minimum.
    var clamped680: CGFloat { CGFloat(Swift.max(680, self)) }
}

struct IslandAutoOpenTests {
    private let key = SessionKey(agent: .claude, sessionID: "fictional")

    @Test func behaviorSwitchesGateEachKind() {
        func open(_ notification: IslandNotification, action: Bool, end: Bool) -> Bool {
            IslandAutoOpen.shouldOpen(notification, expandOnActionNeeded: action, expandOnSessionEnd: end,
                                      focusAwareSuppression: false, frontmostBundleID: nil)
        }
        #expect(open(.attention(key), action: true, end: false))
        #expect(!open(.attention(key), action: false, end: true))
        #expect(open(.completed(key), action: false, end: true))
        #expect(!open(.completed(key), action: true, end: false))
    }

    @Test func focusAwareSuppressionOnlyAppliesToTerminals() {
        func open(_ frontmost: String?, suppress: Bool) -> Bool {
            IslandAutoOpen.shouldOpen(.attention(key), expandOnActionNeeded: true, expandOnSessionEnd: true,
                                      focusAwareSuppression: suppress, frontmostBundleID: frontmost)
        }
        #expect(!open("com.googlecode.iterm2", suppress: true))
        #expect(open("com.googlecode.iterm2", suppress: false))
        #expect(open("com.apple.Safari", suppress: true))
        #expect(open(nil, suppress: true))
    }

    @Test func panelHeightSettingSizesTheWindow() throws {
        let screen = CGRect(x: 0, y: 0, width: 1470, height: 956)
        #expect(try #require(IslandGeometry.windowFrame(screen: screen, safeTop: 38, panelMaxHeight: 300)).height == 332)
        #expect(try #require(IslandGeometry.windowFrame(screen: screen, safeTop: 38, panelMaxHeight: 700)).height == 732)
        #expect(try #require(IslandGeometry.windowFrame(screen: screen, safeTop: 38, panelMaxHeight: 50)).height == 232)
    }
}
