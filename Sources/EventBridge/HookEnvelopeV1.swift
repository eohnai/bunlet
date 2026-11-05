import Foundation

public enum BridgeError: Error {
    case invalidMessage, timeout, unavailable, unsafeEndpoint
}

/// The wire contract. Provider projection and shared session meanings are separate concerns.
public struct HookEnvelopeV1: Encodable, Sendable {
    public let version: Int
    public let eventID: String
    public let agent: Agent
    public let sessionID: String
    public let hookEventName: HookEvent
    public let observedAtMs: Int64
    public let turnID: String?
    public let toolUseID: String?
    public let toolName: String?
    public let cwd: String?
    public let terminal: Terminal?

    public struct Terminal: Encodable, Sendable {
        public let kind: String
        public let paneSelector: String
        enum CodingKeys: String, CodingKey {
            case kind
            case paneSelector = "pane_selector"
        }
    }

    enum CodingKeys: String, CodingKey {
        case version, agent, cwd, terminal
        case eventID = "event_id", sessionID = "session_id"
        case hookEventName = "hook_event_name", observedAtMs = "observed_at_ms"
        case turnID = "turn_id", toolUseID = "tool_use_id", toolName = "tool_name"
    }

    public static let frameLimit = 16_384
    public static let rawHookLimit = 262_144

    public static func decode(frame: Data) throws -> Self {
        guard frame.count <= frameLimit, frame.last == 10,
              !frame.dropLast().contains(10) else { throw BridgeError.invalidMessage }
        var parser = StrictJSON(data: Data(frame.dropLast()), maxDepth: 2)
        return try validate(parser.parse())
    }

    private static func validate(_ value: JSONValue) throws -> Self {
        guard case .object(let fields) = value else { throw BridgeError.invalidMessage }
        let required: Set<String> = ["version", "event_id", "agent", "session_id", "hook_event_name", "observed_at_ms"]
        let optional: Set<String> = ["turn_id", "tool_use_id", "tool_name", "cwd", "terminal"]
        guard required.isSubset(of: Set(fields.keys)),
              Set(fields.keys).isSubset(of: required.union(optional)),
              fields["version"]?.integer == 1,
              let eventID = fields["event_id"]?.string,
              UUID(uuidString: eventID)?.uuidString.lowercased() == eventID,
              eventID.utf8.count == 36,
              let agentName = fields["agent"]?.string, let agent = Agent(rawValue: agentName),
              let hookName = fields["hook_event_name"]?.string, let hook = HookEvent(rawValue: hookName),
              let timestamp = fields["observed_at_ms"]?.integer,
              (0...9_007_199_254_740_991).contains(timestamp)
        else { throw BridgeError.invalidMessage }

        func string(_ name: String, _ limit: Int, required: Bool = false) throws -> String? {
            guard let value = fields[name] else {
                if required { throw BridgeError.invalidMessage }
                return nil
            }
            guard let text = value.string, validString(text, limit: limit) else {
                throw BridgeError.invalidMessage
            }
            return text
        }
        guard let session = try string("session_id", 256, required: true) else {
            throw BridgeError.invalidMessage
        }
        let turn = try string("turn_id", 256)
        let toolID = try string("tool_use_id", 256)
        let tool = try string("tool_name", 128, required: hook.requiresToolName)
        guard hook.requiresToolName || (toolID == nil && tool == nil) else {
            throw BridgeError.invalidMessage
        }
        let cwd = try string("cwd", 4096)
        if let cwd, !cwd.hasPrefix("/") { throw BridgeError.invalidMessage }
        var terminal: Terminal?
        if let value = fields["terminal"] {
            guard case .object(let fields) = value,
                  Set(fields.keys) == ["kind", "pane_selector"],
                  fields["kind"]?.string == "otty",
                  let selector = fields["pane_selector"]?.string,
                  validString(selector, limit: 256) else { throw BridgeError.invalidMessage }
            terminal = Terminal(kind: "otty", paneSelector: selector)
        }
        return Self(version: 1, eventID: eventID, agent: agent, sessionID: session,
                    hookEventName: hook, observedAtMs: timestamp, turnID: turn,
                    toolUseID: toolID, toolName: tool, cwd: cwd, terminal: terminal)
    }

