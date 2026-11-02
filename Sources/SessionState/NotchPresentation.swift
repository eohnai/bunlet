import CoreGraphics
import Foundation

public enum PromptTimer: Equatable, Sendable {
    case running(startedAtMs: Int64)
    case stopped(durationMs: Int64)

    public func elapsedSeconds(at nowMs: Int64) -> Int64 {
        switch self {
        case .running(let startedAtMs):
            guard startedAtMs >= 0, nowMs >= startedAtMs else { return 0 }
            return (nowMs - startedAtMs) / 1000
        case .stopped(let durationMs):
            return max(0, durationMs) / 1000
        }
    }
}

public struct NotchCardPresentation: Equatable, Sendable {
    public let folderName: String
    public let shortSessionID: String?
    public let timer: PromptTimer?
}

public enum NotchPresentation {
    public static func shouldTickPromptTimers(expanded: Bool, sessions: [SessionSnapshot]) -> Bool {
        expanded && sessions.contains { session in
            if case .running = promptTimer(for: session) { return true }
            return false
        }
    }

    public static func card(for session: SessionSnapshot,
                            among sessions: [SessionSnapshot]) -> NotchCardPresentation {
        let path = session.projectPath.flatMap { $0.isEmpty ? nil : $0 }
        let sharedFolder = path.map { path in
            sessions.contains { $0.key != session.key && $0.projectPath == path }
        } ?? false
        return NotchCardPresentation(
            folderName: path.map { ($0 as NSString).lastPathComponent } ?? "Project not observed",
            shortSessionID: sharedFolder ? String(session.key.sessionID.suffix(6)) : nil,
            timer: promptTimer(for: session))
    }

    public static func timerText(seconds: Int64) -> String {
        let seconds = max(0, seconds)
        if seconds >= 3600 {
            return String(format: "%lldh%02lldm", seconds / 3600, seconds % 3600 / 60)
        }
        if seconds >= 60 {
            return String(format: "%lldm%02llds", seconds / 60, seconds % 60)
        }
        return "\(seconds)s"
    }

    private static func promptTimer(for session: SessionSnapshot) -> PromptTimer? {
        guard let start = session.turnStartedAtMs, start >= 0 else { return nil }
        switch session.status {
        case .working, .questionNeeded, .approvalNeeded:
            return .running(startedAtMs: start)
        case .responseReady:
            guard let stop = session.responseReadyAtMs, stop >= 0 else { return nil }
            return .stopped(durationMs: max(0, stop - start))
        case .idle, .unknown, .ended:
            return nil
        }
    }

    public static func activeProviders(_ sessions: [SessionSnapshot]) -> Set<IntegrationAgent> {
        Set(sessions.filter { $0.status != .ended && $0.status != .unknown }
            .compactMap { IntegrationAgent(rawValue: $0.key.agent) })
    }

    public static func ordered(_ sessions: [SessionSnapshot]) -> [SessionSnapshot] {
        let rank: (SessionSnapshot) -> Int = { session in
            if session.pendingRequests.contains(where: \.isConfirmed) { return 0 }
            switch session.status {
            case .responseReady: return 1
            case .working: return 2
            case .idle: return 3
            case .unknown, .questionNeeded, .approvalNeeded: return 4
            case .ended: return 5
            }
        }
        return sessions.sorted { left, right in
            let a = rank(left), b = rank(right)
            if a != b { return a < b }
            if left.key.agent != right.key.agent { return left.key.agent < right.key.agent }
            return left.key.sessionID.utf8.lexicographicallyPrecedes(right.key.sessionID.utf8)
        }
    }

    public static func selection(_ current: SessionKey?, sessions: [SessionSnapshot]) -> SessionKey? {
        if let current, sessions.contains(where: { $0.key == current }) { return current }
        return ordered(sessions).first?.key
    }
}

/// Screen coordinates are supplied by AppKit; the model has no window or process dependencies.
public enum NotchPlacement {
    public static func frame(screen: CGRect, safeTop: CGFloat, notchWidth: CGFloat,
                             expanded: Bool) -> CGRect? {
        guard [screen.origin.x, screen.origin.y, screen.width, screen.height, safeTop, notchWidth]
            .allSatisfy({ $0.isFinite }), screen.width > 24, screen.height > 44,
              safeTop >= 0, notchWidth >= 0, safeTop <= screen.height - 12 else { return nil }
        let header = max(32, safeTop)
        let width = min(expanded ? 620 : max(220, notchWidth + 48), screen.width - 24)
        let height = min(header + (expanded ? 240 : 0), screen.height - 12)
        return CGRect(x: screen.midX - width / 2, y: screen.maxY - height,
                      width: width, height: height)
    }
}
