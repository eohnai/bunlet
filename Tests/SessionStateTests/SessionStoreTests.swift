import EventBridge
import Foundation
import Observation
import os
import SessionState
import Testing

@MainActor
struct SessionStoreTests {
    @Test @MainActor func duplicateDoesNotExtendExpiry() throws {
        let store = SessionStore()
        let frame = Data("""
        {"version":1,"event_id":"00000000-0000-0000-0000-000000000001","agent":"codex","session_id":"fictional","hook_event_name":"UserPromptSubmit","observed_at_ms":1000000,"turn_id":"a"}

        """.utf8)
        let envelope = try HookEnvelopeV1.decode(frame: frame)
        let first = SessionObservationV1(envelope: envelope, receiptWallMs: 1_000_000,
                                        receiptMonotonicNs: 1_000_000_000)
        #expect(store.apply(first) == .applied)
        let duplicate = SessionObservationV1(envelope: envelope, receiptWallMs: 1_010_000,
                                            receiptMonotonicNs: 11_000_000_000)
        #expect(store.apply(duplicate) == .duplicate)
        store.advance(monotonicNs: 121_000_000_000)
        #expect(store.sessions.first?.status == .unknown)
        #expect(store.sessions.first?.reason == .expired)
    }

    private func observation(_ number: Int, hook: String = "UserPromptSubmit", agent: String = "codex",
                             sessionID: String = "fictional", turnID: String? = "a",
                             toolUseID: String? = nil, toolName: String? = nil,
                             observedAtMs: Int64? = nil, wallMs: Int64? = nil,
                             monotonicNs: UInt64? = nil, cwd: String? = nil,
                             pane: String? = nil) throws -> SessionObservationV1 {
        let observed = observedAtMs ?? 1_000_000 + Int64(number)
        var fields: [String: Any] = [
            "version": 1, "event_id": String(format: "00000000-0000-0000-0000-%012x", number),
            "agent": agent, "session_id": sessionID, "hook_event_name": hook, "observed_at_ms": observed
        ]
        fields["turn_id"] = turnID
        fields["tool_use_id"] = toolUseID
        fields["tool_name"] = toolName
        fields["cwd"] = cwd
        if let pane { fields["terminal"] = ["kind": "otty", "pane_selector": pane] }
        let frame = try JSONSerialization.data(withJSONObject: fields, options: [.sortedKeys]) + Data([10])
        return SessionObservationV1(envelope: try HookEnvelopeV1.decode(frame: frame),
                                    receiptWallMs: wallMs ?? observed,
                                    receiptMonotonicNs: monotonicNs ?? UInt64(observed) * 1_000_000)
    }

