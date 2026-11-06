import Darwin
import Foundation

/// The lock inode is persistent: unlinking it would allow two writers to hold different locks.
final class UsageEndpointLease {
    private let descriptor: Int32

    init(endpoint: URL) throws {
        let path = endpoint.deletingLastPathComponent().appendingPathComponent("usage-v1.lock").path
        let fd = open(path, O_RDWR | O_CREAT | O_NOFOLLOW | O_CLOEXEC, 0o600)
        guard fd >= 0 else { throw UsageProviderError.invalidSource }
        var info = stat(), named = stat()
        guard fstat(fd, &info) == 0, lstat(path, &named) == 0,
              info.st_dev == named.st_dev, info.st_ino == named.st_ino,
              info.st_mode & S_IFMT == S_IFREG, info.st_uid == getuid(),
              info.st_nlink == 1, info.st_mode & 0o7777 == 0o600,
              flock(fd, LOCK_EX | LOCK_NB) == 0 else {
            close(fd)
            throw UsageProviderError.invalidSource
        }
        descriptor = fd
    }

    deinit {
        _ = flock(descriptor, LOCK_UN)
        close(descriptor)
    }

    func removeRefusedSocket(_ endpoint: URL) throws {
        var original = stat()
        guard lstat(endpoint.path, &original) == 0 else {
            guard errno == ENOENT else { throw UsageProviderError.invalidSource }
            return
        }
        guard original.st_mode & S_IFMT == S_IFSOCK, original.st_uid == getuid(),
              original.st_mode & 0o7777 == 0o600 else { throw UsageProviderError.invalidSource }
        var address = sockaddr_un()
        let bytes = Array(endpoint.path.utf8) + [0]
        guard bytes.count <= MemoryLayout.size(ofValue: address.sun_path) else { throw UsageProviderError.resourceLimit }
        address.sun_family = sa_family_t(AF_UNIX)
        address.sun_len = UInt8(MemoryLayout<sockaddr_un>.size)
        withUnsafeMutableBytes(of: &address.sun_path) { $0.copyBytes(from: bytes) }
        let fd = socket(AF_UNIX, SOCK_DGRAM, 0)
        guard fd >= 0 else { throw UsageProviderError.invalidSource }
        defer { close(fd) }
        guard fcntl(fd, F_SETFL, O_NONBLOCK) == 0 else { throw UsageProviderError.invalidSource }
        let result = withUnsafePointer(to: &address) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                Darwin.connect(fd, $0, socklen_t(MemoryLayout<sockaddr_un>.size))
            }
        }
        let connectionError = errno
        var current = stat()
        guard result < 0, connectionError == ECONNREFUSED,
              lstat(endpoint.path, &current) == 0,
              current.st_dev == original.st_dev, current.st_ino == original.st_ino,
              current.st_mode == original.st_mode, current.st_uid == original.st_uid,
              unlink(endpoint.path) == 0 else { throw UsageProviderError.invalidSource }
    }
}
