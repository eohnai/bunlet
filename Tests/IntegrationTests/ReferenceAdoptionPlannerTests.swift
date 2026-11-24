import EventBridge
import Foundation
import Testing
@testable import Integration

/// Decision 0025 setup planning: Codex approvals, the Claude subagent upgrade and Cursor's hooks.json. Pure bytes only.
struct ReferenceAdoptionPlannerTests {
    private func target(_ helper: String = "NotchPetHook", file: String = "hooks.json") -> HookSetupTarget {
        HookSetupTarget(configurationPath: "/Users/fictional/.agent/\(file)", parentDevice: 1, parentInode: 1,
                        helperPath: "/Applications/Bunlet.app/Contents/MacOS/\(helper)")
    }

    private func input(_ agent: Agent, version: String, configuration: Data?, ownership: Data? = nil,
                       helper: String = "NotchPetHook", id: UUID = UUID()) -> HookSetupInput {
        HookSetupInput(agent: agent, configuration: configuration, ownership: ownership,
                       target: target(helper, file: agent.hookConfigurationName),
                       support: .documented(version: version, helperAvailable: true), installationID: id)
    }

    private func object(_ data: Data) throws -> [String: Any] {
        try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    // MARK: Codex approvals

    @Test func codexApprovalHookIsPermissionRequestOnly() throws {
        #expect(HookSetupPlanner.events(agent: .codex, interactive: true) == ["PermissionRequest"])
        #expect(HookSetupPlanner.events(agent: .claude, interactive: true) == ["PermissionRequest", "PreToolUse", "Stop"])
        let plan = HookSetupPlanner.plan(input(.codex, version: "0.164.0", configuration: Data("{}".utf8),
                                               helper: "NotchPetActionHook"), interactive: true)
        guard case .update(let configuration, _) = plan else { Issue.record("expected an update, got \(plan)"); return }
        let hooks = try #require(try object(configuration)["hooks"] as? [String: Any])
        #expect(Set(hooks.keys) == ["PermissionRequest"])
        #expect(String(decoding: configuration, as: UTF8.self).contains("NotchPetActionHook' --agent codex"))
        #expect(ProviderSetupScope.claudeActions.applies(to: .codex))
        #expect(!ProviderSetupScope.claudeActions.applies(to: .cursor) && !ProviderSetupScope.claudeQuota.applies(to: .codex))
    }

    // MARK: Claude upgrade

    @Test func ownedClaudeHooksFromTheSevenEventSetUpgradeInPlace() throws {
        let id = UUID()
        let current = try HookSetupPlanner.definitions(target().helperPath, agent: .claude, interactive: false)
        #expect(current.count == 10)
        let legacy = current.filter { HookEvent.core.map(\.rawValue).contains($0.key) }
        let user = #"{"model":"fictional","hooks":{"Stop":[{"hooks":[{"type":"command","command":"say done","timeout":5}]}]}}"#
        let installed = try HookGroupEdits.initialConfiguration(Data(user.utf8), groups: legacy, helperName: "NotchPetHook")
        let ownership = try JSONEncoder().encode(HookSetupOwnership(version: 1, agent: .claude, installationID: id,
            target: target(file: "settings.json"), groups: legacy, createdConfiguration: false, createdHooksContainer: false,
            createdEvents: legacy.keys.filter { $0 != "Stop" }.sorted()))

        let plan = HookSetupPlanner.plan(input(.claude, version: "2.1.306", configuration: installed, ownership: ownership, id: id))
        guard case .update(let upgraded, let nextOwnership) = plan else { Issue.record("expected an upgrade, got \(plan)"); return }
        let hooks = try #require(try object(upgraded)["hooks"] as? [String: Any])
        #expect(hooks["SubagentStart"] != nil && hooks["SubagentStop"] != nil)
        #expect(String(decoding: upgraded, as: UTF8.self).contains("say done"))
        #expect(try object(upgraded)["model"] as? String == "fictional")
        let owner = try JSONDecoder().decode(HookSetupOwnership.self, from: nextOwnership)
        #expect(owner.groups == current && owner.installationID == id)

        // A second launch changes nothing, and removal restores only the user's own entries.
        #expect(HookSetupPlanner.plan(input(.claude, version: "2.1.306", configuration: upgraded,
                                            ownership: nextOwnership, id: id)) == .unchanged)
        guard case .update(let removed, _) = HookSetupPlanner.remove(configuration: upgraded, ownership: nextOwnership,
                                                                    target: target(file: "settings.json"), agent: .claude)
        else { Issue.record("expected removal"); return }
        #expect(!String(decoding: removed, as: UTF8.self).contains("NotchPetHook"))
        #expect(String(decoding: removed, as: UTF8.self).contains("say done"))
    }

    // MARK: Cursor

    @Test func cursorHooksAreAddedAsPlainEntriesAndRemovedExactly() throws {
        let id = UUID()
        let user = Data(#"{"version":1,"hooks":{"stop":[{"command":"afplay /System/Library/Sounds/Glass.aiff"}]}}"#.utf8)
        let plan = CursorHookPlanner.plan(input(.cursor, version: "2026.09.18-9a7762b", configuration: user, id: id))
        guard case .update(let installed, let ownership) = plan else { Issue.record("expected an update, got \(plan)"); return }
        let hooks = try #require(try object(installed)["hooks"] as? [String: [[String: Any]]])
        #expect(Set(hooks.keys) == Set(CursorEventAdapter.events.keys))
        #expect(hooks["stop"]?.count == 2 && hooks["stop"]?.first?["command"] as? String == "afplay /System/Library/Sounds/Glass.aiff")
        #expect(hooks["sessionStart"]?.first?["command"] as? String == "'/Applications/Bunlet.app/Contents/MacOS/NotchPetHook' --agent cursor")

        #expect(CursorHookPlanner.plan(input(.cursor, version: "2026.09.18-9a7762b", configuration: installed,
                                             ownership: ownership, id: id)) == .unchanged)
        guard case .update(let removed, _) = CursorHookPlanner.remove(configuration: installed, ownership: ownership,
                                                                     target: target())
        else { Issue.record("expected removal"); return }
        #expect(try object(removed) as NSDictionary == (try object(user)) as NSDictionary)
    }

    @Test func cursorNewFileGetsAVersionAndLookalikesConflict() throws {
        guard case .update(let created, _) = CursorHookPlanner.plan(input(.cursor, version: "2026.09.18-9a7762b", configuration: nil))
        else { Issue.record("expected a new file"); return }
        #expect(try object(created)["version"] as? Int == 1)

        let lookalike = Data(#"{"version":1,"hooks":{"stop":[{"command":"/old/NotchPetHook --agent cursor"}]}}"#.utf8)
        #expect(CursorHookPlanner.plan(input(.cursor, version: "2026.09.18-9a7762b", configuration: lookalike))
                == .conflict(.ownershipConflict))
        let wrongShape = Data(#"{"hooks":{"stop":"not-a-list"}}"#.utf8)
        #expect(CursorHookPlanner.plan(input(.cursor, version: "2026.09.18-9a7762b", configuration: wrongShape))
                == .conflict(.unsupportedShape))
        #expect(CursorHookPlanner.plan(input(.cursor, version: "2026.10.1-0000000", configuration: nil))
                == .unavailable(.unsupportedVersion))
    }
}
