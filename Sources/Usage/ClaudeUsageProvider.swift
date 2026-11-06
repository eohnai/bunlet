import CryptoKit
import EventBridge
import Foundation

public enum UsageProviderError: Error, Equatable {
    case malformed, resourceLimit, invalidSource
}

public enum ClaudeUsageProvider {
    /// No raw session ID or unrelated status-line data leaves this projection.
    public static func forward(_ input: Data, receivedAtMs: Int64,
                               endpointURL: URL = UsageDelivery.standardEndpoint) -> Bool {
        guard input.count <= 262_144, (try? HookConfigurationJSON(data: input)) != nil else { return false }
        struct Identity: Decodable { let session_id: String }
        guard let identity = try? JSONDecoder().decode(Identity.self, from: input),
              !identity.session_id.isEmpty, identity.session_id.utf8.count <= 256 else { return false }
        let digest = SHA256.hash(data: Data(identity.session_id.utf8))
            .map { String(format: "%02x", $0) }.joined()
        guard let observation = try? parse(input, sourceID: UsageValidation.claudeSourcePrefix + digest,
                                           receivedAtMs: receivedAtMs) else { return false }
        return UsageDelivery.send(observation, endpointURL: endpointURL)
    }

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
