import Foundation
import Testing
@testable import Usage

struct CodexUsageProtocolTests {
    @Test func initializationPrecedesQuotaAndOnlyReadMethodsAreSent() throws {
        var session = CodexUsageProtocol(sourceID: "fixture")
        let start = String(decoding: session.start(), as: UTF8.self)
        #expect(start.contains("initialize") && !start.contains("rateLimits"))
        let next = try session.receive(Data(#"{"id":1,"result":{}}"#.utf8), receivedAtMs: 1000)
        #expect(next.count == 2)
        #expect(String(decoding: next[0], as: UTF8.self).contains("initialized"))
        #expect(String(decoding: next[1], as: UTF8.self).contains("account/rateLimits/read"))
        #expect(!String(decoding: next.joined(), as: UTF8.self).contains("thread/"))
        #expect(try session.receive(Data(#"{"id":2,"result":{"rateLimits":{"primary":{"usedPercent":25,"windowDurationMins":300}}}}"#.utf8), receivedAtMs: 1000).isEmpty)
        #expect(session.observation?.windows.first?.usedPercent == 25)
    }

    @Test func notificationsWrongIDsAndDuplicateResponsesCannotAdvanceProtocol() throws {
        var session = CodexUsageProtocol(sourceID: "fixture")
        _ = session.start()
        for raw in [#"{"method":"account/updated","params":{"secret":"PRIVATE"}}"#,
                    #"{"id":99,"result":{}}"#, #"{"id":2,"result":{}}"#] {
            #expect(try session.receive(Data(raw.utf8), receivedAtMs: 0).isEmpty)
        }
        #expect(session.observation == nil)
        #expect(try session.receive(Data(#"{"id":1,"result":{}}"#.utf8), receivedAtMs: 0).count == 2)
        #expect(try session.receive(Data(#"{"id":1,"result":{}}"#.utf8), receivedAtMs: 0).isEmpty)
    }

    @Test func sourceErrorsHaveBoundedCategories() throws {
        var session = CodexUsageProtocol(sourceID: "fixture")
        _ = session.start()
        _ = try session.receive(Data(#"{"id":1,"result":{}}"#.utf8), receivedAtMs: 0)
        _ = try session.receive(Data(#"{"id":2,"error":{"code":-32600,"message":"PRIVATE"}}"#.utf8), receivedAtMs: 0)
        #expect(session.failure == .sourceUnavailable)
        #expect(session.observation == nil)
        #expect(!String(reflecting: session).contains("PRIVATE"))
    }

    @Test func malformedAndOversizedFramesAreRejected() {
        var session = CodexUsageProtocol(sourceID: "fixture")
        _ = session.start()
        for raw in ["[]", "{", #"{"id":true,"result":{}}"#] {
            #expect(throws: UsageProviderError.malformed) {
                try session.receive(Data(raw.utf8), receivedAtMs: 0)
            }
        }
        #expect(throws: UsageProviderError.resourceLimit) {
            try session.receive(Data(repeating: 32, count: 262145), receivedAtMs: 0)
        }
    }

    @Test func completedSessionNeverRequestsMoreWork() throws {
        var session = CodexUsageProtocol(sourceID: "fixture")
        _ = session.start()
        _ = try session.receive(Data(#"{"id":1,"result":{}}"#.utf8), receivedAtMs: 0)
        _ = try session.receive(Data(#"{"id":2,"result":{}}"#.utf8), receivedAtMs: 0)
        #expect(session.observation?.failure == .awaitingSource)
        #expect(session.start().isEmpty)
        #expect(try session.receive(Data(#"{"id":2,"result":{}}"#.utf8), receivedAtMs: 0).isEmpty)
    }
}
