import Darwin
import Foundation

public struct BridgeEndpoint: Sendable {
    public let directory: String
    public var socketPath: String { directory + "/events-v1.sock" }
    public static var standard: Self { Self(directory: "/private/tmp/notch-pet-\(getuid())") }

    /// Custom directories are for isolated tests. Production uses `standard`.
    public init(directory: String) { self.directory = directory }
}

func monotonicNanoseconds() -> UInt64 { DispatchTime.now().uptimeNanoseconds }
func wallMilliseconds() -> Int64 { Int64(Date().timeIntervalSince1970 * 1000) }
func deadline(after milliseconds: UInt64, total: UInt64? = nil) -> UInt64 {
    min(monotonicNanoseconds() + milliseconds * 1_000_000, total ?? UInt64.max)
}
func checkDeadline(_ limit: UInt64?) throws {
    if let limit, monotonicNanoseconds() >= limit { throw BridgeError.timeout }
}

func waitFor(_ fd: Int32, _ events: Int16, until limit: UInt64) throws {
    while true {
        try checkDeadline(limit)
        let remaining = limit - min(limit, monotonicNanoseconds())
        var descriptor = pollfd(fd: fd, events: events, revents: 0)
        let result = poll(&descriptor, 1, Int32((remaining + 999_999) / 1_000_000))
        if result < 0 && errno == EINTR { continue }
        guard result >= 0 else { throw BridgeError.unavailable }
        if result == 0 { throw BridgeError.timeout }
        try checkDeadline(limit)
        guard descriptor.revents & Int16(POLLNVAL) == 0 else { throw BridgeError.unavailable }
        // HUP and ERR must reach read/connect, which determine EOF or the socket error.
        return
    }
}

func makeSocket() throws -> Int32 {
    let fd = socket(AF_UNIX, SOCK_STREAM, 0)
    guard fd >= 0 else { throw BridgeError.unavailable }
    do {
        guard fcntl(fd, F_SETFD, FD_CLOEXEC) == 0,
              fcntl(fd, F_SETFL, O_NONBLOCK) == 0 else { throw BridgeError.unavailable }
        var enabled: Int32 = 1
        guard setsockopt(fd, SOL_SOCKET, SO_NOSIGPIPE, &enabled, socklen_t(MemoryLayout.size(ofValue: enabled))) == 0
        else { throw BridgeError.unavailable }
        return fd
    } catch { close(fd); throw error }
}

func withAddress<T>(_ path: String, _ body: (UnsafePointer<sockaddr>, socklen_t) throws -> T) throws -> T {
    var address = sockaddr_un()
    let pathBytes = Array(path.utf8) + [0]
    guard path.hasPrefix("/"), !path.utf8.contains(0), pathBytes.count <= MemoryLayout.size(ofValue: address.sun_path)
    else { throw BridgeError.unsafeEndpoint }
    address.sun_family = sa_family_t(AF_UNIX)
    address.sun_len = UInt8(MemoryLayout<sockaddr_un>.size)
    withUnsafeMutableBytes(of: &address.sun_path) { buffer in
        buffer.copyBytes(from: pathBytes)
    }
    return try withUnsafePointer(to: &address) { pointer in
        try pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) {
            try body($0, socklen_t(MemoryLayout<sockaddr_un>.size))
        }
    }
}

func connectSocket(_ fd: Int32, path: String, until limit: UInt64) throws {
    try checkDeadline(limit)
    let result = try withAddress(path) { connect(fd, $0, $1) }
    if result != 0 {
        guard errno == EINPROGRESS || errno == EAGAIN || errno == EWOULDBLOCK else {
            throw BridgeError.unavailable
        }
        try waitFor(fd, Int16(POLLOUT), until: limit)
        var error: Int32 = 0
        var size = socklen_t(MemoryLayout.size(ofValue: error))
        guard getsockopt(fd, SOL_SOCKET, SO_ERROR, &error, &size) == 0, error == 0 else {
            throw BridgeError.unavailable
        }
    }
    try checkDeadline(limit)
}

