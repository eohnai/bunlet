import Darwin
import Foundation

/// Optional adapter using public iTerm2 scripting identifiers, without executable scripts.
struct ITermPaneAdapter: TerminalPaneAdapter {
    let applicationIdentifier = "com.googlecode.iterm2"

    func currentPane(processID: pid_t) async -> TerminalPaneIdentity? {
        let worker = Task.detached(priority: .userInitiated) {
            PaneEvents(processID: processID).currentPane()
        }
        return await withTaskCancellationHandler(operation: { await worker.value }, onCancel: { worker.cancel() })
    }

    func focus(_ pane: TerminalPaneIdentity, processID: pid_t) async -> Bool {
        let worker = Task.detached(priority: .userInitiated) {
            PaneEvents(processID: processID).focus(pane)
        }
        return await withTaskCancellationHandler(operation: { await worker.value }, onCancel: { worker.cancel() })
    }
}

/// All descriptors stay inside one worker. PID addressing cannot relaunch an exited application.
private struct PaneEvents {
    private let target: NSAppleEventDescriptor
    private let deadline = DispatchTime.now().uptimeNanoseconds + 3_000_000_000
    private static let replyLimit = 65_536
    private static let identityLimit = 256
    private static let windowLimit = 64
    private static let collectionLimit = 128
    private static let paneLimit = 512

    init(processID: pid_t) {
        target = NSAppleEventDescriptor(processIdentifier: processID)
    }

    func currentPane() -> TerminalPaneIdentity? {
        guard let window = property("Crwn", of: nil),
              let session = property("Wcsn", of: window) else { return nil }
        return identity(session)
    }

    func focus(_ pane: TerminalPaneIdentity) -> Bool {
        guard valid(pane.id), valid(pane.tty), pane.tty.hasPrefix("/dev/"),
              let windows = elements("cwin", of: nil, limit: Self.windowLimit) else { return false }
        var match: (NSAppleEventDescriptor, NSAppleEventDescriptor, NSAppleEventDescriptor)?
        var count = 0
        for window in windows {
            guard let tabs = elements("Trmt", of: window, limit: Self.collectionLimit) else { return false }
            for tab in tabs {
                guard let sessions = elements("Trms", of: tab, limit: Self.collectionLimit) else { return false }
                for session in sessions {
                    count += 1
                    guard count <= Self.paneLimit, let found = identity(session) else { return false }
                    if equal(found, pane) {
                        guard match == nil else { return false }
                        match = (window, tab, session)
                    }
                }
            }
        }
        guard let (window, tab, session) = match, let found = identity(session), equal(found, pane),
              select(session), select(tab), select(window), let actual = currentPane() else { return false }
        return equal(actual, pane)
    }

    private func identity(_ session: NSAppleEventDescriptor) -> TerminalPaneIdentity? {
        guard let id = property("Uniq", of: session)?.stringValue,
              let tty = property("Stty", of: session)?.stringValue,
              valid(id), valid(tty), tty.hasPrefix("/dev/") else { return nil }
        return TerminalPaneIdentity(id: id, tty: tty)
    }

    private func equal(_ lhs: TerminalPaneIdentity, _ rhs: TerminalPaneIdentity) -> Bool {
        lhs.id.utf8.elementsEqual(rhs.id.utf8) && lhs.tty.utf8.elementsEqual(rhs.tty.utf8)
    }

    private func valid(_ value: String) -> Bool {
        !value.isEmpty && value.utf8.count <= Self.identityLimit &&
            !value.unicodeScalars.contains { $0.properties.generalCategory == .control }
    }

    private func property(_ code: String, of parent: NSAppleEventDescriptor?) -> NSAppleEventDescriptor? {
        guard let object = specifier(want: "prop", form: "prop",
            selector: NSAppleEventDescriptor(typeCode: Self.code(code)), parent: parent),
              let reply = send("core", "getd", object: object) else { return nil }
        return reply.paramDescriptor(forKeyword: Self.code("----"))
    }

    private func elements(_ kind: String, of parent: NSAppleEventDescriptor?, limit: Int) -> [NSAppleEventDescriptor]? {
        guard let object = specifier(want: kind, form: "indx",
            selector: NSAppleEventDescriptor(enumCode: Self.code("all ")), parent: parent),
              let reply = send("core", "getd", object: object),
              let list = reply.paramDescriptor(forKeyword: Self.code("----")),
              list.descriptorType == Self.code("list"), list.numberOfItems <= limit else { return nil }
        guard list.numberOfItems > 0 else { return [] }
        var result: [NSAppleEventDescriptor] = []
        for index in 1...list.numberOfItems {
            guard let item = list.atIndex(index), item.descriptorType == Self.code("obj ") else { return nil }
            result.append(item)
        }
        return result
    }

    private func select(_ object: NSAppleEventDescriptor) -> Bool {
        send("Itrm", "slct", object: object) != nil
    }

    private func specifier(want: String, form: String, selector: NSAppleEventDescriptor,
        parent: NSAppleEventDescriptor?) -> NSAppleEventDescriptor? {
        let record = NSAppleEventDescriptor.record()
        record.setDescriptor(NSAppleEventDescriptor(typeCode: Self.code(want)), forKeyword: Self.code("want"))
        record.setDescriptor(NSAppleEventDescriptor(enumCode: Self.code(form)), forKeyword: Self.code("form"))
        record.setDescriptor(selector, forKeyword: Self.code("seld"))
        record.setDescriptor(parent ?? NSAppleEventDescriptor.null(), forKeyword: Self.code("from"))
        return record.coerce(toDescriptorType: Self.code("obj "))
    }

    private func send(_ eventClass: String, _ eventID: String,
        object: NSAppleEventDescriptor) -> NSAppleEventDescriptor? {
        let now = DispatchTime.now().uptimeNanoseconds
        guard !Task.isCancelled, now < deadline else { return nil }
        let event = NSAppleEventDescriptor(eventClass: Self.code(eventClass), eventID: Self.code(eventID),
            targetDescriptor: target, returnID: -1, transactionID: 0)
        event.setParam(object, forKeyword: Self.code("----"))
        guard let reply = try? event.sendEvent(options: [.waitForReply, .neverInteract],
            timeout: Double(deadline - now) / 1_000_000_000),
              !Task.isCancelled, DispatchTime.now().uptimeNanoseconds < deadline,
              reply.data.count <= Self.replyLimit else { return nil }
        if let error = reply.paramDescriptor(forKeyword: Self.code("errn")), error.int32Value != 0 { return nil }
        return reply
    }

    private static func code(_ value: String) -> UInt32 {
        value.utf8.reduce(0) { ($0 << 8) | UInt32($1) }
    }
}
