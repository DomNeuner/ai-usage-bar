import AppKit
let size: CGFloat = 1024
let cs = CGColorSpace(name: CGColorSpace.sRGB)!
let ctx = CGContext(data: nil, width: Int(size), height: Int(size), bitsPerComponent: 8, bytesPerRow: 0, space: cs,
                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
func c(_ h: UInt32, _ a: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: CGFloat((h >> 16) & 255)/255, green: CGFloat((h >> 8) & 255)/255, blue: CGFloat(h & 255)/255, alpha: a)
}
// macOS icon grid: 824pt body inset 100, corner ~185, soft drop shadow
let body = CGRect(x: 100, y: 100, width: 824, height: 824)
let shape = CGPath(roundedRect: body, cornerWidth: 185, cornerHeight: 185, transform: nil)
ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: -12), blur: 28, color: c(0x000000, 0.35))
ctx.addPath(shape); ctx.setFillColor(c(0x1B1A2B)); ctx.fillPath()
ctx.restoreGState()
ctx.saveGState(); ctx.addPath(shape); ctx.clip()
let g = CGGradient(colorsSpace: cs, colors: [c(0x34304F), c(0x16151F)] as CFArray, locations: [0, 1])!
ctx.drawLinearGradient(g, start: CGPoint(x: 512, y: 924), end: CGPoint(x: 512, y: 100), options: [])
// subtle top highlight
let hl = CGGradient(colorsSpace: cs, colors: [c(0xFFFFFF, 0.10), c(0xFFFFFF, 0)] as CFArray, locations: [0, 1])!
ctx.drawLinearGradient(hl, start: CGPoint(x: 512, y: 924), end: CGPoint(x: 512, y: 600), options: [])
ctx.restoreGState()

// Gauges: 240° sweep, open at the bottom. Angles in degrees, CG = counter-clockwise from +x.
let center = CGPoint(x: 512, y: 440)
let start: CGFloat = 210, sweep: CGFloat = 240
func rad(_ d: CGFloat) -> CGFloat { d * .pi / 180 }
func arc(_ r: CGFloat, _ w: CGFloat, _ frac: CGFloat, _ color: CGColor) {
    ctx.setLineCap(.round); ctx.setLineWidth(w)
    ctx.setStrokeColor(c(0xFFFFFF, 0.10))
    ctx.addArc(center: center, radius: r, startAngle: rad(start), endAngle: rad(start - sweep), clockwise: true); ctx.strokePath()
    ctx.setStrokeColor(color)
    ctx.addArc(center: center, radius: r, startAngle: rad(start), endAngle: rad(start - sweep * frac), clockwise: true); ctx.strokePath()
}
arc(300, 64, 0.72, c(0xD97757))   // Claude coral
arc(205, 64, 0.45, c(0xF5F3EE))   // OpenAI white
// needle + hub
let a = rad(start - sweep * 0.58)
ctx.setLineCap(.round); ctx.setLineWidth(26); ctx.setStrokeColor(c(0x8E8AA3))
ctx.move(to: center); ctx.addLine(to: CGPoint(x: center.x + 150 * cos(a), y: center.y + 150 * sin(a))); ctx.strokePath()
ctx.setFillColor(c(0x8E8AA3)); ctx.fillEllipse(in: CGRect(x: center.x - 44, y: center.y - 44, width: 88, height: 88))
ctx.setFillColor(c(0x1B1A2B)); ctx.fillEllipse(in: CGRect(x: center.x - 16, y: center.y - 16, width: 32, height: 32))

let img = ctx.makeImage()!
let rep = NSBitmapImageRep(cgImage: img)
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
