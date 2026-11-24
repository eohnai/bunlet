import EventBridge
import Foundation

/// Picks the planner for an agent's configuration format and a setup scope, in one place.
enum ProviderSetupPlanners {
    static func plan(_ input: HookSetupInput, scope: ProviderSetupScope) -> HookSetupPlan {
        guard scope.applies(to: input.agent) else { return .unavailable(.unsupportedProvider) }
        switch (input.agent, scope) {
        case (_, .claudeQuota): return ClaudeStatusLinePlanner.plan(input)
        case (.cursor, _): return CursorHookPlanner.plan(input)
        default: return HookSetupPlanner.plan(input, interactive: scope == .claudeActions)
        }
    }

    static func remove(configuration: Data?, ownership: Data?, target: HookSetupTarget, agent: Agent,
                       scope: ProviderSetupScope) -> HookSetupPlan {
        switch (agent, scope) {
        case (_, .claudeQuota): ClaudeStatusLinePlanner.remove(configuration: configuration, ownership: ownership, target: target)
        case (.cursor, _): CursorHookPlanner.remove(configuration: configuration, ownership: ownership, target: target)
        default: HookSetupPlanner.remove(configuration: configuration, ownership: ownership, target: target, agent: agent,
                                         interactive: scope == .claudeActions)
        }
    }

    static func validatedOwner(_ data: Data, target: HookSetupTarget, agent: Agent, scope: ProviderSetupScope) throws -> UUID {
        switch (agent, scope) {
        case (_, .claudeQuota): try ClaudeStatusLinePlanner.validatedOwnership(data, target: target).installationID
        case (.cursor, _): try CursorHookPlanner.validatedOwnership(data, target: target).installationID
        default: try HookSetupPlanner.validatedOwnership(data, target: target, agent: agent,
                                                         interactive: scope == .claudeActions).installationID
        }
    }

    static func verifyInstalled(_ configuration: Data, ownership: Data, target: HookSetupTarget, agent: Agent,
                                scope: ProviderSetupScope) throws {
        switch (agent, scope) {
        case (_, .claudeQuota): try ClaudeStatusLinePlanner.verifyInstalled(configuration, ownership: ownership, target: target)
        case (.cursor, _): try CursorHookPlanner.verifyInstalled(configuration, ownership: ownership, target: target)
        default: try HookSetupPlanner.verifyInstalled(configuration, ownership: ownership, target: target, agent: agent,
                                                      interactive: scope == .claudeActions)
        }
    }
}
