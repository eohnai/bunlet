import Foundation

/// One quota read per connection. No thread, turn, authentication or credit mutation methods.
public struct CodexUsageProtocol {
    public private(set) var observation: UsageObservation?
    public private(set) var failure: UsageFailure?
    private let sourceID: String
    private var expectedID = 0
    private var bytesReceived = 0

    public init(sourceID: String) { self.sourceID = sourceID }

    public mutating func start() -> Data {
        guard expectedID == 0, observation == nil, failure == nil else { return Data() }
        expectedID = 1
        return Data((#"{"id":1,"method":"initialize","params":{"clientInfo":{"name":"notch-pet-usage","version":"0.1.0"},"capabilities":{"experimentalApi":false}}}"# + "\n").utf8)
    }

    public mutating func receive(_ line: Data, receivedAtMs: Int64) throws -> [Data] {
        guard observation == nil, failure == nil else { return [] }
        guard line.count <= 262_144, bytesReceived <= 1_048_576 - line.count else {
            throw UsageProviderError.resourceLimit
        }
        bytesReceived += line.count
        struct Header: Decodable {
            struct ServerError: Decodable { let code: Int }
            let id: Int?
            let error: ServerError?
        }
        let header: Header
        do { header = try JSONDecoder().decode(Header.self, from: line) }
        catch { throw UsageProviderError.malformed }
        guard let id = header.id, id == expectedID, expectedID != 0 else { return [] }
        if header.error != nil {
            failure = .sourceUnavailable
            return []
        }
        guard let object = try? JSONSerialization.jsonObject(with: line) as? [String: Any],
              let result = object["result"] as? [String: Any] else { throw UsageProviderError.malformed }
        if expectedID == 1 {
            expectedID = 2
            return [Data("{\"method\":\"initialized\"}\n".utf8),
                    Data("{\"id\":2,\"method\":\"account/rateLimits/read\",\"params\":{\"excludeResetCreditDetails\":true}}\n".utf8)]
        }
        let raw = try JSONSerialization.data(withJSONObject: result)
        observation = try CodexUsageProvider.parse(raw, sourceID: sourceID, receivedAtMs: receivedAtMs)
        return []
    }
}
