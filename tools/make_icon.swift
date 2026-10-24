// Draws the app icon (1024x1024 PNG). Usage: make_icon OUTPUT.png
// Shield with a battery charged to ~80% (the charge limit) and a bolt, on a deep teal tile.
import AppKit

let size: CGFloat = 1024
let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(size), pixelsHigh: Int(size), bitsPerSample: 8,
                           samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                           bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
let ctx = NSGraphicsContext.current!.cgContext

func rgb(_ hex: UInt32, _ a: CGFloat = 1) -> NSColor {
    NSColor(srgbRed: CGFloat((hex >> 16) & 0xff) / 255, green: CGFloat((hex >> 8) & 0xff) / 255, blue: CGFloat(hex & 0xff) / 255, alpha: a)
}
func shadow(_ blur: CGFloat, _ dy: CGFloat, _ color: NSColor, _ draw: () -> Void) {
    NSGraphicsContext.saveGraphicsState()
    let s = NSShadow(); s.shadowBlurRadius = blur; s.shadowOffset = NSSize(width: 0, height: dy); s.shadowColor = color; s.set()
    draw()
    NSGraphicsContext.restoreGraphicsState()
}
func gradientFill(_ path: NSBezierPath, _ colors: [NSColor], angle: CGFloat = -90) {
    NSGradient(colors: colors)!.draw(in: path, angle: angle)
}

// Tile: macOS icon grid, 824 px square with ~185 px corners, centered.
let tileRect = NSRect(x: 100, y: 100, width: 824, height: 824)
let tile = NSBezierPath(roundedRect: tileRect, xRadius: 185, yRadius: 185)
shadow(28, -12, rgb(0x000000, 0.35)) { rgb(0x0B3B44).setFill(); tile.fill() }
gradientFill(tile, [rgb(0x147A7E), rgb(0x0E4F63), rgb(0x0A2F45)])
// Soft light from the top
NSGraphicsContext.saveGraphicsState()
tile.addClip()
NSGradient(colors: [rgb(0xFFFFFF, 0.16), rgb(0xFFFFFF, 0)])!
    .draw(in: NSBezierPath(ovalIn: NSRect(x: 40, y: 560, width: 944, height: 560)), relativeCenterPosition: .zero)
NSGraphicsContext.restoreGraphicsState()

// Shield
let cx: CGFloat = 512
let shield = NSBezierPath()
shield.move(to: NSPoint(x: cx, y: 838))
shield.curve(to: NSPoint(x: 806, y: 742), controlPoint1: NSPoint(x: 630, y: 792), controlPoint2: NSPoint(x: 722, y: 764))
shield.curve(to: NSPoint(x: cx, y: 168), controlPoint1: NSPoint(x: 810, y: 470), controlPoint2: NSPoint(x: 708, y: 270))
shield.curve(to: NSPoint(x: 218, y: 742), controlPoint1: NSPoint(x: 316, y: 270), controlPoint2: NSPoint(x: 214, y: 470))
shield.curve(to: NSPoint(x: cx, y: 838), controlPoint1: NSPoint(x: 302, y: 764), controlPoint2: NSPoint(x: 394, y: 792))
shield.close()
shadow(30, -14, rgb(0x00131F, 0.5)) { rgb(0xF4F8F8).setFill(); shield.fill() }
gradientFill(shield, [rgb(0xFFFFFF), rgb(0xE3EEF0), rgb(0xC9DCDF)])
rgb(0xFFFFFF, 0.9).setStroke(); shield.lineWidth = 4; shield.stroke()

// Battery, vertical, inside the shield
let body = NSRect(x: cx - 134, y: 268, width: 268, height: 412)
let cap = NSBezierPath(roundedRect: NSRect(x: cx - 54, y: body.maxY - 6, width: 108, height: 46), xRadius: 16, yRadius: 16)
rgb(0x24485A).setFill(); cap.fill()
let shell = NSBezierPath(roundedRect: body, xRadius: 54, yRadius: 54)
shadow(10, -4, rgb(0x00131F, 0.25)) { rgb(0x24485A).setFill(); shell.fill() }
let inner = body.insetBy(dx: 22, dy: 22)
rgb(0x0E2633).setFill(); NSBezierPath(roundedRect: inner, xRadius: 34, yRadius: 34).fill()

// Charge up to 80%: the limit the app keeps
let level = inner.height * 0.8
let fillRect = NSRect(x: inner.minX, y: inner.minY, width: inner.width, height: level)
NSGraphicsContext.saveGraphicsState()
NSBezierPath(roundedRect: inner, xRadius: 34, yRadius: 34).addClip()
NSBezierPath(rect: fillRect).addClip()
gradientFill(NSBezierPath(rect: inner), [rgb(0x7CF29A), rgb(0x2FCB63), rgb(0x169A47)])
// glossy stripe on the left
gradientFill(NSBezierPath(rect: NSRect(x: inner.minX + 18, y: inner.minY, width: 34, height: level)),
             [rgb(0xFFFFFF, 0.35), rgb(0xFFFFFF, 0.05)], angle: 0)
NSGraphicsContext.restoreGraphicsState()
// limit mark
rgb(0xFFFFFF, 0.85).setFill()
NSBezierPath(roundedRect: NSRect(x: inner.minX + 10, y: fillRect.maxY - 3, width: inner.width - 20, height: 6), xRadius: 3, yRadius: 3).fill()

// Bolt
let bolt = NSBezierPath()
let pts: [(CGFloat, CGFloat)] = [(42, 176), (-72, -12), (-8, -12), (-36, -176), (78, 24), (10, 24)]
for (i, p) in pts.enumerated() {
    let pt = NSPoint(x: cx + p.0, y: body.midY + p.1)
    if i == 0 { bolt.move(to: pt) } else { bolt.line(to: pt) }
}
bolt.close()
bolt.lineJoinStyle = .round
shadow(16, -6, rgb(0x00131F, 0.45)) { rgb(0xFFFFFF).setFill(); bolt.fill() }
gradientFill(bolt, [rgb(0xFFFFFF), rgb(0xEAF6EE)])
rgb(0xFFFFFF).setStroke(); bolt.lineWidth = 6; bolt.stroke()

NSGraphicsContext.restoreGraphicsState()
let out = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "icon.png"
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: out))
