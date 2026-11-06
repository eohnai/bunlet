import EventBridge
import Foundation

public enum HookPlanningFailure: String, Error, Equatable, Sendable {
    case resourceLimit, unsupportedShape, ownershipConflict, malformedConfiguration
    case unverifiedVersion, unsupportedVersion, unsupportedProvider, hooksDisabled, helperUnavailable, unsafeTarget
}

/// Provider setup policy plus pure planning; file validation/application belongs to the installer.
public enum HookSetupPlanner {
    public static func plan(_ input: HookSetupInput, interactive: Bool = false) -> HookSetupPlan {
        guard !interactive || input.agent == .claude else { return .unavailable(.unsupportedProvider) }
        if let failure = ProviderHookPolicy.installationFailure(input.support, agent: input.agent) { return .unavailable(failure) }
        do {
            try validateTarget(input.target)
            let groups = try definitions(input.target.helperPath, agent: input.agent, interactive: interactive)
            let document = try HookConfigurationJSON(data: input.configuration ?? Data("{}".utf8))
            if let record = input.ownership {
                let owner = try validatedOwnership(record, target: input.target, agent: input.agent, interactive: interactive)
                guard owner.installationID == input.installationID else { throw HookPlanningFailure.ownershipConflict }
                try verifyInstalled(document.data, ownership: record, target: input.target, agent: input.agent, interactive: interactive)
                return .unchanged
            }
            let candidate = try HookGroupEdits.initialConfiguration(input.configuration, groups: groups,
                helperName: URL(fileURLWithPath: input.target.helperPath).lastPathComponent)
            let owner = HookSetupOwnership(version: 1, agent: input.agent, installationID: input.installationID,
                target: input.target, groups: groups, createdConfiguration: input.configuration == nil,
                createdHooksContainer: document.range(at: [.key("hooks")]) == nil,
                createdEvents: groups.keys.sorted().filter { document.range(at: [.key("hooks"), .key($0)]) == nil })
            let data = try JSONEncoder().encode(owner)
            guard data.count <= HookEnvelopeV1.rawHookLimit else { throw HookPlanningFailure.resourceLimit }
            return .update(configuration: candidate, ownership: data)
        } catch let failure as HookPlanningFailure {
            return failure == .resourceLimit ? .unavailable(failure) : .conflict(failure)
        } catch { return .conflict(.malformedConfiguration) }
    }

    /// Removal depends on exact content ownership, never on the installed CLI or its current policy.
    public static func remove(configuration: Data?, ownership: Data?, target: HookSetupTarget,
                              agent: Agent = .codex, interactive: Bool = false) -> HookSetupPlan {
        do {
            try validateTarget(target)
            let groups = try definitions(target.helperPath, agent: agent, interactive: interactive)
            guard let ownership else {
                _ = try HookGroupEdits.initialConfiguration(configuration, groups: groups,
                    helperName: URL(fileURLWithPath: target.helperPath).lastPathComponent)
                return .unchanged
            }
            guard let configuration else { throw HookPlanningFailure.ownershipConflict }
            let owner = try validatedOwnership(ownership, target: target, agent: agent, interactive: interactive)
            try verifyInstalled(configuration, ownership: ownership, target: target, agent: agent, interactive: interactive)
            var candidate = configuration
            for event in groups.keys.sorted() {
                guard let encoded = groups[event] else { throw HookPlanningFailure.ownershipConflict }
                let expected = try JSONDecoder().decode(HookManagedGroup.self, from: encoded)
                let current = try HookConfigurationJSON(data: candidate)
                let path: [JSONPathComponent] = [.key("hooks"), .key(event)]
                guard let members = current.members(at: path), let owned = members.first(where: {
                    guard let raw = current.rawValue(at: path + [$0]) else { return false }
                    return (try? JSONDecoder().decode(HookManagedGroup.self, from: raw)) == expected
                }) else { throw HookPlanningFailure.ownershipConflict }
                candidate = try HookGroupEdits.removing([owned], at: path, in: current)
                let next = try HookConfigurationJSON(data: candidate)
                if owner.createdEvents.contains(event), next.members(at: path)?.isEmpty == true {
                    candidate = try HookGroupEdits.removing([.key(event)], at: [.key("hooks")], in: next)
                }
            }
            let next = try HookConfigurationJSON(data: candidate)
            if owner.createdHooksContainer, next.members(at: [.key("hooks")])?.isEmpty == true {
                candidate = try HookGroupEdits.removing([.key("hooks")], at: [], in: next)
            }
            return .update(configuration: candidate, ownership: Data())
        } catch { return .conflict(.ownershipConflict) }
    }

