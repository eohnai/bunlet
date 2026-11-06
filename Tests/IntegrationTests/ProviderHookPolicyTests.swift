import EventBridge
import Integration
import Testing

/// Decision 0019: the documented version or newer, within the same major version.
struct ProviderHookPolicyTests {
    @Test(arguments: [
        (Agent.claude, "2.1.306"), (.claude, "2.1.319"), (.claude, "2.2.0"), (.claude, "2.10.0"),
        (.codex, "0.164.0"), (.codex, "0.166.0"), (.codex, "0.200.3")
    ])
    func acceptsDocumentedOrNewerSameMajor(agent: Agent, version: String) {
        #expect(ProviderHookPolicy.supportsDocumented(version, agent: agent))
    }

    @Test(arguments: [
        (Agent.claude, "2.1.305"), (.claude, "2.0.999"), (.claude, "1.9.0"), (.claude, "3.0.0"),
        (.codex, "0.163.9"), (.codex, "1.0.0"),
        (.claude, "2.1"), (.claude, "2.1.319-beta"), (.codex, "0.x.0"), (.codex, ""),
        (.claude, "2.1.99999999999999999999")
    ])
    func rejectsOlderOtherMajorOrMalformed(agent: Agent, version: String) {
        #expect(!ProviderHookPolicy.supportsDocumented(version, agent: agent))
    }
}
