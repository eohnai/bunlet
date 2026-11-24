import Foundation
import Testing
@testable import EventBridge

/// Decision 0026: more exact panes and the app the agent runs in. Fictional data only.
struct AnyTerminalTests {
    private let session = "6A0E2F4C-1B3D-4E5F-8A9B-0C1D2E3F4A5B"

    @Test func itermWeztermAndKittyPanesAreRecognized() {
        #expect(TerminalDetection.terminal(environment: ["ITERM_SESSION_ID": "w0t1p2:\(session)"], tty: { nil })
                == HookEnvelopeV1.Terminal(kind: .iterm, paneSelector: session))
        #expect(TerminalDetection.terminal(environment: ["WEZTERM_PANE": "12"], tty: { nil })
                == HookEnvelopeV1.Terminal(kind: .wezterm, paneSelector: "12"))
        #expect(TerminalDetection.terminal(environment: ["KITTY_WINDOW_ID": "3", "KITTY_LISTEN_ON": "unix:/private/tmp/kitty-501"],
                                           tty: { nil })
                == HookEnvelopeV1.Terminal(kind: .kitty, paneSelector: "3", socket: "/private/tmp/kitty-501"))
    }

    @Test func otherTerminalsFallBackToTheirApp() {
        let host = { "com.example.fictional-terminal" }
        // kitty without a listening socket, and terminals with no pane address, are known by their app.
        #expect(TerminalDetection.terminal(environment: ["KITTY_WINDOW_ID": "3", "KITTY_LISTEN_ON": "tcp:localhost:1"],
                                           tty: { nil }, host: host)?.kind == .app)
        #expect(TerminalDetection.terminal(environment: ["TERM_PROGRAM": "ghostty"], tty: { nil }, host: host)
                == HookEnvelopeV1.Terminal(kind: .app, paneSelector: "com.example.fictional-terminal"))
        // The process walk wins over the inherited identifier, which can be stale.
        #expect(TerminalDetection.terminal(environment: ["__CFBundleIdentifier": "com.example.launcher"], tty: { nil }, host: host)?
                .paneSelector == "com.example.fictional-terminal")
        #expect(TerminalDetection.terminal(environment: ["__CFBundleIdentifier": "com.example.launcher"], tty: { nil })?
                .paneSelector == "com.example.launcher")
        // Terminal with no readable tty is still Terminal.
        #expect(TerminalDetection.terminal(environment: ["TERM_PROGRAM": "Apple_Terminal"], tty: { nil },
                                           host: { "com.apple.Terminal" })?.kind == .app)
        #expect(TerminalDetection.terminal(environment: [:], tty: { nil }, host: { "not a bundle id" }) == nil)
    }

    @Test func malformedPaneAddressesAreRejected() {
        for bad in [
            HookEnvelopeV1.Terminal(kind: .iterm, paneSelector: "\"; do shell script \"x"),
            HookEnvelopeV1.Terminal(kind: .wezterm, paneSelector: "1 2"),
            HookEnvelopeV1.Terminal(kind: .kitty, paneSelector: "3"),
            HookEnvelopeV1.Terminal(kind: .kitty, paneSelector: "3", socket: "relative/socket"),
            HookEnvelopeV1.Terminal(kind: .app, paneSelector: "com.example.app", app: "com.example.other"),
        ] {
            #expect(!bad.isValid)
        }
        #expect(TerminalDetection.terminal(environment: ["WEZTERM_PANE": "-1"], tty: { nil }) == nil)
    }

    @Test func newKindsSurviveTheWire() throws {
        for terminal in [HookEnvelopeV1.Terminal(kind: .iterm, paneSelector: session),
                         HookEnvelopeV1.Terminal(kind: .kitty, paneSelector: "9", socket: "/private/tmp/kitty"),
                         HookEnvelopeV1.Terminal(kind: .app, paneSelector: "com.example.fictional-terminal")] {
            let raw = Data(#"{"session_id":"fictional","hook_event_name":"SessionStart"}"#.utf8)
            let envelope = try HookEnvelopeV1.project(rawHook: raw, agent: .claude, terminal: terminal)
            #expect(try HookEnvelopeV1.decode(frame: envelope.frame()).terminal == terminal)
            #expect(terminal.hostApp != nil)
        }
    }

    @Test func theHostIsTheNearestAncestorInAnAppBundle() {
        let paths: [pid_t: String] = [
            40: "/usr/local/bin/node",
            30: "/bin/zsh",
            20: "/Applications/Fictional Term.app/Contents/Frameworks/Helper.app/Contents/MacOS/Helper",
            10: "/Applications/Other.app/Contents/MacOS/Other",
        ]
        let parents: [pid_t: pid_t] = [40: 30, 30: 20, 20: 10, 10: 1]
        var asked: [String] = []
        let found = TerminalDetection.hostApplication(startingAt: 40, depth: 12, parent: { parents[$0] },
                                                      executablePath: { paths[$0] }) { bundle in
            asked.append(bundle)
            return bundle == "/Applications/Fictional Term.app" ? "com.example.fictional-term" : nil
        }
        #expect(found == "com.example.fictional-term")
        #expect(asked == ["/Applications/Fictional Term.app"])
        // Bounded: never walks past the depth or into launchd.
        #expect(TerminalDetection.hostApplication(startingAt: 40, depth: 2, parent: { parents[$0] },
                                                  executablePath: { paths[$0] }) { _ in "com.example.x" } == nil)
        #expect(TerminalDetection.outermostBundle(inExecutablePath: "relative/A.app/Contents/MacOS/A") == nil)
    }

    @Test func claudeRuntimeBundleDoesNotHideTheDesktopHost() {
        let paths: [pid_t: String] = [30: "/fictional/Runtime/claude.app/Contents/MacOS/claude",
                                    20: "/Applications/Claude.app/Contents/MacOS/Claude"]
        let identifiers = ["/fictional/Runtime/claude.app": "com.anthropic.claude-code",
                           "/Applications/Claude.app": "com.anthropic.claudefordesktop"]
        let result = TerminalDetection.hostApplication(startingAt: 30, depth: 12, parent: { $0 == 30 ? 20 : 1 },
                                                       executablePath: { paths[$0] }, identify: { identifiers[$0] })
        #expect(result == Agent.claude.desktopBundleIdentifier)
    }
}