    static func definitions(_ helper: String, agent: Agent, interactive: Bool) throws -> [String: Data] {
        guard !interactive || agent == .claude else { throw HookPlanningFailure.unsupportedProvider }
        let events = interactive ? ["PermissionRequest", "PreToolUse", "Stop"] : HookEvent.allCases.map(\.rawValue).sorted()
        let command = "'" + helper.replacingOccurrences(of: "'", with: "'\"'\"'") + "' --agent " + agent.rawValue
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return try Dictionary(uniqueKeysWithValues: events.map { event in
            let group = HookManagedGroup(hooks: [HookManagedCommand(type: "command", command: command, timeout: interactive ? 75 : 3)],
                                         matcher: interactive && event == "PreToolUse" ? "^AskUserQuestion$" : nil)
            return (event, try encoder.encode(group))
        })
    }

    static func validatedOwnership(_ data: Data, target: HookSetupTarget, agent: Agent = .codex,
                                   interactive: Bool = false) throws -> HookSetupOwnership {
        try validateTarget(target)
        let document = try HookConfigurationJSON(data: data)
        let owner = try JSONDecoder().decode(HookSetupOwnership.self, from: data)
        let groups = try definitions(target.helperPath, agent: agent, interactive: interactive)
        let keys = ["version", "agent", "installationID", "target", "groups", "createdConfiguration", "createdHooksContainer", "createdEvents"]
        guard Set(document.members(at: []) ?? []) == Set(keys.map(JSONPathComponent.key)),
              Set(document.members(at: [.key("target")]) ?? []) == Set(["configurationPath", "parentDevice", "parentInode", "helperPath"].map(JSONPathComponent.key)),
              document.rawValue(at: [.key("version")]) == Data("1".utf8), owner.version == 1,
              owner.agent == agent, owner.target == target, owner.groups == groups,
              owner.createdEvents.count == Set(owner.createdEvents).count,
              Set(owner.createdEvents).isSubset(of: Set(groups.keys)),
              !owner.createdHooksContainer || Set(owner.createdEvents) == Set(groups.keys),
              !owner.createdConfiguration || owner.createdHooksContainer else { throw HookPlanningFailure.ownershipConflict }
        return owner
    }

    static func verifyInstalled(_ configuration: Data, ownership: Data, target: HookSetupTarget,
                                agent: Agent = .codex, interactive: Bool = false) throws {
        _ = try validatedOwnership(ownership, target: target, agent: agent, interactive: interactive)
        let groups = try definitions(target.helperPath, agent: agent, interactive: interactive)
            .mapValues { try JSONDecoder().decode(HookManagedGroup.self, from: $0) }
        try HookGroupEdits.verifyOwnedConfiguration(HookConfigurationJSON(data: configuration), expected: groups,
            helperName: URL(fileURLWithPath: target.helperPath).lastPathComponent)
    }

    static func validateTarget(_ target: HookSetupTarget) throws {
        for path in [target.configurationPath, target.helperPath] {
            guard path.hasPrefix("/"), !path.hasSuffix("/"), path.utf8.count <= 4096,
                  !path.unicodeScalars.contains(where: { $0.properties.generalCategory == .control }),
                  URL(fileURLWithPath: path).standardizedFileURL.path == path else { throw HookPlanningFailure.unsafeTarget }
        }
        guard target.parentDevice > 0, target.parentInode > 0 else { throw HookPlanningFailure.unsafeTarget }
    }
}

/// Pure byte edits shared by provider planners. No settings are read, written or executed here.
enum HookGroupEdits {
    static func setting(_ member: JSONPathComponent, value: Data, in document: HookConfigurationJSON) throws -> Data {
        guard case .key(let key) = member, let root = document.range(at: []),
              let members = document.members(at: []), document.rawValue(at: [])?.first == 123 else {
            throw HookPlanningFailure.malformedConfiguration
        }
        var result = document.data
        if let range = document.range(at: [member]) { result.replaceSubrange(range, with: value) }
        else {
            var insertion = Data((members.isEmpty ? "" : ",").utf8)
            insertion.append(try JSONEncoder().encode(key))
            insertion.append(58)
            insertion.append(value)
            result.insert(contentsOf: insertion, at: root.upperBound - 1)
        }
        guard result.count <= HookEnvelopeV1.rawHookLimit else { throw HookPlanningFailure.resourceLimit }
        _ = try HookConfigurationJSON(data: result)
        return result
    }

