import Darwin
import Foundation
import os
import Testing
@testable import SessionState

struct UsageReceiverTests {
    private func endpoint() throws -> URL {
        let directory = URL(fileURLWithPath: "/private/tmp/nr-\(UUID().uuidString.prefix(8))")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false,
                                                attributes: [.posixPermissions: 0o700])
        return directory.appendingPathComponent("usage.sock")
    }

    /// Returns whether the whole datagram reached the receiver's socket.
    /// A rejected input proves nothing unless it was delivered.
    private func rawSend(_ data: Data, to url: URL) -> Bool {
        let fd = socket(AF_UNIX, SOCK_DGRAM, 0)
        defer { close(fd) }
        // The 2,048-byte default send limit must not stand in for the receiver's own limit.
        var size: Int32 = 16_384
        guard setsockopt(fd, SOL_SOCKET, SO_SNDBUF, &size, 4) == 0 else { return false }
        var address = sockaddr_un()
        address.sun_family = sa_family_t(AF_UNIX)
        address.sun_len = UInt8(MemoryLayout<sockaddr_un>.size)
        withUnsafeMutableBytes(of: &address.sun_path) { $0.copyBytes(from: Array(url.path.utf8) + [0]) }
        let sent = withUnsafePointer(to: &address) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { address in
                data.withUnsafeBytes { sendto(fd, $0.baseAddress, $0.count, 0, address, socklen_t(MemoryLayout<sockaddr_un>.size)) }
            }
        }
        return sent == data.count
    }

    @Test func validQuotaIsReceivedWithAppReceiptTime() async throws {
        let url = try endpoint(), received = OSAllocatedUnfairLock(initialState: [UsageObservation]())
        let receiver = UsageReceiver(endpointURL: url)
        defer { receiver.stop(); try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        try receiver.start { value in received.withLock { $0.append(value) } }
        let value = try ClaudeUsageProvider.parse(Data(#"{"rate_limits":{"five_hour":{"used_percentage":25}}}"#.utf8), sourceID: "fixture", receivedAtMs: 0)
        #expect(UsageDelivery.send(value, endpointURL: url))
        for _ in 0..<100 where received.withLock({ $0.isEmpty }) { try await Task.sleep(for: .milliseconds(10)) }
        let values = received.withLock { $0 }
        #expect(values.count == 1)
        #expect(values.first?.windows.first?.usedPercent == 25)
        #expect((values.first?.receivedAtMs ?? 0) > 0)
    }

    @Test func malformedAndInvalidQuotaCannotReachCallback() async throws {
        let url = try endpoint(), received = OSAllocatedUnfairLock(initialState: [UsageObservation]())
        let receiver = UsageReceiver(endpointURL: url)
        defer { receiver.stop(); try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        try receiver.start { value in received.withLock { $0.append(value) } }
        for data in [Data("{".utf8), Data("{}".utf8),
                     Data(#"{"provider":"claude","sourceID":"a","receivedAtMs":0,"windows":[{"id":"x","usedPercent":101}]}"#.utf8)] {
            #expect(rawSend(data, to: url))
        }
        // The receiver keeps the 4,096-byte default receive buffer, so the kernel refuses this datagram
        // before the receiver's 8,192-byte check can run. See the usage datagram limit in docs/STATUS.md.
        withKnownIssue("the receiver cannot be sent a datagram over its 8,192-byte limit") {
            #expect(rawSend(Data(repeating: 32, count: 8193), to: url))
        }
        // The receiver reads datagrams in order, so this valid one arrives after every rejected one.
        // Waiting for it replaces a fixed sleep that a slow receiver could pass without checking anything.
        let final = try ClaudeUsageProvider.parse(Data(#"{"rate_limits":{"five_hour":{"used_percentage":25}}}"#.utf8),
                                                  sourceID: "final-fixture", receivedAtMs: 0)
        #expect(UsageDelivery.send(final, endpointURL: url))
        for _ in 0..<200 where received.withLock({ $0.isEmpty }) { try await Task.sleep(for: .milliseconds(10)) }
        #expect(received.withLock { $0.map(\.sourceID) } == ["final-fixture"])
    }

    @Test func unsafeDirectoryAndExistingFilesArePreserved() throws {
        let url = try endpoint()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        try Data("unrelated".utf8).write(to: url)
        let receiver = UsageReceiver(endpointURL: url)
        #expect(throws: (any Error).self) { try receiver.start { _ in } }
        receiver.stop()
        #expect(try String(contentsOf: url, encoding: .utf8) == "unrelated")
        try FileManager.default.removeItem(at: url)
        _ = chmod(url.deletingLastPathComponent().path, 0o755)
        #expect(throws: (any Error).self) { try receiver.start { _ in } }
    }

    @Test func secondReceiverCannotStealEndpointAndStopAllowsRestart() throws {
        let url = try endpoint()
        let first = UsageReceiver(endpointURL: url), second = UsageReceiver(endpointURL: url)
        defer { first.stop(); second.stop(); try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        try first.start { _ in }
        #expect(throws: (any Error).self) { try second.start { _ in } }
        second.stop()
        #expect(FileManager.default.fileExists(atPath: url.path))
        first.stop()
        #expect(!FileManager.default.fileExists(atPath: url.path))
        try second.start { _ in }
    }

    @Test func stopDoesNotRemoveReplacementFile() throws {
        let url = try endpoint(), receiver = UsageReceiver(endpointURL: url)
        defer { receiver.stop(); try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        try receiver.start { _ in }
        try FileManager.default.removeItem(at: url)
        try Data("replacement".utf8).write(to: url)
        receiver.stop()
        #expect(try String(contentsOf: url, encoding: .utf8) == "replacement")
    }
}
