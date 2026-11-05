import Foundation
import Testing
@testable import Usage

struct ClaudeUsageProviderTests {
    @Test func mapsSubscriptionWindowsWithoutInventingAccountOrMeasurementTime() throws {
        let input = Data(#"{"rate_limits":{"five_hour":{"used_percentage":23.5,"resets_at":1000},"seven_day":{"used_percentage":41,"resets_at":2000}}}"#.utf8)
        let result = try ClaudeUsageProvider.parse(input, sourceID: "fixture", receivedAtMs: 500)
        #expect(result.provider == "claude" && result.sourceID == "fixture")
        #expect(result.accountID == nil && result.measuredAtMs == nil)
        #expect(result.windows.map(\.durationMinutes) == [300, 10080])
        #expect(result.windows.map(\.usedPercent) == [23.5, 41])
        #expect(result.windows.map(\.resetsAtMs) == [1000000, 2000000])
        #expect(result.failure == nil)
    }

    @Test func independentlyMissingWindowsAndResetTimesRemainMissing() throws {
        for key in ["five_hour", "seven_day"] {
            let input = Data("{\"rate_limits\":{\"\(key)\":{\"used_percentage\":0}}}".utf8)
            let result = try ClaudeUsageProvider.parse(input, sourceID: "fixture", receivedAtMs: 0)
            #expect(result.windows.count == 1)
            #expect(result.windows[0].resetsAtMs == nil)
            #expect(result.windows[0].usedPercent == 0)
        }
        for input in ["{}", "{\"rate_limits\":null}", "{\"rate_limits\":{}}"] {
            let result = try ClaudeUsageProvider.parse(Data(input.utf8), sourceID: "fixture", receivedAtMs: 0)
            #expect(result.windows.isEmpty && result.failure == .awaitingSource)
        }
    }

    @Test func malformedAndOutOfRangeValuesProduceBoundedErrors() {
        for input in ["[]", "{", #"{"rate_limits":{"five_hour":{"used_percentage":true}}}"#,
                      #"{"rate_limits":{"five_hour":{"used_percentage":101}}}"#,
                      #"{"rate_limits":{"five_hour":{"used_percentage":-1}}}"#,
                      #"{"rate_limits":{"five_hour":{"used_percentage":20,"resets_at":-1}}}"#,
                      #"{"rate_limits":{"five_hour":{"used_percentage":20,"resets_at":1e100}}}"#] {
            #expect(throws: UsageProviderError.malformed) {
                try ClaudeUsageProvider.parse(Data(input.utf8), sourceID: "fixture", receivedAtMs: 0)
            }
        }
    }

    @Test func unrelatedContentAndGatewaySpendNeverBecomeSubscriptionQuota() throws {
        let raw = Data(#"{"account":"PRIVATE_SENTINEL","prompt":"PRIVATE_SENTINEL","context_window":{"used_percentage":99},"rate_limits":{"spend_limit":{"used_percentage":80,"resets_at":1000}}}"#.utf8)
        let result = try ClaudeUsageProvider.parse(raw, sourceID: "fixture", receivedAtMs: 0)
        #expect(result.windows.isEmpty && result.accountID == nil)
        #expect(!String(reflecting: result).contains("PRIVATE_SENTINEL"))
    }

    @Test func inputAndSourceIdentityAreBounded() {
        #expect(throws: UsageProviderError.resourceLimit) {
            try ClaudeUsageProvider.parse(Data(repeating: 32, count: 262145), sourceID: "fixture", receivedAtMs: 0)
        }
        for source in ["", String(repeating: "x", count: 257)] {
            #expect(throws: UsageProviderError.invalidSource) {
                try ClaudeUsageProvider.parse(Data("{}".utf8), sourceID: source, receivedAtMs: 0)
            }
        }
    }
}
