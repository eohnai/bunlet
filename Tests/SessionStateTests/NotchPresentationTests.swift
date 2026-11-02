import CoreGraphics
import Foundation
import Testing
@testable import SessionState

struct NotchPresentationTests {
    @Test func compactPanelLeavesRoomForPhysicalNotch() throws {
        let frame = try #require(NotchPlacement.frame(screen: CGRect(x: 0, y: 0, width: 1470, height: 956),
                                                     safeTop: 38, notchWidth: 200, expanded: false))
        #expect(frame == CGRect(x: 611, y: 918, width: 248, height: 38))
    }

    @Test(arguments: [CGFloat(0), CGFloat(38)])
    func expandedPanelUsesRequestedSize(safeTop: CGFloat) throws {
        let screen = CGRect(x: 0, y: 0, width: 1470, height: 956)
        let frame = try #require(NotchPlacement.frame(screen: screen, safeTop: safeTop,
                                                     notchWidth: safeTop == 0 ? 0 : 200, expanded: true))
        #expect(frame.width == 620)
        #expect(frame.height == max(32, safeTop) + 240)
        #expect(frame.midX == screen.midX)
        #expect(frame.maxY == screen.maxY)
    }

    @Test func expandedPanelUsesScreenCoordinatesAndClampsWidth() throws {
        let frame = try #require(NotchPlacement.frame(screen: CGRect(x: -320, y: 100, width: 320, height: 600),
                                                     safeTop: 38, notchWidth: 200, expanded: true))
        #expect(frame == CGRect(x: -308, y: 422, width: 296, height: 278))
    }

    @Test func displayWithoutCutoutStillHasAnAccessibleHeader() throws {
        let frame = try #require(NotchPlacement.frame(screen: CGRect(x: 0, y: 0, width: 1200, height: 800),
                                                     safeTop: 0, notchWidth: 0, expanded: false))
        #expect(frame == CGRect(x: 490, y: 768, width: 220, height: 32))
    }

    @Test func expandedHeightStaysWithinSmallScreen() throws {
        let screen = CGRect(x: 100, y: -200, width: 800, height: 200)
        let frame = try #require(NotchPlacement.frame(screen: screen, safeTop: 38,
                                                     notchWidth: 200, expanded: true))
        #expect(screen.contains(frame))
        #expect(frame.height == 188)
        #expect(frame.maxY == screen.maxY)
    }

    @Test func invalidGeometryIsRejected() {
        for width in [Double.nan, Double.infinity, -1, 0, 20] {
            #expect(NotchPlacement.frame(screen: CGRect(x: 0, y: 0, width: width, height: 800),
                                         safeTop: 38, notchWidth: 200, expanded: false) == nil)
        }
        #expect(NotchPlacement.frame(screen: CGRect(x: 0, y: 0, width: 1200, height: 800),
                                     safeTop: -1, notchWidth: 200, expanded: false) == nil)
    }
}
