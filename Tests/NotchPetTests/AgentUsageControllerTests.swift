import EventBridge
import Foundation
import SessionState
import Testing
@testable import Usage
@testable import NotchPet

@MainActor
struct AgentUsageControllerTests {
    private final class Counter {
        var reads = 0
    }

    private func reading(_ counter: Counter) -> @MainActor () async -> UsageObservation {
        {
            counter.reads += 1
            return UsageObservation(provider: "codex", sourceID: "codex-managed", accountID: nil,
                                    receivedAtMs: Int64(Date().timeIntervalSince1970 * 1000), measuredAtMs: nil,
                                    windows: [UsageWindow(id: "codex/primary", usedPercent: 20, durationMinutes: 300,
                                                          resetsAtMs: nil)], failure: nil)
        }
    }

    private func settle() async {
        for _ in 0..<50 { await Task.yield() }
    }

    /// An open, quiet Codex session sends nothing after Bunlet starts, so the badge needs a read at start.
    @Test func startReadsCodexOnceWithoutASession() async {
        let counter = Counter()
        let store = UsageStore()
        let controller = AgentUsageController(store: store, sessions: SessionStore(), read: reading(counter))
        controller.start()
        await settle()
        #expect(counter.reads == 1)
        #expect(store.providersWithReadings == [.codex])
        try? await Task.sleep(for: .milliseconds(50))
        #expect(counter.reads == 1)
        controller.stop()
    }

    @Test func startDoesNotReadWhenCodexIsOff() async {
        let counter = Counter()
        let controller = AgentUsageController(store: UsageStore(), sessions: SessionStore(), read: reading(counter))
        controller.setEnabledProviders([.claude])
        controller.start()
        await settle()
        #expect(counter.reads == 0)
        controller.stop()
    }
}
