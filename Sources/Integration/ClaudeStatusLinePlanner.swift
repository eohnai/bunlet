import EventBridge
import Foundation

struct StatusLineOwnership: Codable {
    let version: Int
    let kind: String
    let agent: Agent
    let installationID: UUID
    let target: HookSetupTarget
    let original: Data?
    let installed: Data
}

/// Only the statusLine value is owned. Other settings, including lifecycle hooks, stay untouched.
enum ClaudeStatusLinePlanner {
    static let commandLimit = 16_384
    static let fieldLimit = 65_536
    private static let field: [JSONPathComponent] = [.key("statusLine")]

    static func plan(_ input: HookSetupInput) -> HookSetupPlan {
        guard input.agent == .claude else { return .unavailable(.unsupportedProvider) }
        if let failure = ProviderHookPolicy.installationFailure(input.support, agent: .claude) { return .unavailable(failure) }
        do {
            let document = try HookConfigurationJSON(data: input.configuration ?? Data("{}".utf8))
            if let ownership = input.ownership {
                let owner = try validatedOwnership(ownership, target: input.target)
                guard owner.installationID == input.installationID else { throw HookPlanningFailure.ownershipConflict }
                try verifyInstalled(document.data, ownership: ownership, target: input.target)
                return .unchanged
            }
            let original = document.rawValue(at: field)
            try rejectLookalike(original, helper: input.target.helperPath)
            let installed = try installedValue(original: original, target: input.target)
            let candidate = try HookGroupEdits.setting(.key("statusLine"), value: installed, in: document)
            let owner = StatusLineOwnership(version: 1, kind: "claudeStatusLine", agent: .claude,
                installationID: input.installationID, target: input.target, original: original, installed: installed)
            let encoded = try JSONEncoder().encode(owner)
            guard encoded.count <= HookFileDirectory.byteLimit else { throw HookPlanningFailure.resourceLimit }
            return .update(configuration: candidate, ownership: encoded)
        } catch let failure as HookPlanningFailure { return .conflict(failure) }
        catch { return .conflict(.malformedConfiguration) }
    }

    static func remove(configuration: Data?, ownership: Data?, target: HookSetupTarget) -> HookSetupPlan {
        do {
            try HookSetupPlanner.validateTarget(target)
            let document = try HookConfigurationJSON(data: configuration ?? Data("{}".utf8))
            guard let ownership else {
                try rejectLookalike(document.rawValue(at: field), helper: target.helperPath)
                return .unchanged
            }
            let owner = try validatedOwnership(ownership, target: target)
            try verifyInstalled(document.data, ownership: ownership, target: target)
            let candidate: Data
            if let original = owner.original { candidate = try HookGroupEdits.setting(.key("statusLine"), value: original, in: document) }
            else { candidate = try HookGroupEdits.removing([.key("statusLine")], at: [], in: document) }
            return .update(configuration: candidate, ownership: Data())
        } catch { return .conflict(.ownershipConflict) }
    }

    static func validatedOwnership(_ data: Data, target: HookSetupTarget) throws -> StatusLineOwnership {
        try HookSetupPlanner.validateTarget(target)
        let document = try HookConfigurationJSON(data: data)
        let owner = try JSONDecoder().decode(StatusLineOwnership.self, from: data)
        let required = Set(["version", "kind", "agent", "installationID", "target", "installed"].map(JSONPathComponent.key))
        let actual = Set(document.members(at: []) ?? [])
        guard required.isSubset(of: actual), actual.isSubset(of: required.union([.key("original")])),
              Set(document.members(at: [.key("target")]) ?? []) == Set(["configurationPath", "parentDevice", "parentInode", "helperPath"].map(JSONPathComponent.key)),
              document.rawValue(at: [.key("version")]) == Data("1".utf8),
              owner.version == 1, owner.kind == "claudeStatusLine", owner.agent == .claude, owner.target == target,
              owner.installed == (try installedValue(original: owner.original, target: target)) else {
            throw HookPlanningFailure.ownershipConflict
        }
        return owner
    }

    static func verifyInstalled(_ configuration: Data, ownership: Data, target: HookSetupTarget) throws {
        let owner = try validatedOwnership(ownership, target: target)
        let document = try HookConfigurationJSON(data: configuration)
        guard document.rawValue(at: field) == owner.installed else { throw HookPlanningFailure.ownershipConflict }
    }

    private static func installedValue(original: Data?, target: HookSetupTarget) throws -> Data {
        try HookSetupPlanner.validateTarget(target)
        let quote: (String) -> String = { "'" + $0.replacingOccurrences(of: "'", with: "'\"'\"'") + "'" }
        var command = quote(target.helperPath)
        let document: HookConfigurationJSON
        if let original {
            guard original.count <= fieldLimit else { throw HookPlanningFailure.resourceLimit }
            document = try HookConfigurationJSON(data: original)
            guard (document.members(at: [])?.count ?? 33) <= 32,
                  document.rawValue(at: [.key("type")]) == Data("\"command\"".utf8),
                  let raw = document.rawValue(at: [.key("command")]),
                  let previous = try? JSONDecoder().decode(String.self, from: raw),
                  previous.utf8.count <= commandLimit, !previous.utf8.contains(0) else {
                throw HookPlanningFailure.unsupportedShape
            }
            command += " --command " + quote(previous)
        } else {
            document = try HookConfigurationJSON(data: Data("{\"type\":\"command\"}".utf8))
        }
        let result = try HookGroupEdits.setting(.key("command"), value: JSONEncoder().encode(command), in: document)
        guard result.count <= fieldLimit else { throw HookPlanningFailure.resourceLimit }
        return result
    }

    private static func rejectLookalike(_ value: Data?, helper: String) throws {
        guard let value else { return }
        let document = try HookConfigurationJSON(data: value)
        if let raw = document.rawValue(at: [.key("command")]),
           let command = try? JSONDecoder().decode(String.self, from: raw),
           command.contains(URL(fileURLWithPath: helper).lastPathComponent) {
            throw HookPlanningFailure.ownershipConflict
        }
    }
}
