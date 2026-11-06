import CoreFoundation
import Foundation

public struct PetPreferences {
    public static let defaultSize = 120.0
    public static let sizeRange = 64.0...256.0
    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public var size: Double {
        get {
            guard let value = defaults.object(forKey: "pet.size") as? Double,
                  value.isFinite, Self.sizeRange.contains(value) else { return Self.defaultSize }
            return value
        }
        set {
            let safe = newValue.isFinite && Self.sizeRange.contains(newValue) ? newValue : Self.defaultSize
            defaults.set(safe, forKey: "pet.size")
        }
    }

    public var soundEnabled: Bool {
        get {
            guard let value = defaults.object(forKey: "pet.soundEnabled") as? NSNumber,
                  CFGetTypeID(value) == CFBooleanGetTypeID() else { return false }
            return value.boolValue
        }
        set { defaults.set(newValue, forKey: "pet.soundEnabled") }
    }

    public var placement: PetSavedPlacement? {
        get {
            guard let data = defaults.data(forKey: "pet.placement.v1"), data.count <= 1024,
                  let saved = try? JSONDecoder().decode(PetSavedPlacement.self, from: data), saved.isValid else { return nil }
            return saved
        }
        set {
            guard let newValue, newValue.isValid, let data = try? JSONEncoder().encode(newValue) else { return }
            defaults.set(data, forKey: "pet.placement.v1")
        }
    }

}
