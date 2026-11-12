import AppKit
import Combine
import Observation
import Pet
import SwiftUI

@MainActor
@Observable
private final class PetSurfaceState {
    var mood: PetMood = .idle
    var cue = false
    var dragging = false
    var size: Double
    var presentation: PetPresentation

    init(size: Double, presentation: PetPresentation) {
        self.size = size
        self.presentation = presentation
    }

    var pose: PetPose {
        if mood == .attention || mood == .unknown { return mood.pose }
        if dragging { return .drag }
        return cue ? .complete : mood.pose
    }
}

@MainActor
private struct PetSurfaceView: View {
    let state: PetSurfaceState
    let visible: Bool
    let sleeping: Bool
    let onFrame: (NSImage?) -> Void

    /// The speech bubble sits above the pet; clicking it toggles the session panel.
    var body: some View {
        VStack(spacing: 4) {
            if state.mood != .idle {
                Text(state.mood.label)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(bubbleColor)
                    .lineLimit(1).minimumScaleFactor(0.7)
                    .padding(.horizontal, 8).frame(height: 22)
                    .background(Color(red: 18 / 255, green: 19 / 255, blue: 20 / 255).opacity(0.9), in: Capsule())
                    .overlay { Capsule().strokeBorder(.white.opacity(0.1), lineWidth: 1) }
                    .frame(height: 26)
                    .accessibilityAddTraits(.isButton)
                    .accessibilityHint("Shows sessions")
            } else { Color.clear.frame(height: 26) }
            PetView(presentation: state.presentation, pose: state.pose, isVisible: visible,
                    isSleeping: sleeping, onFrameImage: onFrame)
                .frame(width: state.size, height: state.size)
        }
    }

    private var bubbleColor: Color {
        switch state.mood {
        case .attention: IslandPalette.attention
        case .responseReady: IslandPalette.completed
        case .unknown: IslandPalette.unknown
        case .ended: IslandPalette.mutedText
        case .working, .idle: .white.opacity(0.9)
        }
    }
}

/// Transparent pixels do not own input. A native drag never activates this panel.
@MainActor
private final class PetDragView: NSView {
    var onBegin: (() -> Void)?
    var onDrop: (() -> Void)?
    var onImageChange: (() -> Void)?
    var onBadgeClick: (() -> Void)?
    var showsBadge = false
    private var image: NSImage?
    private var bitmap: NSBitmapImageRep?
    private var dragStart: NSPoint?
    private var initialOrigin: NSPoint = .zero
    private var moved = false

    func setImage(_ image: NSImage?) {
        self.image = image
        bitmap = image?.cgImage(forProposedRect: nil, context: nil, hints: nil).map { NSBitmapImageRep(cgImage: $0) }
        onImageChange?()
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        accepts(convert(point, from: superview)) ? self : nil
    }

    func accepts(_ local: NSPoint) -> Bool {
        guard bounds.contains(local) else { return false }
        if showsBadge && isBadge(local) { return true }
        let art = NSRect(x: 0, y: 0, width: bounds.width, height: max(0, bounds.height - 30))
        guard let image, let bitmap, image.size.width > 0, image.size.height > 0 else {
            return art.insetBy(dx: art.width * 0.2, dy: art.height * 0.2).contains(local)
        }
        let scale = min(art.width / image.size.width, art.height / image.size.height)
        let fitted = NSRect(x: art.midX - image.size.width * scale / 2,
                            y: art.midY - image.size.height * scale / 2,
                            width: image.size.width * scale, height: image.size.height * scale)
        guard fitted.contains(local), fitted.width > 0, fitted.height > 0 else { return false }
        let x = min(bitmap.pixelsWide - 1, max(0, Int((local.x - fitted.minX) / fitted.width * Double(bitmap.pixelsWide))))
        let y = min(bitmap.pixelsHigh - 1, max(0, Int((fitted.maxY - local.y) / fitted.height * Double(bitmap.pixelsHigh))))
        return (bitmap.colorAt(x: x, y: y)?.alphaComponent ?? 0) > 0.08
    }

    private func isBadge(_ local: NSPoint) -> Bool { local.y >= bounds.height - 26 }

    override func mouseDown(with event: NSEvent) {
        dragStart = NSEvent.mouseLocation
        initialOrigin = window?.frame.origin ?? .zero
        moved = false
    }

