import EventBridge
import Darwin
import Foundation
import os

/// Call stop during app shutdown. A lease permits recovery of provably refused owned sockets.
public final class UsageReceiver {
    private let endpointURL: URL
    private let lock = NSLock()
    private var source: DispatchSourceRead?
    private var identity: stat?
    private var lease: UsageEndpointLease?
    private var cancelled = OSAllocatedUnfairLock(initialState: false)

    public init(endpointURL: URL = UsageDelivery.standardEndpoint) { self.endpointURL = endpointURL }

    public func start(onRejected: @escaping @Sendable () -> Void = {},
                      onObservation: @escaping @Sendable (UsageObservation) -> Void) throws {
        lock.lock()
        defer { lock.unlock() }
        guard source == nil, endpointURL.isFileURL else { throw UsageProviderError.invalidSource }
        let parent = endpointURL.deletingLastPathComponent().path
        var directory = stat(), existing = stat()
        if lstat(parent, &directory) != 0 {
            guard errno == ENOENT, mkdir(parent, 0o700) == 0,
                  lstat(parent, &directory) == 0 else { throw UsageProviderError.invalidSource }
        }
        guard directory.st_mode & S_IFMT == S_IFDIR, directory.st_uid == getuid(),
              directory.st_mode & 0o7777 == 0o700 else {
            throw UsageProviderError.invalidSource
        }
        let candidateLease = try UsageEndpointLease(endpoint: endpointURL)
        try candidateLease.removeRefusedSocket(endpointURL)
        var address = sockaddr_un()
        let path = Array(endpointURL.path.utf8) + [0]
        guard path.count <= MemoryLayout.size(ofValue: address.sun_path) else { throw UsageProviderError.resourceLimit }
        let fd = socket(AF_UNIX, SOCK_DGRAM, 0)
        guard fd >= 0 else { throw UsageProviderError.invalidSource }
        var ready = false, owned: stat?
        defer {
            if !ready {
                close(fd)
                if let owned {
                    var current = stat()
                    if lstat(endpointURL.path, &current) == 0 && current.st_ino == owned.st_ino && current.st_dev == owned.st_dev {
                        _ = unlink(endpointURL.path)
                    }
                }
            }
        }
        var capacity = UsageDelivery.receiveBufferBytes
        guard setsockopt(fd, SOL_SOCKET, SO_RCVBUF, &capacity, socklen_t(MemoryLayout<Int32>.size)) == 0,
              fcntl(fd, F_SETFL, O_NONBLOCK) == 0, fcntl(fd, F_SETFD, FD_CLOEXEC) == 0 else {
            throw UsageProviderError.invalidSource
        }
        address.sun_family = sa_family_t(AF_UNIX)
        address.sun_len = UInt8(MemoryLayout<sockaddr_un>.size)
        withUnsafeMutableBytes(of: &address.sun_path) { $0.copyBytes(from: path) }
        let bound = withUnsafePointer(to: &address) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                Darwin.bind(fd, $0, socklen_t(MemoryLayout<sockaddr_un>.size))
            }
        }
        guard bound == 0, lstat(endpointURL.path, &existing) == 0 else { throw UsageProviderError.invalidSource }
        owned = existing
        guard chmod(endpointURL.path, 0o600) == 0 else { throw UsageProviderError.invalidSource }
        let flag = OSAllocatedUnfairLock(initialState: false)
        let reader = DispatchSource.makeReadSource(fileDescriptor: fd,
                                                   queue: DispatchQueue(label: "local.notchpet.usage"))
        reader.setEventHandler {
            var bytes = [UInt8](repeating: 0, count: UsageDelivery.payloadLimit + 1)
            for _ in 0..<32 {
                guard !flag.withLock({ $0 }) else { return }
                let count = recv(fd, &bytes, bytes.count, 0)
                if count < 0 { return }
                guard count > 0, count <= UsageDelivery.payloadLimit,
                      let value = try? JSONDecoder().decode(UsageObservation.self, from: Data(bytes.prefix(count))),
                      UsageValidation.acceptsClaudeIngress(value) else {
                    if !flag.withLock({ $0 }) { onRejected() }
                    continue
                }
                guard !flag.withLock({ $0 }) else { return }
                onObservation(UsageObservation(provider: value.provider, sourceID: value.sourceID,
                    accountID: value.accountID, receivedAtMs: Int64(Date().timeIntervalSince1970 * 1000),
                    measuredAtMs: value.measuredAtMs, windows: value.windows, failure: value.failure))
            }
        }
        reader.setCancelHandler { close(fd) }
        source = reader
        identity = owned
        lease = candidateLease
        cancelled = flag
        ready = true
        reader.resume()
    }

    public func stop() {
        lock.lock()
        defer { lock.unlock() }
        cancelled.withLock { $0 = true }
        source?.cancel()
        source = nil
        if let identity {
            var current = stat()
            if lstat(endpointURL.path, &current) == 0 && current.st_ino == identity.st_ino &&
                current.st_dev == identity.st_dev && current.st_mode & S_IFMT == S_IFSOCK && current.st_uid == getuid() {
                _ = unlink(endpointURL.path)
            }
        }
        identity = nil
        lease = nil
    }
}
