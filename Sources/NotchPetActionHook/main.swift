import AgentActions
import Darwin

// Provider-owned hook cancellation ends this short-lived helper. No child processes are launched.
_ = signal(SIGPIPE, SIG_IGN)
if CommandLine.arguments.count == 3, CommandLine.arguments[1] == "--agent" {
    switch CommandLine.arguments[2] {
    case "claude": ClaudeHookActionAdapter.run()
    case "codex": CodexHookActionAdapter.run()
    default: break
    }
}
