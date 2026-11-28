import SwiftUI

/// The open panel's top row: one side left of the notch, a gap as wide as the notch, and one side right of it.
/// Each side keeps its width even when its content is empty. A side with no content would otherwise take no space,
/// and the row would shrink and center, which moves the right-hand buttons away from the edge.
struct NotchTopRow<Leading: View, Trailing: View>: View {
    /// Each side's width beside a notch, or nil to share the row equally on a screen without one.
    let sideWidth: CGFloat?
    let notchWidth: CGFloat
    @ViewBuilder let leading: Leading
    @ViewBuilder let trailing: Trailing

    var body: some View {
        HStack(spacing: 0) {
            side(alignment: .leading) { leading }
            Color.clear.frame(width: notchWidth)
            side(alignment: .trailing) { trailing }
        }
    }

    private func side(alignment: Alignment, @ViewBuilder content: () -> some View) -> some View {
        Color.clear
            .frame(maxWidth: .infinity)
            .frame(width: sideWidth)
            .overlay(alignment: alignment, content: content)
    }
}
