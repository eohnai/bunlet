import EventBridge
import Foundation

public struct HookSetupTarget: Codable, Equatable, Sendable {
    public let configurationPath: String
    public let parentDevice: UInt64
    public let parentInode: UInt64
    public let helperPath: String

    public init(configurationPath: String, parentDevice: UInt64, parentInode: UInt64, helperPath: String) {
        self.configurationPath = configurationPath
        self.parentDevice = parentDevice
        self.parentInode = parentInode
        self.helperPath = helperPath
    }
}

/// Explicit producer evidence. A pure planner cannot establish any of these facts itself.
public enum HookSetupSupport: Equatable, Sendable {
    case unverified
    case verified(version: String, hooksEnabled: Bool, helperAvailable: Bool)
}

public struct HookSetupInput: Sendable {
    public let agent: Agent
    public let configuration: Data?
    public let ownership: Data?
    public let target: HookSetupTarget
    public let support: HookSetupSupport
    public let installationID: UUID

    public init(agent: Agent, configuration: Data?, ownership: Data?, target: HookSetupTarget,
                support: HookSetupSupport, installationID: UUID) {
        self.agent = agent
        self.configuration = configuration
        self.ownership = ownership
        self.target = target
        self.support = support
        self.installationID = installationID
    }
}

public struct HookSetupOwnership: Codable, Equatable, Sendable {
    public let version: Int
    public let agent: Agent
    public let installationID: UUID
    public let target: HookSetupTarget
    public let groups: [String: Data]
    public let createdConfiguration: Bool
    public let createdHooksContainer: Bool
    public let createdEvents: [String]
}

public enum HookSetupPlan: Equatable, Sendable {
    case update(configuration: Data, ownership: Data)
    case unchanged
    case unavailable(HookPlanningFailure)
    case conflict(HookPlanningFailure)
}

struct HookManagedCommand: Codable, Equatable, Sendable {
    let type: String
    let command: String
    let timeout: Int
}

struct HookManagedGroup: Codable, Equatable, Sendable {
    let hooks: [HookManagedCommand]
}
