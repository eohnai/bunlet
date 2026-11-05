import Darwin
import Foundation

public enum IntegrationAgent: String, CaseIterable, Hashable, Sendable {
    case codex, claude
}

/// Bounded categories only. Raw errors, configuration values and process output are not diagnostics.
public enum IntegrationHealthFailure: String, Equatable, Sendable {
    /// Not found at the supplied executable/lookup path; not a machine-wide installation claim.
    case executableNotFound
    case unreadable, malformed, unsupportedShape, resourceLimit
    case launchFailed, timedOut, nonzeroExit, invalidOutput
    case unsafeEndpoint, receiverUnavailable
}

public enum IntegrationVersionEvidence: Equatable, Sendable {
    case notChecked
    case reported(String)
    case unavailable(IntegrationHealthFailure)
}

public enum IntegrationVersionSupport: Equatable, Sendable {
    case notChecked
    /// Appears in the compatibility record, whose per-event/runtime limitations still apply.
    case recordedCompatibility(String)
    case unverified(String)
    case unavailable(IntegrationHealthFailure)
}

public enum IntegrationConfigurationEvidence: Equatable, Sendable {
    case notChecked, missing
    /// Counts describe the hook JSON shape, not app ownership, agent enablement, or hook trust.
    case recognizedShape(eventCount: Int, commandCount: Int)
    case unavailable(IntegrationHealthFailure)
}

public enum IntegrationHelperAvailability: Equatable, Sendable {
    case notChecked, available, missing, notExecutable
    case unavailable(IntegrationHealthFailure)
}

public enum IntegrationReceiverState: Equatable, Sendable {
    case notStarted, listening, stopped
    case failed(IntegrationHealthFailure)
}

/// A validated observation's receipt, independent of a session's lifecycle/freshness.
public struct IntegrationDeliveryReceipt: Equatable, Sendable {
    public let wallMs: Int64
    public let monotonicNs: UInt64

    public init(wallMs: Int64, monotonicNs: UInt64) {
        self.wallMs = wallMs
        self.monotonicNs = monotonicNs
    }
}

public struct IntegrationHealthEvidence: Equatable, Sendable {
    public let agent: IntegrationAgent
    public var version: IntegrationVersionEvidence
    public var configuration: IntegrationConfigurationEvidence
    public var helper: IntegrationHelperAvailability
    public var receiver: IntegrationReceiverState
    public var lastDelivery: IntegrationDeliveryReceipt?

    public init(agent: IntegrationAgent, version: IntegrationVersionEvidence = .notChecked,
                configuration: IntegrationConfigurationEvidence = .notChecked,
                helper: IntegrationHelperAvailability = .notChecked,
                receiver: IntegrationReceiverState = .notStarted,
                lastDelivery: IntegrationDeliveryReceipt? = nil) {
        self.agent = agent
        self.version = version
        self.configuration = configuration
        self.helper = helper
        self.receiver = receiver
        self.lastDelivery = lastDelivery
    }
}

/// No aggregate connected/disconnected flag: each observation proves only its own field.
public struct IntegrationHealthSnapshot: Equatable, Sendable {
    public let agent: IntegrationAgent
    public let version: IntegrationVersionSupport
    public let configuration: IntegrationConfigurationEvidence
    public let helper: IntegrationHelperAvailability
    public let receiver: IntegrationReceiverState
    public let lastDelivery: IntegrationDeliveryReceipt?
}

public enum IntegrationHealth {
    public static func evaluate(_ evidence: IntegrationHealthEvidence) -> IntegrationHealthSnapshot {
        let version: IntegrationVersionSupport
        switch evidence.version {
        case .notChecked:
            version = .notChecked
        case .unavailable(let reason):
            version = .unavailable(reason)
        case .reported(let value):
            let parts = value.split(separator: ".", omittingEmptySubsequences: false)
            let isVersion = value.utf8.count <= 32 && parts.count == 3 && parts.allSatisfy {
                !$0.isEmpty && $0.utf8.allSatisfy { (48...57).contains($0) }
            }
            let recorded = evidence.agent == .codex ? ["0.163.0", "0.164.0"] : ["2.1.306"]
            if !isVersion {
                version = .unavailable(.invalidOutput)
            } else if recorded.contains(value) {
                version = .recordedCompatibility(value)
            } else {
                version = .unverified(value)
            }
        }
        return IntegrationHealthSnapshot(agent: evidence.agent, version: version,
                                         configuration: evidence.configuration, helper: evidence.helper,
                                         receiver: evidence.receiver, lastDelivery: evidence.lastDelivery)
    }
}

