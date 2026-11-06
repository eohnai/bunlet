import CoreGraphics
import Observation

/// Window presentation only; the app's session/action stores remain independent authorities.
@MainActor
@Observable
final class NotchWindowState {
    var expanded = false
    var headerHeight: CGFloat = 32
    var notchWidth: CGFloat = 0
    var hasKeyboardFocus = false
}
