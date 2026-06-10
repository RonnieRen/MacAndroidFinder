import AppKit
import SwiftUI

// MARK: - HoverPointReader
//
// Bridges `NSTrackingArea` into SwiftUI so we get reliable enter/exit/move
// callbacks AND can translate the cursor location into screen coordinates —
// needed for the floating NSPanel-based tooltip that escapes parent clipping.

struct HoverPointReader: NSViewRepresentable {
    enum Phase {
        case active(screen: NSPoint, local: CGPoint)
        case ended
    }

    let onChange: (Phase) -> Void

    func makeNSView(context: Context) -> TrackingView {
        let v = TrackingView()
        v.onChange = onChange
        return v
    }

    func updateNSView(_ nsView: TrackingView, context: Context) {
        nsView.onChange = onChange
    }

    final class TrackingView: NSView {
        var onChange: ((Phase) -> Void)?
        private var tracking: NSTrackingArea?

        override func updateTrackingAreas() {
            super.updateTrackingAreas()
            if let t = tracking { removeTrackingArea(t) }
            let t = NSTrackingArea(
                rect: bounds,
                options: [.mouseEnteredAndExited, .mouseMoved, .activeInActiveApp, .inVisibleRect],
                owner: self,
                userInfo: nil
            )
            addTrackingArea(t)
            tracking = t
        }

        private func report(_ event: NSEvent) {
            guard let win = window else { return }
            let localInView = convert(event.locationInWindow, from: nil)
            let pointInWindow = event.locationInWindow
            let screenPoint = win.convertPoint(toScreen: pointInWindow)
            onChange?(.active(screen: screenPoint, local: localInView))
        }

        override func mouseEntered(with event: NSEvent) { report(event) }
        override func mouseMoved(with event: NSEvent) { report(event) }
        override func mouseExited(with event: NSEvent) { onChange?(.ended) }
    }
}
