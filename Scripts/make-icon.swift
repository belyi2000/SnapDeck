#!/usr/bin/env swift
import AppKit
import Foundation

let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
    .deletingLastPathComponent()
let iconset = root.appendingPathComponent("Resources/AppIcon.iconset")
let icns = root.appendingPathComponent("Resources/AppIcon.icns")

try? FileManager.default.removeItem(at: iconset)
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)

func makeIcon(size: Int) -> NSBitmapImageRep {
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: size,
        pixelsHigh: size,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    )!
    rep.size = NSSize(width: size, height: size)

    let context = NSGraphicsContext(bitmapImageRep: rep)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = context

    let scale = CGFloat(size) / 1024.0
    context.cgContext.scaleBy(x: scale, y: scale)

    // Background: deep navy to electric blue.
    let background = NSBezierPath(
        roundedRect: NSRect(x: 62, y: 62, width: 900, height: 900),
        xRadius: 210,
        yRadius: 210
    )
    let gradient = NSGradient(colors: [
        NSColor(calibratedRed: 0.035, green: 0.06, blue: 0.20, alpha: 1),
        NSColor(calibratedRed: 0.03, green: 0.31, blue: 0.95, alpha: 1)
    ])!
    gradient.draw(in: background, angle: -52)

    // Soft highlight in the upper-left, clipped to the rounded icon shape.
    let highlight = NSBezierPath(ovalIn: NSRect(x: 80, y: 520, width: 600, height: 600))
    context.cgContext.saveGState()
    background.addClip()
    NSColor.white.withAlphaComponent(0.075).setFill()
    highlight.fill()
    context.cgContext.restoreGState()

    // Window silhouette.
    let windowRect = NSRect(x: 218, y: 278, width: 588, height: 468)
    let window = NSBezierPath(roundedRect: windowRect, xRadius: 58, yRadius: 58)
    NSColor.black.withAlphaComponent(0.18).setFill()
    let shadow = window.copy() as! NSBezierPath
    shadow.transform(using: AffineTransform(translationByX: 0, byY: -18))
    shadow.fill()

    NSColor(calibratedWhite: 1, alpha: 0.14).setFill()
    window.fill()
    NSColor(calibratedWhite: 1, alpha: 0.72).setStroke()
    window.lineWidth = 16
    window.stroke()

    // Window split. The left pane is bright, the right pane is a translucent
    // target — the icon reads as a snap action at every size.
    let leftPane = NSBezierPath(
        roundedRect: NSRect(x: 266, y: 326, width: 238, height: 346),
        xRadius: 25,
        yRadius: 25
    )
    NSColor(calibratedWhite: 1, alpha: 0.94).setFill()
    leftPane.fill()

    let rightPane = NSBezierPath(
        roundedRect: NSRect(x: 523, y: 326, width: 237, height: 346),
        xRadius: 25,
        yRadius: 25
    )
    NSColor(calibratedWhite: 1, alpha: 0.36).setFill()
    rightPane.fill()
    NSColor(calibratedWhite: 1, alpha: 0.48).setStroke()
    rightPane.lineWidth = 9
    rightPane.stroke()

    // A bright blue seam is the visual identity of the app.
    let seam = NSBezierPath(roundedRect: NSRect(x: 496, y: 337, width: 18, height: 324), xRadius: 9, yRadius: 9)
    NSColor(calibratedRed: 0.24, green: 0.73, blue: 1.0, alpha: 1).setFill()
    seam.fill()

    // Two small title-bar dots.
    NSColor.white.withAlphaComponent(0.65).setFill()
    for x in [282.0, 310.0] {
        NSBezierPath(ovalIn: NSRect(x: x, y: 691, width: 14, height: 14)).fill()
    }

    NSGraphicsContext.restoreGraphicsState()
    return rep
}

let files: [(String, Int)] = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024)
]

for (name, size) in files {
    let rep = makeIcon(size: size)
    guard let png = rep.representation(using: .png, properties: [:]) else {
        fatalError("Could not encode \(name)")
    }
    try png.write(to: iconset.appendingPathComponent(name))
}

let process = Process()
process.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
process.arguments = ["-c", "icns", iconset.path, "-o", icns.path]
try process.run()
process.waitUntilExit()
guard process.terminationStatus == 0 else {
    fatalError("iconutil failed")
}

try? FileManager.default.removeItem(at: iconset)
print("Created \(icns.path)")
