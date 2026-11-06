import Foundation

public enum UsageProviderError: Error, Equatable {
    case malformed, resourceLimit, invalidSource
}

public enum ClaudeUsageProvider {
    /// Extract only supported allowance fields. Raw status-line input is never retained.
    public static func parse(_ input: Data, sourceID: String, receivedAtMs: Int64) throws -> UsageObservation {
        guard input.count <= 262_144 else { throw UsageProviderError.resourceLimit }
        guard !sourceID.isEmpty, sourceID.utf8.count <= 256, receivedAtMs >= 0 else {
            throw UsageProviderError.invalidSource
        }
        struct Window: Decodable {
            let used_percentage: Double
            let resets_at: Double?
        }
        struct Limits: Decodable {
            let five_hour: Window?
            let seven_day: Window?
        }
        struct Payload: Decodable { let rate_limits: Limits? }
        let payload: Payload
        do { payload = try JSONDecoder().decode(Payload.self, from: input) }
        catch { throw UsageProviderError.malformed }
        let candidates = [("five_hour", 300, payload.rate_limits?.five_hour),
                          ("seven_day", 10080, payload.rate_limits?.seven_day)]
        let windows: [UsageWindow] = try candidates.compactMap { id, duration, value in
            guard let value else { return nil }
            guard value.used_percentage.isFinite, (0...100).contains(value.used_percentage) else {
                throw UsageProviderError.malformed
            }
            let reset: Int64?
            if let seconds = value.resets_at {
                // Strict inequality avoids Double rounding Int64.max upward before conversion.
                guard seconds.isFinite, seconds >= 0, seconds * 1000 < Double(Int64.max) else {
                    throw UsageProviderError.malformed
                }
                reset = Int64(seconds * 1000)
            } else { reset = nil }
            return UsageWindow(id: id, usedPercent: value.used_percentage,
                               durationMinutes: duration, resetsAtMs: reset)
        }
        return UsageObservation(provider: "claude", sourceID: sourceID, accountID: nil,
                                receivedAtMs: receivedAtMs, measuredAtMs: nil,
                                windows: windows, failure: windows.isEmpty ? .awaitingSource : nil)
    }
}