/// Read-only probes. Callers supply paths; no configuration commands or agent turns are executed.
public enum IntegrationHealthProbe {
    private static let outputLimit = 65_536
    private static let configurationLimit = 262_144
    private static let processTimeoutNs: UInt64 = 2_000_000_000

    public static func inspect(agent: IntegrationAgent, executableURL: URL?,
                               configurationURL: URL?, helperURL: URL?) async -> IntegrationHealthEvidence {
        await Task.detached(priority: .utility) {
            let version = readVersion(agent: agent, executableURL: executableURL)
            let configuration = readConfiguration(configurationURL)
            let helper: IntegrationHelperAvailability
            if let helperURL, helperURL.isFileURL {
                var info = stat()
                if lstat(helperURL.path, &info) != 0 {
                    helper = errno == ENOENT ? .missing : .unavailable(.unreadable)
                } else if info.st_mode & S_IFMT != S_IFREG {
                    helper = .unavailable(.unsupportedShape)
                } else {
                    helper = FileManager.default.isExecutableFile(atPath: helperURL.path) ? .available : .notExecutable
                }
            } else {
                helper = helperURL == nil ? .missing : .unavailable(.unsupportedShape)
            }
            return IntegrationHealthEvidence(agent: agent, version: version,
                                             configuration: configuration, helper: helper)
        }.value
    }

    private static func readVersion(agent: IntegrationAgent, executableURL: URL?) -> IntegrationVersionEvidence {
        guard let executableURL else { return .unavailable(.executableNotFound) }
        guard executableURL.isFileURL else { return .unavailable(.launchFailed) }
        let process = Process()
        let output = Pipe()
        let fd = output.fileHandleForReading.fileDescriptor
        defer {
            // Kill only the process we launched. Never wait indefinitely for exit or inherited pipe writers.
            if process.isRunning { _ = Darwin.kill(process.processIdentifier, SIGKILL) }
            try? output.fileHandleForReading.close()
            try? output.fileHandleForWriting.close()
        }
        guard fcntl(fd, F_SETFL, O_NONBLOCK) == 0 else { return .unavailable(.launchFailed) }
        process.executableURL = executableURL
        process.arguments = ["--version"]
        process.standardInput = FileHandle.nullDevice
        process.standardOutput = output
        process.standardError = output
        let deadline = DispatchTime.now().uptimeNanoseconds + processTimeoutNs
        do { try process.run() }
        catch { return .unavailable(.launchFailed) }
        try? output.fileHandleForWriting.close()
        var data = Data()
        var bytes = [UInt8](repeating: 0, count: 8192)
        while true {
            let now = DispatchTime.now().uptimeNanoseconds
            guard now < deadline else { return .unavailable(.timedOut) }
            let count = bytes.withUnsafeMutableBytes { buffer in
                Darwin.read(fd, buffer.baseAddress, buffer.count)
            }
            if count > 0 {
                guard data.count + count <= outputLimit else { return .unavailable(.resourceLimit) }
                data.append(contentsOf: bytes.prefix(count))
                continue
            }
            if count == 0 {
                if !process.isRunning { break }
                // EOF may precede process exit; POLLHUP itself would otherwise spin.
                Thread.sleep(forTimeInterval: 0.01)
                continue
            }
            if count < 0 && errno != EAGAIN && errno != EWOULDBLOCK && errno != EINTR {
                return .unavailable(.unreadable)
            }
            var descriptor = pollfd(fd: fd, events: Int16(POLLIN), revents: 0)
            // Recheck exit/deadline even if a child holds the inherited output pipe open.
            let remainingMs = (deadline - min(deadline, DispatchTime.now().uptimeNanoseconds)) / 1_000_000
            if poll(&descriptor, 1, Int32(min(remainingMs, 20))) < 0 && errno != EINTR {
                return .unavailable(.unreadable)
            }
        }
        guard process.terminationStatus == 0 else { return .unavailable(.nonzeroExit) }
        guard let text = String(data: data, encoding: .utf8) else { return .unavailable(.invalidOutput) }
        let words = text.split(whereSeparator: \.isWhitespace)
        let version: String
        switch agent {
        case .codex:
            guard words.count == 2, words[0] == "codex-cli" else { return .unavailable(.invalidOutput) }
            version = String(words[1])
        case .claude:
            guard words.count == 1 || (words.count == 3 && words[1] == "(Claude" && words[2] == "Code)") else {
                return .unavailable(.invalidOutput)
            }
            version = String(words[0])
        }
        let parts = version.split(separator: ".", omittingEmptySubsequences: false)
        guard version.utf8.count <= 32, parts.count == 3, parts.allSatisfy({
            !$0.isEmpty && $0.utf8.allSatisfy { (48...57).contains($0) }
        }) else { return .unavailable(.invalidOutput) }
        return .reported(version)
    }

