import EventBridge
import Darwin
import Foundation
import Testing
@testable import Integration

@Suite(.serialized)
struct ProviderSetupServiceTests {
    @Test(arguments: [Agent.codex, .claude])
    func connectsAndRemovesHooksFromCleanDesktopConfiguration(agent: Agent) async throws {
        let root = URL(fileURLWithPath: "/private/tmp/bunlet-desktop-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false,
                                               attributes: [.posixPermissions: 0o700])
        defer { try? FileManager.default.removeItem(at: root) }
        let executable = root.appendingPathComponent("agent")
        let version = agent == .codex ? "codex-cli 0.169.0-alpha.11.1" : "2.1.325 (Claude Code)"
        try "#!/bin/sh\n[ \"$1\" = --version ] || exit 1\nprintf '%s\\n' '\(version)'\n".write(to: executable, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: executable.path)
        let helper = root.appendingPathComponent("NotchPetHook")
        try FileManager.default.copyItem(at: executable, to: helper)
        let configuration = root.appendingPathComponent("configuration", isDirectory: true)
        try FileManager.default.createDirectory(at: configuration, withIntermediateDirectories: false,
                                               attributes: [.posixPermissions: 0o700])
        let configFile = configuration.appendingPathComponent(agent.hookConfigurationName)
        let original = Data(#"{"hooks":{"Stop":[{"hooks":[{"type":"command","command":"/usr/bin/true"}]}]}}"#.utf8)
        try original.write(to: configFile)
        let context = ProviderSetupContext(configurationDirectory: configuration,
            ownershipDirectory: root.appendingPathComponent("ownership"), helperURL: helper,
            executableURL: executable, agent: agent)
        let service = ProviderSetupService()
        let connected = try await service.executeAndInspect(.connect, context: context)
        #expect(connected.inspection.ownership == .owned)
        let installed = try Data(contentsOf: configFile)
        #expect(String(decoding: installed, as: UTF8.self).contains("/usr/bin/true"))
        #expect(try await service.execute(.connect, context: context) == .unchanged)
        #expect(try Data(contentsOf: configFile) == installed)
        _ = try await service.execute(.remove, context: context)
        #expect(try Data(contentsOf: configFile) == original)

        // Unknown user metadata must still block transactions.
        let attribute = "org.example.bunlet.test"
        let value: [UInt8] = [1]
        try #require(setxattr(configFile.path, attribute, value, value.count, 0, 0) == 0)
        await #expect(throws: ProviderSetupFailure.unsafeMetadata) {
            try await service.execute(.connect, context: context)
        }
        #expect(try Data(contentsOf: configFile) == original)
    }

    @Test func postSaveVerificationReadsChangedFilesWithoutRepeatingCLIOrPolicyProbe() async throws {
        // Foundation standardizes /private/tmp to /tmp, which the path guard rejects as a symlink.
        let directory = URL(fileURLWithPath: "/Users/Shared", isDirectory: true)
            .appendingPathComponent("bunlet-setup-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true,
                                               attributes: [.posixPermissions: 0o700])
        defer { try? FileManager.default.removeItem(at: directory) }
        let executable = directory.appendingPathComponent("fictional-codex")
        let calls = directory.appendingPathComponent("version-calls")
        try "#!/bin/sh\nprintf 'call\\n' >> '\(calls.path)'\nprintf 'codex-cli 0.164.0\\n'\n"
            .write(to: executable, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: executable.path)
        let configuration = directory.appendingPathComponent("configuration")
        try FileManager.default.createDirectory(at: configuration, withIntermediateDirectories: false,
                                               attributes: [.posixPermissions: 0o700])
        let configFile = configuration.appendingPathComponent("hooks.json")
        try "{}".write(to: configFile, atomically: true, encoding: .utf8)
        let recorder = SetupProbeRecorder()
        let service = ProviderSetupService(releases: ["0.164.0": CodexHookQualification { _, _ in
            await recorder.recordPolicy()
            return .enabled
        }])
        let context = ProviderSetupContext(configurationDirectory: configuration,
            ownershipDirectory: directory.appendingPathComponent("ownership"), helperURL: executable,
            executableURL: executable, agent: .codex)
        let preflight = await service.check(context)
        #expect(preflight.installationUnavailable == nil)
        #expect(preflight.health.configuration == .recognizedShape(eventCount: 0, commandCount: 0))

        // Test the post-save seam without changing the transaction's strict metadata policy.
        let changed = Data(#"{"hooks":{"Stop":[{"hooks":[{"type":"command","command":"fictional-observer"}]}]}}"#.utf8)
        try changed.write(to: configFile)
        let verified = await service.check(context, preflight: preflight)
        #expect(verified.health.configuration == .recognizedShape(eventCount: 1, commandCount: 1))
        #expect(verified.health.version == .reported("0.164.0"))
        #expect(verified.policy == .enabled)
        #expect(await recorder.policyCalls == 1)
        #expect(try String(contentsOf: calls, encoding: .utf8) == "call\n")
        #expect(try Data(contentsOf: configFile) == changed)

        let freshCheck = await service.check(context)
        #expect(freshCheck.health.configuration == verified.health.configuration)
        #expect(await recorder.policyCalls == 2)
        #expect(try String(contentsOf: calls, encoding: .utf8) == "call\ncall\n")

        try Data("{".utf8).write(to: configFile)
        let malformed = await service.check(context, preflight: preflight)
        #expect(malformed.health.configuration == .unavailable(.malformed))
        #expect(malformed.ownership == .conflict)
        #expect(await recorder.policyCalls == 2)
        #expect(try String(contentsOf: calls, encoding: .utf8) == "call\ncall\n")
    }
}

private actor SetupProbeRecorder {
    var policyCalls = 0
    func recordPolicy() { policyCalls += 1 }
}
