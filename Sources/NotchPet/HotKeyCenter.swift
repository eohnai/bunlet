import Carbon.HIToolbox
import Foundation

/// System-wide hot keys through the Carbon event API, which needs no Accessibility or Input Monitoring permission.
/// Each key is registered only while it should work, so panel keys never shadow other apps while the panel is closed.
@MainActor
final class HotKeyCenter {
    struct Key: Hashable {
        let code: UInt32
        let modifiers: UInt32

        static let controlI = Key(code: UInt32(kVK_ANSI_I), modifiers: UInt32(controlKey))
        static let escape = Key(code: UInt32(kVK_Escape), modifiers: 0)
        static let controlY = Key(code: UInt32(kVK_ANSI_Y), modifiers: UInt32(controlKey))
        static let controlN = Key(code: UInt32(kVK_ANSI_N), modifiers: UInt32(controlKey))
        static let controlReturn = Key(code: UInt32(kVK_Return), modifiers: UInt32(controlKey))
    }

    private static let signature: OSType = 0x424E_4C54 // "BNLT"
    private var registered: [UInt32: (ref: EventHotKeyRef, key: Key, action: () -> Void)] = [:]
    private var nextID: UInt32 = 1
    private var handler: EventHandlerRef?

    init() {
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let context = Unmanaged.passUnretained(self).toOpaque()
        InstallEventHandler(GetApplicationEventTarget(), { _, event, context in
            guard let event, let context else { return OSStatus(eventNotHandledErr) }
            var identity = EventHotKeyID()
            let status = GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID),
                                           nil, MemoryLayout<EventHotKeyID>.size, nil, &identity)
            guard status == noErr, identity.signature == HotKeyCenter.signature else { return OSStatus(eventNotHandledErr) }
            let center = Unmanaged<HotKeyCenter>.fromOpaque(context).takeUnretainedValue()
            // The application event target delivers on the main thread.
            MainActor.assumeIsolated { center.fire(identity.id) }
            return noErr
        }, 1, &spec, context, &handler)
    }

    /// Registers the key unless it is already registered. Returns false when another app owns it.
    @discardableResult
    func register(_ key: Key, action: @escaping () -> Void) -> Bool {
        if let existing = registered.first(where: { $0.value.key == key }) {
            registered[existing.key]?.action = action
            return true
        }
        var ref: EventHotKeyRef?
        let id = nextID
        nextID &+= 1
        let status = RegisterEventHotKey(key.code, key.modifiers, EventHotKeyID(signature: Self.signature, id: id),
                                         GetApplicationEventTarget(), 0, &ref)
        guard status == noErr, let ref else { return false }
        registered[id] = (ref, key, action)
        return true
    }

    func unregister(_ key: Key) {
        for (id, entry) in registered where entry.key == key {
            UnregisterEventHotKey(entry.ref)
            registered.removeValue(forKey: id)
        }
    }

    func unregisterAll() {
        for entry in registered.values { UnregisterEventHotKey(entry.ref) }
        registered.removeAll()
    }

    private func fire(_ id: UInt32) {
        registered[id]?.action()
    }
}
