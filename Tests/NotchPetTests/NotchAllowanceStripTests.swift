import CoreGraphics
import Foundation
import SwiftUI
import Testing
@testable import Usage
@testable import NotchPet

@MainActor
struct NotchAllowanceStripTests {
    /// Worst common case beside a 185 pt cutout: Claude has no reading and Codex shows a full badge with a countdown.
    @Test func bothProvidersFitBesideTheNotchWhenOneIsMissing() throws {
        let nowMs = Int64(Date().timeIntervalSince1970 * 1_000)
        let store = UsageStore()
        store.apply(UsageObservation(provider: "codex", sourceID: "fixture", accountID: nil,
                                     receivedAtMs: nowMs - 360_000, measuredAtMs: nil,
                                     windows: [UsageWindow(id: "weekly", usedPercent: 13, durationMinutes: 10_080,
                                                           resetsAtMs: nowMs + 20_000_000)], failure: nil))
        let strip = NotchAllowanceStrip(store: store, activeProviders: [.claude, .codex])
        let renderer = ImageRenderer(content: strip)
        // A 704 pt panel with a 185 pt cutout, 18 pt outer inset and 6 pt notch margin.
        let availableWidth: CGFloat = 235.5

        let full = try #require(renderer.cgImage)
        #expect(CGFloat(full.width) > availableWidth)

        renderer.proposedSize = ProposedViewSize(width: availableWidth, height: 32)
        let compact = try #require(renderer.cgImage)
        #expect(CGFloat(compact.width) <= availableWidth)
    }
}
