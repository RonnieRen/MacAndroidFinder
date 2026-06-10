import AppKit
import SwiftUI

// MARK: - FinderHoverTooltipModifier
//
// Mimics macOS Finder's hover tooltip: when the row is selected/highlighted
// and the cursor hovers in place for ~1 second, show a small label with the
// full text just above the cursor. Moving the mouse cancels and re-arms the
// dwell timer; leaving the row hides the tooltip.

struct FinderHoverTooltipModifier: ViewModifier {
    let text: String
    let enabled: Bool

    @State private var pendingTask: Task<Void, Never>?
    @State private var lastLocalPoint: CGPoint = .zero
    @State private var isShowing: Bool = false

    func body(content: Content) -> some View {
        content
            .background(HoverPointReader { phase in
                guard enabled else {
                    cancel()
                    return
                }
                switch phase {
                case .active(let screenPoint, let localPoint):
                    lastLocalPoint = localPoint
                    if isShowing {
                        // Mouse moved while showing: hide and re-arm dwell timer.
                        FinderTooltipWindow.shared.hide()
                        isShowing = false
                    }
                    schedule(screenPoint: screenPoint)
                case .ended:
                    cancel()
                }
            })
            .onChange(of: enabled) { newValue in
                if !newValue { cancel() }
            }
            .onDisappear { cancel() }
    }

    private func schedule(screenPoint: NSPoint) {
        pendingTask?.cancel()
        let snapshot = screenPoint
        let displayText = text
        pendingTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            if Task.isCancelled { return }
            FinderTooltipWindow.shared.show(text: displayText, atScreenPoint: snapshot)
            isShowing = true
        }
    }

    private func cancel() {
        pendingTask?.cancel()
        pendingTask = nil
        if isShowing {
            FinderTooltipWindow.shared.hide()
            isShowing = false
        }
    }
}

// MARK: - View extension

extension View {
    /// Finder-style tooltip: only when `enabled` (e.g. row selected/highlighted),
    /// shows the full text near the cursor after a 1-second hover dwell.
    func finderHoverTooltip(_ text: String, enabled: Bool) -> some View {
        modifier(FinderHoverTooltipModifier(text: text, enabled: enabled))
    }
}
