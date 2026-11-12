import CoreGraphics
import Foundation

/// Dominant state shown by the closed island.
public enum IslandPhase: Equatable, Sendable {
    case idle, running, attention, completed

    /// Attention wins over running, which wins over completed. Unknown and ended sessions add no phase.
    public static func dominant(_ sessions: [SessionSnapshot]) -> IslandPhase {
        if sessions.contains(where: { session in
            session.status == .approvalNeeded || session.status == .questionNeeded
                || session.pendingRequests.contains(where: \.isConfirmed)
        }) { return .attention }
        if sessions.contains(where: { $0.status == .working }) { return .running }
        if sessions.contains(where: { $0.status == .responseReady }) { return .completed }
        return .idle
    }
}

/// Island sizes and timings (decision 0017).
public enum IslandMetrics {
    public static let windowWidth: CGFloat = 740
    public static let windowHeight: CGFloat = 750
    public static let closedTopRadius: CGFloat = 8
    public static let closedBottomRadius: CGFloat = 10
    public static let openTopRadius: CGFloat = 24
    public static let openBottomRadius: CGFloat = 18
    public static let openTopInset: CGFloat = 8
    public static let panelMaxHeight: CGFloat = 540
    public static let shadowMargin: CGFloat = 32
    public static let minimumNotchWidth: CGFloat = 126
    public static let fallbackHeaderHeight: CGFloat = 24
    public static let hoverOpenDelay: Duration = .milliseconds(200)
    public static let leaveCloseDelay: Duration = .milliseconds(300)
    public static let completionPopupDuration: Duration = .seconds(5)
    /// Dragging the pill this far down pulls the pet out of the island.
    public static let pillDragThreshold: CGFloat = 50
}

/// The island's black shape inside a fixed transparent window. Pure geometry with top-left origin, y downward.
public struct IslandShapeSpec: Equatable, Sendable {
    public var bodyWidth: CGFloat
    public var bottom: CGFloat
    public var topRadius: CGFloat
    public var bottomRadius: CGFloat
    public var topInset: CGFloat

    public init(bodyWidth: CGFloat, bottom: CGFloat, topRadius: CGFloat, bottomRadius: CGFloat, topInset: CGFloat = 0) {
        self.bodyWidth = bodyWidth
        self.bottom = bottom
        self.topRadius = topRadius
        self.bottomRadius = bottomRadius
        self.topInset = topInset
    }

    /// The flared top corners sit outside the body width.
    public func outerWidth(windowWidth: CGFloat) -> CGFloat {
        min(bodyWidth + 2 * min(topRadius, bottomRadius), windowWidth)
    }

    /// Concave top corners join the screen edge; convex bottom corners finish the shape.
    public func path(windowWidth: CGFloat) -> CGPath {
        let outer = outerWidth(windowWidth: windowWidth)
        let left = max(0, (windowWidth - outer) / 2)
        let right = windowWidth - left
        let width = right - left
        let top = -topInset
        let topR = max(0, min(topRadius, width / 4, bottom / 4))
        let bottomR = max(0, min(bottomRadius, width / 4, bottom / 2))
        let path = CGMutablePath()
        path.move(to: CGPoint(x: left, y: top))
        path.addLine(to: CGPoint(x: right, y: top))
        path.addArc(tangent1End: CGPoint(x: right - topR, y: top), tangent2End: CGPoint(x: right - topR, y: top + topR), radius: topR)
        path.addLine(to: CGPoint(x: right - topR, y: bottom - bottomR))
        path.addArc(tangent1End: CGPoint(x: right - topR, y: bottom), tangent2End: CGPoint(x: right - topR - bottomR, y: bottom), radius: bottomR)
        path.addLine(to: CGPoint(x: left + topR + bottomR, y: bottom))
        path.addArc(tangent1End: CGPoint(x: left + topR, y: bottom), tangent2End: CGPoint(x: left + topR, y: bottom - bottomR), radius: bottomR)
        path.addLine(to: CGPoint(x: left + topR, y: top + topR))
        path.addArc(tangent1End: CGPoint(x: left + topR, y: top), tangent2End: CGPoint(x: left, y: top), radius: topR)
        path.closeSubpath()
        return path
    }
}

public enum IslandGeometry {
    /// Header height follows the physical notch, else a plausible menu bar, else a fixed fallback.
    public static func headerHeight(safeTop: CGFloat, menuBarHeight: CGFloat) -> CGFloat {
        if safeTop > 0, safeTop.isFinite { return safeTop }
        if menuBarHeight > 0, menuBarHeight < 40 { return menuBarHeight }
        return IslandMetrics.fallbackHeaderHeight
    }

