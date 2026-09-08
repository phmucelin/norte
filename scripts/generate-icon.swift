#!/usr/bin/env swift
// Gera o ícone do Norte (bússola/estrela do norte + "N") para iOS e macOS.
// Uso: swift scripts/generate-icon.swift
import AppKit

let root = FileManager.default.currentDirectoryPath

func color(_ hex: UInt32) -> NSColor {
    NSColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
}

/// Desenha o ícone mestre em 1024. `bleed` = full-bleed (iOS); senão
/// desenha com padding e cantos arredondados no estilo macOS.
func drawMaster(bleed: Bool) -> NSImage {
    let s: CGFloat = 1024
    let image = NSImage(size: NSSize(width: s, height: s))
    image.lockFocus()
    let ctx = NSGraphicsContext.current!.cgContext

    let pad: CGFloat = bleed ? 0 : s * 0.09
    let rect = CGRect(x: pad, y: pad, width: s - pad * 2, height: s - pad * 2)
    let radius: CGFloat = bleed ? 0 : rect.width * 0.2237

    if !bleed {
        // Sombra suave sob o ícone (estilo dock do macOS).
        ctx.saveGState()
        ctx.setShadow(offset: CGSize(width: 0, height: -s * 0.012),
                      blur: s * 0.03, color: color(0x000000).withAlphaComponent(0.35).cgColor)
        ctx.addPath(CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil))
        ctx.setFillColor(color(0x000000).cgColor)
        ctx.fillPath()
        ctx.restoreGState()
    }

    // Recorte no cartão arredondado.
    ctx.saveGState()
    let cardPath = CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)
    ctx.addPath(cardPath)
    ctx.clip()

    // Fundo em gradiente diagonal roxo (identidade do app).
    let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                              colors: [color(0x8B6BFF).cgColor, color(0x5A34C9).cgColor,
                                       color(0x3B1E8F).cgColor] as CFArray,
                              locations: [0, 0.55, 1])!
    ctx.drawLinearGradient(gradient,
                           start: CGPoint(x: rect.minX, y: rect.maxY),
                           end: CGPoint(x: rect.maxX, y: rect.minY),
                           options: [])

    // Brilho radial no topo.
    let glow = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                          colors: [color(0xB9A3FF).withAlphaComponent(0.55).cgColor,
                                   color(0xB9A3FF).withAlphaComponent(0).cgColor] as CFArray,
                          locations: [0, 1])!
    ctx.drawRadialGradient(glow,
                           startCenter: CGPoint(x: rect.midX, y: rect.maxY - rect.height * 0.12),
                           startRadius: 0,
                           endCenter: CGPoint(x: rect.midX, y: rect.maxY - rect.height * 0.12),
                           endRadius: rect.width * 0.6, options: [])
    ctx.restoreGState()

    // "N" central, fonte arredondada pesada, branco levemente gradiente.
    let fontSize = rect.width * 0.62
    let baseFont = NSFont.systemFont(ofSize: fontSize, weight: .heavy)
    let font: NSFont
    if let rounded = baseFont.fontDescriptor.withDesign(.rounded) {
        font = NSFont(descriptor: rounded, size: fontSize) ?? baseFont
    } else {
        font = baseFont
    }
    let paragraph = NSMutableParagraphStyle()
    paragraph.alignment = .center
    let attributes: [NSAttributedString.Key: Any] = [
        .font: font,
        .foregroundColor: NSColor.white,
        .paragraphStyle: paragraph
    ]
    let text = NSAttributedString(string: "N", attributes: attributes)
    let textSize = text.size()
    let textRect = CGRect(x: rect.midX - textSize.width / 2,
                          y: rect.midY - textSize.height / 2 - rect.height * 0.01,
                          width: textSize.width, height: textSize.height)
    // Sombra sutil no N para dar profundidade.
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -s * 0.006),
                  blur: s * 0.02, color: color(0x2A1466).withAlphaComponent(0.6).cgColor)
    text.draw(in: textRect)
    ctx.restoreGState()

    // Estrela do norte (4 pontas) no canto superior direito do N.
    let starCenter = CGPoint(x: rect.midX + textSize.width * 0.30,
                             y: rect.midY + textSize.height * 0.34)
    let r1 = rect.width * 0.052   // ponta longa
    let r2 = rect.width * 0.017   // ponta curta
    let star = NSBezierPath()
    for i in 0..<8 {
        let angle = CGFloat(i) * .pi / 4
        let radiusForPoint = i % 2 == 0 ? r1 : r2
        let p = CGPoint(x: starCenter.x + cos(angle) * radiusForPoint,
                        y: starCenter.y + sin(angle) * radiusForPoint)
        if i == 0 { star.move(to: p) } else { star.line(to: p) }
    }
    star.close()
    color(0xFFFFFF).setFill()
    star.fill()

    image.unlockFocus()
    return image
}

