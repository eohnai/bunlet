import Darwin
import Foundation

public enum CodexUsageConnection {
    public static func read(executableURL: URL, sourceID: String,
                            timeoutMs: UInt64 = 5000) async -> UsageObservation {
        let worker = Task.detached(priority: .utility) {
            exchange(executableURL: executableURL, sourceID: sourceID,
                     timeoutMs: min(max(timeoutMs, 1), 10_000))
        }
        return await withTaskCancellationHandler(operation: { await worker.value },
                                                onCancel: { worker.cancel() })
    }

    private static func exchange(executableURL: URL, sourceID: String, timeoutMs: UInt64) -> UsageObservation {
        var failure: UsageFailure = .sourceUnavailable
        let process = Process()
        let input = Pipe(), output = Pipe()
        let readFD = output.fileHandleForReading.fileDescriptor
        let writeFD = input.fileHandleForWriting.fileDescriptor
        defer {
            if process.isRunning { _ = kill(process.processIdentifier, SIGKILL) }
            try? input.fileHandleForWriting.close()
            try? input.fileHandleForReading.close()
            try? output.fileHandleForWriting.close()
            try? output.fileHandleForReading.close()
        }
        do {
            guard !Task.isCancelled, executableURL.isFileURL,
                  fcntl(readFD, F_SETFL, O_NONBLOCK) == 0,
                  fcntl(writeFD, F_SETFL, O_NONBLOCK) == 0,
                  fcntl(writeFD, F_SETNOSIGPIPE, 1) == 0 else { throw UsageProviderError.malformed }
            process.executableURL = executableURL
            process.arguments = ["app-server", "--stdio", "-c", "analytics.enabled=false", "-c", "feedback.enabled=false"]
            process.standardInput = input
            process.standardOutput = output
            process.standardError = FileHandle.nullDevice
            let deadline = DispatchTime.now().uptimeNanoseconds + timeoutMs * 1_000_000
            try process.run()
            try? input.fileHandleForReading.close()
            try? output.fileHandleForWriting.close()
            var session = CodexUsageProtocol(sourceID: sourceID)
            var pending = session.start(), offset = 0
            var buffer = Data()
            var total = 0
            var bytes = [UInt8](repeating: 0, count: 8192)
            protocolLoop: while !Task.isCancelled {
                guard DispatchTime.now().uptimeNanoseconds < deadline else {
                    failure = .timedOut
                    break
                }
                if offset < pending.count {
                    let count = pending.withUnsafeBytes {
                        Darwin.write(writeFD, $0.baseAddress!.advanced(by: offset), pending.count - offset)
                    }
                    if count > 0 { offset += count }
                    else if errno != EAGAIN && errno != EINTR { break }
                }
                let count = bytes.withUnsafeMutableBytes { Darwin.read(readFD, $0.baseAddress, $0.count) }
                if count > 0 {
                    total += count
                    guard total <= 1_048_576 else { throw UsageProviderError.resourceLimit }
                    buffer.append(contentsOf: bytes.prefix(count))
                    while let newline = buffer.firstIndex(of: 10) {
                        let line = Data(buffer.prefix(upTo: newline))
                        buffer.removeSubrange(...newline)
                        let requests = try session.receive(line, receivedAtMs: Int64(Date().timeIntervalSince1970 * 1000))
                        if let observation = session.observation { return observation }
                        if let error = session.failure { failure = error; break protocolLoop }
                        for request in requests { pending.append(request) }
                    }
                    guard buffer.count <= 262_144 else { throw UsageProviderError.resourceLimit }
                } else if count == 0 { break }
                else if errno != EAGAIN && errno != EINTR { break }
                var descriptors = [pollfd(fd: readFD, events: Int16(POLLIN), revents: 0),
                                   pollfd(fd: writeFD, events: offset < pending.count ? Int16(POLLOUT) : 0, revents: 0)]
                _ = poll(&descriptors, 2, 20)
            }
        } catch is UsageProviderError {
            if failure != .timedOut { failure = .malformed }
        } catch { failure = .sourceUnavailable }
        return UsageObservation(provider: "codex", sourceID: sourceID, accountID: nil,
                                receivedAtMs: Int64(Date().timeIntervalSince1970 * 1000),
                                measuredAtMs: nil, windows: [], failure: failure)
    }
}
