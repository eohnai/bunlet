import Darwin
import Foundation
import Usage

/// Runs only when installed as an explicit statusLine command. Never logs the input or command.
/// stdout/stderr stay inherited; a bounded pipe pump preserves stdin without retaining large payloads.
enum StatusLineForwarder {
    static let inputLimit = 262_144
    static let commandLimit = 16_384
    static let signals: [Int32] = [SIGTERM, SIGINT, SIGHUP, SIGQUIT]

    static func run(command: String?) -> Int32 {
        let events = kqueue()
        guard events >= 0 else { return 1 }
        defer { close(events) }
        _ = fcntl(events, F_SETFD, FD_CLOEXEC)
        for number in signals {
            _ = signal(number, SIG_IGN)
            var change = kevent(ident: UInt(number), filter: Int16(EVFILT_SIGNAL),
                                flags: UInt16(EV_ADD | EV_ENABLE), fflags: 0, data: 0, udata: nil)
            guard kevent(events, &change, 1, nil, 0, nil) == 0 else { return 1 }
        }

        var child: pid_t = 0
        var writer: Int32 = -1
        if let command {
            guard let launched = spawn(command: command) else { return 1 }
            child = launched.0
            writer = launched.1
        }
        defer {
            if writer >= 0 { close(writer) }
            if child > 0 {
                _ = kill(-child, SIGKILL)
                var ignored: Int32 = 0
                while waitpid(child, &ignored, 0) < 0 && errno == EINTR { }
            }
        }
        var capture = Data()
        var withinLimit = true
        var pending = Data()
        var offset = 0
        var ended = false
        var forwarded = false
        var status: Int32 = 0
        var completedStatus: Int32?
        var drainUntil: UInt64?
        var terminatingSignal: Int32?
        var killAt: UInt64?
        var bytes = [UInt8](repeating: 0, count: 16_384)
        while true {
            var event = kevent()
            var immediate = timespec(tv_sec: 0, tv_nsec: 0)
            if kevent(events, nil, 0, &event, 1, &immediate) > 0,
               signals.contains(Int32(event.ident)) {
                let number = Int32(event.ident)
                terminatingSignal = number
                if child > 0 {
                    _ = kill(-child, number)
                    // Cancellation has a bound even if the user's shell ignores the signal.
                    if killAt == nil { killAt = DispatchTime.now().uptimeNanoseconds + 250_000_000 }
                } else { return 128 + number }
            }
            if let killAt, DispatchTime.now().uptimeNanoseconds >= killAt, child > 0 {
                _ = kill(-child, SIGKILL)
            }
            // Keep the leader unreaped until cancellation escalation, reserving its process-group ID
            // while terminating descendants that might ignore the first signal.
            if child > 0, (killAt.map { DispatchTime.now().uptimeNanoseconds >= $0 } ?? true) {
                let result = waitpid(child, &status, WNOHANG)
                if result == child {
                    child = 0
                    if let terminatingSignal { return 128 + terminatingSignal }
                    completedStatus = exitCode(status)
                    if writer >= 0 {
                        close(writer)
                        writer = -1
                    }
                    pending.removeAll()
                    drainUntil = DispatchTime.now().uptimeNanoseconds + 250_000_000
                }
                if result < 0, errno != EINTR {
                    if errno == ECHILD { child = 0 }
                    return 1
                }
            }
            if let completedStatus, forwarded { return completedStatus }
            if let drainUntil, DispatchTime.now().uptimeNanoseconds >= drainUntil {
                return completedStatus ?? 1
            }
            if ended, pending.isEmpty, !forwarded {
                if writer >= 0 {
                    close(writer)
                    writer = -1
                }
                if withinLimit, terminatingSignal == nil {
                    _ = ClaudeUsageProvider.forward(capture,
                        receivedAtMs: Int64(Date().timeIntervalSince1970 * 1_000))
                }
                capture.removeAll()
                forwarded = true
                if child == 0 { return completedStatus ?? 0 }
            }
            var descriptors = [pollfd(fd: !ended && pending.isEmpty ? STDIN_FILENO : -1,
                                       events: Int16(POLLIN), revents: 0),
                               pollfd(fd: writer >= 0 && !pending.isEmpty ? writer : -1,
                                       events: Int16(POLLOUT), revents: 0)]
            let ready = poll(&descriptors, 2, 20)
            if ready < 0, errno != EINTR {
                if child > 0 { _ = kill(-child, SIGTERM) }
                return 1
            }
            if descriptors[0].revents & Int16(POLLIN | POLLHUP) != 0 {
                let count = Darwin.read(STDIN_FILENO, &bytes, bytes.count)
                if count > 0 {
                    if withinLimit, capture.count <= inputLimit - count { capture.append(contentsOf: bytes.prefix(count)) }
                    else {
                        withinLimit = false
                        capture.removeAll()
                    }
                    if writer >= 0 {
                        pending = Data(bytes.prefix(count))
                        offset = 0
                    }
                } else if count == 0 { ended = true }
                else if errno != EINTR {
                    ended = true
                    withinLimit = false
                }
            }
            if descriptors[0].revents & Int16(POLLERR | POLLNVAL) != 0 {
                ended = true
                withinLimit = false
            }
            if descriptors[1].revents & Int16(POLLOUT | POLLHUP | POLLERR) != 0, !pending.isEmpty {
                let count = pending.withUnsafeBytes { buffer in
                    guard let base = buffer.baseAddress else { return -1 }
                    return Darwin.write(writer, base.advanced(by: offset), pending.count - offset)
                }
                if count > 0 {
                    offset += count
                    if offset == pending.count { pending.removeAll(keepingCapacity: true) }
                } else if count < 0, errno != EAGAIN, errno != EINTR {
                    // A command may intentionally close stdin. Do not change its exit/output semantics.
                    close(writer)
                    writer = -1
                    pending.removeAll()
                    ended = true
                    withinLimit = false
                }
            }
        }
    }

