import EventBridge
import Foundation

/// Codex `PermissionRequest` only (decision 0025): Allow once or Deny, in the reply shape Codex shares with Claude.
/// Holds no provider process and reads no transcript. Codex has no Always allow, questions or follow-ups here.
public enum CodexHookActionAdapter {
    public static func offer(raw: Data, nowMs: Int64) throws -> ActionOffer? {
        let document = try HookConfigurationJSON(data: raw)
        func string(_ name: String) -> String? {
            document.rawValue(at: [.key(name)]).flatMap { try? JSONDecoder().decode(String.self, from: $0) }
        }
        guard string("hook_event_name") == "PermissionRequest",
              let session = string("session_id"), let turn = string("turn_id"),
              let tool = string("tool_name"),
              // Requests Codex would not ask about in its own terminal are left to Codex.
              string("permission_mode") != "bypassPermissions",
              let input = document.rawValue(at: [.key("tool_input")]), input.first == 123,
              input.count <= ActionProtocol.inputLimit else { return nil }
        let result = ActionOffer(version: 1, id: UUID(), provider: .codex, sessionID: session, turnID: turn,
            toolUseID: string("tool_use_id"), toolName: tool, kind: .permission, capturedAtMs: nowMs,
            input: input, questions: [])
        return ActionProtocol.valid(result, nowMs: nowMs) ? result : nil
    }

    public static func providerOutput(for decision: ActionDecision, offer: ActionOffer) throws -> Data? {
        guard offer.provider == .codex, ActionProtocol.valid(decision, for: offer) else { throw BridgeError.invalidMessage }
        let value: [String: Any]
        switch decision.choice {
        case .cancel: return nil
        case .approveOnce: value = ["behavior": "allow"]
        case .deny: value = ["behavior": "deny", "message": "Denied by the user in Bunlet."]
        case .allowAlways, .answer, .followUp: throw BridgeError.invalidMessage
        }
        let object: [String: Any] = ["hookSpecificOutput": ["hookEventName": "PermissionRequest", "decision": value]]
        var data = try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
        data.append(10)
        guard data.count <= ActionSocketIO.frameLimit else { throw BridgeError.invalidMessage }
        return data
    }

    public static func run(endpoint: BridgeEndpoint = .standard) {
        ActionHookRunner.run(endpoint: endpoint, offer: offer(raw:nowMs:), output: providerOutput(for:offer:))
    }
}

/// The one exchange every action helper performs: offer, wait for one decision, write the provider's reply.
/// Silent fallback on any failure, so the agent asks in its own terminal as usual.
enum ActionHookRunner {
    static func run(endpoint: BridgeEndpoint,
                    offer makeOffer: (Data, Int64) throws -> ActionOffer?,
                    output makeOutput: (ActionDecision, ActionOffer) throws -> Data?) {
        do {
            let raw = try ActionSocketIO.readHookInput()
            guard let offer = try makeOffer(raw, Int64(Date().timeIntervalSince1970 * 1000)) else { return }
            let fd = try ActionSocketIO.connect(endpoint: endpoint)
            defer { close(fd) }
            try ActionSocketIO.write(fd, frame: ActionProtocol.frame(offer))
            let frame = try ActionSocketIO.read(fd, timeoutMs: ActionSocketIO.waitMs)
            let decision = try ActionProtocol.decode(frame, as: ActionDecision.self)
            guard let output = try makeOutput(decision, offer) else { return }
            try ActionSocketIO.writeProviderOutput(output)
            let receipt = ActionWriteReceipt(version: 1, requestID: offer.id,
                decisionID: decision.decisionID, wroteProviderOutput: true)
            try ActionSocketIO.write(fd, frame: ActionProtocol.frame(receipt))
        } catch {
            // No failure path emits a decision, diagnostic content or automatic retry.
        }
    }
}
