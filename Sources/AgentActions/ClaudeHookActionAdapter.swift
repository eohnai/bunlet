import EventBridge
import Darwin
import Foundation

/// Holds no provider process and reads no transcript. A response goes back to its own hook invocation only.
public enum ClaudeHookActionAdapter {
    public static func offer(raw: Data, nowMs: Int64) throws -> ActionOffer? {
        let document = try HookConfigurationJSON(data: raw)
        func string(_ name: String) -> String? {
            document.rawValue(at: [.key(name)]).flatMap { try? JSONDecoder().decode(String.self, from: $0) }
        }
        guard document.range(at: [.key("agent_id")]) == nil,
              let session = string("session_id"), let turn = string("prompt_id"),
              let event = string("hook_event_name") else { return nil }
        let tool = string("tool_name")
        let toolID = string("tool_use_id")
        let input = document.rawValue(at: [.key("tool_input")])
        let kind: LocalActionKind
        var questions: [ActionQuestion] = []
        switch event {
        case "PermissionRequest":
            // AskUserQuestion is handled by its PreToolUse callback, never approved as a command.
            guard tool != "AskUserQuestion", input?.first == 123 else { return nil }
            kind = .permission
        case "PreToolUse":
            guard tool == "AskUserQuestion", let input, input.count <= ActionProtocol.inputLimit else { return nil }
            questions = try ActionProtocol.questions(from: input)
            kind = .question
        case "Stop":
            guard document.rawValue(at: [.key("stop_hook_active")]) == Data("false".utf8) else { return nil }
            kind = .followUp
        default: return nil
        }
        let result = ActionOffer(version: 1, id: UUID(), provider: .claude, sessionID: session, turnID: turn,
            toolUseID: kind == .followUp ? nil : toolID, toolName: kind == .followUp ? nil : tool,
            kind: kind, capturedAtMs: nowMs, input: kind == .followUp ? nil : input, questions: questions)
        return ActionProtocol.valid(result, nowMs: nowMs) ? result : nil
    }

    public static func providerOutput(for decision: ActionDecision, offer: ActionOffer) throws -> Data? {
        guard ActionProtocol.valid(decision, for: offer) else { throw BridgeError.invalidMessage }
        if decision.choice == .cancel { return nil }
        let object: [String: Any]
        switch offer.kind {
        case .permission:
            let value: [String: Any] = decision.choice == .approveOnce
                ? ["behavior": "allow"] : ["behavior": "deny", "message": "Denied by the user in Notch Pet."]
            object = ["hookSpecificOutput": ["hookEventName": "PermissionRequest", "decision": value]]
        case .question:
            guard let input = offer.input,
                  var updated = try JSONSerialization.jsonObject(with: input) as? [String: Any] else { throw BridgeError.invalidMessage }
            updated["answers"] = Dictionary(uniqueKeysWithValues: decision.answers.map { ($0.question, $0.answer) })
            object = ["hookSpecificOutput": ["hookEventName": "PreToolUse", "permissionDecision": "allow", "updatedInput": updated]]
        case .followUp:
            guard let text = decision.text else { throw BridgeError.invalidMessage }
            object = ["decision": "block", "reason": text]
        }
        var data = try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
        data.append(10)
        guard data.count <= ActionSocketIO.frameLimit else { throw BridgeError.invalidMessage }
        return data
    }

    /// Silent fallback on any failure. A successful receipt attests only to stdout write completion.
    public static func run(endpoint: BridgeEndpoint = .standard) {
        do {
            let raw = try ActionSocketIO.readHookInput()
            guard let offer = try offer(raw: raw, nowMs: Int64(Date().timeIntervalSince1970 * 1000)) else { return }
            let fd = try ActionSocketIO.connect(endpoint: endpoint)
            defer { close(fd) }
            try ActionSocketIO.write(fd, frame: ActionProtocol.frame(offer))
            let frame = try ActionSocketIO.read(fd, timeoutMs: ActionSocketIO.waitMs)
            let decision = try ActionProtocol.decode(frame, as: ActionDecision.self)
            guard let output = try providerOutput(for: decision, offer: offer) else { return }
            try ActionSocketIO.writeProviderOutput(output)
            let receipt = ActionWriteReceipt(version: 1, requestID: offer.id,
                decisionID: decision.decisionID, wroteProviderOutput: true)
            try ActionSocketIO.write(fd, frame: ActionProtocol.frame(receipt))
        } catch {
            // No failure path emits a decision, diagnostic content or automatic retry.
        }
    }
}
