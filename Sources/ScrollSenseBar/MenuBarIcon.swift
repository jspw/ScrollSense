import AppKit

/// What the menu-bar glyph should depict.
enum MenuBarIconState {
    case mouse
    case trackpad
    case idle
    case disabled
}

/// Renders the menu-bar icon as a crisp template `NSImage`.
///
/// Drawn with vector paths at the exact menu-bar size so it stays sharp at any
/// scale factor, and marked `isTemplate` so macOS tints it for the active /
/// inactive menu bar in both light and dark mode automatically.
enum MenuBarIcon {

    static func image(for state: MenuBarIconState) -> NSImage {
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size, flipped: false) { _ in
            let alpha: CGFloat = state == .disabled ? 0.4 : 1.0
            NSColor.black.withAlphaComponent(alpha).set()
            switch state {
            case .mouse: drawMouse()
            case .trackpad: drawTrackpad()
            case .idle, .disabled: drawBrand()
            }
            return true
        }
        image.isTemplate = true
        return image
    }

    // MARK: - Glyphs

    /// A tall rounded mouse body with a short scroll-wheel tick.
    private static func drawMouse() {
        let body = NSBezierPath(
            roundedRect: NSRect(x: 4.7, y: 1.6, width: 8.6, height: 14.8),
            xRadius: 4.3, yRadius: 4.3)
        body.lineWidth = 1.5
        body.stroke()

        let wheel = NSBezierPath()
        wheel.move(to: NSPoint(x: 9, y: 12.6))
        wheel.line(to: NSPoint(x: 9, y: 14.6))
        wheel.lineWidth = 1.5
        wheel.lineCapStyle = .round
        wheel.stroke()
    }

    /// A wide rounded trackpad with two "two-finger scroll" dots.
    private static func drawTrackpad() {
        let pad = NSBezierPath(
            roundedRect: NSRect(x: 1.8, y: 3.4, width: 14.4, height: 11.2),
            xRadius: 3.0, yRadius: 3.0)
        pad.lineWidth = 1.5
        pad.stroke()

        let r: CGFloat = 1.0
        for cx in [7.4, 10.6] {
            let dot = NSBezierPath(
                ovalIn: NSRect(x: cx - r, y: 9 - r, width: r * 2, height: r * 2))
            dot.fill()
        }
    }

    /// The ScrollSense mark: a vertical double-headed arrow (scroll both ways).
    private static func drawBrand() {
        let path = NSBezierPath()
        path.lineWidth = 1.7
        path.lineCapStyle = .round
        path.lineJoinStyle = .round

        // Stem
        path.move(to: NSPoint(x: 9, y: 4))
        path.line(to: NSPoint(x: 9, y: 14))

        // Up arrowhead
        path.move(to: NSPoint(x: 6.2, y: 11.3))
        path.line(to: NSPoint(x: 9, y: 14.3))
        path.line(to: NSPoint(x: 11.8, y: 11.3))

        // Down arrowhead
        path.move(to: NSPoint(x: 6.2, y: 6.7))
        path.line(to: NSPoint(x: 9, y: 3.7))
        path.line(to: NSPoint(x: 11.8, y: 6.7))

        path.stroke()
    }
}
