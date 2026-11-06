import EventBridge
import Foundation
import SessionState
import Testing
@testable import NotchPet

@MainActor
struct FeatureRuntimeTests {
    private final class Service: AppFeatureService {
        var starts = 0
        var stops = 0
        func start() { starts += 1 }
        func stop() { stops += 1 }
    }

    private func observation(_ number: Int, hook: String = "UserPromptSubmit",
                             session: String = "fixture", request: Bool = false) throws -> SessionObservationV1 {
        var payload: [String: Any] = [
            "version": 1, "event_id": String(format: "00000000-0000-0000-0000-%012x", number),
            "agent": "claude", "session_id": session, "hook_event_name": hook,
            "observed_at_ms": 1_000_000 + number, "turn_id": "turn"
        ]
        if request {
            payload["tool_use_id"] = "tool"
            payload["tool_name"] = "Write"
        }
        let frame = try JSONSerialization.data(withJSONObject: payload) + Data([10])
        return SessionObservationV1(envelope: try HookEnvelopeV1.decode(frame: frame),
            receiptWallMs: Int64(1_000_000 + number), receiptMonotonicNs: UInt64(1_000_000_000 + number * 1_000_000))
    }

    @Test(arguments: 0..<8) func absentFeaturesNeverConstructAndDesiredStateIsIdempotent(mask: Int) {
        var creations: [AppFeature: Int] = [:]
        var services: [AppFeature: Service] = [:]
        var factories: [AppFeature: () -> (any AppFeatureService)?] = [:]
        for feature in AppFeature.allCases {
            factories[feature] = {
                creations[feature, default: 0] += 1
                let service = Service()
                services[feature] = service
                return service
            }
        }
        let owner = FeatureRuntimeOwner(factories: factories)
        let selected = Set(AppFeature.allCases.enumerated().compactMap { index, feature in
            mask & (1 << index) != 0 ? feature : nil
        })
        #expect(creations.isEmpty)
        owner.apply(selected)
        owner.apply(selected)
        #expect(owner.activeFeatures == selected)
        for feature in AppFeature.allCases {
            #expect(creations[feature, default: 0] == (selected.contains(feature) ? 1 : 0))
            if let service = services[feature] { #expect(service.starts == 1 && service.stops == 0) }
        }
        owner.apply([])
        owner.apply([])
        #expect(owner.activeFeatures.isEmpty)
        #expect(services.values.allSatisfy { $0.starts == 1 && $0.stops == 1 })
    }

    @Test func removingSurfaceLeavesOtherRuntimesRunning() {
        let pet = Service()
        let notch = Service()
        let agents = Service()
        let owner = FeatureRuntimeOwner(factories: [.pet: { pet }, .notch: { notch }, .agents: { agents }])
        owner.apply(Set(AppFeature.allCases))
        owner.apply([.pet, .agents])
        #expect(notch.stops == 1)
        #expect(pet.stops == 0 && agents.stops == 0)
        owner.apply([.agents])
        #expect(pet.stops == 1 && agents.starts == 1 && agents.stops == 0)
        owner.apply([])
        #expect(agents.stops == 1)
    }

    @Test func stoppedAndOldGenerationDeliveriesCannotReachStore() throws {
        let sessions = SessionStore()
        let usage = Service()
        var handlers: [AgentServices.BatchHandler] = []
        var receiverStops = 0
        let service = AgentServices(sessionStore: sessions, usage: usage, startObserving: { handler in
            handlers.append(handler)
            return { receiverStops += 1 }
        }, wall: { 1_000_000 }, monotonic: { 1_000_000_000 })
        service.start()
        service.start()
        #expect(handlers.count == 1 && usage.starts == 1)
        handlers[0]([try observation(1)], false)
        #expect(sessions.sessions.first?.status == .working)
        service.stop()
        service.stop()
        #expect(receiverStops == 1 && usage.stops == 1)
        handlers[0]([try observation(2, session: "stopped")], false)
        #expect(sessions.sessions.count == 1)
        #expect(sessions.sessions.first?.reason == .monitoringStopped)
        service.start()
        #expect(handlers.count == 2 && usage.starts == 2)
        handlers[0]([try observation(3, session: "old-generation")], false)
        #expect(sessions.sessions.count == 1)
        handlers[1]([try observation(4, session: "current")], false)
        #expect(sessions.sessions.contains { $0.key.sessionID == "current" && $0.status == .working })
        service.stop()
    }

    @Test func stoppingRetainsUnconfirmedRequestsWithoutSyntheticCompletion() throws {
        let sessions = SessionStore()
        var deliver: AgentServices.BatchHandler?
        let service = AgentServices(sessionStore: sessions, usage: Service(), startObserving: { handler in
            deliver = handler
            return {}
        }, wall: { 1_000_000 }, monotonic: { 1_000_000_000 })
        service.start()
        let handler = try #require(deliver)
        handler([try observation(1), try observation(2, hook: "PermissionRequest", request: true)], false)
        #expect(sessions.sessions.first?.status == .approvalNeeded)
        #expect(sessions.sessions.first?.pendingRequests.first?.isConfirmed == true)
        service.stop()
        #expect(sessions.sessions.first?.status == .unknown)
        #expect(sessions.sessions.first?.pendingRequests.first?.isConfirmed == false)
        handler([try observation(3, hook: "Stop")], false)
        #expect(sessions.sessions.first?.pendingRequests.count == 1)
        #expect(sessions.sessions.first?.responseReadyAtMs == nil)
    }

    @Test func receiverFailureLeavesUsageIndependent() {
        struct Failed: Error {}
        let usage = Service()
        let service = AgentServices(usage: usage, startObserving: { _ in throw Failed() })
        service.start()
        #expect(usage.starts == 1)
        service.stop()
        #expect(usage.stops == 1)
    }

    @Test func failedFactoriesAreReportedAndCanRecover() {
        var available = false
        let service = Service()
        let owner = FeatureRuntimeOwner(factories: [.pet: { available ? service : nil }])
        owner.apply([.pet])
        #expect(owner.activeFeatures.isEmpty)
        #expect(owner.unavailableFeatures == [.pet])
        available = true
        owner.apply([.pet])
        #expect(owner.activeFeatures == [.pet])
        #expect(owner.unavailableFeatures.isEmpty)
        #expect(service.starts == 1)
        owner.apply([])
        #expect(service.stops == 1)
    }

    @Test func petPlacementUsesVisibleDesktopAndPreservesSafeSizes() {
        let screen = CGRect(x: -1280, y: 40, width: 1280, height: 760)
        for size in [64.0, 120, 256] {
            let frame = PetPanelController.desktopFrame(screen: screen, size: size)
            #expect(screen.contains(frame))
            #expect(frame.width == size && frame.height == size)
            #expect(frame.minY == screen.minY + 16)
            #expect(frame.maxX == screen.maxX - 16)
        }
        #expect(PetPanelController.desktopFrame(screen: screen, size: .nan).width == 120)
    }
}
