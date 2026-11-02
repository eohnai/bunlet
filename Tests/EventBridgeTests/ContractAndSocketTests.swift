import Darwin
import Foundation
import os
import Testing
@testable import EventBridge

private final class Observations: @unchecked Sendable {
    private let lock = NSLock()
    private var values: [ReceivedHookEnvelope] = []
    let signal = DispatchSemaphore(value: 0)
    func append(_ value: ReceivedHookEnvelope) {
        lock.withLock { values.append(value) }
        signal.signal()
    }
    var count: Int { lock.withLock { values.count } }
    var eventIDs: [String] { lock.withLock { values.map(\.envelope.eventID) } }
}

struct ContractAndSocketTests {
    private func endpoint() -> BridgeEndpoint {
        BridgeEndpoint(directory: "/private/tmp/notch-pet-test-\(UUID().uuidString)")
    }
    private func envelope() throws -> HookEnvelopeV1 {
        try HookEnvelopeV1.project(rawHook: Data("{\"session_id\":\"fictional\",\"hook_event_name\":\"SessionStart\"}".utf8), agent: "codex")
    }
    private func connect(_ endpoint: BridgeEndpoint) throws -> Int32 {
        let fd = try makeSocket()
        do { try connectSocket(fd, path: endpoint.socketPath, until: deadline(after: 50)) }
        catch { close(fd); throw error }
        return fd
    }

    @Test func allContractMessageCases() throws {
        // Python serializes independent fixtures; production Swift validates the frames.
        // This preserves integer versus float values and invalid surrogate escapes.
        let process = Process(), output = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/python3")
        let fixture = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().appendingPathComponent("docs/contracts/agent-events-v1-cases.json")
        process.arguments = ["-c", """
        import base64,json,sys
        result=[]
        for case in json.load(open(sys.argv[1]))['messages']:
            if 'message' in case:
                frame=(json.dumps(case['message'],ensure_ascii=True,sort_keys=True,separators=(',',':'))+'\\n').encode()
            elif 'raw' in case:
                frame=case['raw'].encode()
            else:
                frame=bytes.fromhex(case['hex'])
            if 'pad_to_bytes' in case:
                frame=frame[:-1]+b' '*(case['pad_to_bytes']-len(frame))+frame[-1:]
            result.append(dict(name=case['name'],frame=base64.b64encode(frame).decode(),valid=case['expect']=='valid'))
        print(json.dumps(result))
        """, fixture.path]
        process.standardOutput = output
        try process.run()
        let data = output.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        #expect(process.terminationStatus == 0)
        struct Case: Decodable { let name: String; let frame: Data; let valid: Bool }
        let cases = try JSONDecoder().decode([Case].self, from: data)
        #expect(cases.count == 68)
        for item in cases {
            #expect(((try? HookEnvelopeV1.decode(frame: item.frame)) != nil) == item.valid, "\(item.name)")
        }
    }