    override func mouseDragged(with event: NSEvent) {
        guard let start = dragStart, let window else { return }
        let current = NSEvent.mouseLocation
        if !moved {
            guard hypot(current.x - start.x, current.y - start.y) >= 3 else { return }
            moved = true
            onBegin?()
        }
        window.setFrameOrigin(NSPoint(x: initialOrigin.x + current.x - start.x,
                                      y: initialOrigin.y + current.y - start.y))
    }

    override func mouseUp(with event: NSEvent) {
        dragStart = nil
        if moved {
            onDrop?()
        } else if showsBadge, isBadge(convert(event.locationInWindow, from: nil)) {
            onBadgeClick?()
        }
        moved = false
    }
}

@MainActor
final class PetPanelController: AppFeatureService {
    private let panel: NSPanel
    private let state: PetSurfaceState
    private let dragView: PetDragView
    private var preferences: PetPreferences
    private let onDragBegan: () -> Void
    private let returnTarget: () -> CGRect?
    private let onReturn: () -> Void
    private let onHide: () -> Void
    private var subscriptions: Set<AnyCancellable> = []
    private var cueTask: Task<Void, Never>?
    private var sleeping = false
    private var running = false
    private var detached: Bool
    private var globalMouseMonitor: Any?
    private var localMouseMonitor: Any?
    private var followTimer: Timer?
    var isDetached: Bool { detached }

    init?(size: Double, defaults: UserDefaults = .standard, presentation selected: PetPresentation? = nil,
          onDragBegan: @escaping () -> Void = {},
          returnTarget: @escaping () -> CGRect? = { nil }, onReturn: @escaping () -> Void = {},
          onBadgeClick: @escaping () -> Void = {}, onHide: @escaping () -> Void = {}) {
        self.onHide = onHide
        guard let presentation = selected ?? PetArtwork.presentation() else { return nil }
        preferences = PetPreferences(defaults: defaults)
        detached = preferences.placement?.detached ?? false
        self.onDragBegan = onDragBegan
        self.returnTarget = returnTarget
        self.onReturn = onReturn
        state = PetSurfaceState(size: size, presentation: presentation)
        panel = NSPanel(contentRect: NSRect(x: 0, y: 0, width: size, height: size + 30),
                        styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.title = presentation.name
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.level = .statusBar
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.becomesKeyOnlyIfNeeded = true
        panel.ignoresMouseEvents = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        dragView = PetDragView(frame: NSRect(x: 0, y: 0, width: size, height: size + 30))
        let host = NSHostingView(rootView: PetWindowPlayback(window: panel) { [state, weak dragView] visible, sleeping in
            PetSurfaceView(state: state, visible: visible, sleeping: sleeping,
                onFrame: { [weak dragView] in dragView?.setImage($0) })
        })
        host.frame = dragView.bounds
        host.autoresizingMask = [.width, .height]
        dragView.addSubview(host)
        panel.contentView = dragView
        dragView.onBegin = { [weak self] in
            guard let self else { return }
            self.detached = true
            self.state.dragging = true
            self.onDragBegan()
        }
        dragView.onDrop = { [weak self] in self?.finishDrag() }
        dragView.onBadgeClick = onBadgeClick
        dragView.onImageChange = { [weak self] in self?.updateMousePassThrough() }
        restorePlacement()
    }

    /// A returned pet lives inside the island and has no window of its own until it is pulled out again.
    /// Without an island (Notch not installed or no usable display) it always stays on the desktop.
    private var docked: Bool { !detached && returnTarget() != nil }

    /// Shows the pet window, or keeps it hidden while docked. Also re-evaluates docking when the island appears or goes away.
    func show() {
        guard running && !sleeping else { return }
        if docked {
            panel.orderOut(nil)
            onHide()
        } else {
            panel.orderFrontRegardless()
            updateMousePassThrough()
        }
    }

    /// Show Pet: a docked pet comes back out to its last desktop spot, which hides the island as dragging out does.
    func reveal() {
        guard running && !sleeping else { return }
        if docked {
            detached = true
            restorePlacement()
            savePlacement()
            onDragBegan()
        }
        show()
    }

    func start() {
        guard !running else { return }
        running = true
        globalMouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: .mouseMoved) { [weak self] _ in
            MainActor.assumeIsolated { self?.updateMousePassThrough() }
        }
        localMouseMonitor = NSEvent.addLocalMonitorForEvents(matching: .mouseMoved) { [weak self] event in
            MainActor.assumeIsolated { self?.updateMousePassThrough() }
            return event
        }
        let local = NotificationCenter.default
        let workspace = NSWorkspace.shared.notificationCenter
        local.publisher(for: NSWindow.didChangeOcclusionStateNotification)
            .receive(on: DispatchQueue.main).sink { [weak self] note in
                MainActor.assumeIsolated {
                    guard let self, note.object as? NSWindow === self.panel else { return }
                    if !self.panel.occlusionState.contains(.visible) { self.cancelCue() }
                }
            }.store(in: &subscriptions)
        local.publisher(for: NSApplication.didChangeScreenParametersNotification)
            .receive(on: DispatchQueue.main).sink { [weak self] _ in
                MainActor.assumeIsolated { self?.restorePlacement() }
            }.store(in: &subscriptions)
        Publishers.Merge3(workspace.publisher(for: NSWorkspace.willSleepNotification),
                          workspace.publisher(for: NSWorkspace.didWakeNotification),
                          workspace.publisher(for: NSWorkspace.activeSpaceDidChangeNotification))
            .receive(on: DispatchQueue.main).sink { [weak self] note in
                MainActor.assumeIsolated {
                    guard let self else { return }
                    if note.name == NSWorkspace.willSleepNotification {
                        self.sleeping = true
                        self.stopFollowing()
                        self.state.dragging = false
                        self.cancelCue()
                        self.panel.orderOut(nil)
                        self.onHide()
                    } else {
                        self.sleeping = false
                        self.restorePlacement()
                        self.show()
                    }
                }
            }.store(in: &subscriptions)
        if detached { onDragBegan() }
        show()
    }