    @Test(arguments: ["codex", "claude"])
    func turnTimesUseCaptureTimesAndSurviveSameTurnActivity(agent: String) throws {
        let store = SessionStore()
        #expect(store.apply(try observation(1, hook: "SessionStart", agent: agent,
                                           turnID: nil, wallMs: 1_001_001)) == .applied)
        let idle = try #require(store.sessions.first)
        #expect(idle.turnStartedAtMs == nil)
        #expect(idle.responseReadyAtMs == nil)

        #expect(store.apply(try observation(2, agent: agent, wallMs: 1_001_002)) == .applied)
        let started = try #require(store.sessions.first)
        #expect(started.turnStartedAtMs == 1_000_002)
        #expect(started.responseReadyAtMs == nil)
        #expect(store.apply(try observation(3, agent: agent, wallMs: 1_001_003)) == .repeatedSubmit)
        #expect(store.sessions.first?.turnStartedAtMs == started.turnStartedAtMs)
        #expect(store.sessions.first?.expiryMonotonicNs == started.expiryMonotonicNs)

        #expect(store.apply(try observation(4, hook: "PermissionRequest", agent: agent,
                                           toolUseID: "tool", toolName: "Write",
                                           wallMs: 1_001_004)) == .applied)
        let waiting = try #require(store.sessions.first)
        #expect(waiting.status == .approvalNeeded)
        #expect(waiting.turnStartedAtMs == started.turnStartedAtMs)
        #expect(waiting.responseReadyAtMs == nil)

        #expect(store.apply(try observation(5, hook: "Stop", agent: agent,
                                           wallMs: 1_001_005)) == .applied)
        let stopped = try #require(store.sessions.first)
        #expect(stopped.status == .responseReady)
        #expect(stopped.pendingRequests.isEmpty)
        #expect(stopped.turnStartedAtMs == 1_000_002)
        #expect(stopped.responseReadyAtMs == 1_000_005)
    }

    @Test(arguments: ["codex", "claude"])
    func repeatedStopPreservesFirstResponseTimeAndDeadline(agent: String) throws {
        let store = SessionStore()
        #expect(store.apply(try observation(1, agent: agent)) == .applied)
        let stop = try observation(2, hook: "Stop", agent: agent)
        #expect(store.apply(stop) == .applied)
        let stopped = try #require(store.sessions.first)
        #expect(stopped.responseReadyAtMs == 1_000_002)
        #expect(store.apply(stop) == .duplicate)
        #expect(store.apply(try observation(3, hook: "Stop", agent: agent)) == .repeatedStop)
        #expect(store.sessions.first == stopped)
    }

    @Test(arguments: ["codex", "claude"])
    func newTurnResetsTimesAndRetiredStopCannotChangeThem(agent: String) throws {
        let store = SessionStore()
        #expect(store.apply(try observation(1, agent: agent)) == .applied)
        #expect(store.apply(try observation(2, hook: "Stop", agent: agent)) == .applied)
        #expect(store.apply(try observation(3, agent: agent, turnID: "b")) == .applied)
        let next = try #require(store.sessions.first)
        #expect(next.currentTurnID == "b")
        #expect(next.turnStartedAtMs == 1_000_003)
        #expect(next.responseReadyAtMs == nil)
        #expect(store.apply(try observation(4, hook: "Stop", agent: agent)) == .retiredTurn)
        #expect(store.sessions.first == next)
        #expect(store.apply(try observation(5, hook: "Stop", agent: agent, turnID: "b")) == .applied)
        #expect(store.sessions.first?.turnStartedAtMs == next.turnStartedAtMs)
        #expect(store.sessions.first?.responseReadyAtMs == 1_000_005)
    }

    @Test(arguments: ["codex", "claude"])
    func matchingStopsKeepFirstTimeWithoutRevivingUnknownTurn(agent: String) throws {
        let store = SessionStore()
        #expect(store.apply(try observation(1, agent: agent)) == .applied)
        store.advance(monotonicNs: 1_120_001_000_000)
        #expect(store.sessions.first?.status == .unknown)
        #expect(store.sessions.first?.turnStartedAtMs == 1_000_001)
        #expect(store.apply(try observation(2, hook: "Stop", agent: agent,
                                           observedAtMs: 1_120_002)) == .resolvedButUnknown)
        let stopped = try #require(store.sessions.first)
        #expect(stopped.status == .unknown)
        #expect(stopped.reason == .expired)
        #expect(stopped.responseReadyAtMs == 1_120_002)
        #expect(store.apply(try observation(3, hook: "Stop", agent: agent,
                                           observedAtMs: 1_120_003)) == .resolvedButUnknown)
        #expect(store.sessions.first == stopped)
        #expect(store.apply(try observation(4, agent: agent, turnID: "b",
                                           observedAtMs: 1_120_004)) == .applied)
        #expect(store.sessions.first?.turnStartedAtMs == 1_120_004)
        #expect(store.sessions.first?.responseReadyAtMs == nil)
    }

    @Test func allContractStateSequences() throws {
        let fixture = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().appendingPathComponent("docs/contracts/agent-events-v1-cases.json")
        // Other fixture sections deliberately include invalid Unicode. Extract only valid sequences.
        let process = Process(), output = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/python3")
        process.arguments = ["-c", "import json,sys; print(json.dumps(json.load(open(sys.argv[1]))['sequences']))", fixture.path]
        process.standardOutput = output
        try process.run()
        let data = output.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        #expect(process.terminationStatus == 0)
        let cases = try #require(JSONSerialization.jsonObject(with: data) as? [[String: Any]])
        #expect(cases.count == 37)
        var stepsChecked = 0
        for item in cases {
            let name = try #require(item["name"] as? String)
            let steps = try #require(item["steps"] as? [[String: Any]])
            let store = SessionStore()
            for (index, step) in steps.enumerated() {
                let context = "\(name), step \(index + 1)"
                if let message = step["message"] as? [String: Any] {
                    let frame = try JSONSerialization.data(withJSONObject: message, options: [.sortedKeys]) + Data([10])
                    let event = try HookEnvelopeV1.decode(frame: frame)
                    let wall = try #require(step["wall_ms"] as? NSNumber).int64Value
                    let monotonic = try #require(step["monotonic_ms"] as? NSNumber).uint64Value * 1_000_000
                    let result = store.apply(SessionObservationV1(envelope: event, receiptWallMs: wall,
                                                                 receiptMonotonicNs: monotonic))
                    #expect(result.rawValue == step["outcome"] as? String, "\(context)")
                } else if step["operation"] as? String == "advance" {
                    let monotonic = try #require(step["monotonic_ms"] as? NSNumber).uint64Value * 1_000_000
                    store.advance(monotonicNs: monotonic)
                } else {
                    store.invalidateClocks()
                }
                let expected = try #require(step["expect"] as? [[String: Any]])
                #expect(store.sessions.count == expected.count, "\(context)")
                for (actual, expected) in zip(store.sessions, expected) {
                    #expect(actual.key.agent == expected["agent"] as? String, "\(context)")
                    #expect(actual.key.sessionID == expected["session_id"] as? String, "\(context)")
                    #expect(actual.status.rawValue == expected["status"] as? String, "\(context)")
                    #expect(actual.pendingRequests.count == expected["pending"] as? Int, "\(context)")
                    #expect(actual.reason?.rawValue == expected["reason"] as? String, "\(context)")
                    if actual.status == .unknown {
                        #expect(actual.pendingRequests.allSatisfy { !$0.isConfirmed }, "\(context)")
                    }
                }
                stepsChecked += 1
            }
        }
        #expect(stepsChecked == 122)
    }

    @Test func sessionCapacityRetainsTerminalRecords() throws {
        let store = SessionStore()
        for n in 1...SessionStore.sessionLimit {
            #expect(store.apply(try observation(n, sessionID: "fictional-\(n)")) == .applied)
        }
        #expect(store.apply(try observation(999, hook: "SessionEnd", sessionID: "fictional-1")) == .ended)
        #expect(store.apply(try observation(1000, sessionID: "overflow")) == .sessionCapacity)
        #expect(store.sessions.count == 128)
        #expect(store.sessions.first { $0.key.sessionID == "fictional-1" }?.status == .ended)
    }

    @Test func eventIDCapacityIsPermanentAndStillRecognizesDuplicates() throws {
        let store = SessionStore()
        let first = try observation(1)
        #expect(store.apply(first) == .applied)
        for n in 2...SessionStore.eventIDLimit {
            #expect(store.apply(try observation(n)) == .repeatedSubmit)
        }
        #expect(store.apply(first) == .duplicate)
        let deadline = store.sessions.first?.expiryMonotonicNs
        #expect(store.apply(try observation(4097)) == .identityCapacity)
        #expect(store.apply(try observation(4098, turnID: "b")) == .identityCapacity)
        #expect(store.sessions.first?.reason == .identityCapacity)
        #expect(store.sessions.first?.expiryMonotonicNs == deadline)
    }

    @Test func turnCapacityDoesNotEvictRetiredIdentities() throws {
        let store = SessionStore()
        for n in 0..<SessionStore.turnIDLimit {
            #expect(store.apply(try observation(n * 2 + 1, turnID: "turn-\(n)")) == .applied)
            #expect(store.apply(try observation(n * 2 + 2, hook: "Stop", turnID: "turn-\(n)")) == .applied)
        }
        #expect(store.apply(try observation(999, turnID: "overflow")) == .identityCapacity)
        #expect(store.apply(try observation(1000, turnID: "turn-0")) == .identityCapacity)
        #expect(store.sessions.first?.status == .unknown)
    }

    @Test func requestCapacityRetainsEveryExistingNotice() throws {
        let store = SessionStore()
        #expect(store.apply(try observation(1)) == .applied)
        for n in 0..<SessionStore.requestLimit {
            #expect(store.apply(try observation(n + 2, hook: "PermissionRequest",
                                               toolUseID: "tool-\(n)", toolName: "Write")) == .applied)
        }
        #expect(store.apply(try observation(999, hook: "PermissionRequest",
                                           toolUseID: "overflow", toolName: "Write")) == .requestCapacity)
        let snapshot = try #require(store.sessions.first)
        #expect(snapshot.reason == .requestCapacity)
        #expect(snapshot.pendingRequests.count == 64)
        #expect(Set(snapshot.pendingRequests.compactMap(\.toolUseID)) == Set((0..<64).map { "tool-\($0)" }))
        #expect(snapshot.pendingRequests.allSatisfy { !$0.isConfirmed })
    }

    @Test func byteDistinctUnicodeIdentitiesAndFingerprints() throws {
        let composed = "\u{e9}", decomposed = "e\u{301}"
        let store = SessionStore()
        #expect(store.apply(try observation(1, sessionID: composed)) == .applied)
        #expect(store.apply(try observation(2, sessionID: decomposed)) == .applied)
        #expect(store.sessions.count == 2)

        let turns = SessionStore()
        #expect(turns.apply(try observation(3, turnID: composed)) == .applied)
        #expect(turns.apply(try observation(4, turnID: decomposed)) == .conflict)
        #expect(turns.sessions.first?.reason == .overlappingTurns)

        let requests = SessionStore()
        #expect(requests.apply(try observation(5)) == .applied)
        #expect(requests.apply(try observation(6, hook: "PermissionRequest", toolUseID: composed,
                                              toolName: "Write")) == .applied)
        #expect(requests.apply(try observation(7, hook: "PermissionRequest", toolUseID: decomposed,
                                              toolName: "Write")) == .applied)
        #expect(requests.sessions.first?.pendingRequests.count == 2)

        let conflicts = SessionStore()
        #expect(conflicts.apply(try observation(8, cwd: "/\(composed)")) == .applied)
        #expect(conflicts.apply(try observation(8, cwd: "/\(decomposed)")) == .eventIDConflict)
    }

    @Test func freshTurnRecoversOnlyAfterRequestsResolve() throws {
        let store = SessionStore()
        #expect(store.apply(try observation(1)) == .applied)
        #expect(store.apply(try observation(2, hook: "PermissionRequest",
                                           toolUseID: "tool", toolName: "Write")) == .applied)
        store.advance(monotonicNs: 1_120_002_000_000)
        #expect(store.apply(try observation(3, turnID: "b", observedAtMs: 1_120_003)) == .conflict)
        #expect(store.apply(try observation(4, hook: "PostToolUse", toolUseID: "tool", toolName: "Write",
                                           observedAtMs: 1_120_004)) == .resolvedButUnknown)
        #expect(store.sessions.first?.pendingRequests.isEmpty == true)
        #expect(store.apply(try observation(5, turnID: "c", observedAtMs: 1_120_005)) == .applied)
        #expect(store.sessions.first?.status == .working)
        #expect(store.apply(try observation(6, hook: "Stop", turnID: "a",
                                           observedAtMs: 1_120_006)) == .retiredTurn)
    }

    @Test func recoveryRequiresAnUnseenTurnIdentity() throws {
        let store = SessionStore()
        #expect(store.apply(try observation(1)) == .applied)
        #expect(store.apply(try observation(2, turnID: "b")) == .conflict)
        let deadline = store.sessions.first?.expiryMonotonicNs
        #expect(store.apply(try observation(3, turnID: "b")) == .conflict)
        #expect(store.sessions.first?.status == .unknown)
        #expect(store.sessions.first?.expiryMonotonicNs == deadline)
        #expect(store.apply(try observation(4, turnID: "c")) == .applied)
        #expect(store.sessions.first?.status == .working)
    }

    @Test func clocksAndWakeNeverReviveTerminalSessions() throws {
        let store = SessionStore()
        #expect(store.apply(try observation(1)) == .applied)
        #expect(store.apply(try observation(2, hook: "SessionEnd", sessionID: "ended")) == .ended)
        store.checkClocks(wallMs: 1_000_010, monotonicNs: 1_000_010_000_000)
        store.checkClocks(wallMs: 999_000, monotonicNs: 1_000_011_000_000)
        #expect(store.sessions.first { $0.key.sessionID == "fictional" }?.reason == .clockOrWake)
        #expect(store.sessions.first { $0.key.sessionID == "ended" }?.status == .ended)
        store.invalidateClocks()
        store.advance(monotonicNs: UInt64.max)
        #expect(store.sessions.first { $0.key.sessionID == "ended" }?.status == .ended)

        let forwards = SessionStore()
        #expect(forwards.apply(try observation(3)) == .applied)
        forwards.checkClocks(wallMs: 1_000_003, monotonicNs: 1_000_003_000_000)
        forwards.checkClocks(wallMs: 1_010_003, monotonicNs: 1_000_004_000_000)
        #expect(forwards.sessions.first?.reason == .clockOrWake)

        let backwards = SessionStore()
        #expect(backwards.apply(try observation(4)) == .applied)
        backwards.advance(monotonicNs: 1_000_004_000_000)
        backwards.advance(monotonicNs: 1)
        #expect(backwards.sessions.first?.reason == .clockOrWake)
    }

    @Test func queuedObservationIsExpiredWhenObserversFirstRead() async throws {
        let store = SessionStore()
        let event = try observation(1)
        let announced = OSAllocatedUnfairLock(initialState: false)
        _ = withObservationTracking { store.sessions } onChange: { announced.withLock { $0 = true } }
        store.applyBatch([event], observationsLost: false, wallMs: 1_120_001,
                         monotonicNs: 1_120_001_000_000)
        // Observers read after a main-actor hop, so they never see a value within the batch.
        await Task { @MainActor in }.value
        #expect(announced.withLock { $0 })
        #expect(store.sessions.first?.reason == .expired)
    }

    @Test func newEvidenceCanRecoverAfterAMonotonicClockReset() throws {
        let store = SessionStore()
        #expect(store.apply(try observation(1)) == .applied)
        #expect(store.apply(try observation(2, turnID: "b", monotonicNs: 1_000_000)) == .applied)
        #expect(store.sessions.first?.status == .working)
        #expect(store.sessions.first?.expiryMonotonicNs == 120_001_000_000)
        #expect(store.apply(try observation(3, hook: "Stop", turnID: "b", monotonicNs: 2_000_000)) == .applied)
        #expect(store.apply(try observation(4, turnID: "c", monotonicNs: 3_000_000)) == .applied)
        #expect(store.sessions.first?.status == .working)
    }

    @Test func metadataNeedsCompatibleEvidenceAndPaneHintsStayUnverified() throws {
        let store = SessionStore()
        #expect(store.apply(try observation(1, cwd: "/example", pane: "fictional-pane")) == .applied)
        #expect(store.apply(try observation(2, hook: "PreToolUse", toolName: "Write",
                                           observedAtMs: 1_000_001, cwd: "/wrong", pane: "wrong")) == .ambiguousCaptureOrder)
        #expect(store.sessions.first?.projectPath == "/example")
        #expect(store.sessions.first?.paneSelector == "fictional-pane")
        #expect(store.sessions.first?.status == .unknown)
    }

    @Test func boundedInboxRetainsOrderAndMarksOverflowUnknown() async throws {
        let store = SessionStore()
        let delivered = expectation()
        let inbox = SessionEventInbox { batch, lost in
            #expect(batch.count == SessionEventInbox.capacity)
            #expect(lost)
            #expect(batch.map(\.envelope.observedAtMs) == (1...128).map { 1_000_000 + Int64($0) })
            store.applyBatch(batch, observationsLost: lost, wallMs: 1_000_129,
                             monotonicNs: 1_000_129_000_000)
            delivered.signal()
        }
        // The main actor cannot drain until this synchronous burst yields.
        for n in 1...129 { inbox.enqueue(try observation(n, sessionID: "fictional-\(n)")) }
        #expect(await delivered.wait())
        #expect(store.sessions.count == 128)
        #expect(store.sessions.allSatisfy { $0.reason == .deliveryOverflow })
    }

    @Test func concurrentInboxProducersKeepSessionsSeparate() async throws {
        let store = SessionStore()
        let delivered = expectation()
        let inbox = SessionEventInbox { batch, lost in
            #expect(!lost)
            store.applyBatch(batch, observationsLost: lost, wallMs: 1_000_001,
                             monotonicNs: 1_000_001_000_000)
            if store.sessions.count == 64 { delivered.signal() }
        }
        let observations = try (1...64).map {
            try observation($0, sessionID: "fictional-\($0)", observedAtMs: 1_000_001)
        }
        await withTaskGroup(of: Void.self) { group in
            for event in observations { group.addTask { inbox.enqueue(event) } }
        }
        #expect(await delivered.wait())
        #expect(store.sessions.count == 64)
        #expect(store.sessions.allSatisfy { $0.status == .working })
    }

    private func expectation() -> DeliverySignal { DeliverySignal() }

    @Test(arguments: ["codex", "claude"])
    func adaptersPreserveSharedSessionMeanings(agent: String) throws {
        // Seed each store just before the adapter's real capture time. No wall-clock sleeps are needed.
        let questionTool = agent == "codex" ? "request_user_input" : "AskUserQuestion"
        let cases: [(String, String?, SessionStatus)] = [
            ("SessionStart", nil, .idle), ("UserPromptSubmit", nil, .working),
            ("PreToolUse", "Bash", .working), ("PreToolUse", questionTool, .questionNeeded),
            ("PermissionRequest", "Bash", .approvalNeeded),
            ("PermissionRequest", questionTool, .questionNeeded),
            ("PostToolUse", questionTool, .working),
            ("Stop", nil, .responseReady), ("SessionEnd", nil, .ended)
        ]
        for (hook, tool, status) in cases {
            var source: [String: Any] = ["session_id": "fictional", "hook_event_name": hook,
                                         (agent == "codex" ? "turn_id" : "prompt_id"): "a", "cwd": "/example"]
            if let tool { source["tool_name"] = tool; source["tool_use_id"] = "call" }
            // Prose questions are deliberately absent from the wire projection.
            if hook == "Stop" { source["last_assistant_message"] = "Which option should I use?" }
            let input = try JSONSerialization.data(withJSONObject: source)
            let envelope = try HookEnvelopeV1.project(rawHook: input, agent: agent, paneSelector: "unverified-pane")
            let now = envelope.observedAtMs
            let store = SessionStore()
            if hook != "SessionStart" && hook != "UserPromptSubmit" {
                #expect(store.apply(try observation(1, agent: agent, observedAtMs: now - 2,
                                                   monotonicNs: 1_000_000_000)) == .applied)
                if hook == "PostToolUse" || hook == "Stop" {
                    #expect(store.apply(try observation(2, hook: "PreToolUse", agent: agent, toolUseID: "call",
                        toolName: questionTool, observedAtMs: now - 1,
                        monotonicNs: 1_001_000_000)) == .applied)
                }
            }
            let value = SessionObservationV1(envelope: envelope, receiptWallMs: now,
                                             receiptMonotonicNs: 1_002_000_000)
            #expect(store.apply(value) == (hook == "SessionEnd" ? .ended : .applied))
            let snapshot = try #require(store.sessions.first)
            #expect(snapshot.status == status, "\(hook), \(tool ?? "no tool")")
            #expect(snapshot.key == SessionKey(agent: agent, sessionID: "fictional"))
            #expect(envelope.cwd == "/example" && envelope.terminal?.paneSelector == "unverified-pane")
            if hook == "SessionEnd" {
                // Terminal handling clears requests without refreshing captured metadata.
                #expect(snapshot.projectPath == nil && snapshot.paneSelector == nil)
            } else {
                #expect(snapshot.projectPath == "/example" && snapshot.paneSelector == "unverified-pane")
            }
            if status == .questionNeeded || status == .approvalNeeded {
                #expect(snapshot.pendingRequests.count == 1)
                #expect(snapshot.pendingRequests.first?.toolUseID == "call")
                #expect(snapshot.pendingRequests.first?.isConfirmed == true)
            } else {
                #expect(snapshot.pendingRequests.isEmpty)
            }
            #expect(store.apply(value) == .duplicate)
        }
    }

    @Test(arguments: ["codex", "claude"])
    func adaptersDoNotInventMissingTurnOrRequestIdentity(agent: String) throws {
        let store = SessionStore()
        let source: [String: Any] = [
            "session_id": "fictional", "hook_event_name": "PermissionRequest",
            "tool_name": agent == "codex" ? "request_user_input" : "AskUserQuestion",
            (agent == "codex" ? "prompt_id" : "turn_id"): "not-this-provider-turn", "id": "not-a-tool-call"
        ]
        let envelope = try HookEnvelopeV1.project(rawHook: JSONSerialization.data(withJSONObject: source), agent: agent)
        let value = SessionObservationV1(envelope: envelope, receiptWallMs: envelope.observedAtMs,
                                         receiptMonotonicNs: 1_000_000_000)
        #expect(envelope.turnID == nil && envelope.toolUseID == nil)
        #expect(store.apply(value) == .conflict)
        let snapshot = try #require(store.sessions.first)
        #expect(snapshot.status == .unknown && snapshot.currentTurnID == nil)
        #expect(snapshot.reason == .uncorrelatedActivity)
        #expect(snapshot.pendingRequests.count == 1)
        #expect(snapshot.pendingRequests.first?.turnID == nil)
        #expect(snapshot.pendingRequests.first?.toolUseID == nil)
        #expect(snapshot.pendingRequests.first?.isConfirmed == false)
    }

    @Test(arguments: ["codex", "claude"])
    func actualBridgeCallbackReachesSharedStore(agent: String) async throws {
        let directory = "/private/tmp/notch-pet-store-test-\(UUID().uuidString)"
        defer { try? FileManager.default.removeItem(atPath: directory) }
        let endpoint = BridgeEndpoint(directory: directory)
        let server = EventBridgeServer(endpoint: endpoint)
        let store = SessionStore(), delivered = expectation()
        let inbox = SessionEventInbox { batch, lost in
            #expect(!lost)
            store.applyBatch(batch, observationsLost: lost,
                             wallMs: Int64(Date().timeIntervalSince1970 * 1000),
                             monotonicNs: DispatchTime.now().uptimeNanoseconds)
            delivered.signal()
        }
        try server.start { inbox.receive($0) }
        defer { server.stop() }
        let source = ["session_id": "fictional-bridge", "hook_event_name": "UserPromptSubmit",
                      (agent == "codex" ? "turn_id" : "prompt_id"): "a", "cwd": "/example"]
        let envelope = try HookEnvelopeV1.project(rawHook: JSONSerialization.data(withJSONObject: source), agent: agent)
        try EventBridgeClient(endpoint: endpoint).send(envelope)
        #expect(await delivered.wait())
        #expect(store.sessions.first?.status == .working)
        #expect(store.sessions.first?.key.sessionID == "fictional-bridge")
        #expect(store.sessions.first?.key.agent == agent)
        #expect(store.sessions.first?.projectPath == "/example")
        #expect(store.sessions.first?.receiptWallMs != nil)
    }
}

/// Avoid blocking the main actor while a scheduled inbox drain runs.
private actor DeliverySignal {
    private var result: Bool?
    private var continuation: CheckedContinuation<Bool, Never>?
    nonisolated func signal() { Task { await finish(true) } }
    private func finish(_ delivered: Bool) {
        guard result == nil else { return }
        result = delivered
        continuation?.resume(returning: delivered)
        continuation = nil
    }
    func wait() async -> Bool {
        if let result { return result }
        Task {
            try? await Task.sleep(for: .seconds(5))
            finish(false)
        }
        return await withCheckedContinuation { continuation = $0 }
    }
}
