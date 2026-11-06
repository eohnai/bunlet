import AppKit
import QuartzCore
import SessionState
import SwiftUI
import Usage

@MainActor
final class NotchPanelController: AppFeatureService {
    private let panel: NSPanel
    private var hiddenForPet = false

    init(sessionStore: SessionStore, usageStore: UsageStore,
         features: FeatureSettingsModel, onOpenFeatures: @escaping () -> Void,
         actions: LocalActionController? = nil) {
        panel = ActionNotchPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel],
                        backing: .buffered, defer: false)
        panel.title = "Notch Pet Sessions"
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.level = .statusBar
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.becomesKeyOnlyIfNeeded = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        let screen = NSScreen.screens.first(where: { $0.safeAreaInsets.top > 0 }) ?? NSScreen.main
        let top = screen?.safeAreaInsets.top ?? 0
        let notch = screen.flatMap { screen -> CGFloat? in
            guard let left = screen.auxiliaryTopLeftArea, let right = screen.auxiliaryTopRightArea else { return nil }
            return max(0, right.minX - left.maxX)
        } ?? 0
        panel.contentView = NSHostingView(rootView: NotchSessionView(
            sessionStore: sessionStore, usageStore: usageStore, features: features, onOpenFeatures: onOpenFeatures,
            headerHeight: max(32, top), notchWidth: notch,
            onExpand: { [weak self] expanded in self?.updatePlacement(expanded: expanded) },
            actions: actions, beginInput: { [weak self] in self?.beginInput() }))
        updatePlacement(expanded: false)
    }

    func show() {
        hiddenForPet = false
        panel.orderFrontRegardless()
    }

    func start() { if !hiddenForPet { panel.orderFrontRegardless() } }

    func setHiddenForPet(_ hidden: Bool) {
        hiddenForPet = hidden
        if hidden { panel.orderOut(nil) } else { panel.orderFrontRegardless() }
    }

    var returnTarget: CGRect? {
        guard let screen = NSScreen.screens.first(where: { $0.safeAreaInsets.top > 0 }) ?? NSScreen.main else { return nil }
        let width = screen.auxiliaryTopLeftArea.flatMap { left in
            screen.auxiliaryTopRightArea.map { max(0, $0.minX - left.maxX) }
        } ?? 0
        return NotchPlacement.frame(screen: screen.frame, safeTop: screen.safeAreaInsets.top,
                                    notchWidth: width, expanded: false)
    }

    private func beginInput() {
        // Only an explicit Respond click calls this; incoming offers never activate the app.
        NSApplication.shared.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
    }

    func stop() {
        panel.orderOut(nil)
    }

    func updatePlacement(expanded: Bool) {
        guard let screen = NSScreen.screens.first(where: { $0.safeAreaInsets.top > 0 }) ?? NSScreen.main else { return }
        let notchWidth: CGFloat
        if let left = screen.auxiliaryTopLeftArea, let right = screen.auxiliaryTopRightArea {
            notchWidth = max(0, right.minX - left.maxX)
        } else { notchWidth = 0 }
        guard let frame = NotchPlacement.frame(screen: screen.frame, safeTop: screen.safeAreaInsets.top,
                                               notchWidth: notchWidth, expanded: expanded) else { return }
        if panel.isVisible && !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.24
                context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                panel.animator().setFrame(frame, display: true)
            }
        } else {
            panel.setFrame(frame, display: true)
        }
    }
}

private final class ActionNotchPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}