func png(from image: NSImage, size: Int) -> Data {
    let target = NSImage(size: NSSize(width: size, height: size))
    target.lockFocus()
    NSGraphicsContext.current?.imageInterpolation = .high
    image.draw(in: NSRect(x: 0, y: 0, width: size, height: size),
               from: NSRect(x: 0, y: 0, width: image.size.width, height: image.size.height),
               operation: .copy, fraction: 1)
    target.unlockFocus()
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size,
                              bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                              isPlanar: false, colorSpaceName: .deviceRGB,
                              bytesPerRow: 0, bitsPerPixel: 0)!
    let g = NSGraphicsContext(bitmapImageRep: rep)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = g
    g.imageInterpolation = .high
    target.draw(in: NSRect(x: 0, y: 0, width: size, height: size))
    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

func write(_ data: Data, to path: String) {
    let url = URL(fileURLWithPath: path)
    try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(),
                                             withIntermediateDirectories: true)
    try! data.write(to: url)
    print("  \(path)")
}

// iOS: um único 1024 full-bleed.
let iosMaster = drawMaster(bleed: true)
let iosDir = "\(root)/Apps/iOS/Assets.xcassets/AppIcon.appiconset"
print("iOS:")
write(png(from: iosMaster, size: 1024), to: "\(iosDir)/Icon-1024.png")
let iosContents = """
{
  "images" : [
    { "filename" : "Icon-1024.png", "idiom" : "universal", "platform" : "ios", "size" : "1024x1024" }
  ],
  "info" : { "author" : "xcode", "version" : 1 }
}
"""
write(iosContents.data(using: .utf8)!, to: "\(iosDir)/Contents.json")

// macOS: conjunto padrão com padding/cantos.
let macMaster = drawMaster(bleed: false)
let macDir = "\(root)/Apps/macOS/Assets.xcassets/AppIcon.appiconset"
print("macOS:")
let macSpecs: [(name: String, px: Int)] = [
    ("icon_16", 16), ("icon_16@2x", 32),
    ("icon_32", 32), ("icon_32@2x", 64),
    ("icon_128", 128), ("icon_128@2x", 256),
    ("icon_256", 256), ("icon_256@2x", 512),
    ("icon_512", 512), ("icon_512@2x", 1024)
]
var seen = Set<Int>()
for spec in macSpecs where !seen.contains(spec.px) {
    seen.insert(spec.px)
}
for spec in macSpecs {
    write(png(from: macMaster, size: spec.px), to: "\(macDir)/\(spec.name).png")
}
let macContents = """
{
  "images" : [
    { "filename" : "icon_16.png", "idiom" : "mac", "scale" : "1x", "size" : "16x16" },
    { "filename" : "icon_16@2x.png", "idiom" : "mac", "scale" : "2x", "size" : "16x16" },
    { "filename" : "icon_32.png", "idiom" : "mac", "scale" : "1x", "size" : "32x32" },
    { "filename" : "icon_32@2x.png", "idiom" : "mac", "scale" : "2x", "size" : "32x32" },
    { "filename" : "icon_128.png", "idiom" : "mac", "scale" : "1x", "size" : "128x128" },
    { "filename" : "icon_128@2x.png", "idiom" : "mac", "scale" : "2x", "size" : "128x128" },
    { "filename" : "icon_256.png", "idiom" : "mac", "scale" : "1x", "size" : "256x256" },
    { "filename" : "icon_256@2x.png", "idiom" : "mac", "scale" : "2x", "size" : "256x256" },
    { "filename" : "icon_512.png", "idiom" : "mac", "scale" : "1x", "size" : "512x512" },
    { "filename" : "icon_512@2x.png", "idiom" : "mac", "scale" : "2x", "size" : "512x512" }
  ],
  "info" : { "author" : "xcode", "version" : 1 }
}
"""
write(macContents.data(using: .utf8)!, to: "\(macDir)/Contents.json")
print("Pronto.")
