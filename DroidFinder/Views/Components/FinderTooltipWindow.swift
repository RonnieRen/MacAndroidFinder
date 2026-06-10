import AppKit

// MARK: - FinderTooltipWindow
//
// Floating, mouse-transparent NSPanel used by `finderHoverTooltip(_:enabled:)`
// to draw a tooltip near the cursor. Implemented as an AppKit panel so it can
// escape SwiftUI's per-row clipping in List.

@MainActor
final class FinderTooltipWindow {
    static let shared = FinderTooltipWindow()

    private var panel: NSPanel?
    private let label: NSTextField

    private init() {
        label = NSTextField(labelWithString: "")
        label.font = NSFont.systemFont(ofSize: 11)
        label.textColor = .labelColor
        label.backgroundColor = .clear
        label.isBezeled = false
        label.isEditable = false
        label.drawsBackground = false
        label.lineBreakMode = .byTruncatingMiddle
        label.maximumNumberOfLines = 1
    }

    func show(text: String, atScreenPoint p: NSPoint) {
        if text.isEmpty { hide(); return }
        label.stringValue = text
        let size = label.sizeThatFits(NSSize(width: 800, height: 30))
        let padX: CGFloat = 6
        let padY: CGFloat = 3
        let w = ceil(size.width) + padX * 2
        let h = ceil(size.height) + padY * 2

        // Position the tooltip above the cursor, centered horizontally on it.
        // AppKit screen coordinates are bottom-up, so "above" means a larger y.
        var x = p.x - w / 2
        var y = p.y + 14
        if let screen = NSScreen.screens.first(where: { $0.frame.contains(p) }) ?? NSScreen.main {
            let vis = screen.visibleFrame
            if x < vis.minX + 4 { x = vis.minX + 4 }
            if x + w > vis.maxX - 4 { x = vis.maxX - 4 - w }
            // If it would go off the top, flip to below the cursor.
            if y + h > vis.maxY - 4 { y = p.y - h - 14 }
        }
        let frame = NSRect(x: x, y: y, width: w, height: h)

        if panel == nil {
            panel = makePanel(frame: frame, padX: padX, padY: padY)
        } else {
            panel?.setFrame(frame, display: false)
            if let v = panel?.contentView {
                label.frame = NSRect(
                    x: padX,
                    y: padY,
                    width: v.bounds.width - padX * 2,
                    height: v.bounds.height - padY * 2
                )
            }
        }

        panel?.orderFrontRegardless()
    }

    func hide() {
        panel?.orderOut(nil)
    }

    // MARK: - Helpers

    private func makePanel(frame: NSRect, padX: CGFloat, padY: CGFloat) -> NSPanel {
        let p = NSPanel(
            contentRect: frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        p.isFloatingPanel = true
        p.level = .statusBar
        p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        p.hasShadow = true
        p.isOpaque = false
        p.backgroundColor = .clear
        p.ignoresMouseEvents = true
        p.hidesOnDeactivate = false

        let container = NSView(frame: NSRect(origin: .zero, size: frame.size))
        container.wantsLayer = true
        container.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
        container.layer?.cornerRadius = 4
        container.layer?.borderWidth = 0.5
        container.layer?.borderColor = NSColor.separatorColor.cgColor

        label.frame = NSRect(
            x: padX,
            y: padY,
            width: frame.width - padX * 2,
            height: frame.height - padY * 2
        )
        label.autoresizingMask = [.width, .height]
        container.addSubview(label)
        p.contentView = container
        return p
    }
}
