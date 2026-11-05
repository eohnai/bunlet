import Darwin
import Foundation
import Testing
@testable import Usage

struct UsageDeliveryTests {
    private func fixture() throws -> (URL, Int32) {
        let directory = URL(fileURLWithPath: "/private/tmp/nu-\(UUID().uuidString.prefix(8))")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false,
                                                attributes: [.posixPermissions: 0o700])
        let endpoint = directory.appendingPathComponent("usage.sock")
        let fd = socket(AF_UNIX, SOCK_DGRAM, 0)
        var address = sockaddr_un()
        address.sun_family = sa_family_t(AF_UNIX)
        address.sun_len = UInt8(MemoryLayout<sockaddr_un>.size)
        withUnsafeMutableBytes(of: &address.sun_path) { $0.copyBytes(from: Array(endpoint.path.utf8) + [0]) }
        let result = withUnsafePointer(to: &address) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                Darwin.bind(fd, $0, socklen_t(MemoryLayout<sockaddr_un>.size))
            }
        }
        #expect(result == 0)
        _ = chmod(endpoint.path, 0o600)
        _ = fcntl(fd, F_SETFL, O_NONBLOCK)
        return (endpoint, fd)
    }

    private func observation(_ source: String = "fixture") -> UsageObservation {
        UsageObservation(provider: "claude", sourceID: source, accountID: nil,
                         receivedAtMs: 1000, measuredAtMs: nil,
                         windows: [UsageWindow(id: "five_hour", usedPercent: 25,
                                               durationMinutes: 300, resetsAtMs: nil)], failure: nil)
    }

    @Test func sendsOnlyTheTypedQuotaObservation() throws {
        let (endpoint, fd) = try fixture()
        defer { close(fd); try? FileManager.default.removeItem(at: endpoint.deletingLastPathComponent()) }
        #expect(UsageDelivery.send(observation(), endpointURL: endpoint))
        var bytes = [UInt8](repeating: 0, count: 8193)
        let count = recv(fd, &bytes, bytes.count, 0)
        #expect(count > 0)
        let result = try JSONDecoder().decode(UsageObservation.self, from: Data(bytes.prefix(max(0, count))))
        #expect(result == observation())
    }

    @Test func absentReceiverReturnsWithoutWaiting() {
        #expect(!UsageDelivery.send(observation(), endpointURL: URL(fileURLWithPath: "/private/tmp/no-usage-endpoint/absent.sock")))
    }

    @Test func unsafeDirectoryAndSocketPermissionsAreRejected() throws {
        let (endpoint, fd) = try fixture()
        defer { close(fd); try? FileManager.default.removeItem(at: endpoint.deletingLastPathComponent()) }
        _ = chmod(endpoint.path, 0o666)
        #expect(!UsageDelivery.send(observation(), endpointURL: endpoint))
        _ = chmod(endpoint.path, 0o600)
        _ = chmod(endpoint.deletingLastPathComponent().path, 0o755)
        #expect(!UsageDelivery.send(observation(), endpointURL: endpoint))
    }

    @Test func regularFileAndSymlinkCannotBecomeReceiver() throws {
        let (endpoint, fd) = try fixture()
        defer { close(fd); try? FileManager.default.removeItem(at: endpoint.deletingLastPathComponent()) }
        let file = endpoint.deletingLastPathComponent().appendingPathComponent("file")
        try Data().write(to: file)
        let link = endpoint.deletingLastPathComponent().appendingPathComponent("link")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: endpoint)
        #expect(!UsageDelivery.send(observation(), endpointURL: file))
        #expect(!UsageDelivery.send(observation(), endpointURL: link))
    }

    @Test func oversizedDatagramsAndPathsAreRejected() throws {
        let (endpoint, fd) = try fixture()
        defer { close(fd); try? FileManager.default.removeItem(at: endpoint.deletingLastPathComponent()) }
        #expect(!UsageDelivery.send(observation(String(repeating: "x", count: 9000)), endpointURL: endpoint))
        #expect(!UsageDelivery.send(observation(), endpointURL: URL(fileURLWithPath: "/" + String(repeating: "x", count: 200))))
    }
}
