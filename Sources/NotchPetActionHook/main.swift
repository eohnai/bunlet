import AgentActions
import Darwin

// Provider-owned hook cancellation ends this short-lived helper. No child processes are launched.
_ = signal(SIGPIPE, SIG_IGN)
if CommandLine.arguments.count == 3, CommandLine.arguments[1] == "--agent", CommandLine.arguments[2] == "claude" {
    ClaudeHookActionAdapter.run()
}
