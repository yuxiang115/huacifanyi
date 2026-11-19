// Renders Design/AppIcon.svg into the PNG sizes of Huaci/Assets.xcassets/AppIcon.appiconset.
// Run on a Mac from the repo root:  swift scripts/render_icon.swift
import AppKit

let svg = URL(fileURLWithPath: "Design/AppIcon.svg")
let output = URL(fileURLWithPath: "Huaci/Assets.xcassets/AppIcon.appiconset")

guard let image = NSImage(contentsOf: svg) else {
    fatalError("cannot load \(svg.path)")
}

// (file name, pixel size)
let sizes: [(String, Int)] = [
    ("icon_16x16.png", 16), ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32), ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128), ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256), ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512), ("icon_512x512@2x.png", 1024),
]

for (name, pixels) in sizes {
    guard let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
    ) else { fatalError("bitmap \(pixels)") }
    rep.size = NSSize(width: pixels, height: pixels)

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    NSGraphicsContext.current?.imageInterpolation = .high
    image.draw(in: NSRect(x: 0, y: 0, width: pixels, height: pixels))
    NSGraphicsContext.restoreGraphicsState()

    guard let png = rep.representation(using: .png, properties: [:]) else { fatalError("png \(name)") }
    try png.write(to: output.appendingPathComponent(name))
    print("wrote \(name) (\(pixels)px)")
}
