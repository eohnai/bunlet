import Foundation

public enum JSONPathComponent: Hashable, Sendable {
    case key(String)
    case index(Int)
}

/// Validated original bytes and value locations; never round-trips unrelated JSON through Double.
public struct HookConfigurationJSON: Sendable {
    public let data: Data
    private let ranges: [[JSONPathComponent]: Range<Int>]
    private let childMembers: [[JSONPathComponent]: [JSONPathComponent]]

    public init(data: Data) throws {
        guard data.count <= HookEnvelopeV1.rawHookLimit else { throw BridgeError.invalidMessage }
        var parser = StrictJSON(data: data, maxDepth: 64, captureRanges: true)
        guard case .object = try parser.parse() else { throw BridgeError.invalidMessage }
        self.data = Data(Array(data))
        self.ranges = parser.ranges
        self.childMembers = parser.childMembers
    }

    public func range(at path: [JSONPathComponent]) -> Range<Int>? {
        ranges[path]
    }

    public func rawValue(at path: [JSONPathComponent]) -> Data? {
        ranges[path].map { Data(data[$0]) }
    }

    /// Container members in source order; nil distinguishes scalars and missing paths.
    public func members(at path: [JSONPathComponent]) -> [JSONPathComponent]? {
        childMembers[path]
    }
}
