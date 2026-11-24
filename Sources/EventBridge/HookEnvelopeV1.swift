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
    /// Display-only preview of the submitted prompt (decision 0019). Present only on UserPromptSubmit.
    public let promptPreview: String?
    /// Display-only preview of the agent's last reply (decision 0019). Present only on Stop.
    public let replyPreview: String?
    /// The subagent's identifier (decision 0025). Present only on SubagentStart and SubagentStop.
    public var agentID: String? = nil

    /// Where the agent runs, reported by the hook's own environment (decision 0025). A hint, never proof of a pane.
    public struct Terminal: Encodable, Equatable, Sendable {
        public enum Kind: String, Encodable, Sendable {
            /// `pane_selector` is Otty's `OTTY_PANE_ID`.
            case otty
            /// `pane_selector` is `TMUX_PANE` (`%N`); `socket` is the server socket; `app` is the outer terminal.
            case tmux
            /// `pane_selector` is the tab's tty, such as `/dev/ttys003`.
            case appleTerminal = "apple_terminal"
            /// `pane_selector` is the session's unique id from `ITERM_SESSION_ID` (decision 0026).
            case iterm
            /// `pane_selector` is `WEZTERM_PANE`, a number.
            case wezterm
            /// `pane_selector` is `KITTY_WINDOW_ID`, a number; `socket` is the path from `KITTY_LISTEN_ON`.
            case kitty
            /// `pane_selector` is the editor's bundle identifier; navigation opens the project folder in it.
            case editor
            /// `pane_selector` is the bundle identifier of the app the agent runs in; only the app is known.
            case app

            /// The app that shows this kind of terminal, when the kind alone names it.
            public var bundleIdentifier: String? {
                switch self {
                case .otty: "io.appmakes.otty"
                case .appleTerminal: "com.apple.Terminal"
                case .iterm: "com.googlecode.iterm2"
                case .wezterm: "com.github.wez.wezterm"
                case .kitty: "net.kovidgoyal.kitty"
                case .tmux, .editor, .app: nil
                }
            }
        }
        public let kind: Kind
        public let paneSelector: String
        public let socket: String?
        public let app: String?

        public init(kind: Kind, paneSelector: String, socket: String? = nil, app: String? = nil) {
            self.kind = kind
            self.paneSelector = paneSelector
            self.socket = socket
            self.app = app
        }

        enum CodingKeys: String, CodingKey {
            case kind, socket, app
            case paneSelector = "pane_selector"
        }

        public static let socketLimit = 1_024
        public static let bundleLimit = 128

        /// Each kind accepts only its own selector shape, so a hint can never name a different kind of target.
        public var isValid: Bool {
            if let app, !Self.bundleIdentifier(app) { return false }
            switch kind {
            case .otty:
                return socket == nil && app == nil && HookEnvelopeV1.validString(paneSelector, limit: 256)
            case .tmux:
                guard let socket, Self.socketPath(socket), paneSelector.hasPrefix("%") else { return false }
                return Self.digits(paneSelector.dropFirst())
            case .appleTerminal:
                guard socket == nil, app == nil, paneSelector.hasPrefix("/dev/ttys") else { return false }
                let digits = paneSelector.dropFirst("/dev/ttys".count)
                return (1...4).contains(digits.count) && digits.allSatisfy { $0.isASCII && $0.isNumber }
            case .iterm:
                return socket == nil && app == nil && UUID(uuidString: paneSelector) != nil && paneSelector.utf8.count == 36
            case .wezterm:
                return socket == nil && app == nil && Self.digits(Substring(paneSelector))
            case .kitty:
                guard let socket, Self.socketPath(socket), app == nil else { return false }
                return Self.digits(Substring(paneSelector))
            case .editor, .app:
                return socket == nil && app == nil && Self.bundleIdentifier(paneSelector)
            }
        }

        /// The app to bring forward when the exact pane cannot be selected.
        public var hostApp: String? {
            switch kind {
            case .tmux: app
            case .editor, .app: paneSelector
            default: kind.bundleIdentifier
            }
        }

        private static func digits(_ value: Substring) -> Bool {
            (1...9).contains(value.count) && value.allSatisfy { $0.isASCII && $0.isNumber }
        }

        private static func socketPath(_ value: String) -> Bool {
            value.hasPrefix("/") && HookEnvelopeV1.validString(value, limit: socketLimit)
        }

        static func bundleIdentifier(_ value: String) -> Bool {
            !value.isEmpty && value.utf8.count <= bundleLimit && value.contains(".") && value.unicodeScalars.allSatisfy {
                ("a"..."z").contains($0) || ("A"..."Z").contains($0) || ("0"..."9").contains($0) || $0 == "." || $0 == "-"
            }
        }
    }

    enum CodingKeys: String, CodingKey {
        case version, agent, cwd, terminal
        case eventID = "event_id", sessionID = "session_id"
        case hookEventName = "hook_event_name", observedAtMs = "observed_at_ms"
        case turnID = "turn_id", toolUseID = "tool_use_id", toolName = "tool_name"
        case promptPreview = "prompt_preview", replyPreview = "reply_preview"
        case agentID = "agent_id"
    }

    /// Previews are cut to this many characters, then to the byte limit.
    public static let previewCharacterLimit = 200
    public static let previewByteLimit = 1_024

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
        let optional: Set<String> = ["turn_id", "tool_use_id", "tool_name", "cwd", "terminal",
                                     "prompt_preview", "reply_preview", "agent_id"]
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
        let promptPreview = try string("prompt_preview", previewByteLimit)
        let replyPreview = try string("reply_preview", previewByteLimit)
        guard promptPreview == nil || hook == .userPromptSubmit, replyPreview == nil || hook == .stop else {
            throw BridgeError.invalidMessage
        }
        // Only Claude reports failed turns (decision 0030); the other agents' hooks have no such event.
        guard hook != .stopFailure || agent == .claude else { throw BridgeError.invalidMessage }
        // Subagent events must name their subagent; no other event may carry one.
        let agentID = try string("agent_id", 256, required: hook.isSubagent)
        guard agentID == nil || hook.isSubagent else { throw BridgeError.invalidMessage }
        let cwd = try string("cwd", 4096)
        if let cwd, !cwd.hasPrefix("/") { throw BridgeError.invalidMessage }
        var terminal: Terminal?
        if let value = fields["terminal"] {
            guard case .object(let fields) = value,
                  Set(fields.keys).isSuperset(of: ["kind", "pane_selector"]),
                  Set(fields.keys).isSubset(of: ["kind", "pane_selector", "socket", "app"]),
                  let kind = fields["kind"]?.string.flatMap(Terminal.Kind.init(rawValue:)),
                  let selector = fields["pane_selector"]?.string else { throw BridgeError.invalidMessage }
            func optional(_ name: String) throws -> String? {
                guard let value = fields[name] else { return nil }
                guard let text = value.string else { throw BridgeError.invalidMessage }
                return text
            }
            let candidate = Terminal(kind: kind, paneSelector: selector, socket: try optional("socket"), app: try optional("app"))
            guard candidate.isValid else { throw BridgeError.invalidMessage }
            terminal = candidate
        }
        return Self(version: 1, eventID: eventID, agent: agent, sessionID: session,
                    hookEventName: hook, observedAtMs: timestamp, turnID: turn,
                    toolUseID: toolID, toolName: tool, cwd: cwd, terminal: terminal,
                    promptPreview: promptPreview, replyPreview: replyPreview, agentID: agentID)
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
        try project(rawHook: rawHook, agent: agent, terminal: ottyTerminal(paneSelector), deadline: nil)
    }

    public static func project(rawHook: Data, agent: Agent, terminal: Terminal?) throws -> Self {
        try project(rawHook: rawHook, agent: agent, terminal: terminal, deadline: nil)
    }

    static func project(rawHook: Data, agent: Agent, paneSelector: String?, deadline: UInt64?) throws -> Self {
        try project(rawHook: rawHook, agent: agent, terminal: ottyTerminal(paneSelector), deadline: deadline)
    }

    static func project(rawHook: Data, agent: Agent, terminal: Terminal?, deadline: UInt64?) throws -> Self {
        switch agent {
        case .codex:
            return try CodexEventAdapter.project(rawHook: rawHook, terminal: terminal, deadline: deadline)
        case .claude:
            return try ClaudeEventAdapter.project(rawHook: rawHook, terminal: terminal, deadline: deadline)
        case .cursor:
            return try CursorEventAdapter.project(rawHook: rawHook, terminal: terminal, deadline: deadline)
        }
    }

    static func ottyTerminal(_ paneSelector: String?) -> Terminal? {
        paneSelector.map { Terminal(kind: .otty, paneSelector: $0) }
    }

    static func rawFields(_ rawHook: Data, deadline: UInt64?) throws -> [String: JSONValue] {
        guard rawHook.count <= rawHookLimit else { throw BridgeError.invalidMessage }
        var parser = StrictJSON(data: rawHook, maxDepth: 64, deadline: deadline)
        guard case .object(let source) = try parser.parse() else { throw BridgeError.invalidMessage }
        return source
    }

    static func projected(_ sourceFields: [String: JSONValue], agent: Agent, observedAtMs: Int64,
                          terminal: Terminal?) throws -> Self {
        var fields = sourceFields
        fields["version"] = .number("1")
        fields["event_id"] = .string(UUID().uuidString.lowercased())
        fields["agent"] = .string(agent.rawValue)
        fields["observed_at_ms"] = .number(String(observedAtMs))
        if let terminal {
            var object: [String: JSONValue] = ["kind": .string(terminal.kind.rawValue),
                                               "pane_selector": .string(terminal.paneSelector)]
            if let socket = terminal.socket { object["socket"] = .string(socket) }
            if let app = terminal.app { object["app"] = .string(app) }
            fields["terminal"] = .object(object)
        }
        return try validate(.object(fields))
    }

    /// Collapses whitespace, drops control and format characters, and bounds length.
    /// Returns nil for anything that is not non-empty text, so no other JSON type can pass through.
    static func preview(_ value: JSONValue?) -> JSONValue? {
        guard let text = value?.string else { return nil }
        var scalars = String.UnicodeScalarView()
        var pendingSpace = false
        for scalar in text.unicodeScalars {
            let category = scalar.properties.generalCategory
            if scalar.properties.isWhitespace || category == .control {
                pendingSpace = !scalars.isEmpty
                continue
            }
            if category == .surrogate || category == .format { continue }
            if pendingSpace { scalars.append(" ") }
            pendingSpace = false
            scalars.append(scalar)
        }
        var preview = String(scalars)
        guard !preview.isEmpty else { return nil }
        if preview.count > previewCharacterLimit {
            preview = String(preview.prefix(previewCharacterLimit - 1)) + "…"
        }
        while preview.utf8.count > previewByteLimit {
            preview = String(preview.dropLast(2)) + "…"
        }
        return .string(preview)
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
    private let captureRanges: Bool
    private var offset = 0
    private var path: [JSONPathComponent] = []
    private(set) var ranges: [[JSONPathComponent]: Range<Int>] = [:]
    private(set) var childMembers: [[JSONPathComponent]: [JSONPathComponent]] = [:]
    private let decoder = JSONDecoder()

    init(data: Data, maxDepth: Int, deadline: UInt64? = nil, captureRanges: Bool = false) {
        bytes = Array(data)
        self.maxDepth = maxDepth
        self.deadline = deadline
        self.captureRanges = captureRanges
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
        let startOfValue = offset
        defer {
            if captureRanges { ranges[path] = startOfValue..<offset }
        }
        if bytes[offset] == 34 { return .string(try text()) }
        if try consume(123) {
            guard depth < maxDepth else { throw BridgeError.invalidMessage }
            if captureRanges { childMembers[path] = [] }
            var fields: [String: JSONValue] = [:]
            if try consume(125) { return .object(fields) }
            repeat {
                let key = try text()
                guard fields[key] == nil, try consume(58) else { throw BridgeError.invalidMessage }
                if captureRanges {
                    childMembers[path, default: []].append(.key(key))
                    path.append(.key(key))
                }
                fields[key] = try value(depth: depth + 1)
                if captureRanges { path.removeLast() }
                if try consume(125) { return .object(fields) }
            } while try consume(44)
            throw BridgeError.invalidMessage
        }
        if try consume(91) {
            guard depth < maxDepth else { throw BridgeError.invalidMessage }
            if captureRanges { childMembers[path] = [] }
            var values: [JSONValue] = []
            if try consume(93) { return .array(values) }
            repeat {
                if captureRanges {
                    childMembers[path, default: []].append(.index(values.count))
                    path.append(.index(values.count))
                }
                values.append(try value(depth: depth + 1))
                if captureRanges { path.removeLast() }
                if try consume(93) { return .array(values) }
            } while try consume(44)
            throw BridgeError.invalidMessage
        }
        let start = offset
        while offset < bytes.count && ![9, 10, 13, 32, 44, 93, 125].contains(bytes[offset]) {
            if offset % 1024 == 0 { try checkDeadline(deadline) }
            offset += 1
        }
        let token = String(decoding: bytes[start..<offset], as: UTF8.self)
        if token == "true" || token == "false" { return .bool }
        if token == "null" { return .null }
        // Setup scans preserve arbitrary valid numeric lexemes without a floating-point conversion.
        if captureRanges {
            guard Self.isJSONNumber(Array(token.utf8)) else { throw BridgeError.invalidMessage }
            return .number(token)
        }
        // Retain the observer's existing finite-number boundary.
        guard !token.isEmpty, let number = Double(token), number.isFinite,
              (try? decoder.decode(Double.self, from: Data(token.utf8))) != nil else {
            throw BridgeError.invalidMessage
        }
        return .number(token)
    }

    private static func isJSONNumber(_ bytes: [UInt8]) -> Bool {
        var index = 0
        if index < bytes.count, bytes[index] == 45 { index += 1 }
        guard index < bytes.count else { return false }
        if bytes[index] == 48 {
            index += 1
        } else {
            guard (49...57).contains(bytes[index]) else { return false }
            repeat { index += 1 } while index < bytes.count && (48...57).contains(bytes[index])
        }
        if index < bytes.count, bytes[index] == 46 {
            index += 1
            let start = index
            while index < bytes.count && (48...57).contains(bytes[index]) { index += 1 }
            guard index > start else { return false }
        }
        if index < bytes.count, bytes[index] == 69 || bytes[index] == 101 {
            index += 1
            if index < bytes.count, bytes[index] == 43 || bytes[index] == 45 { index += 1 }
            let start = index
            while index < bytes.count && (48...57).contains(bytes[index]) { index += 1 }
            guard index > start else { return false }
        }
        return index == bytes.count
    }
}
