import AppKit
import SwiftUI

// MARK: - ColumnDividerHandle
//
// A 6 pt-wide drag handle drawn at the trailing edge of a column. Shows the
// horizontal-resize cursor while hovered and reports drag deltas in points to
// the caller, which can then translate them to a fractional width change.

struct ColumnDividerHandle: View {
    let onDrag: (CGFloat) -> Void

    @GestureState private var lastTranslation: CGFloat = 0

    var body: some View {
        Rectangle()
            .fill(Color.secondary.opacity(0.001)) // hit area, near-invisible
            .overlay(
                Rectangle()
                    .fill(Color.secondary.opacity(0.25))
                    .frame(width: 1)
            )
            .frame(width: 6)
            .contentShape(Rectangle())
            .onHover { inside in
                if inside {
                    NSCursor.resizeLeftRight.set()
                } else {
                    NSCursor.arrow.set()
                }
            }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .updating($lastTranslation) { value, state, _ in
                        let delta = value.translation.width - state
                        state = value.translation.width
                        onDrag(delta)
                    }
            )
    }
}
