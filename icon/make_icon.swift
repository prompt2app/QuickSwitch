// 生成 QuickSwitch 应用图标：swift icon/make_icon.swift <输出png路径>
import AppKit

let size: CGFloat = 1024
let out = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "icon_1024.png"

let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(size), pixelsHigh: Int(size),
                           bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                           colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

// 底板：macOS 图标网格，四周留 100px，圆角约 22.5%
let inset: CGFloat = 100
let body = NSRect(x: inset, y: inset, width: size - inset * 2, height: size - inset * 2)
let radius = body.width * 0.225
let plate = NSBezierPath(roundedRect: body, xRadius: radius, yRadius: radius)

// 投影
NSGraphicsContext.saveGraphicsState()
let shadow = NSShadow()
shadow.shadowColor = NSColor.black.withAlphaComponent(0.35)
shadow.shadowBlurRadius = 28
shadow.shadowOffset = NSSize(width: 0, height: -12)
shadow.set()
NSColor.black.setFill()
plate.fill()
NSGraphicsContext.restoreGraphicsState()

// 渐变：靛蓝 → 天蓝
let gradient = NSGradient(colors: [
    NSColor(srgbRed: 0.33, green: 0.25, blue: 0.85, alpha: 1),
    NSColor(srgbRed: 0.16, green: 0.55, blue: 0.98, alpha: 1),
])!
gradient.draw(in: plate, angle: 60)

// 顶部高光
NSGraphicsContext.saveGraphicsState()
plate.addClip()
let gloss = NSGradient(colors: [NSColor.white.withAlphaComponent(0.18), NSColor.white.withAlphaComponent(0)])!
gloss.draw(in: NSRect(x: body.minX, y: body.midY, width: body.width, height: body.height / 2), angle: -90)
NSGraphicsContext.restoreGraphicsState()

// 两个拨动开关：上面是「开」，下面是「关」
func drawSwitch(centerY: CGFloat, on: Bool) {
    let w: CGFloat = 520, h: CGFloat = 220
    let track = NSRect(x: (size - w) / 2, y: centerY - h / 2, width: w, height: h)
    let trackPath = NSBezierPath(roundedRect: track, xRadius: h / 2, yRadius: h / 2)
    (on ? NSColor.white : NSColor.white.withAlphaComponent(0.28)).setFill()
    trackPath.fill()

    let pad: CGFloat = 22
    let d = h - pad * 2
    let x = on ? track.maxX - pad - d : track.minX + pad
    let knob = NSBezierPath(ovalIn: NSRect(x: x, y: track.minY + pad, width: d, height: d))

    NSGraphicsContext.saveGraphicsState()
    let s = NSShadow()
    s.shadowColor = NSColor.black.withAlphaComponent(0.25)
    s.shadowBlurRadius = 14
    s.shadowOffset = NSSize(width: 0, height: -5)
    s.set()
    (on ? NSColor(srgbRed: 0.27, green: 0.42, blue: 0.95, alpha: 1) : NSColor.white).setFill()
    knob.fill()
    NSGraphicsContext.restoreGraphicsState()
}
drawSwitch(centerY: size / 2 + 150, on: true)
drawSwitch(centerY: size / 2 - 150, on: false)

NSGraphicsContext.restoreGraphicsState()
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: out))
print("已生成 \(out)")
