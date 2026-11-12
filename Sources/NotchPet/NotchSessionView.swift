import AgentActions
import SessionState
import SwiftUI
import Usage

struct NotchSessionView: View {
    let sessionStore: SessionStore
    let usageStore: UsageStore
    let features: FeatureSettingsModel
    let onOpenFeatures: () -> Void
    let windowState: NotchWindowState
    var headerHeight: CGFloat { windowState.headerHeight }
    var expanded: Bool { windowState.expanded }
    let onExpand: (Bool) -> Void
    let isVisible: Bool
    let isSleeping: Bool
    var navigation: TerminalNavigation? = nil
    var actions: LocalActionController? = nil
    var beginInput: () -> Void = {}
    var endInput: () -> Void = {}
    var onOpenSettings: () -> Void = {}
    @State private var selection: SessionKey?
    @State private var listContentHeight: CGFloat = 0
    @State private var detailsKey: SessionKey?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var sessions: [SessionSnapshot] { sessionStore.sessions }
    private var attentionCount: Int {
        sessions.filter { IslandPhase.dominant([$0]) == .attention }.count
    }

    var body: some View {
        let motion: Animation? = reduceMotion ? nil
            : expanded ? .timingCurve(0.32, 0.02, 0.2, 1, duration: 0.26) : .easeOut(duration: 0.24)
        ZStack(alignment: .top) {
            IslandShape(spec: windowState.shape(sessions: sessions))
                .fill(.black)
                .overlay {
                    IslandShape(spec: windowState.shape(sessions: sessions))
                        .stroke(.white.opacity(expanded ? 0 : 0.1), lineWidth: 1)
                }
                .shadow(color: .black.opacity(expanded ? 0.35 : 0), radius: 8, y: 8)
                .animation(motion, value: windowState.shape(sessions: sessions))

            pillLayer
                .frame(width: windowState.pillWidth(sessions: sessions), height: headerHeight)
                .opacity(expanded ? 0 : 1)
                .allowsHitTesting(!expanded)
                .accessibilityHidden(expanded)

            panelLayer
                .frame(width: windowState.panelWidth)
                .opacity(expanded ? 1 : 0)
                .allowsHitTesting(expanded)
                .accessibilityHidden(!expanded)
        }
        .animation(reduceMotion ? nil : .easeOut(duration: 0.15), value: expanded)
        .phaseAnimator([CGFloat(1), 1.04, 1], trigger: reduceMotion ? 0 : attentionCount) { content, scale in
            content.scaleEffect(scale, anchor: .top)
        } animation: { _ in .timingCurve(0.32, 0.02, 0.2, 1, duration: 0.093) }
        .frame(width: windowState.windowWidth, height: windowState.windowHeight, alignment: .top)
        .foregroundStyle(.white)
        .preferredColorScheme(.dark)
        .onExitCommand {
            onExpand(false)
            endInput()
        }
        .onAppear {
            selection = NotchPresentation.selection(selection, sessions: sessions)
        }
        .onChange(of: sessionStore.sessions) { _, sessions in
            selection = NotchPresentation.selection(selection, sessions: sessions)
        }
        .onChange(of: windowState.focusedSession) { _, key in
            if let key { selection = key }
        }
    }

    /// The running label: the prompt of the most recently updated working session.
    private var latestRunningPrompt: String? {
        sessions.filter { $0.status == .working }
            .max { ($0.receiptWallMs ?? 0) < ($1.receiptWallMs ?? 0) }
            .flatMap { NotchPresentation.displayText($0.latestPrompt, cwd: $0.projectPath) }
    }

