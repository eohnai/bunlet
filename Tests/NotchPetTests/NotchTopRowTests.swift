import AppKit
import SwiftUI
import Testing
@testable import NotchPet

@MainActor
struct NotchTopRowTests {
    /// With no quota to show, the left side must still take its width so the buttons stay at the right edge.
    @Test(arguments: [false, true])
    func theRowKeepsItsFullWidthWhetherOrNotTheLeftSideHasContent(showsQuota: Bool) {
        let row = NotchTopRow(sideWidth: 241.5, notchWidth: 185) {
            if showsQuota { Text("5h 80%") }
        } trailing: {
            Text("Settings")
        }
        let width: CGFloat = NSHostingView(rootView: row).fittingSize.width
        let expected: CGFloat = 2 * 241.5 + 185
        #expect(width == expected)
    }
}
