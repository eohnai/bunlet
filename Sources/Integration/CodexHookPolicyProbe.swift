import Darwin
import EventBridge
import Foundation

/// Explicit Check/Connect only. These methods inspect configuration, never load a thread or start a turn.
enum CodexHookPolicyProbe {
    private static let frameLimit = 262_144
    private static let totalLimit = 1_048_576
    private static let timeoutNs: UInt64 = 3_000_000_000

    static func inspect(executable: URL, configuration: URL) async -> ProviderHookEnablement {
        let worker = Task.detached(priority: .utility) { exchange(executable: executable, configuration: configuration) }
        return await withTaskCancellationHandler(operation: { await worker.value }, onCancel: { worker.cancel() })
    }

    private static func exchange(executable: URL, configuration: URL) -> ProviderHookEnablement {
        let process = Process()
        let input = Pipe()
        let output = Pipe()
        let reader = output.fileHandleForReading.fileDescriptor
        let writer = input.fileHandleForWriting.fileDescriptor
        defer {
            if process.isRunning { _ = kill(process.processIdentifier, SIGKILL) }
            try? input.fileHandleForWriting.close()
            try? input.fileHandleForReading.close()
            try? output.fileHandleForWriting.close()
            try? output.fileHandleForReading.close()
        }
        guard executable.isFileURL, configuration.isFileURL, !Task.isCancelled,
              fcntl(reader, F_SETFL, O_NONBLOCK) == 0,
              fcntl(writer, F_SETFL, O_NONBLOCK) == 0,
              fcntl(writer, F_SETNOSIGPIPE, 1) == 0 else { return .unverified }
        process.executableURL = executable
        process.arguments = ["app-server", "-c", "analytics.enabled=false", "-c", "feedback.enabled=false"]
        process.currentDirectoryURL = configuration
        var environment = ProcessInfo.processInfo.environment
        environment["CODEX_HOME"] = configuration.path
        process.environment = environment
        process.standardInput = input
        process.standardOutput = output
        process.standardError = FileHandle.nullDevice
        let deadline = DispatchTime.now().uptimeNanoseconds + timeoutNs
        do { try process.run() } catch { return .unverified }
        try? input.fileHandleForReading.close()
        try? output.fileHandleForWriting.close()
        var pending = Data((#"{"id":1,"method":"initialize","params":{"clientInfo":{"name":"notch-pet-setup","version":"0.1.0"},"capabilities":{"experimentalApi":false}}}"# + "\n").utf8)
        var offset = 0
        var expected = 1
        var buffer = Data()
        var total = 0
        var configuredHooks: Bool?
        var managedOnly: Bool?
        var bytes = [UInt8](repeating: 0, count: 8192)
        while !Task.isCancelled, DispatchTime.now().uptimeNanoseconds < deadline {
            if offset < pending.count {
                let count = pending.withUnsafeBytes { block in
                    guard let base = block.baseAddress else { return -1 }
                    return Darwin.write(writer, base.advanced(by: offset), pending.count - offset)
                }
                if count > 0 { offset += count }
                else if count < 0, errno != EAGAIN, errno != EINTR { return .unverified }
            }
            let count = Darwin.read(reader, &bytes, bytes.count)
            if count > 0 {
                total += count
                guard total <= totalLimit else { return .unverified }
                buffer.append(contentsOf: bytes.prefix(count))
                while let newline = buffer.firstIndex(of: 10) {
                    let line = Data(buffer.prefix(upTo: newline))
                    buffer.removeSubrange(...newline)
                    guard line.count <= frameLimit, let document = try? HookConfigurationJSON(data: line) else {
                        return .unverified
                    }
                    guard document.rawValue(at: [.key("id")]) == Data(String(expected).utf8) else { continue }
                    guard document.range(at: [.key("error")]) == nil,
                          document.rawValue(at: [.key("result")])?.first == 123 else { return .unverified }
                    switch expected {
                    case 1:
                        expected = 2
                        pending.append(Data("{\"method\":\"initialized\"}\n{\"id\":2,\"method\":\"config/read\",\"params\":{\"includeLayers\":false}}\n".utf8))
                    case 2:
                        let config: [JSONPathComponent] = [.key("result"), .key("config")]
                        guard document.rawValue(at: config)?.first == 123 else { return .unverified }
                        configuredHooks = boolean(document, config + [.key("features"), .key("hooks")])
                            ?? boolean(document, config + [.key("features"), .key("codex_hooks")])
                        managedOnly = boolean(document, config + [.key("allow_managed_hooks_only")])
                        expected = 3
                        pending.append(Data("{\"id\":3,\"method\":\"configRequirements/read\",\"params\":{}}\n".utf8))
                    case 3:
                        let requirements: [JSONPathComponent] = [.key("result"), .key("requirements")]
                        guard let raw = document.rawValue(at: requirements), raw.first == 123 || raw == Data("null".utf8) else {
                            return .unverified
                        }
                        let required = boolean(document, requirements + [.key("featureRequirements"), .key("hooks")])
                        if managedOnly == true { return .managedOnly }
                        if required == false || configuredHooks == false { return .disabled }
                        // Only explicit effective fields establish enablement; absent fields remain unknown.
                        if managedOnly == false, configuredHooks == true { return .enabled }
                        return .unverified
                    default: return .unverified
                    }
                }
                guard buffer.count <= frameLimit else { return .unverified }
            } else if count == 0 { return .unverified }
            else if errno != EAGAIN, errno != EINTR { return .unverified }
            var descriptors = [pollfd(fd: reader, events: Int16(POLLIN), revents: 0),
                               pollfd(fd: writer, events: offset < pending.count ? Int16(POLLOUT) : 0, revents: 0)]
            _ = poll(&descriptors, 2, 20)
        }
        return .unverified
    }

    private static func boolean(_ document: HookConfigurationJSON, _ path: [JSONPathComponent]) -> Bool? {
        guard let raw = document.rawValue(at: path) else { return nil }
        if raw == Data("true".utf8) { return true }
        if raw == Data("false".utf8) { return false }
        return nil
    }
}
