import AppKit
import SwiftUI

// MARK: - MultiItemDragOverlay
//
// SwiftUI's `.onDrag` only ever exports one NSItemProvider per drag, which
// breaks multi-selection drag-out to Finder. To work around that we install
// an NSEvent local monitor on the row's window that watches for left-mouse
// drag inside this overlay's frame, then starts a real `NSDraggingSession`
// carrying every selected `NSFilePromiseProvider`. The monitor co-exists
// with SwiftUI's tap / double-tap / context-menu recognisers because it does
// not consume the events (returns them unchanged).
//
// We use NSFilePromiseProvider (not NSItemProvider with
// `registerFileRepresentation`) because Finder only honours the file-promise
// pasteboard protocol for on-demand drag exports: when the user drops onto
// Finder, AppKit asks our `FileExportPromiseDelegate` for the file name and
// to materialise the file at the drop location.

struct MultiItemDragOverlay: NSViewRepresentable {
    /// Closure invoked at drag start to produce the providers for this gesture.
    /// We accept the general `NSPasteboardWriting` so callers can hand back
    /// either `NSFilePromiseProvider` (preferred) or `NSPasteboardItem`.
    let providersProvider: () -> [NSPasteboardWriting]

    func makeNSView(context: Context) -> DragAnchorView {
        let v = DragAnchorView()
        v.providersProvider = providersProvider
        return v
    }

    func updateNSView(_ nsView: DragAnchorView, context: Context) {
        nsView.providersProvider = providersProvider
    }

    // MARK: - Drag-source NSView

    final class DragAnchorView: NSView, NSDraggingSource {
        var providersProvider: (() -> [NSPasteboardWriting])?

        // Stay event-transparent so SwiftUI keeps handling taps, double-taps
        // and context menus on the row.
        override func hitTest(_ point: NSPoint) -> NSView? { nil }
        override var acceptsFirstResponder: Bool { false }

        private var downMonitor: Any?
        private var dragMonitor: Any?
        private var mouseDownWindowPoint: NSPoint?
        private var mouseDownWasInside = false

        // MARK: Monitor lifecycle

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            tearDownMonitors()
            guard window != nil else { return }
            installMonitors()
        }

        deinit {
            // viewDidMoveToWindow(nil) takes care of teardown; this is belt-
            // and-braces in case the view is deallocated mid-flight.
            if let m = downMonitor { NSEvent.removeMonitor(m) }
            if let m = dragMonitor { NSEvent.removeMonitor(m) }
        }

        private func installMonitors() {
            downMonitor = NSEvent.addLocalMonitorForEvents(matching: .leftMouseDown) { [weak self] event in
                guard let self else { return event }
                guard event.window === self.window else { return event }
                let pointInWindow = event.locationInWindow
                let frameInWindow = self.convert(self.bounds, to: nil)
                self.mouseDownWasInside = frameInWindow.contains(pointInWindow)
                self.mouseDownWindowPoint = pointInWindow
                return event
            }

            dragMonitor = NSEvent.addLocalMonitorForEvents(matching: .leftMouseDragged) { [weak self] event in
                guard let self else { return event }
                guard event.window === self.window else { return event }
                guard self.mouseDownWasInside else { return event }
                guard let start = self.mouseDownWindowPoint else { return event }
                let here = event.locationInWindow
                if hypot(here.x - start.x, here.y - start.y) < 4 { return event }

                // Don't fire twice for the same gesture.
                self.mouseDownWasInside = false
                self.startDrag(with: event)
                return event
            }
        }

        private func tearDownMonitors() {
            if let m = downMonitor { NSEvent.removeMonitor(m); downMonitor = nil }
            if let m = dragMonitor { NSEvent.removeMonitor(m); dragMonitor = nil }
        }

        // MARK: Start drag

        private func startDrag(with event: NSEvent) {
            let providers = providersProvider?() ?? []
            guard !providers.isEmpty else { return }

            let baseRect = bounds.isEmpty ? NSRect(x: 0, y: 0, width: 120, height: 22) : bounds
            let badge = dragImage(badgeCount: providers.count)

            let items: [NSDraggingItem] = providers.enumerated().map { idx, provider in
                let di = NSDraggingItem(pasteboardWriter: provider)
                let offset = CGFloat(idx) * 4
                let rect = NSRect(
                    x: baseRect.minX + offset,
                    y: baseRect.minY - offset,
                    width: baseRect.width,
                    height: baseRect.height
                )
                di.setDraggingFrame(rect, contents: badge)
                return di
            }

            beginDraggingSession(with: items, event: event, source: self)
        }

        private func dragImage(badgeCount: Int) -> NSImage {
            let size = NSSize(width: 28, height: 20)
            let img = NSImage(size: size)
            img.lockFocus()
            NSColor.controlAccentColor.withAlphaComponent(0.85).setFill()
            NSBezierPath(roundedRect: NSRect(origin: .zero, size: size), xRadius: 4, yRadius: 4).fill()
            if badgeCount > 1 {
                let attrs: [NSAttributedString.Key: Any] = [
                    .font: NSFont.boldSystemFont(ofSize: 11),
                    .foregroundColor: NSColor.white
                ]
                let s = "\(badgeCount)" as NSString
                let textSize = s.size(withAttributes: attrs)
                s.draw(
                    at: NSPoint(
                        x: (size.width - textSize.width) / 2,
                        y: (size.height - textSize.height) / 2
                    ),
                    withAttributes: attrs
                )
            }
            img.unlockFocus()
            return img
        }

        // MARK: NSDraggingSource

        func draggingSession(
            _ session: NSDraggingSession,
            sourceOperationMaskFor context: NSDraggingContext
        ) -> NSDragOperation {
            return [.copy]
        }
    }
}