    private static func spawn(command: String) -> (pid_t, Int32)? {
        var descriptors: [Int32] = [0, 0]
        guard pipe(&descriptors) == 0 else { return nil }
        // Keep pipe descriptors out of stdio slots when an inherited stream is closed.
        for index in descriptors.indices where descriptors[index] < 3 {
            let original = descriptors[index]
            let moved = fcntl(original, F_DUPFD_CLOEXEC, 3)
            guard moved >= 0 else {
                for fd in descriptors { close(fd) }
                return nil
            }
            descriptors[index] = moved
            close(original)
        }
        var keepWriter = false
        defer {
            close(descriptors[0])
            if !keepWriter { close(descriptors[1]) }
        }
        for fd in descriptors {
            guard fcntl(fd, F_SETFD, FD_CLOEXEC) == 0 else { return nil }
        }
        guard fcntl(descriptors[1], F_SETFL, O_NONBLOCK) == 0,
              fcntl(descriptors[1], F_SETNOSIGPIPE, 1) == 0 else { return nil }
        var actions: posix_spawn_file_actions_t?
        var attributes: posix_spawnattr_t?
        guard posix_spawn_file_actions_init(&actions) == 0 else { return nil }
        defer { posix_spawn_file_actions_destroy(&actions) }
        guard posix_spawnattr_init(&attributes) == 0 else { return nil }
        defer { posix_spawnattr_destroy(&attributes) }
        var defaults = sigset_t()
        var mask = sigset_t()
        sigemptyset(&defaults)
        sigemptyset(&mask)
        for number in signals { sigaddset(&defaults, number) }
        let flags = Int16(POSIX_SPAWN_SETPGROUP | POSIX_SPAWN_SETSIGDEF | POSIX_SPAWN_SETSIGMASK)
        guard posix_spawn_file_actions_adddup2(&actions, descriptors[0], STDIN_FILENO) == 0,
              posix_spawn_file_actions_addclose(&actions, descriptors[0]) == 0,
              posix_spawn_file_actions_addclose(&actions, descriptors[1]) == 0,
              posix_spawnattr_setpgroup(&attributes, 0) == 0,
              posix_spawnattr_setsigdefault(&attributes, &defaults) == 0,
              posix_spawnattr_setsigmask(&attributes, &mask) == 0,
              posix_spawnattr_setflags(&attributes, flags) == 0 else { return nil }
        let arguments = ["/bin/sh", "-c", command].map { strdup($0) }
        defer { for argument in arguments { free(argument) } }
        guard arguments.allSatisfy({ $0 != nil }) else { return nil }
        var argv = arguments + [nil]
        var pid: pid_t = 0
        let result = argv.withUnsafeMutableBufferPointer { buffer in
            guard let base = buffer.baseAddress else { return EINVAL }
            return posix_spawn(&pid, "/bin/sh", &actions, &attributes, base, _NSGetEnviron().pointee)
        }
        guard result == 0 else { return nil }
        keepWriter = true
        return (pid, descriptors[1])
    }

    private static func exitCode(_ status: Int32) -> Int32 {
        let number = status & 0x7f
        return number == 0 ? (status >> 8) & 0xff : 128 + number
    }
}

let arguments = Array(CommandLine.arguments.dropFirst())
let command: String?
if arguments.isEmpty { command = nil }
else if arguments.count == 2, arguments[0] == "--command",
        arguments[1].utf8.count <= StatusLineForwarder.commandLimit, !arguments[1].utf8.contains(0) {
    command = arguments[1]
} else { exit(2) }
exit(StatusLineForwarder.run(command: command))
