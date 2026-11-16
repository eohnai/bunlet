import Foundation
import Testing
@testable import AgentActions
import EventBridge

struct AllowAlwaysTests {
    private func raw(suggestions: String?) -> Data {
        let extra = suggestions.map { ",\"permission_suggestions\":\($0)" } ?? ""
        return Data("""
        {"session_id":"s1","prompt_id":"p1","hook_event_name":"PermissionRequest","tool_name":"Bash",
         "tool_use_id":"t1","tool_input":{"command":"ls"}\(extra)}
        """.utf8)
    }

    private let now: Int64 = 1_000_000

    @Test func offerKeepsSuggestionsOnlyWhenWellFormed() throws {
        let good = try #require(try ClaudeHookActionAdapter.offer(
            raw: raw(suggestions: "[{\"type\":\"addRules\",\"behavior\":\"allow\"}]"), nowMs: now))
        #expect(good.canAllowAlways)
        let none = try #require(try ClaudeHookActionAdapter.offer(raw: raw(suggestions: nil), nowMs: now))
        #expect(!none.canAllowAlways)
        let notArray = try #require(try ClaudeHookActionAdapter.offer(raw: raw(suggestions: "{\"x\":1}"), nowMs: now))
        #expect(!notArray.canAllowAlways)
    }

    @Test func allowAlwaysIsRefusedWithoutSuggestions() throws {
        let offer = try #require(try ClaudeHookActionAdapter.offer(raw: raw(suggestions: nil), nowMs: now))
        let decision = ActionDecision(requestID: offer.id, choice: .allowAlways)
        #expect(!ActionProtocol.valid(decision, for: offer))
    }

    @Test func allowAlwaysEchoesSuggestionsToClaude() throws {
        let offer = try #require(try ClaudeHookActionAdapter.offer(
            raw: raw(suggestions: "[{\"type\":\"addRules\",\"behavior\":\"allow\"}]"), nowMs: now))
        let decision = ActionDecision(requestID: offer.id, choice: .allowAlways)
        let output = try #require(try ClaudeHookActionAdapter.providerOutput(for: decision, offer: offer))
        let object = try #require(JSONSerialization.jsonObject(with: output) as? [String: Any])
        let hook = try #require(object["hookSpecificOutput"] as? [String: Any])
        let value = try #require(hook["decision"] as? [String: Any])
        #expect(value["behavior"] as? String == "allow")
        #expect((value["updatedPermissions"] as? [Any])?.count == 1)
    }

    @Test func allowOnceSendsNoPermissionUpdate() throws {
        let offer = try #require(try ClaudeHookActionAdapter.offer(
            raw: raw(suggestions: "[{\"type\":\"addRules\"}]"), nowMs: now))
        let decision = ActionDecision(requestID: offer.id, choice: .approveOnce)
        let output = try #require(try ClaudeHookActionAdapter.providerOutput(for: decision, offer: offer))
        let text = String(decoding: output, as: UTF8.self)
        #expect(!text.contains("updatedPermissions"))
    }
}
