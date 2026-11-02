import AppKit
import QuartzCore
import SessionState
import SwiftUI

@MainActor
final class NotchPanelController {
    private let panel: NSPanel
    private let usageStore = UsageStore()
    private let usageController: AgentUsageController

    init(sessionStore: SessionStore) {
        panel = NSPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel],
                        backing: .buffered, defer: false)
        usageController = AgentUsageController(store: usageStore, sessions: sessionStore)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.level = .statusBar
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        let screen = NSScreen.screens.first(where: { $0.safeAreaInsets.top > 0 }) ?? NSScreen.main
        let top = screen?.safeAreaInsets.top ?? 0
        let notch = screen.flatMap { screen -> CGFloat? in
            guard let left = screen.auxiliaryTopLeftArea, let right = screen.auxiliaryTopRightArea else { return nil }
            return max(0, right.minX - left.maxX)
        } ?? 0
        panel.contentView = NSHostingView(rootView: NotchSessionView(
            sessionStore: sessionStore, usageStore: usageStore, headerHeight: max(32, top), notchWidth: notch,
            onExpand: { [weak self] expanded in self?.updatePlacement(expanded: expanded) }))
        updatePlacement(expanded: false)
    }

    func show() {
        panel.orderFrontRegardless()
        usageController.start()
    }

    func stop() {
        usageController.stop()
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