    private var pillLayer: some View {
        Button(action: toggleExpansion) {
            IslandPillView(sessions: sessions, hasNotch: windowState.hasNotch, latestPrompt: latestRunningPrompt,
                           animates: isVisible && !isSleeping && !expanded)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Expand sessions")
        .accessibilityValue("\(sessions.count) observed sessions")
    }

    private var panelLayer: some View {
        VStack(spacing: 0) {
            usageRow
            Rectangle().fill(IslandPalette.divider).frame(height: 1).padding(.horizontal, 18)
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    notices
                    if NotchPresentation.shouldTickPromptTimers(expanded: expanded && isVisible && !isSleeping,
                                                              sessions: sessions) {
                        TimelineView(.periodic(from: .now, by: 1)) { context in
                            sessionCards(at: Int64(context.date.timeIntervalSince1970 * 1000))
                        }
                    } else {
                        sessionCards(at: Int64(Date.now.timeIntervalSince1970 * 1000))
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { height in
                    listContentHeight = height
                    windowState.panelContentHeight = headerHeight + 1 + min(height, listMaxHeight)
                }
            }
            .scrollBounceBehavior(.basedOnSize)
            .scrollIndicators(.automatic)
            .frame(height: min(listContentHeight, listMaxHeight))
        }
    }

    private var listMaxHeight: CGFloat { max(0, IslandMetrics.panelMaxHeight - headerHeight - 1) }

    /// Sits beside the physical notch: limits on the left, panel actions on the right.
    private var usageRow: some View {
        HStack(spacing: 0) {
            Group {
                if expanded && isVisible && !isSleeping {
                    NotchAllowanceStrip(store: usageStore,
                                        activeProviders: NotchPresentation.activeProviders(sessions))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Color.clear.frame(width: windowState.hasNotch ? windowState.notchWidth : 0)
            HStack(spacing: 12) {
                if windowState.hasKeyboardFocus {
                    Button("Done", action: endInput).buttonStyle(.plain)
                        .font(.system(size: 12, weight: .medium)).foregroundStyle(IslandPalette.mutedText)
                }
                IslandIconButton(systemImage: "gearshape", label: "Settings", action: onOpenSettings)
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(.horizontal, 18)
        .frame(height: headerHeight)
        // The usage popup extends below the row and must draw over the session list.
        .zIndex(1)
    }

    @ViewBuilder private var notices: some View {
        if let actions {
            if actions.store.capacityReached {
                Text("Local response history capacity reached. Return to the existing session for new requests.")
                    .font(.system(size: 12)).foregroundStyle(.orange)
            }
        }
        if let issue = sessionStore.capacityIssue {
            Text(issue == .sessionCapacity
                 ? "Session capacity reached. New sessions are not being observed. Existing requests are retained."
                 : "A session reached its identity or request capacity. Its state is unconfirmed.")
                .font(.system(size: 12)).foregroundStyle(IslandPalette.attention)
        }
        if sessionStore.deliveryOverflowed {
            Text("Some events were lost. Affected sessions need fresh evidence.")
                .font(.system(size: 12)).foregroundStyle(IslandPalette.attention)
        }
        if !features.installed.contains(.agents) {
            emptyState("Agents is not installed.", action: ("Open Features", onOpenFeatures))
        } else if !features.monitoringEnabled {
            emptyState("Monitoring is off.", action: ("Open Features", onOpenFeatures))
        } else if sessions.isEmpty {
            emptyState("No sessions", action: nil)
        }
    }

    private func emptyState(_ text: String, action: (String, () -> Void)?) -> some View {
        VStack(spacing: 8) {
            IslandPhaseIcon(kind: .idle, size: 40)
            Text(text).font(.system(size: 11)).foregroundStyle(.white.opacity(0.9))
            if let action {
                Button(action.0, action: action.1).buttonStyle(.plain)
                    .font(.system(size: 12, weight: .medium)).foregroundStyle(IslandPalette.mutedText)
            }
        }
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
    }

    private func toggleExpansion() {
        onExpand(!expanded)
    }

    private func sessionCards(at nowMs: Int64) -> some View {
        LazyVStack(alignment: .leading, spacing: 24) {
            ForEach(NotchPresentation.ordered(sessions)) { snapshot in
                VStack(alignment: .leading, spacing: 12) {
                    NotchSessionCard(snapshot: snapshot,
                                     presentation: NotchPresentation.card(for: snapshot, among: sessions),
                                     nowMs: nowMs, isActive: selection == snapshot.key,
                                     detailsOpen: detailsKey == snapshot.key,
                                     animates: expanded && isVisible && !isSleeping,
                                     onJump: navigation.map { navigation in { jump(to: snapshot.key, using: navigation) } },
                                     onToggleDetails: {
                                         detailsKey = detailsKey == snapshot.key ? nil : snapshot.key
                                         selection = snapshot.key
                                     })
                    VStack(alignment: .leading, spacing: 8) {
                        if detailsKey == snapshot.key, let navigation {
                            TerminalNavigationView(controller: navigation, session: snapshot.key)
                        }
                        // A request with a verified local channel is shown by its action card instead.
                        ForEach(snapshot.pendingRequests.filter { request in
                            actions?.store.snapshots.contains {
                                $0.observedRequestID == request.eventID &&
                                    SessionKey(agent: $0.offer.provider, sessionID: $0.offer.sessionID) == snapshot.key &&
                                    $0.phase == .available
                            } != true
                        }, id: \.eventID) { request in
                            NotchRequestCard(request: request,
                                             onJump: navigation.map { navigation in { jump(to: snapshot.key, using: navigation) } })
                        }
                        if selection == snapshot.key, snapshot.status == .responseReady, snapshot.lastReply != nil {
                            CompletionCard(snapshot: snapshot,
                                           onJump: navigation.map { navigation in { jump(to: snapshot.key, using: navigation) } })
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
    }

    /// A row click returns to the session's terminal, then collapse. Without a known target, show setup instead.
    private func jump(to key: SessionKey, using navigation: TerminalNavigation) {
        if navigation.hasLinkedPane(key) {
            navigation.focusLinkedPane(for: key)
        } else if navigation.preferredName != nil {
            navigation.activateApplication()
        } else {
            detailsKey = key
            selection = key
            return
        }
        onExpand(false)
    }
}

/// A 16-point panel icon button: half-white, brightening on hover.
struct IslandIconButton: View {
    let systemImage: String
    let label: String
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 13, weight: .medium))
                .frame(width: 22, height: 22)
                .foregroundStyle(.white.opacity(hovering ? 0.85 : 0.5))
                .background(.white.opacity(hovering ? 0.08 : 0), in: RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .accessibilityLabel(label)
        .help(label)
    }
}
