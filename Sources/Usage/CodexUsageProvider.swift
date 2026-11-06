import Foundation

public enum CodexUsageProvider {
    /// Normalizes a full account/rateLimits/read result, not a sparse notification.
    public static func parse(_ input: Data, sourceID: String, receivedAtMs: Int64) throws -> UsageObservation {
        guard input.count <= 262_144 else { throw UsageProviderError.resourceLimit }
        guard !sourceID.isEmpty, sourceID.utf8.count <= 256, receivedAtMs >= 0 else {
            throw UsageProviderError.invalidSource
        }
        struct Window: Decodable {
            let usedPercent: Int
            let windowDurationMins: Int?
            let resetsAt: Int64?
        }
        struct Bucket: Decodable { let primary: Window?; let secondary: Window? }
        struct Payload: Decodable {
            let accountId: String?
            let rateLimits: Bucket?
            let rateLimitsByLimitId: [String: Bucket]?
        }
        let payload: Payload
        do { payload = try JSONDecoder().decode(Payload.self, from: input) }
        catch { throw UsageProviderError.malformed }
        guard payload.accountId.map({ !$0.isEmpty && $0.utf8.count <= 256 }) ?? true else {
            throw UsageProviderError.malformed
        }
        let buckets = payload.rateLimitsByLimitId ?? payload.rateLimits.map { ["codex": $0] } ?? [:]
        guard buckets.count <= 32 else { throw UsageProviderError.resourceLimit }
        var windows: [UsageWindow] = []
        for key in buckets.keys.sorted() {
            guard !key.isEmpty, key.utf8.count <= 240, let bucket = buckets[key] else {
                throw UsageProviderError.malformed
            }
            for (name, window) in [("primary", bucket.primary), ("secondary", bucket.secondary)] {
                guard let window else { continue }
                guard (0...100).contains(window.usedPercent),
                      window.windowDurationMins.map({ $0 > 0 }) ?? true,
                      window.resetsAt.map({ $0 >= 0 && $0 <= Int64.max / 1000 }) ?? true else {
                    throw UsageProviderError.malformed
                }
                windows.append(UsageWindow(id: key + "/" + name, usedPercent: Double(window.usedPercent),
                                           durationMinutes: window.windowDurationMins,
                                           resetsAtMs: window.resetsAt.map { $0 * 1000 }))
            }
        }
        return UsageObservation(provider: "codex", sourceID: sourceID, accountID: payload.accountId,
                                receivedAtMs: receivedAtMs, measuredAtMs: nil, windows: windows,
                                failure: windows.isEmpty ? .awaitingSource : nil)
    }
}
