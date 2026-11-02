import Darwin
import EventBridge
import Foundation
import SessionState
import Testing

struct IntegrationHealthModelTests {
    @Test(arguments: IntegrationAgent.allCases)
    func versionAndConfigurationRemainIndependent(agent: IntegrationAgent) {
        let recorded = agent == .codex ? "0.164.0" : "2.1.306"
        var evidence = IntegrationHealthEvidence(agent: agent, version: .reported(recorded))
        evidence.configuration = .missing
        let missing = IntegrationHealth.evaluate(evidence)
        #expect(missing.version == .recordedCompatibility(recorded))
        #expect(missing.configuration == .missing)

        evidence.version = .reported("99.0.0")
        evidence.configuration = .recognizedShape(eventCount: 1, commandCount: 2)
        let unfamiliar = IntegrationHealth.evaluate(evidence)
        #expect(unfamiliar.version == .unverified("99.0.0"))
        #expect(unfamiliar.configuration == .recognizedShape(eventCount: 1, commandCount: 2))
    }

    @Test(arguments: IntegrationAgent.allCases)
    func helperAndReceiverRemainIndependent(agent: IntegrationAgent) {
        var evidence = IntegrationHealthEvidence(agent: agent, helper: .available,
                                                 receiver: .failed(.receiverUnavailable))
        let failed = IntegrationHealth.evaluate(evidence)
        #expect(failed.helper == .available)
        #expect(failed.receiver == .failed(.receiverUnavailable))
        #expect(failed.lastDelivery == nil)

        evidence.helper = .missing
        evidence.receiver = .listening
        let listening = IntegrationHealth.evaluate(evidence)
        #expect(listening.helper == .missing)
        #expect(listening.receiver == .listening)
    }

    @Test(arguments: IntegrationAgent.allCases)
    func missingDeliveryDoesNotMeanDisconnected(agent: IntegrationAgent) {
        let receivers: [IntegrationReceiverState] = [.notStarted, .listening, .stopped]
        for receiver in receivers {
            let snapshot = IntegrationHealth.evaluate(IntegrationHealthEvidence(
                agent: agent, helper: .available, receiver: receiver))
            #expect(snapshot.lastDelivery == nil)
            #expect(snapshot.receiver == receiver)
            #expect(snapshot.version == .notChecked)
            #expect(snapshot.configuration == .notChecked)
        }
    }

    @Test @MainActor
    func recordedDeliverySurvivesSessionExpiryAndIndependentStoreReplacement() throws {
        let frame = Data("""
        {"version":1,"event_id":"00000000-0000-0000-0000-000000000001","agent":"codex","session_id":"fictional-health","hook_event_name":"UserPromptSubmit","observed_at_ms":1000000,"turn_id":"a"}

        """.utf8)
        let event = try HookEnvelopeV1.decode(frame: frame)
        let receipt = IntegrationDeliveryReceipt(wallMs: 1_000_000, monotonicNs: 1_000_000_000)
        let evidence = IntegrationHealthEvidence(agent: .codex, receiver: .listening,
                                                 lastDelivery: receipt)
        let store = SessionStore()
        #expect(store.apply(SessionObservationV1(envelope: event, receiptWallMs: receipt.wallMs,
                                                 receiptMonotonicNs: receipt.monotonicNs)) == .applied)
        store.advance(monotonicNs: 121_000_000_000)
        #expect(store.sessions.first?.status == .unknown)
        #expect(IntegrationHealth.evaluate(evidence).lastDelivery == receipt)
        #expect(SessionStore().sessions.isEmpty)
        #expect(IntegrationHealth.evaluate(evidence).lastDelivery == receipt)
    }

    @Test(arguments: IntegrationAgent.allCases)
    func configurationAndReceiptNeverPromoteSupport(agent: IntegrationAgent) {
        let receipt = IntegrationDeliveryReceipt(wallMs: 1_000, monotonicNs: 2_000)
        let evidence = IntegrationHealthEvidence(
            agent: agent, version: .reported("99.0.0"),
            configuration: .recognizedShape(eventCount: 7, commandCount: 7),
            helper: .available, receiver: .listening, lastDelivery: receipt)
        let snapshot = IntegrationHealth.evaluate(evidence)
        #expect(snapshot.version == .unverified("99.0.0"))
        #expect(snapshot.lastDelivery == receipt)
        #expect(snapshot.configuration == evidence.configuration)
        #expect(snapshot.receiver == .listening)

        let invalid = IntegrationHealthEvidence(agent: agent, version: .reported("unrelated output"))
        #expect(IntegrationHealth.evaluate(invalid).version == .unavailable(.invalidOutput))
    }
}

