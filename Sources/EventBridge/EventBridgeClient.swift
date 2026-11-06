import Darwin
import Foundation

public struct EventBridgeClient: Sendable {
    public let endpoint: BridgeEndpoint
    public init(endpoint: BridgeEndpoint = .standard) { self.endpoint = endpoint }

    public func send(_ envelope: HookEnvelopeV1) throws {
        try send(envelope, until: deadline(after: 250))
    }

    func send(_ envelope: HookEnvelopeV1, until total: UInt64) throws {
        try checkDeadline(total)
        let frame = try envelope.frame()
        let directory = try directoryFD(endpoint, create: false)
        defer { close(directory) }
        guard let info = try socketInfo(directory), info.st_mode & 0o7777 == 0o600 else {
            throw BridgeError.unsafeEndpoint
        }
        let fd = try makeSocket()
        defer { close(fd) }
        try connectSocket(fd, path: endpoint.socketPath, until: deadline(after: 50, total: total))
        try requireSameUser(fd)
        try writeAll(fd, data: frame, until: deadline(after: 50, total: total))
    }
}

/// A hook invocation always fails silently and never returns an approval decision.
public enum HookHelper {
    public static func run(arguments: [String], environment: [String: String], enteredAt: UInt64) {
        let total = enteredAt + 250_000_000
        do {
            guard arguments.count == 2, arguments[0] == "--agent",
                  let agent = Agent(rawValue: arguments[1]) else { return }
            let flags = fcntl(STDIN_FILENO, F_GETFL)
            guard flags >= 0, fcntl(STDIN_FILENO, F_SETFL, flags | O_NONBLOCK) == 0 else { return }
            defer { _ = fcntl(STDIN_FILENO, F_SETFL, flags) }
            let raw = try readBounded(STDIN_FILENO, limit: HookEnvelopeV1.rawHookLimit,
                                      until: deadline(after: 50, total: total), framed: false)
            let envelope = try HookEnvelopeV1.project(rawHook: raw, agent: agent,
                                                     paneSelector: environment["OTTY_PANE_ID"], deadline: total)
            try EventBridgeClient().send(envelope, until: total)
            try checkDeadline(total)
        } catch {
            // No stdout, stderr, retries, acknowledgement, or spool.
        }
    }
}