    private static func readConfiguration(_ url: URL?) -> IntegrationConfigurationEvidence {
        guard let url else { return .notChecked }
        guard url.isFileURL else { return .unavailable(.unsupportedShape) }
        let fd = open(url.path, O_RDONLY | O_CLOEXEC | O_NOFOLLOW | O_NONBLOCK)
        guard fd >= 0 else {
            if errno == ENOENT { return .missing }
            return .unavailable(errno == ELOOP ? .unsupportedShape : .unreadable)
        }
        defer { close(fd) }
        var info = stat()
        guard fstat(fd, &info) == 0 else { return .unavailable(.unreadable) }
        guard info.st_mode & S_IFMT == S_IFREG else { return .unavailable(.unsupportedShape) }
        guard info.st_size >= 0, info.st_size <= Int64(configurationLimit) else { return .unavailable(.resourceLimit) }
        var data = Data()
        var bytes = [UInt8](repeating: 0, count: 8192)
        while true {
            let count = bytes.withUnsafeMutableBytes { buffer in
                Darwin.read(fd, buffer.baseAddress, min(buffer.count, configurationLimit + 1 - data.count))
            }
            if count == 0 { break }
            if count < 0 {
                if errno == EINTR { continue }
                return .unavailable(.unreadable)
            }
            data.append(contentsOf: bytes.prefix(count))
            guard data.count <= configurationLimit else { return .unavailable(.resourceLimit) }
        }
        let value: Any
        do { value = try JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed]) }
        catch { return .unavailable(.malformed) }
        guard let root = value as? [String: Any] else { return .unavailable(.unsupportedShape) }
        // Inspect only the hooks subtree. Never expose other fields, hook commands or decoder errors.
        guard let rawHooks = root["hooks"] else { return .recognizedShape(eventCount: 0, commandCount: 0) }
        guard let hooks = rawHooks as? [String: Any] else { return .unavailable(.unsupportedShape) }
        var commands = 0
        for rawGroups in hooks.values {
            guard let groups = rawGroups as? [[String: Any]] else { return .unavailable(.unsupportedShape) }
            for group in groups {
                guard group["matcher"] == nil || group["matcher"] is String,
                      let handlers = group["hooks"] as? [[String: Any]] else {
                    return .unavailable(.unsupportedShape)
                }
                for handler in handlers {
                    guard handler["type"] as? String == "command", handler["command"] is String else {
                        return .unavailable(.unsupportedShape)
                    }
                    commands += 1
                }
            }
        }
        return .recognizedShape(eventCount: hooks.count, commandCount: commands)
    }
}
