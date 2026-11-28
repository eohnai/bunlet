import CoreGraphics
import Foundation
import SwiftUI
import Testing
import SessionState
@testable import Usage
@testable import NotchPet

@MainActor
struct NotchAllowanceStripTests {
    /// Claude has no reading and Codex shows a full badge with a countdown. In a side too narrow for the full badges,
    /// the strip switches to the short form.
    @Test func bothProvidersFitBesideTheNotchWhenOneIsMissing() throws {
        let nowMs = Int64(Date().timeIntervalSince1970 * 1_000)
        let store = UsageStore()
        store.apply(UsageObservation(provider: "codex", sourceID: "fixture", accountID: nil,
                                     receivedAtMs: nowMs - 360_000, measuredAtMs: nil,
                                     windows: [UsageWindow(id: "weekly", usedPercent: 13, durationMinutes: 10_080,
                                                           resetsAtMs: nowMs + 20_000_000)], failure: nil))
        let strip = NotchAllowanceStrip(store: store, activeProviders: [.claude, .codex])
        let renderer = ImageRenderer(content: strip)
        let availableWidth: CGFloat = 200

        let full = try #require(renderer.cgImage)
        #expect(CGFloat(full.width) > availableWidth)

        renderer.proposedSize = ProposedViewSize(width: availableWidth, height: 32)
        let compact = try #require(renderer.cgImage)
        #expect(CGFloat(compact.width) <= availableWidth)
    }

    /// Both agents show a 5-hour reading beside a 179 pt cutout on a 1470 pt screen, as measured on the
    /// development MacBook Air. The full badges, with their countdowns, fit in the side a 700 pt panel leaves.
    @Test func bothFullBadgesFitBesideTheNotchOnASmallScreen() throws {
        let nowMs = Int64(Date().timeIntervalSince1970 * 1_000)
        let store = UsageStore()
        // 4h59m is the widest 5-hour countdown.
        let resetMs = nowMs + 299 * 60_000 + 30_000
        store.apply(UsageObservation(provider: "claude", sourceID: "claude-fixture", accountID: "a",
                                     receivedAtMs: nowMs, measuredAtMs: nil,
                                     windows: [UsageWindow(id: "five_hour", usedPercent: 38, durationMinutes: 300,
                                                           resetsAtMs: resetMs)], failure: nil))
        store.apply(UsageObservation(provider: "codex", sourceID: "codex-fixture", accountID: "b",
                                     receivedAtMs: nowMs, measuredAtMs: nil,
                                     windows: [UsageWindow(id: "codex/primary", usedPercent: 38, durationMinutes: 300,
                                                           resetsAtMs: resetMs)], failure: nil))
        let strip = NotchAllowanceStrip(store: store, activeProviders: [.claude, .codex])
        let panel = IslandGeometry.panelBodyWidth(screenWidth: 1470, windowWidth: IslandMetrics.windowWidth)
        // 18 pt outer inset on each side and a 6 pt margin before the notch.
        let side = (panel - 2 * 18 - 179) / 2 - 6

        let full = try #require(ImageRenderer(content: strip).cgImage)
        #expect(CGFloat(full.width) <= side, "full badges are \(full.width) pt, side is \(side) pt")
    }
}
