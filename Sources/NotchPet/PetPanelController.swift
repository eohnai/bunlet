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
    let presentation: PetPresentation

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

    var body: some View {
        VStack(spacing: 4) {
            PetView(presentation: state.presentation, pose: state.pose, isVisible: visible,
                    isSleeping: sleeping, onFrameImage: onFrame)
                .frame(width: state.size, height: state.size)
            if state.mood != .idle {
                Label(state.mood.label, systemImage: state.mood.symbol)
                    .font(.caption2).lineLimit(1).minimumScaleFactor(0.7)
                    .padding(.horizontal, 4).frame(height: 26)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 6))
            } else { Color.clear.frame(height: 26) }
        }
    }
}

/// Transparent pixels do not own input. A native drag never activates this panel.
@MainActor
private final class PetDragView: NSView {
    var onBegin: (() -> Void)?
    var onDrop: (() -> Void)?
    var onImageChange: (() -> Void)?
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
        if showsBadge && local.y <= 26 { return true }
        let art = NSRect(x: 0, y: 30, width: bounds.width, height: max(0, bounds.height - 30))
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
        if moved { onDrop?() }
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
    private var subscriptions: Set<AnyCancellable> = []
    private var cueTask: Task<Void, Never>?
    private var sleeping = false
    private var running = false
    private var detached: Bool
    private var globalMouseMonitor: Any?
    private var localMouseMonitor: Any?
    var isDetached: Bool { detached }

    init?(size: Double, defaults: UserDefaults = .standard, onDragBegan: @escaping () -> Void = {},
          returnTarget: @escaping () -> CGRect? = { nil }, onReturn: @escaping () -> Void = {}) {
        guard let presentation = PetArtwork.presentation() else { return nil }
        preferences = PetPreferences(defaults: defaults)
        detached = preferences.placement?.detached ?? false
        self.onDragBegan = onDragBegan
        self.returnTarget = returnTarget
        self.onReturn = onReturn
        state = PetSurfaceState(size: size, presentation: presentation)
        panel = NSPanel(contentRect: NSRect(x: 0, y: 0, width: size, height: size + 30),
                        styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.title = "White lionhead rabbit"
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
        dragView.onImageChange = { [weak self] in self?.updateMousePassThrough() }
        restorePlacement()
    }

    func show() {
        if running && !sleeping {
            panel.orderFrontRegardless()
            updateMousePassThrough()
        }
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
                        self.cancelCue()
                        self.panel.orderOut(nil)
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
        running = false
        subscriptions.removeAll()
        if let globalMouseMonitor { NSEvent.removeMonitor(globalMouseMonitor) }
        if let localMouseMonitor { NSEvent.removeMonitor(localMouseMonitor) }
        globalMouseMonitor = nil
        localMouseMonitor = nil
        cancelCue()
        panel.orderOut(nil)
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
        if let target = returnTarget(), let screen = screen(containing: target) {
            let proposed = NSRect(x: target.maxX + 8, y: target.minY - panel.frame.height,
                                 width: panel.frame.width, height: panel.frame.height)
            panel.setFrame(PetPlacement.clamped(proposed, in: screen.visibleFrame), display: true)
            onReturn()
        } else { restorePlacement() }
        savePlacement()
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
