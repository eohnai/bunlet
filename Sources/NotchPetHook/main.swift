import Dispatch
import Darwin
import EventBridge
import Foundation

let enteredAt = DispatchTime.now().uptimeNanoseconds
// Only the few variables that say where the agent runs; nothing else leaves the environment.
var environment: [String: String] = [:]
for name in TerminalDetection.variables {
    if let value = getenv(name) { environment[name] = String(cString: value) }
}
HookHelper.run(arguments: Array(CommandLine.arguments.dropFirst()), environment: environment, enteredAt: enteredAt)
