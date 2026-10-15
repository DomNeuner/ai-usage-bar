import AppKit

/// Draws the whole menu bar label into a single image (MenuBarExtra labels drop multi-view content).
enum MenuBarRenderer {
    struct Item {
        let logo: NSImage
        let text: String
        /// Colour for the text when rendering non-template; nil uses the base colour.
        let valueColor: NSColor?
    }

    static let height: CGFloat = 18
    private static let logoSize: CGFloat = 14

    /// `base == nil` renders a template image (black, tinted by the system); otherwise colours are applied.
    static func render(_ items: [Item], base: NSColor?) -> NSImage {
        let font = NSFont.monospacedDigitSystemFont(ofSize: NSFont.menuBarFont(ofSize: 0).pointSize, weight: .regular)
        let baseColor = base ?? .black
        let parts = items.map { item -> (Item, NSAttributedString) in
            let color = base == nil ? NSColor.black : (item.valueColor ?? baseColor)
            return (item, NSAttributedString(string: item.text, attributes: [.font: font, .foregroundColor: color]))
        }
        let gap: CGFloat = 3, pairGap: CGFloat = 8
        var width: CGFloat = 0
        for (i, p) in parts.enumerated() {
            width += logoSize + gap + ceil(p.1.size().width)
            if i > 0 { width += pairGap }
        }
        let size = NSSize(width: max(width, 1), height: height)
        let img = NSImage(size: size, flipped: false) { _ in
            var x: CGFloat = 0
            for (i, p) in parts.enumerated() {
                if i > 0 { x += pairGap }
                let logoRect = NSRect(x: x, y: (height - logoSize) / 2, width: logoSize, height: logoSize)
                tinted(p.0.logo, baseColor, size: logoRect.size).draw(in: logoRect)
                x += logoSize + gap
                let ts = p.1.size()
                p.1.draw(at: NSPoint(x: x, y: (height - ts.height) / 2))
                x += ceil(ts.width)
            }
            return true
        }
        img.isTemplate = base == nil
        return img
    }

    private static func tinted(_ image: NSImage, _ color: NSColor, size: NSSize) -> NSImage {
        NSImage(size: size, flipped: false) { r in
            image.draw(in: r)
            color.set()
            r.fill(using: .sourceAtop)
            return true
        }
    }
}