    public static func pillBodyWidth(notchWidth: CGFloat, hasNotch: Bool, visibleCount: Int,
                                     phase: IslandPhase, windowWidth: CGFloat) -> CGFloat {
        let extra: CGFloat
        if hasNotch {
            extra = visibleCount > 0 ? 72 : 62
        } else if visibleCount == 0 {
            extra = 72
        } else {
            switch phase {
            case .attention: extra = 108
            case .completed: extra = 112
            case .running, .idle: extra = 100
            }
        }
        let base = max(hasNotch ? notchWidth : IslandMetrics.minimumNotchWidth, IslandMetrics.minimumNotchWidth)
        return min(base + extra, maxBodyWidth(top: IslandMetrics.closedTopRadius,
                                              bottom: IslandMetrics.closedBottomRadius, windowWidth: windowWidth))
    }

    public static func panelBodyWidth(screenWidth: CGFloat, windowWidth: CGFloat) -> CGFloat {
        let desired = screenWidth > 0 ? max(680, min(740, screenWidth * 0.46)) : 680
        return min(desired, maxBodyWidth(top: IslandMetrics.openTopRadius,
                                         bottom: IslandMetrics.openBottomRadius, windowWidth: windowWidth))
    }

    public static func maxBodyWidth(top: CGFloat, bottom: CGFloat, windowWidth: CGFloat) -> CGFloat {
        max(0, windowWidth - 2 * min(top, bottom))
    }

    /// AppKit screen points grow upward, so a downward drag lowers y.
    public static func isPillDragOut(from start: CGPoint, to current: CGPoint) -> Bool {
        start.y - current.y > IslandMetrics.pillDragThreshold
    }

    /// The open shape fits its content, at least the header plus 40, within the window.
    public static func openBottom(contentHeight: CGFloat, headerHeight: CGFloat, windowHeight: CGFloat) -> CGFloat {
        max(headerHeight + 40, min(contentHeight, windowHeight - 10))
    }

    /// One fixed window at the top center of the screen; the shape animates inside it.
    public static func windowFrame(screen: CGRect, safeTop: CGFloat,
                                   panelMaxHeight: CGFloat = IslandMetrics.panelMaxHeight) -> CGRect? {
        guard [screen.origin.x, screen.origin.y, screen.width, screen.height, safeTop].allSatisfy({ $0.isFinite }),
              screen.width > 24, screen.height > 44, safeTop >= 0, safeTop <= screen.height - 12 else { return nil }
        let width = min(IslandMetrics.windowWidth, screen.width)
        let height = min(IslandMetrics.windowHeight, max(200, panelMaxHeight) + IslandMetrics.shadowMargin,
                         screen.height - 12)
        return CGRect(x: screen.midX - width / 2, y: screen.maxY - height, width: width, height: height)
    }
}

/// A change that opens the island without taking focus, for approvals, questions and completions.
public enum IslandNotification: Equatable, Sendable {
    case attention(SessionKey)
    case completed(SessionKey)

    public var key: SessionKey {
        switch self {
        case .attention(let key), .completed(let key): key
        }
    }

    /// Attention wins over completion. A session already in that state before produces nothing.
    public static func next(previous: [SessionSnapshot], current: [SessionSnapshot]) -> IslandNotification? {
        let before = Dictionary(previous.map { ($0.key, $0) }, uniquingKeysWith: { _, last in last })
        let ordered = NotchPresentation.ordered(current)
        if let session = ordered.first(where: { session in
            IslandPhase.dominant([session]) == .attention
                && before[session.key].map { IslandPhase.dominant([$0]) != .attention } ?? true
        }) { return .attention(session.key) }
        if let session = ordered.first(where: { session in
            session.status == .responseReady && before[session.key].map { $0.status != .responseReady } ?? true
        }) { return .completed(session.key) }
        return nil
    }
}

/// Whether a notification may open the island on its own (decision 0021's Behavior settings).
public enum IslandAutoOpen {
    /// Terminals and editors where agents usually run. Focus-aware suppression treats them as "the session's terminal".
    public static let terminalBundleIDs: Set<String> = [
        "com.apple.Terminal", "com.googlecode.iterm2", "dev.warp.Warp-Stable", "com.mitchellh.ghostty",
        "net.kovidgoyal.kitty", "org.alacritty", "com.github.wez.wezterm", "co.zeit.hyper",
        "com.microsoft.VSCode", "com.todesktop.230313mzl4w4u92"
    ]

    public static func shouldOpen(_ notification: IslandNotification, expandOnActionNeeded: Bool,
                                  expandOnSessionEnd: Bool, focusAwareSuppression: Bool,
                                  frontmostBundleID: String?) -> Bool {
        let wanted: Bool = switch notification {
        case .attention: expandOnActionNeeded
        case .completed: expandOnSessionEnd
        }
        guard wanted else { return false }
        if focusAwareSuppression, let frontmostBundleID, terminalBundleIDs.contains(frontmostBundleID) { return false }
        return true
    }

    /// Sessions that appeared since the previous snapshot, for the "session starts" sound.
    public static func newSessions(previous: [SessionSnapshot], current: [SessionSnapshot]) -> [SessionKey] {
        let before = Set(previous.map(\.key))
        return current.map(\.key).filter { !before.contains($0) }
    }
}
