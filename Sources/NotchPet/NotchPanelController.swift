import AgentActions
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
    private var pointerInside = false
    private var pillDragStart: NSPoint?
    /// Returns true when a pet took over the drag; the island then hides for the pet.
    private let onPillDragOut: () -> Bool
    private var hoverTask: Task<Void, Never>?
    private var autoCloseTask: Task<Void, Never>?
    private var notificationObservation: ObservationLoop<[SessionSnapshot]>?
    private var lastSessions: [SessionSnapshot] = []
    private let sessionStore: SessionStore
    private let actions: LocalActionController?
    private let settings: BunletSettings
    private var settingsObservation: ObservationLoop<[String]>?
    private var shortcutObservation: ObservationLoop<[String]>?
    private let hotKeys = HotKeyCenter()
    private let navigation: TerminalNavigation?

    init(sessionStore: SessionStore, usageStore: UsageStore,
         features: FeatureSettingsModel, onOpenFeatures: @escaping () -> Void,
         actions: LocalActionController? = nil, navigation: TerminalNavigation? = nil,
         settings: BunletSettings,
         onOpenSettings: @escaping () -> Void = {}, onPillDragOut: @escaping () -> Bool = { false }) {
        self.sessionStore = sessionStore
        self.settings = settings
        self.navigation = navigation
        self.onPillDragOut = onPillDragOut
        self.actions = actions
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
                onExpand: { [weak self] expanded in self?.setExpanded(expanded) },
                isVisible: visible, isSleeping: asleep, navigation: navigation, actions: actions,
                beginInput: { [weak self] in self?.beginInput() }, endInput: { [weak self] in self?.endInput() },
                onOpenSettings: onOpenSettings, settings: settings)
        })
        updatePlacement()
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
                        self.cancelTimers()
                        self.state.expanded = false
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
        localMouseMonitor = NSEvent.addLocalMonitorForEvents(
            matching: [.mouseMoved, .leftMouseDown, .leftMouseDragged, .leftMouseUp]) { [weak self] event in
            let consumed = MainActor.assumeIsolated { () -> Bool in
                guard let self else { return false }
                switch event.type {
                case .leftMouseDown where event.window === self.panel:
                    self.pointerDown = true
                    // Pressing the closed pill arms the drag-out gesture and cancels hover-open.
                    if !self.state.expanded, self.pointerInside {
                        self.pillDragStart = NSEvent.mouseLocation
                        self.hoverTask?.cancel()
                        self.hoverTask = nil
                    }
                case .leftMouseDragged:
                    if let start = self.pillDragStart,
                       IslandGeometry.isPillDragOut(from: start, to: NSEvent.mouseLocation) {
                        self.pillDragStart = nil
                        // The island may hide now and never see this button's release.
                        self.pointerDown = false
                        return self.onPillDragOut()
                    }
                case .leftMouseUp:
                    self.pointerDown = false
                    self.pillDragStart = nil
                default:
                    break
                }
                self.updateMousePassThrough()
                return false
            }
            return consumed ? nil : event
        }
        // Screen choice and panel height change the window; following the active app needs app switches too.
        settingsObservation = ObservationLoop({ [settings] in
            [settings.islandDisplay.rawValue, String(settings.panelMaxHeight)]
        }) { [weak self] _ in self?.recover() }
        workspace.publisher(for: NSWorkspace.didActivateApplicationNotification)
            .receive(on: DispatchQueue.main).sink { [weak self] _ in
                MainActor.assumeIsolated {
                    guard let self, self.settings.islandDisplay == .automatic else { return }
                    self.recover()
                }
            }.store(in: &subscriptions)
        // Re-register shortcuts when their switches change or a request becomes answerable.
        shortcutObservation = ObservationLoop({ [settings, actions] in
            settings.enabledShortcuts.map(\.rawValue).sorted()
                + (actions?.store.snapshots.filter { $0.phase == .available }.map(\.id.uuidString) ?? [])
        }) { [weak self] _ in self?.updateHotKeys() }
        lastSessions = sessionStore.sessions
        notificationObservation = ObservationLoop({ [sessionStore] in sessionStore.sessions }) { [weak self] sessions in
            self?.sessionsChanged(sessions)
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
        pillDragStart = nil
        pointerInside = false
        notificationObservation?.cancel()
        notificationObservation = nil
        settingsObservation?.cancel()
        settingsObservation = nil
        shortcutObservation?.cancel()
        shortcutObservation = nil
        hotKeys.unregisterAll()
        cancelTimers()
        state.expanded = false
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
        setExpanded(true)
        updateVisibility()
        beginInput()
    }

    func setHiddenForPet(_ hidden: Bool) {
        hiddenForPet = hidden
        if hidden {
            cancelTimers()
            state.expanded = false
            endInput()
        }
        updateVisibility()
        updateHotKeys()
    }

    /// The closed pill in screen coordinates, where a dragged pet returns.
    var returnTarget: CGRect? {
        guard let screen = preferredScreen(), let window = windowFrame(on: screen) else { return nil }
        let spec = IslandShapeSpec(bodyWidth: state.pillWidth(sessions: sessionStore.sessions), bottom: state.headerHeight,
                                   topRadius: IslandMetrics.closedTopRadius, bottomRadius: IslandMetrics.closedBottomRadius)
        let width = spec.outerWidth(windowWidth: window.width)
        return CGRect(x: window.midX - width / 2, y: window.maxY - state.headerHeight, width: width, height: state.headerHeight)
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

    func windowDidBecomeKey(_ notification: Notification) {
        state.hasKeyboardFocus = true
        updateHotKeys()
    }

    func windowDidResignKey(_ notification: Notification) {
        state.hasKeyboardFocus = false
        previousApplication = nil
        updateHotKeys()
    }

    private func recover() {
        updatePlacement()
        updateVisibility()
    }

    private func updateVisibility() {
        let available = preferredScreen().flatMap { windowFrame(on: $0) } != nil
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

    /// Main display is the menu-bar screen. Automatic follows the screen holding the active app's front window.
    private func preferredScreen() -> NSScreen? {
        let screens = NSScreen.screens
        if settings.islandDisplay == .automatic, let screen = activeAppScreen(screens) { return screen }
        let previous = displayID.flatMap { wanted in screens.first(where: { identifier($0) == wanted }) }
        return screens.first ?? previous ?? NSScreen.main
    }

    /// Window bounds need no screen-recording permission; names and contents are never read.
    private func activeAppScreen(_ screens: [NSScreen]) -> NSScreen? {
        guard let pid = NSWorkspace.shared.frontmostApplication?.processIdentifier,
              let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID)
                as? [[String: Any]],
              let front = windows.first(where: {
                  ($0[kCGWindowOwnerPID as String] as? pid_t) == pid && ($0[kCGWindowLayer as String] as? Int) == 0
              }),
              let bounds = front[kCGWindowBounds as String] as? [String: CGFloat],
              let primary = screens.first else { return nil }
        // Window bounds use a top-left origin on the primary screen; NSScreen frames use bottom-left.
        let center = CGPoint(x: (bounds["X"] ?? 0) + (bounds["Width"] ?? 0) / 2,
                             y: primary.frame.maxY - (bounds["Y"] ?? 0) - (bounds["Height"] ?? 0) / 2)
        return screens.first { $0.frame.contains(center) }
    }

    private func cutoutWidth(_ screen: NSScreen) -> CGFloat {
        guard let left = screen.auxiliaryTopLeftArea, let right = screen.auxiliaryTopRightArea else { return 0 }
        return max(0, right.minX - left.maxX)
    }

    private func windowFrame(on screen: NSScreen) -> CGRect? {
        IslandGeometry.windowFrame(screen: screen.frame, safeTop: screen.safeAreaInsets.top,
                                   panelMaxHeight: settings.panelMaxHeight)
    }

    /// The window never moves while open or closed; only the shape inside it animates.
    private func updatePlacement() {
        guard let screen = preferredScreen(), let frame = windowFrame(on: screen) else {
            panel.orderOut(nil)
            return
        }
        displayID = identifier(screen)
        let notch = cutoutWidth(screen)
        state.hasNotch = screen.safeAreaInsets.top > 0 && notch > 0
        state.notchWidth = notch
        state.screenWidth = screen.frame.width
        state.headerHeight = IslandGeometry.headerHeight(safeTop: screen.safeAreaInsets.top,
                                                         menuBarHeight: screen.frame.maxY - screen.visibleFrame.maxY)
        state.windowWidth = frame.width
        state.windowHeight = frame.height
        state.panelMaxHeight = settings.panelMaxHeight
        panel.setFrame(frame, display: true)
        updateMousePassThrough()
    }

    func setExpanded(_ expanded: Bool) {
        autoCloseTask?.cancel()
        autoCloseTask = nil
        guard state.expanded != expanded else { return }
        state.expanded = expanded
        if !expanded { endInput() }
        updateMousePassThrough()
        updateHotKeys()
    }

    // MARK: Shortcuts (decision 0021)

    /// ⌃I works everywhere. Panel keys exist only while the panel is open, and ⌃Y/⌃N only while
    /// a permission can be answered here, so they don't take keys from the terminal the rest of the time.
    private func updateHotKeys() {
        let live = running && !sleeping
        let open = live && !hiddenForPet && state.expanded
        bind(.toggleIsland, .controlI, when: live) { [weak self] in self?.toggleIsland() }
        // While the panel has keyboard focus its own Escape handling applies.
        bind(.collapse, .escape, when: open && !state.hasKeyboardFocus) { [weak self] in self?.setExpanded(false) }
        let answerable = open && availablePermission != nil
        bind(.approve, .controlY, when: answerable) { [weak self] in self?.answerPermission(.approveOnce) }
        bind(.deny, .controlN, when: answerable) { [weak self] in self?.answerPermission(.deny) }
        bind(.jump, .controlReturn, when: open && navigation != nil) { [weak self] in self?.jumpToFocusedSession() }
    }

    private func bind(_ shortcut: BunletSettings.Shortcut, _ key: HotKeyCenter.Key, when active: Bool,
                      action: @escaping () -> Void) {
        if active && settings.isShortcutOn(shortcut) { hotKeys.register(key, action: action) } else { hotKeys.unregister(key) }
    }

    private func toggleIsland() {
        if state.expanded && !hiddenForPet { setExpanded(false) } else { openSessions() }
    }

    /// The first permission request with a verified local channel, in island order.
    private var availablePermission: ActionSnapshot? {
        guard let actions else { return nil }
        let order = NotchPresentation.ordered(sessionStore.sessions).map(\.key)
        return actions.store.snapshots
            .filter { $0.phase == .available && $0.offer.kind == .permission }
            .min { left, right in
                let a = order.firstIndex(of: SessionKey(agent: left.offer.provider, sessionID: left.offer.sessionID)) ?? .max
                let b = order.firstIndex(of: SessionKey(agent: right.offer.provider, sessionID: right.offer.sessionID)) ?? .max
                return a < b
            }
    }

    private func answerPermission(_ choice: ActionChoice) {
        guard let actions, let request = availablePermission else { return }
        actions.send(request.id, choice: choice)
    }

    private func jumpToFocusedSession() {
        guard let navigation else { return }
        let key = state.focusedSession.flatMap { key in sessionStore.sessions.contains { $0.key == key } ? key : nil }
            ?? NotchPresentation.ordered(sessionStore.sessions).first?.key
        guard let key, navigation.jump(to: key) else { return }
        setExpanded(false)
    }

    private func cancelTimers() {
        hoverTask?.cancel()
        hoverTask = nil
        autoCloseTask?.cancel()
        autoCloseTask = nil
    }

    /// Hover opens after 200 ms; leaving an open island closes it after 300 ms unless the user is typing.
    private func pointerInsideChanged(_ inside: Bool) {
        hoverTask?.cancel()
        hoverTask = nil
        if inside {
            autoCloseTask?.cancel()
            autoCloseTask = nil
            guard !state.expanded else { return }
            hoverTask = Task { [weak self] in
                try? await Task.sleep(for: IslandMetrics.hoverOpenDelay)
                guard !Task.isCancelled, let self, self.pointerInside else { return }
                if self.settings.hapticFeedback {
                    NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .now)
                }
                self.setExpanded(true)
            }
        } else if state.expanded, !state.hasKeyboardFocus, settings.collapseOnMouseLeave {
            hoverTask = Task { [weak self] in
                try? await Task.sleep(for: IslandMetrics.leaveCloseDelay)
                guard !Task.isCancelled, let self, !self.pointerInside, !self.state.hasKeyboardFocus else { return }
                self.setExpanded(false)
            }
        }
    }

    /// New approvals, questions and completions play their sounds and, if the Behavior settings allow,
    /// open the island without taking focus.
    private func sessionsChanged(_ sessions: [SessionSnapshot]) {
        defer { lastSessions = sessions }
        guard running, !sleeping else { return }
        if !IslandAutoOpen.newSessions(previous: lastSessions, current: sessions).isEmpty { settings.play(.sessionStart) }
        guard let notification = IslandNotification.next(previous: lastSessions, current: sessions) else { return }
        switch notification {
        case .attention: settings.play(.actionNeeded)
        case .completed: settings.play(.taskComplete)
        }
        guard !hiddenForPet,
              IslandAutoOpen.shouldOpen(notification, expandOnActionNeeded: settings.expandOnActionNeeded,
                                        expandOnSessionEnd: settings.expandOnSessionEnd,
                                        focusAwareSuppression: settings.focusAwareSuppression,
                                        frontmostBundleID: NSWorkspace.shared.frontmostApplication?.bundleIdentifier)
        else { return }
        let wasExpanded = state.expanded
        state.focusedSession = notification.key
        setExpanded(true)
        guard !wasExpanded || autoCloseTask == nil else { return }
        if case .attention(let key) = notification, hasLocalResponse(for: key) { return }
        autoCloseTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(self?.settings.reminderSeconds ?? 5))
            guard !Task.isCancelled, let self, !self.pointerInside, !self.state.hasKeyboardFocus else { return }
            self.setExpanded(false)
        }
    }

    /// A request the user can answer here stays open; terminal-only requests close on their own.
    private func hasLocalResponse(for key: SessionKey) -> Bool {
        actions?.store.snapshots.contains {
            SessionKey(agent: $0.offer.provider, sessionID: $0.offer.sessionID) == key && $0.phase == .available
        } == true
    }

    private func updateMousePassThrough() {
        guard !pointerDown else { return }
        let local = panel.convertPoint(fromScreen: NSEvent.mouseLocation)
        // AppKit's origin is bottom-left; the shape uses a top-left origin.
        let point = CGPoint(x: local.x, y: panel.frame.height - local.y)
        let inside = panel.isVisible && state.shape(sessions: sessionStore.sessions)
            .path(windowWidth: panel.frame.width).contains(point)
        panel.ignoresMouseEvents = !inside
        if inside != pointerInside {
            pointerInside = inside
            pointerInsideChanged(inside)
        }
    }
}

private final class ActionNotchPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}
