import EventBridge
import Foundation

/// Cursor CLI's `~/.cursor/hooks.json` (decision 0025): `{"version": 1, "hooks": {"stop": [{"command": "…"}]}}`.
/// Same ownership rules as HookSetupPlanner: Bunlet adds one plain entry per event, removes only exact owned
/// entries, and stops on anything that looks like a copy of its helper. Pure byte planning; no I/O.
public enum CursorHookPlanner {
    struct Entry: Codable, Equatable {
        let command: String
    }

    static func definitions(_ helper: String) throws -> [String: Data] {
        let command = "'" + helper.replacingOccurrences(of: "'", with: "'\"'\"'") + "' --agent cursor"
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        let entry = try encoder.encode(Entry(command: command))
        return Dictionary(uniqueKeysWithValues: CursorEventAdapter.events.keys.map { ($0, entry) })
    }

    public static func plan(_ input: HookSetupInput) -> HookSetupPlan {
        guard input.agent == .cursor else { return .unavailable(.unsupportedProvider) }
        if let failure = ProviderHookPolicy.installationFailure(input.support, agent: .cursor) { return .unavailable(failure) }
        do {
            try HookSetupPlanner.validateTarget(input.target)
            let groups = try definitions(input.target.helperPath)
            let helperName = URL(fileURLWithPath: input.target.helperPath).lastPathComponent
            // Cursor expects a version number in a new file.
            let document = try HookConfigurationJSON(data: input.configuration ?? Data("{\"version\":1}".utf8))
            if let record = input.ownership {
                let owner = try validatedOwnership(record, target: input.target)
                guard owner.installationID == input.installationID else { throw HookPlanningFailure.ownershipConflict }
                try verifyInstalled(document.data, ownership: record, target: input.target)
                return .unchanged
            }
            try rejectCollisions(document, helperName: helperName, owned: [:])
            let candidate = try inserting(groups, into: document)
            let owner = HookSetupOwnership(version: 1, agent: .cursor, installationID: input.installationID,
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

    public static func remove(configuration: Data?, ownership: Data?, target: HookSetupTarget) -> HookSetupPlan {
        do {
            try HookSetupPlanner.validateTarget(target)
            let helperName = URL(fileURLWithPath: target.helperPath).lastPathComponent
            guard let ownership else {
                // Nothing recorded: only a file with no lookalike entries counts as clean.
                try rejectCollisions(HookConfigurationJSON(data: configuration ?? Data("{}".utf8)), helperName: helperName, owned: [:])
                return .unchanged
            }
            guard let configuration else { throw HookPlanningFailure.ownershipConflict }
            let owner = try validatedOwnership(ownership, target: target)
            try verifyInstalled(configuration, ownership: ownership, target: target)
            var candidate = configuration
            for event in owner.groups.keys.sorted() {
                let current = try HookConfigurationJSON(data: candidate)
                let path: [JSONPathComponent] = [.key("hooks"), .key(event)]
                guard let encoded = owner.groups[event], let members = current.members(at: path),
                      let owned = members.first(where: { matches(current, at: path + [$0], expected: encoded) }) else {
                    throw HookPlanningFailure.ownershipConflict
                }
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

    static func validatedOwnership(_ data: Data, target: HookSetupTarget) throws -> HookSetupOwnership {
        try HookSetupPlanner.validateTarget(target)
        let document = try HookConfigurationJSON(data: data)
        let owner = try JSONDecoder().decode(HookSetupOwnership.self, from: data)
        let groups = try definitions(target.helperPath)
        guard document.rawValue(at: [.key("version")]) == Data("1".utf8), owner.version == 1,
              owner.agent == .cursor, owner.target == target, owner.groups == groups,
              owner.createdEvents.count == Set(owner.createdEvents).count,
              Set(owner.createdEvents).isSubset(of: Set(groups.keys)),
              !owner.createdHooksContainer || Set(owner.createdEvents) == Set(groups.keys),
              !owner.createdConfiguration || owner.createdHooksContainer else { throw HookPlanningFailure.ownershipConflict }
        return owner
    }

    static func verifyInstalled(_ configuration: Data, ownership: Data, target: HookSetupTarget) throws {
        let owner = try validatedOwnership(ownership, target: target)
        let document = try HookConfigurationJSON(data: configuration)
        let helperName = URL(fileURLWithPath: target.helperPath).lastPathComponent
        for (event, encoded) in owner.groups {
            let path: [JSONPathComponent] = [.key("hooks"), .key(event)]
            guard let members = document.members(at: path),
                  members.filter({ matches(document, at: path + [$0], expected: encoded) }).count == 1 else {
                throw HookPlanningFailure.ownershipConflict
            }
        }
        try rejectCollisions(document, helperName: helperName, owned: owner.groups)
    }

    /// Every entry must be an object with a string command; any entry other than an owned one that names
    /// Bunlet's helper is treated as a conflict, never adopted or deleted.
    private static func rejectCollisions(_ document: HookConfigurationJSON, helperName: String, owned: [String: Data]) throws {
        let hooks: [JSONPathComponent] = [.key("hooks")]
        guard document.range(at: hooks) != nil else { return }
        guard document.rawValue(at: hooks)?.first == 123, let events = document.members(at: hooks), events.count <= 256 else {
            throw HookPlanningFailure.unsupportedShape
        }
        for event in events {
            let path = hooks + [event]
            guard document.rawValue(at: path)?.first == 91, let entries = document.members(at: path), entries.count <= 256 else {
                throw HookPlanningFailure.unsupportedShape
            }
            for entry in entries {
                if case .key(let name) = event, let expected = owned[name], matches(document, at: path + [entry], expected: expected) {
                    continue
                }
                guard document.rawValue(at: path + [entry])?.first == 123,
                      let raw = document.rawValue(at: path + [entry, .key("command")]),
                      let command = try? JSONDecoder().decode(String.self, from: raw) else {
                    throw HookPlanningFailure.unsupportedShape
                }
                if command.contains(helperName) { throw HookPlanningFailure.ownershipConflict }
            }
        }
    }

    private static func matches(_ document: HookConfigurationJSON, at path: [JSONPathComponent], expected: Data) -> Bool {
        guard document.members(at: path) == [.key("command")], let raw = document.rawValue(at: path),
              let found = try? JSONDecoder().decode(Entry.self, from: raw),
              let wanted = try? JSONDecoder().decode(Entry.self, from: expected) else { return false }
        return found == wanted
    }

    /// Appends one entry per event, adding missing event arrays and the hooks object without reformatting the rest.
    private static func inserting(_ groups: [String: Data], into document: HookConfigurationJSON) throws -> Data {
        guard document.rawValue(at: [])?.first == 123 else { throw HookPlanningFailure.malformedConfiguration }
        let hooksPath: [JSONPathComponent] = [.key("hooks")]
        var edits: [(offset: Int, bytes: Data)] = []
        var additions: [String] = []
        for event in groups.keys.sorted() {
            guard let entry = groups[event] else { throw HookPlanningFailure.unsupportedShape }
            let text = String(decoding: entry, as: UTF8.self)
            let path = hooksPath + [.key(event)]
            if let range = document.range(at: path), let members = document.members(at: path) {
                edits.append((range.upperBound - 1, Data(((members.isEmpty ? "" : ",") + text).utf8)))
            } else {
                additions.append(String(decoding: try JSONEncoder().encode(event), as: UTF8.self) + ":[" + text + "]")
            }
        }
        if let hooks = document.range(at: hooksPath), let members = document.members(at: hooksPath) {
            if !additions.isEmpty {
                edits.append((hooks.upperBound - 1, Data(((members.isEmpty ? "" : ",") + additions.joined(separator: ",")).utf8)))
            }
        } else {
            guard let root = document.range(at: []), let members = document.members(at: []) else {
                throw HookPlanningFailure.malformedConfiguration
            }
            edits.append((root.upperBound - 1,
                          Data(((members.isEmpty ? "" : ",") + "\"hooks\":{" + additions.joined(separator: ",") + "}").utf8)))
        }
        let growth = edits.reduce(0) { $0 + $1.bytes.count }
        guard document.data.count + growth <= HookEnvelopeV1.rawHookLimit else { throw HookPlanningFailure.resourceLimit }
        var candidate = document.data
        for edit in edits.sorted(by: { $0.offset > $1.offset }) { candidate.insert(contentsOf: edit.bytes, at: edit.offset) }
        _ = try HookConfigurationJSON(data: candidate)
        return candidate
    }
}