// These cases check separate outcomes, not concurrent probe sessions.
// Keep fresh fictional executable launches from competing for the process deadline.
@Suite(.serialized)
struct IntegrationHealthProbeTests {
    @Test(arguments: IntegrationAgent.allCases)
    func versionProbeBoundsItsProcessAndOutput(agent: IntegrationAgent) async throws {
        let fixture = try IntegrationHealthFixture()
        let version = agent == .codex ? "codex-cli 0.164.0" : "2.1.306 (Claude Code)"
        let success = try fixture.executable("printf '%s\\n' '\(version)'")
        let normal = await IntegrationHealthProbe.inspect(agent: agent, executableURL: success,
                                                          configurationURL: nil, helperURL: nil)
        #expect(normal.version == .reported(agent == .codex ? "0.164.0" : "2.1.306"))
        let unknown = try fixture.executable("printf '%s\\n' '\(agent == .codex ? "codex-cli 99.0.0" : "99.0.0 (Claude Code)")'")
        let unfamiliar = await IntegrationHealthProbe.inspect(agent: agent, executableURL: unknown,
                                                              configurationURL: nil, helperURL: nil)
        #expect(IntegrationHealth.evaluate(unfamiliar).version == .unverified("99.0.0"))

        let cases: [(String, IntegrationHealthFailure)] = [
            ("exit 7", .nonzeroExit),
            ("exec /bin/sleep 10", .timedOut),
            ("exec /usr/bin/yes fictional-oversized-output", .resourceLimit),
            ("printf 'unexpected version output'", .invalidOutput)
        ]
        for (body, reason) in cases {
            let executable = try fixture.executable(body)
            let result = await IntegrationHealthProbe.inspect(agent: agent, executableURL: executable,
                                                              configurationURL: nil, helperURL: nil)
            #expect(result.version == .unavailable(reason))
        }
        let missing = await IntegrationHealthProbe.inspect(agent: agent, executableURL: nil,
                                                           configurationURL: nil, helperURL: nil)
        #expect(missing.version == .unavailable(.executableNotFound))
        let unlaunchable = await IntegrationHealthProbe.inspect(agent: agent, executableURL: fixture.directory,
                                                                configurationURL: nil, helperURL: nil)
        #expect(unlaunchable.version == .unavailable(.launchFailed))
    }

    @Test
    func configurationProbeRejectsUnreadableAndUnrecognizedInputs() async throws {
        let fixture = try IntegrationHealthFixture()
        let absent = fixture.directory.appendingPathComponent("missing.json")
        let missing = await IntegrationHealthProbe.inspect(agent: .codex, executableURL: nil,
                                                           configurationURL: absent, helperURL: nil)
        #expect(missing.configuration == .missing)
        let cases: [(String, IntegrationConfigurationEvidence)] = [
            ("{}", .recognizedShape(eventCount: 0, commandCount: 0)),
            ("{", .unavailable(.malformed)),
            ("[]", .unavailable(.unsupportedShape)),
            (#"{"hooks": []}"#, .unavailable(.unsupportedShape)),
            (#"{"hooks":{"Stop":[{"hooks":[{"type":"unknown"}]}]}}"#, .unavailable(.unsupportedShape)),
            (String(repeating: " ", count: 262_145), .unavailable(.resourceLimit))
        ]
        for (body, expected) in cases {
            let config = try fixture.configuration(body)
            let result = await IntegrationHealthProbe.inspect(agent: .codex, executableURL: nil,
                                                              configurationURL: config, helperURL: nil)
            #expect(result.configuration == expected)
        }
        if geteuid() != 0 {
            let locked = try fixture.configuration("{}")
            try FileManager.default.setAttributes([.posixPermissions: 0], ofItemAtPath: locked.path)
            let result = await IntegrationHealthProbe.inspect(agent: .claude, executableURL: nil,
                                                              configurationURL: locked, helperURL: nil)
            #expect(result.configuration == .unavailable(.unreadable))
        }
        let link = fixture.directory.appendingPathComponent("linked.json")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: try fixture.configuration("{}"))
        let linked = await IntegrationHealthProbe.inspect(agent: .codex, executableURL: nil,
                                                          configurationURL: link, helperURL: nil)
        #expect(linked.configuration == .unavailable(.unsupportedShape))
    }

    @Test(arguments: IntegrationAgent.allCases)
    func helperAvailabilityDoesNotInvokeTheHelper(agent: IntegrationAgent) async throws {
        let fixture = try IntegrationHealthFixture()
        let marker = fixture.directory.appendingPathComponent("must-not-exist")
        let helper = try fixture.executable("touch '\(marker.path)'")
        let available = await IntegrationHealthProbe.inspect(agent: agent, executableURL: nil,
                                                             configurationURL: nil, helperURL: helper)
        #expect(available.helper == .available)
        #expect(available.receiver == .notStarted)
        #expect(available.lastDelivery == nil)
        #expect(!FileManager.default.fileExists(atPath: marker.path))
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: helper.path)
        let disabled = await IntegrationHealthProbe.inspect(agent: agent, executableURL: nil,
                                                            configurationURL: nil, helperURL: helper)
        #expect(disabled.helper == .notExecutable)
        let absent = await IntegrationHealthProbe.inspect(agent: agent, executableURL: nil,
                                                          configurationURL: nil,
                                                          helperURL: fixture.directory.appendingPathComponent("absent"))
        #expect(absent.helper == .missing)
        #expect(!FileManager.default.fileExists(atPath: marker.path))
    }

