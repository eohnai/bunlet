import AgentActions
import AppKit
import SessionState
import SwiftUI

/// The pet panel: a 400-point session list that opens above the pet, or below when there is no room.
/// It is presentation only; sessions, actions and navigation keep their existing owners.
@MainActor
final class PetSessionPanelController {
    static let width: CGFloat = 400
    static let maxHeight: CGFloat = 400
    private let panel: NSPanel
    private let model = PetSessionPanelModel()
    private let anchor: () -> CGRect?

    init(sessions: SessionStore, features: FeatureSettingsModel, actions: LocalActionController?,
         navigation: TerminalNavigation?, onOpenFeatures: @escaping () -> Void, anchor: @escaping () -> CGRect?) {
        self.anchor = anchor
        panel = PetSessionPanel(contentRect: NSRect(x: 0, y: 0, width: Self.width, height: 120),
                                styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: true)
        panel.title = "Bunlet Pet Sessions"
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.level = .statusBar
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.becomesKeyOnlyIfNeeded = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.contentView = NSHostingView(rootView: PetSessionPanelView(
            sessions: sessions, features: features, actions: actions, navigation: navigation, model: model,
            onOpenFeatures: onOpenFeatures, onResize: { [weak self] height in self?.resize(contentHeight: height) },
            onJumped: { [weak self] in self?.close() }, beginInput: { [weak self] in self?.beginInput() }))
    }

    var isOpen: Bool { panel.isVisible }

    func toggle() {
        if isOpen { close() } else { open() }
    }

    func open() {
        guard anchor() != nil else { return }
        model.isOpen = true
        place()
        panel.orderFrontRegardless()
    }

    func close() {
        model.isOpen = false
        panel.resignKey()
        panel.orderOut(nil)
    }

    private func beginInput() {
        NSApplication.shared.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
    }

    private func resize(contentHeight: CGFloat) {
        model.contentHeight = min(Self.maxHeight, max(60, contentHeight))
        if isOpen { place() }
    }

    /// Above the pet when it fits on that screen, else below, kept inside the visible frame.
    private func place() {
        guard let pet = anchor() else { return close() }
        let screen = NSScreen.screens.first { $0.frame.intersects(pet) } ?? NSScreen.main
        let visible = screen?.visibleFrame ?? pet.insetBy(dx: -1_000, dy: -1_000)
        let height = model.contentHeight
        let above = pet.maxY + 8 + height <= visible.maxY
        let x = min(max(pet.midX - Self.width / 2, visible.minX + 8), visible.maxX - Self.width - 8)
        let y = above ? pet.maxY + 8 : max(visible.minY + 8, pet.minY - 8 - height)
        panel.setFrame(NSRect(x: x, y: y, width: Self.width, height: height), display: true)
    }
}

@MainActor
@Observable
final class PetSessionPanelModel {
    var contentHeight: CGFloat = 120
    /// Timers run only while the panel is on screen (D1).
    var isOpen = false
}

private final class PetSessionPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

private struct PetSessionPanelView: View {
    let sessions: SessionStore
    let features: FeatureSettingsModel
    let actions: LocalActionController?
    let navigation: TerminalNavigation?
    let model: PetSessionPanelModel
    let onOpenFeatures: () -> Void
    let onResize: (CGFloat) -> Void
    let onJumped: () -> Void
    let beginInput: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                if sessions.sessions.isEmpty {
                    empty("No sessions", action: ("Connect agents", onOpenFeatures))
                } else if model.isOpen {
                    TimelineView(.periodic(from: .now, by: 1)) { context in
                        rows(nowMs: Int64(context.date.timeIntervalSince1970 * 1000))
                    }
                } else {
                    rows(nowMs: Int64(Date.now.timeIntervalSince1970 * 1000))
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { onResize($0) }
        }
        .scrollBounceBehavior(.basedOnSize)
        .frame(width: PetSessionPanelController.width, height: model.contentHeight)
        .background(Color(red: 18 / 255, green: 19 / 255, blue: 20 / 255).opacity(0.9), in: RoundedRectangle(cornerRadius: 16))
        .overlay { RoundedRectangle(cornerRadius: 16).strokeBorder(.white.opacity(0.1), lineWidth: 1) }
        .foregroundStyle(.white)
        .preferredColorScheme(.dark)
    }

    private func rows(nowMs: Int64) -> some View {
        VStack(alignment: .leading, spacing: 24) {
            ForEach(NotchPresentation.ordered(sessions.sessions)) { snapshot in
                VStack(alignment: .leading, spacing: 12) {
                    NotchSessionCard(snapshot: snapshot,
                                     presentation: NotchPresentation.card(for: snapshot, among: sessions.sessions),
                                     nowMs: nowMs, isActive: false, detailsOpen: false,
                                     onJump: navigation.map { navigation in { jump(snapshot.key, navigation) } },
                                     onToggleDetails: {})
                    ForEach(snapshot.pendingRequests.filter { request in
                        actions?.store.snapshots.contains { $0.observedRequestID == request.eventID && $0.phase == .available } != true
                    }, id: \.eventID) { request in
                        NotchRequestCard(request: request)
                    }
                    if let actions {
                        ForEach(actions.store.snapshots.filter {
                            SessionKey(agent: $0.offer.provider, sessionID: $0.offer.sessionID) == snapshot.key
                        }) { action in
                            LocalActionView(snapshot: action, controller: actions, beginInput: beginInput)
                        }
                    }
                }
            }
        }
    }

    private func jump(_ key: SessionKey, _ navigation: TerminalNavigation) {
        if !navigation.jump(to: key) { navigation.chooseApplication() }
        onJumped()
    }

    private func empty(_ text: String, action: (String, () -> Void)?) -> some View {
        VStack(spacing: 8) {
            Text(text).font(.system(size: 13)).foregroundStyle(.white.opacity(0.45))
            if let action {
                Button(action.0, action: action.1).buttonStyle(.plain)
                    .font(.system(size: 12, weight: .medium)).foregroundStyle(IslandPalette.mutedText)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 40)
    }
}
