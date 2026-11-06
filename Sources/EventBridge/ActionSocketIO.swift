import Darwin
import Foundation

/// Shared bounded socket primitives; the action protocol never enters the lifecycle event receiver.
public enum ActionSocketIO {
    public static let frameLimit = 65_536
    public static let waitMs: UInt64 = 60_000
    public static let handshakeMs: UInt64 = 250

    public static func read(_ fd: Int32, timeoutMs: UInt64) throws -> Data {
        try readBounded(fd, limit: frameLimit, until: deadline(after: min(timeoutMs, waitMs)), framed: true)
    }

    public static func write(_ fd: Int32, frame: Data) throws {
        guard frame.count <= frameLimit, frame.last == 10 else { throw BridgeError.invalidMessage }
        try writeAll(fd, data: frame, until: deadline(after: handshakeMs))
    }

    public static func readHookInput() throws -> Data {
        try readBounded(STDIN_FILENO, limit: HookEnvelopeV1.rawHookLimit,
                        until: deadline(after: handshakeMs), framed: false)
    }

    public static func connect(endpoint: BridgeEndpoint = .standard) throws -> Int32 {
        let directory = try directoryFD(endpoint, create: false)
        defer { close(directory) }
        guard let info = try socketInfo(directory, name: "actions-v1.sock"),
              info.st_mode & 0o7777 == 0o600 else { throw BridgeError.unsafeEndpoint }
        let fd = try makeSocket()
        do {
            try connectSocket(fd, path: endpoint.directory + "/actions-v1.sock", until: deadline(after: handshakeMs))
            try requireSameUser(fd)
            return fd
        } catch {
            close(fd)
            throw error
        }
    }

    public static func accept(_ listener: Int32) throws -> Int32? {
        let fd = Darwin.accept(listener, nil, nil)
        if fd < 0 {
            if errno == EAGAIN || errno == EWOULDBLOCK || errno == EINTR { return nil }
            throw BridgeError.unavailable
        }
        do {
            guard fcntl(fd, F_SETFL, O_NONBLOCK) == 0, fcntl(fd, F_SETFD, FD_CLOEXEC) == 0 else { throw BridgeError.unavailable }
            var enabled: Int32 = 1
            guard setsockopt(fd, SOL_SOCKET, SO_NOSIGPIPE, &enabled, socklen_t(MemoryLayout<Int32>.size)) == 0 else {
                throw BridgeError.unavailable
            }
            try requireSameUser(fd)
            return fd
        } catch {
            close(fd)
            throw error
        }
    }

    /// A provider response must fit the same bound; stdout is not part of the observer helper.
    public static func writeProviderOutput(_ data: Data) throws {
        guard data.count <= frameLimit else { throw BridgeError.invalidMessage }
        let originalFlags = fcntl(STDOUT_FILENO, F_GETFL)
        guard originalFlags >= 0, fcntl(STDOUT_FILENO, F_SETFL, originalFlags | O_NONBLOCK) == 0 else { throw BridgeError.unavailable }
        defer { _ = fcntl(STDOUT_FILENO, F_SETFL, originalFlags) }
        _ = fcntl(STDOUT_FILENO, F_SETNOSIGPIPE, 1)
        try writeAll(STDOUT_FILENO, data: data, until: deadline(after: handshakeMs))
    }
}

/// Lifetime is retained through DispatchSource cancellation, so descriptors cannot be reused mid-handler.
public final class ActionSocketListener: @unchecked Sendable {
    public let descriptor: Int32
    private let directory: Int32
    private let lock: Int32
    private let identity: stat

    public init(endpoint: BridgeEndpoint = .standard) throws {
        let parent = try directoryFD(endpoint, create: true)
        var lease: Int32 = -1
        var fd: Int32 = -1
        var owned: stat?
        do {
            lease = openat(parent, "actions-v1.lock", O_RDWR | O_CREAT | O_NOFOLLOW | O_CLOEXEC | O_NONBLOCK, 0o600)
            var info = stat()
            guard lease >= 0, fstat(lease, &info) == 0, info.st_uid == getuid(),
                  info.st_mode & S_IFMT == S_IFREG, info.st_mode & 0o7777 == 0o600, info.st_nlink == 1,
                  flock(lease, LOCK_EX | LOCK_NB) == 0 else { throw BridgeError.unsafeEndpoint }
            let path = endpoint.directory + "/actions-v1.sock"
            if let existing = try socketInfo(parent, name: "actions-v1.sock") {
                let probe = try makeSocket()
                defer { close(probe) }
                let result = try withAddress(path) { Darwin.connect(probe, $0, $1) }
                guard result == -1, errno == ECONNREFUSED,
                      let current = try socketInfo(parent, name: "actions-v1.sock"), sameFile(existing, current),
                      unlinkat(parent, "actions-v1.sock", 0) == 0 else { throw BridgeError.unavailable }
            }
            fd = try makeSocket()
            guard try withAddress(path, { bind(fd, $0, $1) }) == 0 else { throw BridgeError.unavailable }
            owned = try socketInfo(parent, name: "actions-v1.sock")
            guard let owned, fchmodat(parent, "actions-v1.sock", 0o600, 0) == 0, listen(fd, 8) == 0 else {
                throw BridgeError.unavailable
            }
            directory = parent
            lock = lease
            descriptor = fd
            identity = owned
        } catch {
            if fd >= 0 { close(fd) }
            if let owned { removeOwnedSocket(parent, identity: owned, name: "actions-v1.sock") }
            if lease >= 0 { close(lease) }
            close(parent)
            throw error
        }
    }

    deinit {
        close(descriptor)
        removeOwnedSocket(directory, identity: identity, name: "actions-v1.sock")
        close(lock)
        close(directory)
    }
}