    @Test(arguments: IntegrationAgent.allCases)
    func hookShapeInspectionPreservesEveryConfigurationByte(agent: IntegrationAgent) async throws {
        let fixture = try IntegrationHealthFixture()
        let marker = fixture.directory.appendingPathComponent("hook-must-not-run")
        let body = #"{"env":{"FICTIONAL_TOKEN":"fictional-private-value"},"hooks":{"Stop":[{"matcher":"*","hooks":[{"type":"command","command":"touch '__MARKER__'"}]}]}}"#
            .replacingOccurrences(of: "__MARKER__", with: marker.path)
        let config = try fixture.configuration(body)
        let before = try Data(contentsOf: config)
        let evidence = await IntegrationHealthProbe.inspect(agent: agent, executableURL: nil,
                                                            configurationURL: config, helperURL: nil)
        #expect(evidence.configuration == .recognizedShape(eventCount: 1, commandCount: 1))
        #expect(try Data(contentsOf: config) == before)
        #expect(!FileManager.default.fileExists(atPath: marker.path))
        #expect(evidence.lastDelivery == nil)
    }

    @Test(arguments: IntegrationAgent.allCases)
    func diagnosticsDiscardUnrelatedFictionalValues(agent: IntegrationAgent) async throws {
        let fixture = try IntegrationHealthFixture()
        let sentinel = "FICTIONAL_PRIVATE_SENTINEL"
        let config = try fixture.configuration(#"{"env":{"TOKEN":"FICTIONAL_PRIVATE_SENTINEL"},"hooks":{"Stop":[{"hooks":[{"type":"command","command":"FICTIONAL_PRIVATE_SENTINEL"}]}]}}"#)
        let executable = try fixture.executable("printf '%s\\n' '\(sentinel)'")
        let evidence = await IntegrationHealthProbe.inspect(agent: agent, executableURL: executable,
                                                            configurationURL: config, helperURL: nil)
        #expect(evidence.version == .unavailable(.invalidOutput))
        #expect(!String(reflecting: evidence).contains(sentinel))
        #expect(!String(reflecting: IntegrationHealth.evaluate(evidence)).contains(sentinel))
    }
}

private final class IntegrationHealthFixture {
    let directory: URL

    init() throws {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent("notch-pet-health-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    deinit { try? FileManager.default.removeItem(at: directory) }

    func executable(_ body: String) throws -> URL {
        let url = directory.appendingPathComponent(UUID().uuidString)
        try ("#!/bin/sh\n" + body + "\n").write(to: url, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: url.path)
        return url
    }

    func configuration(_ body: String) throws -> URL {
        let url = directory.appendingPathComponent("\(UUID().uuidString).json")
        try body.write(to: url, atomically: true, encoding: .utf8)
        return url
    }
}
