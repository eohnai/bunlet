import Darwin
import Foundation

/// Usage uses a separate, private endpoint; lifecycle event framing remains unchanged.
public enum UsageDelivery {
    public static var standardEndpoint: URL {
        URL(fileURLWithPath: "/private/tmp/notch-pet-\(getuid())/usage-v1.sock")
    }

    @discardableResult
    public static func send(_ observation: UsageObservation,
                            endpointURL: URL = standardEndpoint) -> Bool {
        guard endpointURL.isFileURL, observation.sourceID.utf8.count <= 256,
              observation.windows.count <= 64,
              let payload = try? JSONEncoder().encode(observation), payload.count <= 8192 else { return false }
        let path = endpointURL.path
        var address = sockaddr_un()
        let bytes = Array(path.utf8) + [0]
        guard bytes.count <= MemoryLayout.size(ofValue: address.sun_path) else { return false }
        var directory = stat(), endpoint = stat()
        guard lstat(endpointURL.deletingLastPathComponent().path, &directory) == 0,
              directory.st_mode & S_IFMT == S_IFDIR, directory.st_uid == getuid(),
              directory.st_mode & 0o7777 == 0o700,
              lstat(path, &endpoint) == 0, endpoint.st_mode & S_IFMT == S_IFSOCK,
              endpoint.st_uid == getuid(), endpoint.st_mode & 0o7777 == 0o600 else { return false }
        let fd = socket(AF_UNIX, SOCK_DGRAM, 0)
        guard fd >= 0 else { return false }
        defer { close(fd) }
        guard fcntl(fd, F_SETFL, O_NONBLOCK) == 0, fcntl(fd, F_SETFD, FD_CLOEXEC) == 0 else { return false }
        address.sun_family = sa_family_t(AF_UNIX)
        address.sun_len = UInt8(MemoryLayout<sockaddr_un>.size)
        withUnsafeMutableBytes(of: &address.sun_path) { $0.copyBytes(from: bytes) }
        let sent = withUnsafePointer(to: &address) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { address in
                payload.withUnsafeBytes {
                    sendto(fd, $0.baseAddress, $0.count, 0, address,
                           socklen_t(MemoryLayout<sockaddr_un>.size))
                }
            }
        }
        return sent == payload.count
    }
}
