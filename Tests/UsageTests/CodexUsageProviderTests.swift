import Foundation
import Testing
@testable import Usage

struct CodexUsageProviderTests {
    @Test func fullMapIsAuthoritativeAndCompatibilityIsNotDuplicated() throws {
        let raw = Data(#"{"accountId":"fictional","rateLimits":{"primary":{"usedPercent":99}},"rateLimitsByLimitId":{"codex":{"primary":{"usedPercent":25,"windowDurationMins":300,"resetsAt":1000},"secondary":{"usedPercent":40,"windowDurationMins":10080,"resetsAt":2000}}}}"#.utf8)
        let value = try CodexUsageProvider.parse(raw, sourceID: "fixture", receivedAtMs: 0)
        #expect(value.windows.count == 2)
        #expect(value.windows.map(\.usedPercent) == [25, 40])
        #expect(value.windows.map(\.durationMinutes) == [300, 10080])
        #expect(value.windows[0].resetsAtMs == 1000000)
        #expect(value.accountID == "fictional" && value.measuredAtMs == nil)
    }

    @Test func compatibilityFallbackPreservesNonstandardAndMissingMetadata() throws {
        let raw = Data(#"{"rateLimits":{"primary":{"usedPercent":0,"windowDurationMins":15},"secondary":null}}"#.utf8)
        let value = try CodexUsageProvider.parse(raw, sourceID: "fixture", receivedAtMs: 0)
        #expect(value.windows.count == 1 && value.windows[0].durationMinutes == 15)
        #expect(value.windows[0].resetsAtMs == nil && value.accountID == nil)
    }

    @Test func multipleBucketsRemainSeparateAndAbsentWindowsStayAbsent() throws {
        let raw = Data(#"{"rateLimitsByLimitId":{"a":{"primary":{"usedPercent":1}},"b":{"secondary":{"usedPercent":2}}}}"#.utf8)
        let value = try CodexUsageProvider.parse(raw, sourceID: "fixture", receivedAtMs: 0)
        #expect(value.windows.map(\.id) == ["a/primary", "b/secondary"])
        #expect(value.windows.allSatisfy { $0.durationMinutes == nil })
        let empty = try CodexUsageProvider.parse(Data("{}".utf8), sourceID: "fixture", receivedAtMs: 0)
        #expect(empty.windows.isEmpty && empty.failure == .awaitingSource)
    }

    @Test func malformedValuesAndOverflowProduceBoundedErrors() {
        for raw in ["[]", #"{"rateLimits":{"primary":{"usedPercent":true}}}"#,
                    #"{"rateLimits":{"primary":{"usedPercent":101}}}"#,
                    #"{"rateLimits":{"primary":{"usedPercent":1,"windowDurationMins":0}}}"#,
                    #"{"rateLimits":{"primary":{"usedPercent":1,"resetsAt":9223372036854775807}}}"#] {
            #expect(throws: UsageProviderError.malformed) {
                try CodexUsageProvider.parse(Data(raw.utf8), sourceID: "fixture", receivedAtMs: 0)
            }
        }
    }

    @Test func sourceAndInputAreBoundedAndUnrelatedValuesAreDiscarded() throws {
        let value = try CodexUsageProvider.parse(Data(#"{"credits":{"secret":"PRIVATE_SENTINEL"}}"#.utf8), sourceID: "fixture", receivedAtMs: 0)
        #expect(!String(reflecting: value).contains("PRIVATE_SENTINEL"))
        #expect(throws: UsageProviderError.resourceLimit) {
            try CodexUsageProvider.parse(Data(repeating: 32, count: 262145), sourceID: "fixture", receivedAtMs: 0)
        }
        #expect(throws: UsageProviderError.invalidSource) {
            try CodexUsageProvider.parse(Data("{}".utf8), sourceID: "", receivedAtMs: 0)
        }
    }
}