    /// Remove collection members using original byte slices, including original object key spelling.
    static func removing(_ removed: Set<JSONPathComponent>, at path: [JSONPathComponent],
                         in document: HookConfigurationJSON) throws -> Data {
        guard let container = document.range(at: path), let members = document.members(at: path),
              removed.isSubset(of: Set(members)) else { throw HookPlanningFailure.ownershipConflict }
        var body = Data()
        var previousEnd = container.lowerBound + 1
        for member in members {
            guard let range = document.range(at: path + [member]) else { throw HookPlanningFailure.ownershipConflict }
            if !removed.contains(member) {
                var fragment = Data(document.data[previousEnd..<range.upperBound])
                if body.isEmpty, previousEnd != container.lowerBound + 1, let comma = fragment.firstIndex(of: 44) {
                    fragment.remove(at: comma)
                }
                body.append(fragment)
            }
            previousEnd = range.upperBound
        }
        body.append(document.data[previousEnd..<(container.upperBound - 1)])
        var candidate = document.data
        candidate.replaceSubrange((container.lowerBound + 1)..<(container.upperBound - 1), with: body)
        _ = try HookConfigurationJSON(data: candidate)
        return candidate
    }
    static func initialConfiguration(_ current: Data?, groups: [String: Data],
                                     helperName: String) throws -> Data {
        guard !helperName.isEmpty, !groups.isEmpty, groups.count <= 32 else { throw HookPlanningFailure.unsupportedShape }
        for group in groups.values { _ = try HookConfigurationJSON(data: group) }
        let document = try HookConfigurationJSON(data: current ?? Data("{}".utf8))
        let edits = try insertions(document, groups: groups, helperName: helperName)
        let growth = edits.reduce(0) { $0 + $1.bytes.count }
        guard growth <= HookEnvelopeV1.rawHookLimit,
              document.data.count <= HookEnvelopeV1.rawHookLimit - growth else {
            throw HookPlanningFailure.resourceLimit
        }
        var candidate = document.data
        for edit in edits.sorted(by: { $0.offset > $1.offset }) {
            candidate.insert(contentsOf: edit.bytes, at: edit.offset)
        }
        _ = try HookConfigurationJSON(data: candidate)
        return candidate
    }

    private static func insertions(_ document: HookConfigurationJSON, groups: [String: Data],
                                   helperName: String) throws -> [(offset: Int, bytes: Data)] {
        let hooksPath: [JSONPathComponent] = [.key("hooks")]
        var additions: [String] = []
        var edits: [(offset: Int, bytes: Data)] = []
        if document.range(at: hooksPath) != nil {
            guard document.rawValue(at: hooksPath)?.first == 123,
                  let configuredEvents = document.members(at: hooksPath), configuredEvents.count <= 256 else {
                throw HookPlanningFailure.unsupportedShape
            }
            for event in configuredEvents {
                let path = hooksPath + [event]
                guard document.rawValue(at: path)?.first == 91,
                      let groups = document.members(at: path), groups.count <= 256 else {
                    throw HookPlanningFailure.unsupportedShape
                }
                for existing in groups {
                    try rejectCollision(document, at: path + [existing], helperName: helperName)
                }
            }
        }
        for event in groups.keys.sorted() {
            guard let group = groups[event] else { throw HookPlanningFailure.unsupportedShape }
            let groupText = String(decoding: group, as: UTF8.self)
            let key = String(decoding: try JSONEncoder().encode(event), as: UTF8.self)
            let path = hooksPath + [.key(event)]
            if let range = document.range(at: path) {
                guard document.rawValue(at: path)?.first == 91,
                      let members = document.members(at: path), members.count <= 256 else {
                    throw HookPlanningFailure.unsupportedShape
                }
                edits.append((range.upperBound - 1, Data(((members.isEmpty ? "" : ",") + groupText).utf8)))
            } else {
                additions.append(key + ":[" + groupText + "]")
            }
        }
        if let hooksRange = document.range(at: hooksPath) {
            guard document.rawValue(at: hooksPath)?.first == 123,
                  let members = document.members(at: hooksPath) else {
                throw HookPlanningFailure.unsupportedShape
            }
            if !additions.isEmpty {
                edits.append((hooksRange.upperBound - 1,
                              Data(((members.isEmpty ? "" : ",") + additions.joined(separator: ",")).utf8)))
            }
        } else {
            guard let root = document.range(at: []), let members = document.members(at: []) else {
                throw HookPlanningFailure.malformedConfiguration
            }
            let field = (members.isEmpty ? "" : ",") + "\"hooks\":{" + additions.joined(separator: ",") + "}"
            edits.append((root.upperBound - 1, Data(field.utf8)))
        }
        return edits
    }

