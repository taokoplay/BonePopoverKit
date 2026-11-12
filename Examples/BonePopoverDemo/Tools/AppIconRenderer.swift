// AppIcon 渲染脚本（CoreGraphics，无第三方依赖）：swiftc -O Tools/AppIconRenderer.swift -o /tmp/makeicon && /tmp/makeicon Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png

import AppKit
import CoreGraphics

// 1024×1024 无 alpha，iOS 会自行裁圆角。
let size = 1024
let cs = CGColorSpace(name: CGColorSpace.sRGB)!
guard let ctx = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8,
                          bytesPerRow: 0, space: cs,
                          bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else {
    fatalError("context")
}
func rgb(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> CGColor {
    CGColor(colorSpace: cs, components: [r / 255, g / 255, b / 255, a])!
}

// 背景：深靛蓝 → 紫罗兰
let bg = CGGradient(colorsSpace: cs,
                    colors: [rgb(12, 14, 46), rgb(38, 26, 96), rgb(88, 52, 200)] as CFArray,
                    locations: [0, 0.55, 1])!
ctx.drawLinearGradient(bg, start: CGPoint(x: 0, y: 1024), end: CGPoint(x: 1024, y: 0), options: [])

// 顶部径向光晕
let glow = CGGradient(colorsSpace: cs,
                      colors: [rgb(140, 110, 255, 0.55), rgb(140, 110, 255, 0)] as CFArray,
                      locations: [0, 1])!
ctx.drawRadialGradient(glow, startCenter: CGPoint(x: 512, y: 880), startRadius: 0,
                       endCenter: CGPoint(x: 512, y: 780), endRadius: 620, options: [])

// 背景上的极淡网格线（暗示“多个弹层”），保持图标干净
ctx.setStrokeColor(rgb(255, 255, 255, 0.06))
ctx.setLineWidth(2)
for y in stride(from: 760.0, through: 980.0, by: 70.0) {
    ctx.move(to: CGPoint(x: 96, y: y)); ctx.addLine(to: CGPoint(x: 928, y: y))
}
ctx.strokePath()

// 半透明玻璃面板：只圆上方两角，贴住底边
let sheetRect = CGRect(x: 56, y: -40, width: 912, height: 560)
let sheetPath = CGPath(roundedRect: sheetRect, cornerWidth: 132, cornerHeight: 132, transform: nil)
ctx.saveGState()
ctx.addPath(sheetPath)
ctx.clip()

let glass = CGGradient(colorsSpace: cs,
                       colors: [rgb(255, 255, 255, 0.46), rgb(255, 255, 255, 0.22)] as CFArray,
                       locations: [0, 1])!
ctx.drawLinearGradient(glass, start: CGPoint(x: 512, y: 520), end: CGPoint(x: 512, y: -40), options: [])

// 玻璃内的折射亮带
let sheen = CGGradient(colorsSpace: cs,
                       colors: [rgb(190, 210, 255, 0.35), rgb(190, 210, 255, 0)] as CFArray,
                       locations: [0, 1])!
ctx.drawRadialGradient(sheen, startCenter: CGPoint(x: 300, y: 500), startRadius: 0,
                       endCenter: CGPoint(x: 300, y: 500), endRadius: 520, options: [])
ctx.restoreGState()

// 面板描边（顶部更亮，模拟玻璃边缘）
ctx.addPath(sheetPath)
ctx.setStrokeColor(rgb(255, 255, 255, 0.60))
ctx.setLineWidth(6)
ctx.strokePath()

// 关闭按钮：圆形 + 向下箭头
let closeCenter = CGPoint(x: 168, y: 400)
let closeRect = CGRect(x: closeCenter.x - 56, y: closeCenter.y - 56, width: 112, height: 112)
ctx.setFillColor(rgb(255, 255, 255, 0.40))
ctx.fillEllipse(in: closeRect)
ctx.setStrokeColor(rgb(255, 255, 255, 0.55))
ctx.setLineWidth(4)
ctx.strokeEllipse(in: closeRect)
ctx.setStrokeColor(rgb(255, 255, 255, 0.95))
ctx.setLineWidth(13)
ctx.setLineCap(.round)
ctx.setLineJoin(.round)
ctx.move(to: CGPoint(x: closeCenter.x - 24, y: closeCenter.y + 12))
ctx.addLine(to: CGPoint(x: closeCenter.x, y: closeCenter.y - 16))
ctx.addLine(to: CGPoint(x: closeCenter.x + 24, y: closeCenter.y + 12))
ctx.strokePath()

// 标题占位条
ctx.setFillColor(rgb(255, 255, 255, 0.55))
let titleBar = CGPath(roundedRect: CGRect(x: 288, y: 378, width: 420, height: 44), cornerWidth: 22, cornerHeight: 22, transform: nil)
ctx.addPath(titleBar); ctx.fillPath()

// 列表行
let rows: [(CGFloat, CGFloat, CGFloat)] = [
    (268, 1.0, 0.34),
    (186, 0.78, 0.26),
    (104, 0.55, 0.20)
]
for (y, width, alpha) in rows {
    ctx.setFillColor(rgb(255, 255, 255, alpha))
    let bar = CGPath(roundedRect: CGRect(x: 112, y: y, width: 800 * width, height: 46),
                     cornerWidth: 23, cornerHeight: 23, transform: nil)
    ctx.addPath(bar); ctx.fillPath()
}

// 底部操作行的分隔暗示：右侧小圆点
ctx.setFillColor(rgb(255, 255, 255, 0.30))
ctx.fillEllipse(in: CGRect(x: 838, y: 186, width: 26, height: 26))

guard let image = ctx.makeImage() else { fatalError("image") }
let out = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "icon-1024.png"
let url = URL(fileURLWithPath: out)
let rep = NSBitmapImageRep(cgImage: image)
guard let data = rep.representation(using: .png, properties: [:]) else { fatalError("png") }
try data.write(to: url)
print("wrote \(url.path) \(image.width)x\(image.height)")
