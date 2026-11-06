import Darwin
import Foundation
import Testing
@testable import EventBridge

struct EventBridgeTests {
    @Test func strictEnvelopeValidation() throws {
        let frame = Data("{\"version\":1,\"event_id\":\"00000000-0000-4000-8000-000000000001\",\"agent\":\"codex\",\"session_id\":\"fictional\",\"hook_event_name\":\"SessionStart\",\"observed_at_ms\":1000000}\n".utf8)
        #expect(try HookEnvelopeV1.decode(frame: frame).sessionID == "fictional")
        for replacement in ["true", "1.0", "2", "null"] {
            let invalid = String(decoding: frame, as: UTF8.self)
                .replacingOccurrences(of: "\"version\":1", with: "\"version\":\(replacement)")
            #expect(throws: (any Error).self) { try HookEnvelopeV1.decode(frame: Data(invalid.utf8)) }
        }
        let duplicate = String(decoding: frame, as: UTF8.self)
            .replacingOccurrences(of: "\"version\":1", with: "\"version\":1,\"vers\\u0069on\":1")
        #expect(throws: (any Error).self) { try HookEnvelopeV1.decode(frame: Data(duplicate.utf8)) }
        #expect(throws: (any Error).self) { try HookEnvelopeV1.decode(frame: frame + frame) }
        #expect(throws: (any Error).self) { try HookEnvelopeV1.decode(frame: Data(frame.dropLast())) }
    }

    @Test func actualSocketDeliveryAndExclusiveOwnership() throws {
        let directory = "/private/tmp/notch-pet-test-\(UUID().uuidString)"
        defer { try? FileManager.default.removeItem(atPath: directory) }
        let endpoint = BridgeEndpoint(directory: directory)
        let received = DispatchSemaphore(value: 0)
        let server = EventBridgeServer(endpoint: endpoint)
        try server.start { observation in
            #expect(observation.envelope.sessionID == "fictional")
            received.signal()
        }
        defer { server.stop() }
        let second = EventBridgeServer(endpoint: endpoint)
        #expect(throws: (any Error).self) { try second.start { _ in Issue.record("second listener") } }
        let envelope = try HookEnvelopeV1.project(
            rawHook: Data("{\"session_id\":\"fictional\",\"hook_event_name\":\"SessionStart\"}".utf8),
            agent: .codex)
        try EventBridgeClient(endpoint: endpoint).send(envelope)
        #expect(received.wait(timeout: .now() + 2) == .success)
        server.stop()
        #expect(!FileManager.default.fileExists(atPath: endpoint.socketPath))
        #expect(throws: (any Error).self) { try EventBridgeClient(endpoint: endpoint).send(envelope) }
        try server.start { _ in }
        server.stop()
    }
}
