import EventBridge
import Foundation

public enum SessionRequestKind: String, Sendable {
    case questionNeeded = "question_needed"
    case approvalNeeded = "approval_needed"
}

/// Shared meanings from the accepted v1 contract, not additional provider coverage.
public enum SessionEventKind: Sendable {
    case sessionStarted, turnSubmitted, toolObserved, toolFinished, responseReady, sessionEnded
    case requestOpened(SessionRequestKind)
}

public struct SessionObservationV1: Sendable {
    public let envelope: HookEnvelopeV1
    public let receiptWallMs: Int64
    public let receiptMonotonicNs: UInt64
    public let kind: SessionEventKind

    public init(received: ReceivedHookEnvelope) {
        self.init(envelope: received.envelope, receiptWallMs: received.receiptWallMs,
                  receiptMonotonicNs: received.receiptMonotonicNs)
    }

    /// The envelope type can only be constructed through the strict bridge validator.
    public init(envelope: HookEnvelopeV1, receiptWallMs: Int64, receiptMonotonicNs: UInt64) {
        self.envelope = envelope
        self.receiptWallMs = receiptWallMs
        self.receiptMonotonicNs = receiptMonotonicNs
        let questionTool = envelope.agent == "codex" ? "request_user_input" : "AskUserQuestion"
        let isQuestion = envelope.toolName == questionTool
        switch envelope.hookEventName {
        case "SessionStart": kind = .sessionStarted
        case "UserPromptSubmit": kind = .turnSubmitted
        case "PreToolUse": kind = isQuestion ? .requestOpened(.questionNeeded) : .toolObserved
        case "PermissionRequest": kind = .requestOpened(isQuestion ? .questionNeeded : .approvalNeeded)
        case "PostToolUse": kind = .toolFinished
        case "Stop": kind = .responseReady
        default: kind = .sessionEnded // The validator permits only these seven hooks.
        }
    }
}

/// Source identities compare UTF-8 bytes. Swift String equality alone folds Unicode forms.
struct SourceIdentity: Hashable, Sendable {
    let value: String
    static func == (lhs: Self, rhs: Self) -> Bool { lhs.value.utf8.elementsEqual(rhs.value.utf8) }
    func hash(into hasher: inout Hasher) { hasher.combine(Data(value.utf8)) }
}

public struct SessionKey: Hashable, Sendable {
    public let agent: String
    public let sessionID: String

    public init(agent: String, sessionID: String) {
        self.agent = agent
        self.sessionID = sessionID
    }

    public static func == (lhs: Self, rhs: Self) -> Bool {
        SourceIdentity(value: lhs.agent) == SourceIdentity(value: rhs.agent)
            && SourceIdentity(value: lhs.sessionID) == SourceIdentity(value: rhs.sessionID)
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(SourceIdentity(value: agent))
        hasher.combine(SourceIdentity(value: sessionID))
    }
}

public enum SessionStatus: String, Sendable {
    case idle, working, ended, unknown
    case questionNeeded = "question_needed"
    case approvalNeeded = "approval_needed"
    case responseReady = "response_ready"
}

public enum SessionUnknownReason: String, Sendable {
    case noBaseline = "no_baseline"
    case expired
    case eventIDConflict = "event_id_conflict"
    case identityCapacity = "identity_capacity"
    case requestCapacity = "request_capacity"
    case reusedSessionID = "reused_session_id"
    case ambiguousCaptureOrder = "ambiguous_capture_order"
    case missingTurnIdentity = "missing_turn_identity"
    case overlappingTurns = "overlapping_turns"
    case uncorrelatedStop = "uncorrelated_stop"
    case activityAfterStop = "activity_after_stop"
    case requestConflict = "request_conflict"
    case uncorrelatedActivity = "uncorrelated_activity"
    case uncorrelatedResolution = "uncorrelated_resolution"
    case clockOrWake = "clock_or_wake"
    case deliveryOverflow = "delivery_overflow"
}

public enum SessionApplyResult: String, Sendable {
    case applied, duplicate, ended, conflict
    case deliveryTime = "delivery_time"
    case invalidObservation = "invalid_observation"
    case sessionCapacity = "session_capacity"
    case eventIDConflict = "event_id_conflict"
    case identityCapacity = "identity_capacity"
    case requestCapacity = "request_capacity"
    case terminalRestriction = "terminal_restriction"
    case ambiguousCaptureOrder = "ambiguous_capture_order"
    case retiredTurn = "retired_turn"
    case repeatedStart = "repeated_start"
    case repeatedSubmit = "repeated_submit"
    case repeatedStop = "repeated_stop"
    case resolvedButUnknown = "resolved_but_unknown"
    case retainedButUnknown = "retained_but_unknown"
    case mergedRequest = "merged_request"
    case unmatchedCompletion = "unmatched_completion"
    case noChange = "no_change"
}

public struct SessionRequest: Equatable, Sendable {
    public let eventID: String
    public let turnID: String?
    public let toolUseID: String?
    public let toolName: String
    public let kind: SessionRequestKind
    /// Unknown sessions retain notices without claiming the request is still current.
    public let isConfirmed: Bool
}

public struct SessionSnapshot: Equatable, Sendable, Identifiable {
    public var id: SessionKey { key }
    public let key: SessionKey
    public let status: SessionStatus
    public let reason: SessionUnknownReason?
    public let currentTurnID: String?
    /// Capture time of the accepted submit for the current turn, in Unix milliseconds.
    public let turnStartedAtMs: Int64?
    /// Capture time of the first matching stop. Unknown status remains authoritative.
    public let responseReadyAtMs: Int64?
    public let pendingRequests: [SessionRequest]
    public let captureWatermarkMs: Int64?
    public let receiptWallMs: Int64?
    public let receiptMonotonicNs: UInt64?
    public let expiryMonotonicNs: UInt64?
    public let projectPath: String?
    /// An unverified hint. The future terminal adapter must validate it before navigation.
    public let paneSelector: String?
    public let hasTerminalRestriction: Bool
}
