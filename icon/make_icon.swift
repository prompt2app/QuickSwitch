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

// 中间一道白色闪电（SF Symbol bolt.fill），和菜单栏图标呼应
let cfg = NSImage.SymbolConfiguration(pointSize: 470, weight: .semibold)
let bolt = NSImage(systemSymbolName: "bolt.fill", accessibilityDescription: nil)!.withSymbolConfiguration(cfg)!
let white = NSImage(size: bolt.size)
white.lockFocus()
bolt.draw(at: .zero, from: .zero, operation: .sourceOver, fraction: 1)
NSColor.white.set()
NSRect(origin: .zero, size: bolt.size).fill(using: .sourceAtop)
white.unlockFocus()

NSGraphicsContext.saveGraphicsState()
let boltShadow = NSShadow()
boltShadow.shadowColor = NSColor(srgbRed: 0.10, green: 0.08, blue: 0.40, alpha: 0.45)
boltShadow.shadowBlurRadius = 30
boltShadow.shadowOffset = NSSize(width: 0, height: -14)
boltShadow.set()
white.draw(at: NSPoint(x: (size - bolt.size.width) / 2, y: (size - bolt.size.height) / 2),
           from: .zero, operation: .sourceOver, fraction: 1)
NSGraphicsContext.restoreGraphicsState()

NSGraphicsContext.restoreGraphicsState()
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: out))
print("已生成 \(out)")
