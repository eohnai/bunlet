import Carbon.HIToolbox
import Foundation

/// The keys a shortcut can use, kept free of AppKit so rules and conflicts are testable.
enum ShortcutKey: String, CaseIterable, Identifiable {
    case a = "A", b = "B", c = "C", d = "D", e = "E", f = "F", g = "G", h = "H", i = "I", j = "J", k = "K", l = "L", m = "M"
    case n = "N", o = "O", p = "P", q = "Q", r = "R", s = "S", t = "T", u = "U", v = "V", w = "W", x = "X", y = "Y", z = "Z"
    case returnKey = "Return"
    case escape = "Esc"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .returnKey: "↩"
        default: rawValue
        }
    }

    /// Esc is never combined with a modifier, because Control-Esc is not a normal collapse key.
    var usesModifier: Bool { self != .escape }

    var code: UInt32 {
        switch self {
        case .a: UInt32(kVK_ANSI_A)
        case .b: UInt32(kVK_ANSI_B)
        case .c: UInt32(kVK_ANSI_C)
        case .d: UInt32(kVK_ANSI_D)
        case .e: UInt32(kVK_ANSI_E)
        case .f: UInt32(kVK_ANSI_F)
        case .g: UInt32(kVK_ANSI_G)
        case .h: UInt32(kVK_ANSI_H)
        case .i: UInt32(kVK_ANSI_I)
        case .j: UInt32(kVK_ANSI_J)
        case .k: UInt32(kVK_ANSI_K)
        case .l: UInt32(kVK_ANSI_L)
        case .m: UInt32(kVK_ANSI_M)
        case .n: UInt32(kVK_ANSI_N)
        case .o: UInt32(kVK_ANSI_O)
        case .p: UInt32(kVK_ANSI_P)
        case .q: UInt32(kVK_ANSI_Q)
        case .r: UInt32(kVK_ANSI_R)
        case .s: UInt32(kVK_ANSI_S)
        case .t: UInt32(kVK_ANSI_T)
        case .u: UInt32(kVK_ANSI_U)
        case .v: UInt32(kVK_ANSI_V)
        case .w: UInt32(kVK_ANSI_W)
        case .x: UInt32(kVK_ANSI_X)
        case .y: UInt32(kVK_ANSI_Y)
        case .z: UInt32(kVK_ANSI_Z)
        case .returnKey: UInt32(kVK_Return)
        case .escape: UInt32(kVK_Escape)
        }
    }
}

/// The one modifier shared by every shortcut that uses one.
enum ShortcutModifier: String, CaseIterable, Identifiable {
    case control, option, command

    var id: String { rawValue }

    var title: String {
        switch self {
        case .control: "Control ⌃"
        case .option: "Option ⌥"
        case .command: "Command ⌘"
        }
    }

    var symbol: String {
        switch self {
        case .control: "⌃"
        case .option: "⌥"
        case .command: "⌘"
        }
    }

    var carbonFlag: UInt32 {
        switch self {
        case .control: UInt32(controlKey)
        case .option: UInt32(optionKey)
        case .command: UInt32(cmdKey)
        }
    }
}

enum ShortcutRules {
    /// Display text such as ⌃I or Esc.
    static func label(_ key: ShortcutKey, modifier: ShortcutModifier) -> String {
        key.usesModifier ? modifier.symbol + key.title : key.title
    }

    /// Each shortcut that shares a key with another enabled shortcut. The list is sorted by raw value.
    static func conflicts<ID: Hashable & RawRepresentable>(_ keys: [ID: ShortcutKey?]) -> Set<ID> where ID.RawValue == String {
        var byKey: [ShortcutKey: [ID]] = [:]
        for (id, key) in keys {
            if let key { byKey[key, default: []].append(id) }
        }
        return Set(byKey.values.filter { $0.count > 1 }.flatMap { $0 })
    }
}
