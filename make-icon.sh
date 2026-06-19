#!/usr/bin/env bash
#
# Generate Resources/AppIcon.icns from the ScrollSense brand mark.
# The double-headed arrow on a rounded-square, rendered at every required size.
#
set -euo pipefail

OUT_DIR="Resources"
ICONSET="$(mktemp -d)/AppIcon.iconset"
mkdir -p "$ICONSET" "$OUT_DIR"

cat > "${ICONSET}/render.swift" <<'EOF'
import AppKit

let outDir = CommandLine.arguments[1]

// brand background color (deep indigo) and the white mark
let bg = NSColor(srgbRed: 0.231, green: 0.345, blue: 0.961, alpha: 1)

func draw(_ px: Double) {
    let img = NSImage(size: NSSize(width: px, height: px), flipped: false) { _ in
        let margin = px * 0.10
        let side = px - margin * 2
        let rect = NSRect(x: margin, y: margin, width: side, height: side)
        let radius = side * 0.2237
        bg.set()
        NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius).fill()

        // double-headed arrow, centered, ~46% of canvas tall
        let s = px / 18.0 * 0.46 * 18.0 / 18.0  // scale factor base
        let scale = (px * 0.46) / 10.0  // arrow spans ~10 units tall
        let cx = px / 2
        let cy = px / 2
        func p(_ x: Double, _ y: Double) -> NSPoint {
            NSPoint(x: cx + (x - 9) * scale, y: cy + (y - 9) * scale)
        }
        let path = NSBezierPath()
        path.lineWidth = px * 0.052
        path.lineCapStyle = .round
        path.lineJoinStyle = .round
        path.move(to: p(9, 4)); path.line(to: p(9, 14))
        path.move(to: p(6.2, 11.3)); path.line(to: p(9, 14.3)); path.line(to: p(11.8, 11.3))
        path.move(to: p(6.2, 6.7)); path.line(to: p(9, 3.7)); path.line(to: p(11.8, 6.7))
        NSColor.white.set()
        path.stroke()
        _ = s
        return true
    }
    let rep = NSBitmapImageRep(data: img.tiffRepresentation!)!
    rep.size = NSSize(width: px, height: px)
    let data = rep.representation(using: .png, properties: [:])!
    let n = Int(px)
    try! data.write(to: URL(fileURLWithPath: "\(outDir)/icon_\(n).png"))
}

for px in [16.0, 32, 64, 128, 256, 512, 1024] { draw(px) }
print("rendered")
EOF

swift "${ICONSET}/render.swift" "$ICONSET"

# Map rendered PNGs to the names iconutil expects.
cd "$ICONSET"
mv icon_16.png   icon_16x16.png
mv icon_32.png   icon_16x16@2x.png
cp icon_16x16@2x.png icon_32x32.png
mv icon_64.png   icon_32x32@2x.png
mv icon_128.png  icon_128x128.png
mv icon_256.png  icon_128x128@2x.png
cp icon_128x128@2x.png icon_256x256.png
mv icon_512.png  icon_256x256@2x.png
cp icon_256x256@2x.png icon_512x512.png
mv icon_1024.png icon_512x512@2x.png
cd - >/dev/null

iconutil -c icns "$ICONSET" -o "$OUT_DIR/AppIcon.icns"
echo "Wrote $OUT_DIR/AppIcon.icns"