    @Test func projectionExcludesPrivateFieldsAndMapsClaudeTurn() throws {
        let raw = Data("""
        {"session_id":"fictional","hook_event_name":"PermissionRequest","prompt_id":"turn-a",
         "turn_id":"wrong-provider-turn","tool_name":"Write","tool_use_id":"tool-a","cwd":"/example",
         "prompt":"private prompt","transcript_path":"/must/not/open","tool_input":{"command":"private command"}}
        """.utf8)
        let envelope = try HookEnvelopeV1.project(rawHook: raw, agent: "claude", paneSelector: "unverified")
        #expect(envelope.turnID == "turn-a")
        #expect(envelope.terminal?.paneSelector == "unverified")
        let wire = String(decoding: try envelope.frame(), as: UTF8.self)
        for forbidden in ["private", "transcript", "tool_input", "wrong-provider-turn"] {
            #expect(!wire.contains(forbidden))
        }
        #expect(throws: (any Error).self) {
            try HookEnvelopeV1.project(rawHook: Data(repeating: 32, count: 262_145), agent: "claude")
        }
    }

    @Test func rawHookBoundaryPreservesJSONWhitespaceRules() throws {
        let minimal = Data("{\"session_id\":\"fictional\",\"hook_event_name\":\"SessionStart\"}".utf8)
        for agent in ["codex", "claude"] {
            for byte in [UInt8(9), 10, 13, 32] {
                let padding = Data(repeating: byte, count: HookEnvelopeV1.rawHookLimit - minimal.count)
                for raw in [minimal + padding, padding + minimal] {
                    #expect(try HookEnvelopeV1.project(rawHook: raw, agent: agent).sessionID == "fictional")
                    #expect(throws: BridgeError.invalidMessage) {
                        try HookEnvelopeV1.project(rawHook: raw + Data([32]), agent: agent)
                    }
                }
            }
            for text in ["\u{0b}", "\u{0c}", "\u{a0}"] {
                for raw in [minimal + Data(text.utf8), Data(text.utf8) + minimal] {
                    #expect(throws: BridgeError.invalidMessage) {
                        try HookEnvelopeV1.project(rawHook: raw, agent: agent)
                    }
                }
            }
            #expect(throws: BridgeError.invalidMessage) {
                try HookEnvelopeV1.project(rawHook: minimal + Data(" {}".utf8), agent: agent)
            }
        }
    }

    @Test func fragmentedFrameAndPeerIdentity() throws {
        // A socket pair reaches the receiver's reader without the server's 100 ms accept deadline.
        // A slow test thread then delays the result but cannot change it.
        var pair: [Int32] = [0, 0]
        #expect(socketpair(AF_UNIX, SOCK_STREAM, 0, &pair) == 0)
        defer { close(pair[0]); close(pair[1]) }
        let sender = pair[0], receiver = pair[1]
        #expect(fcntl(receiver, F_SETFL, O_NONBLOCK) == 0)
        try requireSameUser(receiver)
        #expect(throws: BridgeError.self) { try requireSameUser(receiver, expectedUID: getuid() + 1) }
        let frame = try envelope().frame()
        try writeAll(sender, data: Data(frame.prefix(17)), until: deadline(after: 2000))
        let separate = OSAllocatedUnfairLock(initialState: false)
        let finished = DispatchSemaphore(value: 0)
        DispatchQueue.global().async {
            defer { finished.signal() }
            // Send the rest only after the reader has consumed the prefix, so the frame needs two reads.
            var queued: Int32 = 1
            var length = socklen_t(MemoryLayout<Int32>.size)
            for _ in 0..<5000 {
                guard getsockopt(receiver, SOL_SOCKET, SO_NREAD, &queued, &length) == 0, queued > 0 else { break }
                usleep(1000)
            }
            let consumed = queued == 0
            separate.withLock { $0 = consumed }
            try? writeAll(sender, data: Data(frame.dropFirst(17)), until: deadline(after: 2000))
        }
        let read = try readBounded(receiver, limit: HookEnvelopeV1.frameLimit, until: deadline(after: 5000), framed: true)
        finished.wait()
        #expect(separate.withLock { $0 }, "the prefix must arrive in its own read")
        #expect(read == frame)
    }

    @Test func queuedExtraBytesAreRejected() throws {
        // The contract rejects extra bytes only when they are already buffered after LF.
        // Each input is queued in full before the read starts, so the result does not depend on delivery timing.
        let valid = try envelope().frame()
        let maximum = Data(valid.dropLast()) + Data(repeating: 32, count: HookEnvelopeV1.frameLimit - valid.count) + Data([10])
        let cases: [(String, Data, Data?)] = [("maximum frame", maximum, maximum), ("second frame", valid + valid, nil),
                                              ("extra byte", valid + Data([32]), nil),
                                              ("maximum frame plus extra byte", maximum + Data([32]), nil)]
        for (name, input, expected) in cases {
            var pair: [Int32] = [0, 0]
            #expect(socketpair(AF_UNIX, SOCK_STREAM, 0, &pair) == 0)
            defer { close(pair[0]); close(pair[1]) }
            // The default buffer is smaller than a maximum frame plus one byte.
            var size: Int32 = 65_536
            #expect(setsockopt(pair[0], SOL_SOCKET, SO_SNDBUF, &size, 4) == 0)
            #expect(setsockopt(pair[1], SOL_SOCKET, SO_RCVBUF, &size, 4) == 0)
            #expect(fcntl(pair[0], F_SETFL, O_NONBLOCK) == 0)
            #expect(fcntl(pair[1], F_SETFL, O_NONBLOCK) == 0)
            try writeAll(pair[0], data: input, until: deadline(after: 2000))
            let read = { try readBounded(pair[1], limit: HookEnvelopeV1.frameLimit, until: deadline(after: 2000), framed: true) }
            if let expected {
                #expect(try read() == expected, "\(name)")
            } else {
                #expect(throws: BridgeError.invalidMessage, "\(name)") { try read() }
            }
        }
    }

    @Test func invalidFramesNeverReachCallback() throws {
        let endpoint = endpoint(), observations = Observations()
        defer { try? FileManager.default.removeItem(atPath: endpoint.directory) }
        let server = EventBridgeServer(endpoint: endpoint)
        try server.start { observations.append($0) }
        defer { server.stop() }
        let message = try envelope(), valid = try message.frame()
        let text = String(decoding: valid, as: UTF8.self)
        // Every prefix of each fixture is also invalid, so a partial or late delivery cannot produce a callback.
        // Inputs that are invalid only while their extra bytes are queued are in `queuedExtraBytesAreRejected`.
        let oversized = Data(valid.dropLast()) + Data(repeating: 32, count: 16_385 - valid.count) + Data([10])
        let frames = [Data("{}\n".utf8), Data(valid.dropLast()),
                      Data([255, 10]), Data(repeating: 32, count: 16_385), oversized,
                      Data(text.replacingOccurrences(of: String(message.observedAtMs), with: "0").utf8),
                      Data(text.replacingOccurrences(of: String(message.observedAtMs), with: "9007199254740991").utf8)]
        for frame in frames {
            let fd = try connect(endpoint)
            try? writeAll(fd, data: frame, until: deadline(after: 50))
            close(fd)
        }
        let final = try envelope()
        try EventBridgeClient(endpoint: endpoint).send(final)
        #expect(observations.signal.wait(timeout: .now() + 2) == .success)
        // The receiver handles one connection at a time, so every fixture finished before this callback.
        #expect(observations.eventIDs == [final.eventID])
    }

    @Test func readerKeepsOriginalDeadlineAcrossFragments() throws {
        var pair: [Int32] = [0, 0]
        try #require(socketpair(AF_UNIX, SOCK_STREAM, 0, &pair) == 0)
        defer { close(pair[0]); close(pair[1]) }
        for fd in pair {
            try #require(fcntl(fd, F_SETFL, O_NONBLOCK) == 0)
        }

        var byte: UInt8 = 32
        try #require(write(pair[0], &byte, 1) == 1)
        let originalDeadline: UInt64 = 100_000_000
        var virtualNow: UInt64 = 0
        var observedDeadlines: [UInt64] = []
        #expect(throws: BridgeError.timeout) {
            try readBounded(pair[1], limit: HookEnvelopeV1.frameLimit, until: originalDeadline, framed: true) { fd, _, end in
                observedDeadlines.append(end)
                // Stop a reset-deadline mutation before it can keep this test waiting indefinitely.
                try #require(end == originalDeadline)
                if observedDeadlines.count > 1 {
                    var queued: Int32 = 0
                    var length = socklen_t(MemoryLayout<Int32>.size)
                    try #require(getsockopt(fd, SOL_SOCKET, SO_NREAD, &queued, &length) == 0)
                    try #require(queued == 0, "the previous fragment must be read before the next arrives")
                    try #require(write(pair[0], &byte, 1) == 1)
                }
                virtualNow += 40_000_000
                if virtualNow >= end { throw BridgeError.timeout }
            }
        }
        #expect(observedDeadlines == [originalDeadline, originalDeadline, originalDeadline])
        #expect(virtualNow == 120_000_000)
        // Two fragments were read. The third was queued before expiry and must remain unread.
        var queued: Int32 = 0
        var length = socklen_t(MemoryLayout<Int32>.size)
        try #require(getsockopt(pair[1], SOL_SOCKET, SO_NREAD, &queued, &length) == 0)
        #expect(queued == 1)
    }

    @Test func refusesUnsafePathsAndKeepsUnrelatedFiles() throws {
        let endpoint = endpoint()
        defer { try? FileManager.default.removeItem(atPath: endpoint.directory) }
        let directory = try directoryFD(endpoint, create: true)
        defer { close(directory) }
        let server = EventBridgeServer(endpoint: endpoint)
        try Data("unrelated".utf8).write(to: URL(fileURLWithPath: endpoint.socketPath))
        #expect(throws: (any Error).self) { try server.start { _ in } }
        #expect(try String(contentsOfFile: endpoint.socketPath, encoding: .utf8) == "unrelated")
        try FileManager.default.removeItem(atPath: endpoint.socketPath)
        #expect(symlink("/private/tmp/nonexistent-fictional-target", endpoint.socketPath) == 0)
        #expect(throws: (any Error).self) { try server.start { _ in } }
        var info = stat()
        #expect(lstat(endpoint.socketPath, &info) == 0)
        #expect(info.st_mode & S_IFMT == S_IFLNK)
        #expect(chmod(endpoint.directory, 0o755) == 0)
        #expect(throws: (any Error).self) { try server.start { _ in } }
        #expect(chmod(endpoint.directory, 0o700) == 0)
        let link = endpoint.directory + "-link"
        defer { unlink(link) }
        #expect(symlink(endpoint.directory, link) == 0)
        #expect(throws: (any Error).self) { try directoryFD(BridgeEndpoint(directory: link), create: false) }
    }

    @Test func recoversOnlyAnOwnedSocketWithoutAListener() throws {
        let endpoint = endpoint()
        defer { try? FileManager.default.removeItem(atPath: endpoint.directory) }
        let directory = try directoryFD(endpoint, create: true)
        defer { close(directory) }
        let fd = try makeSocket()
        #expect(try withAddress(endpoint.socketPath) { bind(fd, $0, $1) } == 0)
        close(fd)
        let server = EventBridgeServer(endpoint: endpoint)
        try server.start { _ in }
        #expect((try socketInfo(directory))!.st_mode & 0o777 == 0o600)
        server.stop()
        #expect(!FileManager.default.fileExists(atPath: endpoint.socketPath))
    }

    @Test func doesNotRemoveAnActiveUncooperativeListener() throws {
        let endpoint = endpoint()
        defer { try? FileManager.default.removeItem(atPath: endpoint.directory) }
        let directory = try directoryFD(endpoint, create: true)
        defer { close(directory) }
        let fd = try makeSocket()
        defer { close(fd) }
        #expect(try withAddress(endpoint.socketPath) { bind(fd, $0, $1) } == 0)
        #expect(listen(fd, 2) == 0)
        let before = try #require(try socketInfo(directory))
        #expect(throws: (any Error).self) { try EventBridgeServer(endpoint: endpoint).start { _ in } }
        let after = try #require(try socketInfo(directory))
        #expect(sameFile(before, after))
    }

    @Test func cleanupLeavesAReplacedPathUntouched() throws {
        let endpoint = endpoint()
        defer { try? FileManager.default.removeItem(atPath: endpoint.directory) }
        let server = EventBridgeServer(endpoint: endpoint)
        try server.start { _ in }
        #expect(unlink(endpoint.socketPath) == 0)
        try Data("replacement".utf8).write(to: URL(fileURLWithPath: endpoint.socketPath))
        server.stop()
        #expect(try String(contentsOfFile: endpoint.socketPath, encoding: .utf8) == "replacement")
    }

    @Test func totalDeadlineAndWriteBackpressure() throws {
        #expect(throws: BridgeError.self) {
            try EventBridgeClient(endpoint: endpoint()).send(envelope(), until: monotonicNanoseconds())
        }
        var pair: [Int32] = [0, 0]
        #expect(socketpair(AF_UNIX, SOCK_STREAM, 0, &pair) == 0)
        defer { close(pair[0]); close(pair[1]) }
        #expect(fcntl(pair[0], F_SETFL, O_NONBLOCK) == 0)
        var enabled: Int32 = 1
        #expect(setsockopt(pair[0], SOL_SOCKET, SO_NOSIGPIPE, &enabled, 4) == 0)
        let start = monotonicNanoseconds()
        #expect(throws: BridgeError.self) {
            try writeAll(pair[0], data: Data(repeating: 32, count: 1_048_576), until: deadline(after: 50))
        }
        #expect(monotonicNanoseconds() - start < 250_000_000)
    }

    @Test func brokenSocketDoesNotRaiseSIGPIPE() throws {
        var pair: [Int32] = [0, 0]
        #expect(socketpair(AF_UNIX, SOCK_STREAM, 0, &pair) == 0)
        defer { close(pair[0]) }
        var enabled: Int32 = 1
        #expect(setsockopt(pair[0], SOL_SOCKET, SO_NOSIGPIPE, &enabled, 4) == 0)
        close(pair[1])
        #expect(throws: BridgeError.self) {
            try writeAll(pair[0], data: Data([32]), until: deadline(after: 50))
        }
    }

    @Test func clientRefusesSocketWithUnexpectedPermissions() throws {
        let endpoint = endpoint(), observations = Observations()
        defer { try? FileManager.default.removeItem(atPath: endpoint.directory) }
        let server = EventBridgeServer(endpoint: endpoint)
        try server.start { observations.append($0) }
        defer { server.stop() }
        #expect(chmod(endpoint.socketPath, 0o666) == 0)
        #expect(throws: BridgeError.self) { try EventBridgeClient(endpoint: endpoint).send(envelope()) }
        #expect(observations.count == 0)
    }

    @Test func stopClosesStalledConnectionAndReleasesOwnership() throws {
        let endpoint = endpoint()
        defer { try? FileManager.default.removeItem(atPath: endpoint.directory) }
        let server = EventBridgeServer(endpoint: endpoint)
        // Stop cannot interrupt an accepted connection's 100 ms read deadline, which starts after connect begins.
        // A stop that ends sooner means the server never accepted, so the stalled read was not tested.
        // The client sees end-of-file in both cases, so only this duration shows the difference. Retry only that case.
        var stalled = false
        for _ in 0..<5 where !stalled {
            try server.start { _ in Issue.record("stalled connection produced a message") }
            let connectStart = monotonicNanoseconds()
            let fd = try connect(endpoint)
            Thread.sleep(forTimeInterval: 0.01)
            let stopStart = monotonicNanoseconds()
            server.stop()
            let stopped = monotonicNanoseconds()
            close(fd)
            // The bound catches a hang, not a latency target.
            #expect(stopped - stopStart < 1_000_000_000)
            #expect(!FileManager.default.fileExists(atPath: endpoint.socketPath))
            stalled = stopped - connectStart >= 100_000_000
        }
        #expect(stalled, "stop must run while the server waits on a silent accepted connection")
        try server.start { _ in }
        server.stop()
    }
}
