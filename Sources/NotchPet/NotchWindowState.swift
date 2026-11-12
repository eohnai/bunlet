import CoreGraphics
import Observation
import SessionState
import SwiftUI

/// Window presentation only; the app's session/action stores remain independent authorities.
@MainActor
@Observable
final class NotchWindowState {
    var expanded = false
    var headerHeight: CGFloat = IslandMetrics.fallbackHeaderHeight
    var notchWidth: CGFloat = 0
    var hasNotch = false
    var screenWidth: CGFloat = 0
    var windowWidth: CGFloat = IslandMetrics.windowWidth
    var windowHeight: CGFloat = IslandMetrics.windowHeight
    /// Measured height of the open panel's content, reported by the view.
    var panelContentHeight: CGFloat = 300
    var hasKeyboardFocus = false
    /// The session a notification opened the island for; the view makes it the active row.
    var focusedSession: SessionKey?

    func pillWidth(sessions: [SessionSnapshot]) -> CGFloat {
        IslandGeometry.pillBodyWidth(notchWidth: notchWidth, hasNotch: hasNotch, visibleCount: sessions.count,
                                     phase: IslandPhase.dominant(sessions), windowWidth: windowWidth)
    }

    var panelWidth: CGFloat {
        IslandGeometry.panelBodyWidth(screenWidth: screenWidth, windowWidth: windowWidth)
    }

    func shape(sessions: [SessionSnapshot]) -> IslandShapeSpec {
        if expanded {
            return IslandShapeSpec(bodyWidth: panelWidth,
                                   bottom: IslandGeometry.openBottom(contentHeight: panelContentHeight,
                                                                     headerHeight: headerHeight, windowHeight: windowHeight),
                                   topRadius: IslandMetrics.openTopRadius, bottomRadius: IslandMetrics.openBottomRadius,
                                   topInset: IslandMetrics.openTopInset)
        }
        return IslandShapeSpec(bodyWidth: pillWidth(sessions: sessions), bottom: headerHeight,
                               topRadius: IslandMetrics.closedTopRadius, bottomRadius: IslandMetrics.closedBottomRadius)
    }
}

/// Animates between the pill and panel outlines by interpolating the shape's measurements.
struct IslandShape: Shape {
    var spec: IslandShapeSpec

    var animatableData: AnimatablePair<AnimatablePair<CGFloat, CGFloat>,
                                       AnimatablePair<AnimatablePair<CGFloat, CGFloat>, CGFloat>> {
        get {
            AnimatablePair(AnimatablePair(spec.bodyWidth, spec.bottom),
                           AnimatablePair(AnimatablePair(spec.topRadius, spec.bottomRadius), spec.topInset))
        }
        set {
            spec.bodyWidth = newValue.first.first
            spec.bottom = newValue.first.second
            spec.topRadius = newValue.second.first.first
            spec.bottomRadius = newValue.second.first.second
            spec.topInset = newValue.second.second
        }
    }

    func path(in rect: CGRect) -> Path {
        Path(spec.path(windowWidth: rect.width))
    }
}