func requireSameUser(_ fd: Int32, expectedUID: uid_t = getuid()) throws {
    var uid: uid_t = 0
    var gid: gid_t = 0
    guard getpeereid(fd, &uid, &gid) == 0, uid == expectedUID else { throw BridgeError.unsafeEndpoint }
}

func directoryFD(_ endpoint: BridgeEndpoint, create: Bool) throws -> Int32 {
    guard endpoint.directory.hasPrefix("/"), !endpoint.directory.utf8.contains(0) else {
        throw BridgeError.unsafeEndpoint
    }
    if create && mkdir(endpoint.directory, 0o700) != 0 && errno != EEXIST { throw BridgeError.unsafeEndpoint }
    let fd = open(endpoint.directory, O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC)
    guard fd >= 0 else { throw BridgeError.unsafeEndpoint }
    var info = stat()
    guard fstat(fd, &info) == 0, info.st_mode & S_IFMT == S_IFDIR,
          info.st_uid == getuid(), info.st_mode & 0o7777 == 0o700 else {
        close(fd)
        throw BridgeError.unsafeEndpoint
    }
    return fd
}

func socketInfo(_ directory: Int32) throws -> stat? {
    var info = stat()
    if fstatat(directory, "events-v1.sock", &info, AT_SYMLINK_NOFOLLOW) != 0 {
        if errno == ENOENT { return nil }
        throw BridgeError.unsafeEndpoint
    }
    guard info.st_uid == getuid(), info.st_mode & S_IFMT == S_IFSOCK,
          info.st_nlink == 1 else { throw BridgeError.unsafeEndpoint }
    return info
}

func sameFile(_ first: stat, _ second: stat) -> Bool {
    first.st_dev == second.st_dev && first.st_ino == second.st_ino
}

func removeOwnedSocket(_ directory: Int32, identity: stat) {
    if let current = try? socketInfo(directory), sameFile(identity, current) {
        _ = unlinkat(directory, "events-v1.sock", 0)
    }
}

func readBounded(_ fd: Int32, limit: Int, until end: UInt64, framed: Bool,
                 wait: (Int32, Int16, UInt64) throws -> Void = waitFor) throws -> Data {
    var result = Data()
    var buffer = [UInt8](repeating: 0, count: 4096)
    while true {
        try wait(fd, Int16(POLLIN), end)
        let count = read(fd, &buffer, min(buffer.count, limit + 1 - result.count))
        if count < 0 && [EINTR, EAGAIN, EWOULDBLOCK].contains(errno) { continue }
        guard count >= 0 else { throw BridgeError.unavailable }
        if count == 0 {
            guard !framed else { throw BridgeError.invalidMessage }
            return result
        }
        guard count <= limit - result.count else { throw BridgeError.invalidMessage }
        result.append(contentsOf: buffer.prefix(count))
        if framed, let newline = result.firstIndex(of: 10) {
            guard newline == result.index(before: result.endIndex) else { throw BridgeError.invalidMessage }
            // Reject any extra byte already queued in the kernel, including a second frame.
            var extra: UInt8 = 0
            let count = recv(fd, &extra, 1, MSG_PEEK | MSG_DONTWAIT)
            guard count <= 0 else { throw BridgeError.invalidMessage }
            if count < 0 && errno != EAGAIN && errno != EWOULDBLOCK { throw BridgeError.unavailable }
            return result
        }
    }
}

func writeAll(_ fd: Int32, data: Data, until end: UInt64) throws {
    try data.withUnsafeBytes { bytes in
        var written = 0
        while written < bytes.count {
            try waitFor(fd, Int16(POLLOUT), until: end)
            let count = write(fd, bytes.baseAddress!.advanced(by: written), bytes.count - written)
            if count < 0 && [EINTR, EAGAIN, EWOULDBLOCK].contains(errno) { continue }
            guard count > 0 else { throw BridgeError.unavailable }
            written += count
        }
    }
    try checkDeadline(end)
}
