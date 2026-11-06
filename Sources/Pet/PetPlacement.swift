import Foundation

public struct PetSavedPlacement: Codable, Equatable, Sendable {
    public let displayID: UInt32
    public let x: Double
    public let y: Double
    public let detached: Bool

    public init?(displayID: UInt32, x: Double, y: Double, detached: Bool) {
        guard x.isFinite, y.isFinite, (0...1).contains(x), (0...1).contains(y) else { return nil }
        self.displayID = displayID
        self.x = x
        self.y = y
        self.detached = detached
    }

    public var isValid: Bool { x.isFinite && y.isFinite && (0...1).contains(x) && (0...1).contains(y) }
}

public enum PetPlacement {
    public static func clamped(_ frame: CGRect, in visible: CGRect) -> CGRect {
        let width = min(max(1, frame.width), max(1, visible.width))
        let height = min(max(1, frame.height), max(1, visible.height))
        let x = frame.minX.isFinite ? frame.minX : visible.minX
        let y = frame.minY.isFinite ? frame.minY : visible.minY
        return CGRect(x: min(max(x, visible.minX), visible.maxX - width),
                      y: min(max(y, visible.minY), visible.maxY - height), width: width, height: height)
    }

    public static func restored(_ saved: PetSavedPlacement?, in visible: CGRect, size: CGSize) -> CGRect {
        let x = saved?.isValid == true ? saved?.x ?? 1 : 1
        let y = saved?.isValid == true ? saved?.y ?? 0 : 0
        return clamped(CGRect(x: visible.minX + x * max(0, visible.width - size.width),
                              y: visible.minY + y * max(0, visible.height - size.height),
                              width: size.width, height: size.height), in: visible)
    }
}
