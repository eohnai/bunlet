import Foundation
import Observation
import SessionState

/// Follow-ups typed into a session's own pane (decision 0025). Owns drafts and send state only;
/// session truth stays in SessionStore and is checked again just before sending.
@MainActor
@Observable
final class TerminalReplyController {
    enum Phase: Equatable {
        case sending, sent, failed
    }

    private(set) var drafts: [SessionKey: String] = [:]
    private(set) var phases: [SessionKey: Phase] = [:]
    @ObservationIgnored private let sessions: SessionStore
    @ObservationIgnored private let typer: @Sendable (String, SessionSnapshot) async -> Bool
    @ObservationIgnored private var tasks: [SessionKey: Task<Void, Never>] = [:]

    init(sessions: SessionStore,
         typer: @escaping @Sendable (String, SessionSnapshot) async -> Bool = { text, session in
             guard let terminal = session.terminal else { return false }
             return await TerminalTargets.type(text, into: terminal)
         }) {
        self.sessions = sessions
        self.typer = typer
    }

    func canReply(_ session: SessionSnapshot) -> Bool { TerminalPolicy.canType(into: session) }

    func draft(for key: SessionKey) -> String { drafts[key] ?? "" }

    func setDraft(_ text: String, for key: SessionKey) {
        guard phases[key] != .sending else { return }
        var bounded = text
        while bounded.utf8.count > TerminalPolicy.textLimit { bounded.removeLast() }
        drafts[key] = bounded
        if phases[key] == .failed || phases[key] == .sent { phases[key] = nil }
    }

    func canSend(_ key: SessionKey) -> Bool {
        phases[key] != .sending && TerminalPolicy.singleLine(draft(for: key)) != nil &&
            sessions.sessions.first(where: { $0.key == key }).map(canReply) == true
    }

    /// One explicit send. The session must still be at its prompt when the user presses Send.
    func send(_ key: SessionKey) {
        guard canSend(key), let session = sessions.sessions.first(where: { $0.key == key }),
              let text = TerminalPolicy.singleLine(draft(for: key)) else { return }
        phases[key] = .sending
        tasks[key]?.cancel()
        tasks[key] = Task { [weak self, typer] in
            let delivered = await typer(text, session)
            guard let self, !Task.isCancelled else { return }
            self.tasks[key] = nil
            if delivered {
                self.drafts[key] = nil
                self.phases[key] = .sent
            } else {
                self.phases[key] = .failed
            }
        }
    }

    func discard(_ key: SessionKey) {
        tasks[key]?.cancel()
        tasks[key] = nil
        drafts[key] = nil
        phases[key] = nil
    }

    func stop() {
        for task in tasks.values { task.cancel() }
        tasks = [:]
        drafts = [:]
        phases = [:]
    }
}
