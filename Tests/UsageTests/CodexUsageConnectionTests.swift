import Darwin
import Foundation
import Testing
@testable import Usage

// These cases exercise separate child-process scenarios, not concurrent provider sessions.
// Keep their synthetic slow/oversized processes from competing with each other at launch.
@Suite(.serialized)
struct CodexUsageConnectionTests {
    private func script(_ body: String) throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("notch-quota-\(UUID().uuidString)")
        try ("#!/usr/bin/python3 -u\nimport json,sys,time,os\n" + body + "\n").write(to: url, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: url.path)
        return url
    }

    @Test func realProcessPerformsOnlyHandshakeAndQuotaRead() async throws {
        let url = try script("""
        first=json.loads(sys.stdin.readline()); assert first['method']=='initialize'
        print(json.dumps({'id':1,'result':{}}))
        assert json.loads(sys.stdin.readline())['method']=='initialized'
        request=json.loads(sys.stdin.readline()); assert request['method']=='account/rateLimits/read'
        print(json.dumps({'id':2,'result':{'rateLimits':{'primary':{'usedPercent':25,'windowDurationMins':300}}}}))
        time.sleep(5)
        """)
        defer { try? FileManager.default.removeItem(at: url) }
        let value = await CodexUsageConnection.read(executableURL: url, sourceID: "fixture")
        #expect(value.failure == nil && value.windows.first?.usedPercent == 25)
    }

    @Test func interleavedNotificationsAndFragmentedFramesAreHandled() async throws {
        let url = try script("""
        sys.stdin.readline()
        print('{"method":"notice","params":{"secret":"PRIVATE"}}')
        print('{"id":99,"result":{}}')
        sys.stdout.write('{"id":1,'); sys.stdout.flush(); time.sleep(.02); print('"result":{}}')
        sys.stdin.readline(); sys.stdin.readline()
        print('{"id":2,"result":{"rateLimits":{"secondary":{"usedPercent":40}}}}')
        """)
        defer { try? FileManager.default.removeItem(at: url) }
        let value = await CodexUsageConnection.read(executableURL: url, sourceID: "fixture")
        #expect(value.windows.first?.usedPercent == 40)
        #expect(!String(reflecting: value).contains("PRIVATE"))
    }

    @Test func errorAndEOFReturnUnavailableWithoutRawOutput() async throws {
        for body in ["sys.stdin.readline(); print('{\"id\":1,\"error\":{\"code\":-1,\"message\":\"PRIVATE\"}}')", "pass", "print('PRIVATE')"] {
            let url = try script(body)
            defer { try? FileManager.default.removeItem(at: url) }
            let value = await CodexUsageConnection.read(executableURL: url, sourceID: "fixture")
            #expect(value.failure != nil && value.windows.isEmpty)
            #expect(!String(reflecting: value).contains("PRIVATE"))
        }
    }

    @Test func timeoutAndCancellationAreBoundedAndStopOwnedChild() async throws {
        let marker = FileManager.default.temporaryDirectory.appendingPathComponent("notch-pid-\(UUID().uuidString)")
        let url = try script("open('\(marker.path)','w').write(str(os.getpid()))\ntime.sleep(10)")
        defer { try? FileManager.default.removeItem(at: url); try? FileManager.default.removeItem(at: marker) }
        let timed = await CodexUsageConnection.read(executableURL: url, sourceID: "fixture", timeoutMs: 500)
        #expect(timed.failure == .timedOut)
        if let raw = try? String(contentsOf: marker, encoding: .utf8), let pid = Int32(raw) {
            for _ in 0..<50 where kill(pid, 0) == 0 { try await Task.sleep(for: .milliseconds(20)) }
            #expect(kill(pid, 0) == -1)
        }
        try? FileManager.default.removeItem(at: marker)
        let task = Task { await CodexUsageConnection.read(executableURL: url, sourceID: "fixture") }
        for _ in 0..<100 where !FileManager.default.fileExists(atPath: marker.path) {
            try await Task.sleep(for: .milliseconds(20))
        }
        task.cancel()
        #expect(await task.value.failure != nil)
        if let raw = try? String(contentsOf: marker, encoding: .utf8), let pid = Int32(raw) {
            for _ in 0..<50 where kill(pid, 0) == 0 { try await Task.sleep(for: .milliseconds(20)) }
            #expect(kill(pid, 0) == -1)
        }
    }

    @Test func oversizedFrameIsRejectedWithoutUnboundedWait() async throws {
        let url = try script("sys.stdout.write('x'*300000); sys.stdout.flush(); time.sleep(10)")
        defer { try? FileManager.default.removeItem(at: url) }
        let value = await CodexUsageConnection.read(executableURL: url, sourceID: "fixture")
        #expect(value.failure == .malformed && value.windows.isEmpty)
    }
}