    public func frame() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        var data = try encoder.encode(self)
        data.append(10)
        guard data.count <= Self.frameLimit else { throw BridgeError.invalidMessage }
        return data
    }

    /// Only projects allowlisted fields. Never reads transcripts or invokes an agent.
    public static func project(rawHook: Data, agent: Agent, paneSelector: String? = nil) throws -> Self {
        try project(rawHook: rawHook, agent: agent, paneSelector: paneSelector, deadline: nil)
    }

    static func project(rawHook: Data, agent: Agent, paneSelector: String?, deadline: UInt64?) throws -> Self {
        switch agent {
        case .codex:
            return try CodexEventAdapter.project(rawHook: rawHook, paneSelector: paneSelector, deadline: deadline)
        case .claude:
            return try ClaudeEventAdapter.project(rawHook: rawHook, paneSelector: paneSelector, deadline: deadline)
        }
    }

    static func rawFields(_ rawHook: Data, deadline: UInt64?) throws -> [String: JSONValue] {
        guard rawHook.count <= rawHookLimit else { throw BridgeError.invalidMessage }
        var parser = StrictJSON(data: rawHook, maxDepth: 64, deadline: deadline)
        guard case .object(let source) = try parser.parse() else { throw BridgeError.invalidMessage }
        return source
    }

    static func projected(_ sourceFields: [String: JSONValue], agent: Agent, observedAtMs: Int64,
                          paneSelector: String?) throws -> Self {
        var fields = sourceFields
        fields["version"] = .number("1")
        fields["event_id"] = .string(UUID().uuidString.lowercased())
        fields["agent"] = .string(agent.rawValue)
        fields["observed_at_ms"] = .number(String(observedAtMs))
        if let paneSelector {
            fields["terminal"] = .object(["kind": .string("otty"), "pane_selector": .string(paneSelector)])
        }
        return try validate(.object(fields))
    }

    static func validString(_ text: String, limit: Int) -> Bool {
        !text.isEmpty && text.utf8.count <= limit && !text.unicodeScalars.contains {
            $0.properties.generalCategory == .control || $0.properties.generalCategory == .surrogate
        }
    }
}

indirect enum JSONValue {
    case object([String: JSONValue]), array([JSONValue]), string(String), number(String), bool, null
    var string: String? { if case .string(let text) = self { return text }; return nil }
    var integer: Int64? {
        guard case .number(let text) = self, !text.contains(where: { ".eE".contains($0) }) else { return nil }
        return Int64(text)
    }
}

/// Checks keys before building dictionaries. JSONDecoder alone discards duplicates.
struct StrictJSON {
    private let bytes: [UInt8]
    private let maxDepth: Int
    private let deadline: UInt64?
    private var offset = 0
    private let decoder = JSONDecoder()

    init(data: Data, maxDepth: Int, deadline: UInt64? = nil) {
        bytes = Array(data)
        self.maxDepth = maxDepth
        self.deadline = deadline
    }

    mutating func parse() throws -> JSONValue {
        guard String(bytes: bytes, encoding: .utf8) != nil else { throw BridgeError.invalidMessage }
        let result = try value(depth: 0)
        try whitespace()
        try checkDeadline(deadline)
        guard offset == bytes.count else { throw BridgeError.invalidMessage }
        return result
    }

    private mutating func whitespace() throws {
        while offset < bytes.count {
            switch bytes[offset] {
            case 9, 10, 13, 32:
                // Avoid rebuilding and searching an array for every padding byte.
                if offset % 1024 == 0 { try checkDeadline(deadline) }
                offset += 1
            default: return
            }
        }
    }

    private mutating func consume(_ byte: UInt8) throws -> Bool {
        try whitespace()
        guard offset < bytes.count && bytes[offset] == byte else { return false }
        offset += 1
        return true
    }

    private mutating func text() throws -> String {
        try whitespace()
        let start = offset
        guard try consume(34) else { throw BridgeError.invalidMessage }
        while offset < bytes.count {
            if offset % 1024 == 0 { try checkDeadline(deadline) }
            let byte = bytes[offset]
            offset += 1
            if byte == 34 { return try decoder.decode(String.self, from: Data(bytes[start..<offset])) }
            if byte == 92 { offset += 1 }
        }
        throw BridgeError.invalidMessage
    }

    private mutating func value(depth: Int) throws -> JSONValue {
        try checkDeadline(deadline)
        try whitespace()
        guard offset < bytes.count else { throw BridgeError.invalidMessage }
        if bytes[offset] == 34 { return .string(try text()) }
        if try consume(123) {
            guard depth < maxDepth else { throw BridgeError.invalidMessage }
            var fields: [String: JSONValue] = [:]
            if try consume(125) { return .object(fields) }
            repeat {
                let key = try text()
                guard fields[key] == nil, try consume(58) else { throw BridgeError.invalidMessage }
                fields[key] = try value(depth: depth + 1)
                if try consume(125) { return .object(fields) }
            } while try consume(44)
            throw BridgeError.invalidMessage
        }
        if try consume(91) {
            guard depth < maxDepth else { throw BridgeError.invalidMessage }
            var values: [JSONValue] = []
            if try consume(93) { return .array(values) }
            repeat {
                values.append(try value(depth: depth + 1))
                if try consume(93) { return .array(values) }
            } while try consume(44)
            throw BridgeError.invalidMessage
        }
        let start = offset
        while offset < bytes.count && ![9, 10, 13, 32, 44, 93, 125].contains(bytes[offset]) { offset += 1 }
        let token = String(decoding: bytes[start..<offset], as: UTF8.self)
        if token == "true" || token == "false" { return .bool }
        if token == "null" { return .null }
        // Foundation checks JSON number syntax; preserve the lexeme to distinguish 1 from 1.0.
        guard !token.isEmpty, let number = Double(token), number.isFinite,
              (try? decoder.decode(Double.self, from: Data(token.utf8))) != nil else {
            throw BridgeError.invalidMessage
        }
        return .number(token)
    }
}
