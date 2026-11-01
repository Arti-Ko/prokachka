// Рисует иконку 1024×1024: системный скруглённый квадрат с символом «двойная стрелка вверх» из SF Symbols.
// Использование: swift Scripts/make-icon.swift Assets/AppIcon-1024.png
import AppKit

let outputPath = CommandLine.arguments.dropFirst().first ?? "AppIcon-1024.png"
let canvas = 1024
let tileRect = NSRect(x: 100, y: 100, width: 824, height: 824)
let cornerRadius: CGFloat = 186

guard let bitmap = NSBitmapImageRep(
    bitmapDataPlanes: nil, pixelsWide: canvas, pixelsHigh: canvas,
    bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
    colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
), let context = NSGraphicsContext(bitmapImageRep: bitmap) else {
    fatalError("Не удалось создать холст")
}

NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = context

let tile = NSBezierPath(roundedRect: tileRect, xRadius: cornerRadius, yRadius: cornerRadius)

let shadow = NSShadow()
shadow.shadowColor = NSColor.black.withAlphaComponent(0.22)
shadow.shadowBlurRadius = 28
shadow.shadowOffset = NSSize(width: 0, height: -12)
NSGraphicsContext.saveGraphicsState()
shadow.set()
NSColor.white.setFill()
tile.fill()
NSGraphicsContext.restoreGraphicsState()

// Индиго → синий, как иконка в макете.
NSGradient(
    starting: NSColor(srgbRed: 0.43, green: 0.42, blue: 0.94, alpha: 1),
    ending: NSColor(srgbRed: 0.10, green: 0.55, blue: 1.0, alpha: 1)
)?.draw(in: tile, angle: -90)

NSGradient(
    starting: NSColor.white.withAlphaComponent(0.28),
    ending: NSColor.white.withAlphaComponent(0.0)
)?.draw(in: tile, angle: -90)

let symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 470, weight: .semibold)
    .applying(NSImage.SymbolConfiguration(paletteColors: [.white]))
if let symbol = NSImage(systemSymbolName: "chevron.up.2", accessibilityDescription: nil)?
    .withSymbolConfiguration(symbolConfiguration) {
    let size = symbol.size
    let origin = NSPoint(x: (CGFloat(canvas) - size.width) / 2, y: (CGFloat(canvas) - size.height) / 2)
    symbol.draw(in: NSRect(origin: origin, size: size))
}

NSGraphicsContext.restoreGraphicsState()

guard let png = bitmap.representation(using: .png, properties: [:]) else {
    fatalError("Не удалось закодировать PNG")
}
try png.write(to: URL(filePath: outputPath))
print("иконка: \(outputPath)")
