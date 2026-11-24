import EventBridge
import Foundation

/// When Bunlet may jump to or type into a session's terminal (decision 0025). Pure rules; no I/O.
public enum TerminalPolicy {
    /// The longest follow-up typed into a terminal, in UTF-8 bytes.
    public static let textLimit = 8_192

    /// A reported terminal Bunlet can bring forward. Editors need the project folder to pick the window.
    public static func canJump(_ session: SessionSnapshot) -> Bool {
        guard let terminal = session.terminal, terminal.isValid, !session.hasTerminalRestriction else { return false }
        if terminal.kind == .editor { return session.projectPath?.hasPrefix("/") == true }
        return true
    }

    /// Only panes addressed by identity, never "whatever is in front", so typing cannot land in another window.
    public static func addressable(_ terminal: HookEnvelopeV1.Terminal?) -> Bool {
        guard let terminal, terminal.isValid else { return false }
        return terminal.kind == .otty || terminal.kind == .tmux
    }

    /// The agent's last observed state is a finished turn (or a fresh session) with nothing waiting on the user.
    /// This is Bunlet's own evidence only: it cannot see what the user did in the pane afterwards.
    public static func isAtPrompt(_ session: SessionSnapshot) -> Bool {
        !session.hasTerminalRestriction && session.pendingRequests.isEmpty &&
            (session.status == .responseReady || session.status == .idle)
    }

    public static func canType(into session: SessionSnapshot) -> Bool {
        addressable(session.terminal) && isAtPrompt(session)
    }

    /// One line, so a newline in the draft cannot submit part of it early. Nil when nothing is left to send.
    public static func singleLine(_ text: String) -> String? {
        let joined = text.components(separatedBy: .newlines).joined(separator: " ")
            .filter { !($0.unicodeScalars.first?.properties.generalCategory == .control) }
            .trimmingCharacters(in: .whitespaces)
        guard !joined.isEmpty, joined.utf8.count <= textLimit else { return nil }
        return joined
    }
}