    func stop() {
        stopFollowing()
        running = false
        subscriptions.removeAll()
        if let globalMouseMonitor { NSEvent.removeMonitor(globalMouseMonitor) }
        if let localMouseMonitor { NSEvent.removeMonitor(localMouseMonitor) }
        globalMouseMonitor = nil
        localMouseMonitor = nil
        cancelCue()
        panel.orderOut(nil)
        onHide()
    }

    /// Drag-out from the island pill: the pet detaches and follows the pointer until the button is released.
    /// The island hides mid-drag, so release is read from the button state rather than from events it would own.
    func beginPointerDrag() -> Bool {
        guard running, !sleeping, followTimer == nil else { return false }
        detached = true
        state.dragging = true
        onDragBegan()
        // Place the pet under the pointer before it appears, so a docked pet does not flash at an old spot.
        moveToPointer()
        show()
        let timer = Timer(timeInterval: 1.0 / 60, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.followPointer() }
        }
        RunLoop.main.add(timer, forMode: .common)
        followTimer = timer
        return true
    }

    private func followPointer() {
        guard NSEvent.pressedMouseButtons & 1 != 0 else {
            stopFollowing()
            finishDrag()
            return
        }
        moveToPointer()
    }

    private func stopFollowing() {
        followTimer?.invalidate()
        followTimer = nil
    }

    /// Centers the artwork, which fills the lower part of the window below the bubble, on the pointer.
    private func moveToPointer() {
        let pointer = NSEvent.mouseLocation
        let frame = panel.frame
        panel.setFrameOrigin(NSPoint(x: pointer.x - frame.width / 2, y: pointer.y - state.size / 2))
    }

    /// Where the session panel anchors. Nil while hidden.
    var frameOnScreen: CGRect? { panel.isVisible ? panel.frame : nil }

    func setArtwork(_ presentation: PetPresentation) {
        cancelCue()
        state.presentation = presentation
        panel.title = presentation.name
    }

    func setReaction(_ mood: PetMood, cue: Bool) {
        state.mood = mood
        dragView.showsBadge = mood != .idle
        dragView.toolTip = mood.label.isEmpty ? "Drag Pet to move it" : mood.label
        updateMousePassThrough()
        if mood != .responseReady { cancelCue() }
        guard cue, running, !sleeping, panel.isVisible, panel.occlusionState.contains(.visible) else { return }
        cancelCue()
        state.cue = true
        if preferences.soundEnabled { NSSound(named: NSSound.Name("Glass"))?.play() }
        cueTask = Task { @MainActor [weak self] in
            do { try await Task.sleep(for: .seconds(2)) } catch { return }
            guard !Task.isCancelled else { return }
            self?.state.cue = false
            self?.cueTask = nil
        }
    }

    private func cancelCue() {
        cueTask?.cancel()
        cueTask = nil
        state.cue = false
    }

    func returnPet() {
        state.dragging = false
        detached = false
        if returnTarget() != nil {
            // Keep the last desktop spot so the pet comes back there when it is pulled out with Show Pet.
            if let saved = preferences.placement {
                preferences.placement = PetSavedPlacement(displayID: saved.displayID, x: saved.x, y: saved.y, detached: false)
            } else {
                savePlacement()
            }
            onReturn()
        } else {
            restorePlacement()
            savePlacement()
        }
        show()
    }

    private func updateMousePassThrough() {
        guard !state.dragging else { return }
        let point = dragView.convert(panel.convertPoint(fromScreen: NSEvent.mouseLocation), from: nil)
        panel.ignoresMouseEvents = !dragView.accepts(point)
    }

    private func finishDrag() {
        state.dragging = false
        if let target = returnTarget(), panel.frame.intersects(target) { returnPet() }
        else {
            let display = screen(containing: panel.frame) ?? NSScreen.main
            if let display { panel.setFrame(PetPlacement.clamped(panel.frame, in: display.visibleFrame), display: true) }
            savePlacement()
        }
        updateMousePassThrough()
    }

    private func screen(containing frame: CGRect) -> NSScreen? {
        NSScreen.screens.max { a, b in
            let first = a.frame.intersection(frame)
            let second = b.frame.intersection(frame)
            return (first.isNull ? 0 : first.width * first.height) < (second.isNull ? 0 : second.width * second.height)
        }
    }

    private func displayID(_ screen: NSScreen) -> UInt32 {
        (screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value ?? 0
    }

    private func restorePlacement() {
        let saved = preferences.placement
        guard let display = NSScreen.screens.first(where: { displayID($0) == saved?.displayID }) ?? NSScreen.main else { return }
        let frame = PetPlacement.restored(saved, in: display.visibleFrame,
                                         size: NSSize(width: state.size, height: state.size + 30))
        panel.setFrame(frame, display: true)
    }

    private func savePlacement() {
        guard let display = screen(containing: panel.frame) ?? NSScreen.main else { return }
        let visible = display.visibleFrame
        preferences.placement = PetSavedPlacement(displayID: displayID(display),
            x: max(0, min(1, (panel.frame.minX - visible.minX) / max(1, visible.width - panel.frame.width))),
            y: max(0, min(1, (panel.frame.minY - visible.minY) / max(1, visible.height - panel.frame.height))), detached: detached)
    }

    static func desktopFrame(screen: CGRect, size: Double) -> CGRect {
        let safe = size.isFinite && PetPreferences.sizeRange.contains(size) ? size : PetPreferences.defaultSize
        return CGRect(x: max(screen.minX, screen.maxX - safe - 16),
                      y: min(screen.minY + 16, max(screen.minY, screen.maxY - safe)), width: safe, height: safe)
    }

    func setSize(_ size: Double) {
        guard size.isFinite, PetPreferences.sizeRange.contains(size) else { return }
        savePlacement()
        state.size = size
        restorePlacement()
        savePlacement()
    }

    /// Opt-in verification observes this same production panel, never a demo view.
    func writeEvidence(phase: String, agentsEnabled: Bool, focusBefore: pid_t) {
        guard let path = ProcessInfo.processInfo.environment["NOTCH_PET_EVIDENCE_DIR"] else { return }
        let directory = URL(fileURLWithPath: path).resolvingSymlinksInPath()
        let roots = ["/private/tmp", NSTemporaryDirectory()].map {
            URL(fileURLWithPath: $0).resolvingSymlinksInPath().path
        }
        guard roots.contains(where: { directory.path.hasPrefix($0.hasSuffix("/") ? $0 : $0 + "/") }) else { return }
        let counts = Dictionary(uniqueKeysWithValues: AgentServiceKind.allCases.map {
            ($0.rawValue, ServiceStartLedger.starts[$0, default: 0])
        })
        let payload: [String: Any] = [
            "pid": ProcessInfo.processInfo.processIdentifier,
            "executable": Bundle.main.executableURL?.path ?? "",
            "phase": phase,
            "presentation": "pet",
            "petVisible": panel.isVisible,
            "artworkLoaded": PetArtwork.url(for: "white-lionhead-idle").flatMap(NSImage.init(contentsOf:)) != nil,
            "size": panel.frame.width,
            "windowNumber": panel.windowNumber,
            "agentServicesEnabled": agentsEnabled,
            "serviceStarts": counts,
            "focusBefore": focusBefore,
            "focusAfter": NSWorkspace.shared.frontmostApplication?.processIdentifier ?? -1
        ]
        do {
            let data = try JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted, .sortedKeys])
            try data.write(to: directory.appendingPathComponent("pet.json"), options: .atomic)
        } catch {
            fputs("Pet verification evidence could not be written.\n", stderr)
        }
    }
}
