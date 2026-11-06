import AppKit
import Combine
import QuartzCore
import SessionState
import SwiftUI
import Usage

@MainActor
final class NotchPanelController: NSObject, AppFeatureService, NSWindowDelegate {
    private let panel: NSPanel
    private let state = NotchWindowState()
    private var hiddenForPet = false
    private var running = false
    private var sleeping = false
    private var displayID: UInt32?
    private var previousApplication: NSRunningApplication?
    private var subscriptions: Set<AnyCancellable> = []
    private var globalMouseMonitor: Any?
    private var localMouseMonitor: Any?
    private var pointerDown = false

    init(sessionStore: SessionStore, usageStore: UsageStore,
         features: FeatureSettingsModel, onOpenFeatures: @escaping () -> Void,
         actions: LocalActionController? = nil, navigation: TerminalNavigation? = nil) {
        panel = ActionNotchPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel],
                                backing: .buffered, defer: false)
        super.init()
        panel.title = "Bunlet Sessions"
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.level = .statusBar
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.becomesKeyOnlyIfNeeded = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.tabbingMode = .disallowed
        panel.delegate = self
        panel.contentView = NSHostingView(rootView: PetWindowPlayback(window: panel) { [state, weak self] visible, asleep in
            NotchSessionView(sessionStore: sessionStore, usageStore: usageStore, features: features,
                onOpenFeatures: onOpenFeatures, windowState: state,
                onExpand: { [weak self] expanded in self?.updatePlacement(expanded: expanded) },
                isVisible: visible, isSleeping: asleep, navigation: navigation, actions: actions,
                beginInput: { [weak self] in self?.beginInput() }, endInput: { [weak self] in self?.endInput() })
        })
        updatePlacement(expanded: false)
    }

    func start() {
        guard !running else { return }
        running = true
        let notifications = NotificationCenter.default
        let workspace = NSWorkspace.shared.notificationCenter
        notifications.publisher(for: NSApplication.didChangeScreenParametersNotification)
            .receive(on: DispatchQueue.main).sink { [weak self] _ in
                MainActor.assumeIsolated { self?.recover() }
            }.store(in: &subscriptions)
        Publishers.Merge3(workspace.publisher(for: NSWorkspace.willSleepNotification),
                          workspace.publisher(for: NSWorkspace.didWakeNotification),
                          workspace.publisher(for: NSWorkspace.activeSpaceDidChangeNotification))
            .receive(on: DispatchQueue.main).sink { [weak self] note in
                MainActor.assumeIsolated {
                    guard let self else { return }
                    if note.name == NSWorkspace.willSleepNotification {
                        self.sleeping = true
                        self.endInput(restore: false)
                        self.updateVisibility()
                    } else {
                        self.sleeping = false
                        self.recover()
                    }
                }
            }.store(in: &subscriptions)
        globalMouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved, .leftMouseUp]) { [weak self] event in
            MainActor.assumeIsolated {
                if event.type == .leftMouseUp { self?.pointerDown = false }
                self?.updateMousePassThrough()
            }
        }
        localMouseMonitor = NSEvent.addLocalMonitorForEvents(matching: [.mouseMoved, .leftMouseDown, .leftMouseUp]) { [weak self] event in
            MainActor.assumeIsolated {
                guard let self else { return }
                if event.type == .leftMouseDown, event.window === self.panel { self.pointerDown = true }
                if event.type == .leftMouseUp { self.pointerDown = false }
                self.updateMousePassThrough()
            }
            return event
        }
        recover()
    }

    func stop() {
        running = false
        subscriptions.removeAll()
        if let globalMouseMonitor { NSEvent.removeMonitor(globalMouseMonitor) }
        if let localMouseMonitor { NSEvent.removeMonitor(localMouseMonitor) }
        globalMouseMonitor = nil
        localMouseMonitor = nil
        pointerDown = false
        endInput()
        panel.orderOut(nil)
    }

    func show() {
        hiddenForPet = false
        recover()
    }

    /// Explicit menu/Settings action, enabling native keyboard navigation without waiting for an alert.
    func openSessions() {
        hiddenForPet = false
        updatePlacement(expanded: true)
        updateVisibility()
        beginInput()
    }

    func setHiddenForPet(_ hidden: Bool) {
        hiddenForPet = hidden
        if hidden { endInput() }
        updateVisibility()
    }

    var returnTarget: CGRect? {
        guard let screen = preferredScreen() else { return nil }
        return frame(on: screen, expanded: false)
    }

    private func beginInput() {
        guard running, !sleeping, !hiddenForPet, panel.isVisible else { return }
        if NSWorkspace.shared.frontmostApplication?.processIdentifier != ProcessInfo.processInfo.processIdentifier {
            previousApplication = NSWorkspace.shared.frontmostApplication
        }
        // Incoming observations never call this method.
        NSApplication.shared.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
    }

    private func endInput(restore: Bool = true) {
        let ownedFocus = panel.isKeyWindow && NSWorkspace.shared.frontmostApplication?.processIdentifier == ProcessInfo.processInfo.processIdentifier
        let previous = previousApplication
        previousApplication = nil
        panel.resignKey()
        state.hasKeyboardFocus = false
        if restore, ownedFocus, let previous, !previous.isTerminated {
            _ = previous.activate(options: [])
        }
    }

    func windowDidBecomeKey(_ notification: Notification) { state.hasKeyboardFocus = true }

    func windowDidResignKey(_ notification: Notification) {
        state.hasKeyboardFocus = false
        previousApplication = nil
    }

    private func recover() {
        updatePlacement(expanded: state.expanded)
        updateVisibility()
    }

    private func updateVisibility() {
        let available = preferredScreen().flatMap { frame(on: $0, expanded: state.expanded) } != nil
        if running && !sleeping && !hiddenForPet && available {
            panel.orderFrontRegardless()
            updateMousePassThrough()
        } else {
            pointerDown = false
            panel.orderOut(nil)
        }
    }

    private func identifier(_ screen: NSScreen) -> UInt32? {
        (screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value
    }

    private func preferredScreen() -> NSScreen? {
        let screens = NSScreen.screens
        let previous = displayID.flatMap { wanted in screens.first(where: { identifier($0) == wanted }) }
        return screens.first(where: { $0.safeAreaInsets.top > 0 }) ?? previous ?? NSScreen.main
    }

    private func cutoutWidth(_ screen: NSScreen) -> CGFloat {
        guard let left = screen.auxiliaryTopLeftArea, let right = screen.auxiliaryTopRightArea else { return 0 }
        return max(0, right.minX - left.maxX)
    }

    private func frame(on screen: NSScreen, expanded: Bool) -> CGRect? {
        NotchPlacement.frame(screen: screen.frame, safeTop: screen.safeAreaInsets.top,
                             notchWidth: cutoutWidth(screen), expanded: expanded)
    }

    func updatePlacement(expanded: Bool) {
        state.expanded = expanded
        guard let screen = preferredScreen(), let frame = frame(on: screen, expanded: expanded) else {
            panel.orderOut(nil)
            return
        }
        displayID = identifier(screen)
        state.headerHeight = max(32, screen.safeAreaInsets.top)
        state.notchWidth = min(cutoutWidth(screen), max(0, frame.width - 48))
        if !expanded { endInput() }
        if panel.isVisible && !sleeping && !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.24
                context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                panel.animator().setFrame(frame, display: true)
            }
        } else { panel.setFrame(frame, display: true) }
        updateMousePassThrough()
    }

    private func updateMousePassThrough() {
        guard !pointerDown else { return }
        let point = panel.convertPoint(fromScreen: NSEvent.mouseLocation)
        let bounds = CGRect(origin: .zero, size: panel.frame.size)
        let radius: CGFloat = state.expanded ? 24 : 16
        var contains = bounds.contains(point)
        // Upper corners extend above the screen edge; only the lower corners are transparent.
        if contains, point.y < radius {
            if point.x < radius { contains = hypot(point.x - radius, point.y - radius) <= radius }
            else if point.x > bounds.maxX - radius {
                contains = hypot(point.x - (bounds.maxX - radius), point.y - radius) <= radius
            }
        }
        panel.ignoresMouseEvents = !contains
    }
}

private final class ActionNotchPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}