    static func verifyOwnedConfiguration(_ document: HookConfigurationJSON, expected: [String: HookManagedGroup], helperName: String) throws {
        let path: [JSONPathComponent] = [.key("hooks")]
        guard document.rawValue(at: path)?.first == 123,
              let configuredEvents = document.members(at: path), configuredEvents.count <= 256,
              Set(expected.keys.map(JSONPathComponent.key)).isSubset(of: Set(configuredEvents)) else {
            throw HookPlanningFailure.ownershipConflict
        }
        for event in configuredEvents {
            let eventPath = path + [event]
            guard document.rawValue(at: eventPath)?.first == 91,
                  let groups = document.members(at: eventPath), groups.count <= 256 else {
                throw HookPlanningFailure.ownershipConflict
            }
            var matches = 0
            for existing in groups {
                let groupPath = eventPath + [existing]
                if case .key(let name) = event, let wanted = expected[name], matchesGroup(document, at: groupPath, expected: wanted) {
                    matches += 1
                } else {
                    try rejectCollision(document, at: groupPath, helperName: helperName)
                }
            }
            if case .key(let name) = event, expected[name] != nil, matches != 1 {
                throw HookPlanningFailure.ownershipConflict
            }
        }
    }

    private static func matchesGroup(_ document: HookConfigurationJSON, at path: [JSONPathComponent],
                                     expected: HookManagedGroup) -> Bool {
        let hooksPath = path + [.key("hooks")]
        let keys: Set<JSONPathComponent> = expected.matcher == nil ? [.key("hooks")] : [.key("hooks"), .key("matcher")]
        guard Set(document.members(at: path) ?? []) == keys,
              document.members(at: hooksPath) == [.index(0)],
              Set(document.members(at: hooksPath + [.index(0)]) ?? []) == [.key("type"), .key("command"), .key("timeout")],
              document.rawValue(at: hooksPath + [.index(0), .key("timeout")]) == Data(String(expected.hooks.first?.timeout ?? 0).utf8),
              let raw = document.rawValue(at: path),
              let decoded = try? JSONDecoder().decode(HookManagedGroup.self, from: raw) else { return false }
        return decoded == expected
    }

    private static func rejectCollision(_ document: HookConfigurationJSON, at path: [JSONPathComponent],
                                        helperName: String) throws {
        let handlersPath = path + [.key("hooks")]
        guard document.rawValue(at: path)?.first == 123,
              document.rawValue(at: handlersPath)?.first == 91,
              let handlers = document.members(at: handlersPath), handlers.count <= 256 else {
            throw HookPlanningFailure.unsupportedShape
        }
        let decoder = JSONDecoder()
        if let matcher = document.rawValue(at: path + [.key("matcher")]),
           (try? decoder.decode(String.self, from: matcher)) == nil {
            throw HookPlanningFailure.unsupportedShape
        }
        for handler in handlers {
            let handlerPath = handlersPath + [handler]
            guard document.rawValue(at: handlerPath)?.first == 123,
                  let typeData = document.rawValue(at: handlerPath + [.key("type")]),
                  (try? decoder.decode(String.self, from: typeData)) == "command",
                  let raw = document.rawValue(at: handlerPath + [.key("command")]),
                  let command = try? decoder.decode(String.self, from: raw) else {
                throw HookPlanningFailure.unsupportedShape
            }
            // Conservatively reject lookalikes. This never adopts or deletes a user's entry.
            if command.contains(helperName) { throw HookPlanningFailure.ownershipConflict }
        }
    }
}
