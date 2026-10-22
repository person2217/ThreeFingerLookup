import AppKit
import Foundation

guard CommandLine.arguments.count == 2 else {
    fputs("usage: generate_icon.swift output.icns\n", stderr)
    exit(2)
}

let outputURL = URL(fileURLWithPath: CommandLine.arguments[1])
let iconsetURL = URL(fileURLWithPath: NSTemporaryDirectory())
    .appendingPathComponent("ThreeFingerLookup-\(UUID().uuidString).iconset")
try FileManager.default.createDirectory(at: iconsetURL, withIntermediateDirectories: true)
defer { try? FileManager.default.removeItem(at: iconsetURL) }

func render(size: Int, filename: String) throws {
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: size,
        pixelsHigh: size,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bitmapFormat: [],
        bytesPerRow: 0,
        bitsPerPixel: 0
    )!
    let context = NSGraphicsContext(bitmapImageRep: rep)!
    NSGraphicsContext.current = context
    NSColor.clear.setFill()
    NSRect(x: 0, y: 0, width: size, height: size).fill()

    let background = NSBezierPath(roundedRect: NSRect(x: 2, y: 2, width: size - 4, height: size - 4), xRadius: CGFloat(size) * 0.22, yRadius: CGFloat(size) * 0.22)
    NSColor(calibratedRed: 0.12, green: 0.42, blue: 0.92, alpha: 1).setFill()
    background.fill()

    let symbolSize = CGFloat(size) * 0.52
    let symbol = NSImage(systemSymbolName: "hand.tap.fill", accessibilityDescription: nil)!
        .withSymbolConfiguration(NSImage.SymbolConfiguration(pointSize: symbolSize, weight: .medium))!
    let symbolRect = NSRect(x: CGFloat(size) * 0.24, y: CGFloat(size) * 0.24, width: CGFloat(size) * 0.52, height: CGFloat(size) * 0.52)
    symbol.draw(in: symbolRect, from: .zero, operation: .sourceOver, fraction: 1)

    let data = rep.representation(using: .png, properties: [:])!
    try data.write(to: iconsetURL.appendingPathComponent(filename))
}

try render(size: 16, filename: "icon_16x16.png")
try render(size: 32, filename: "icon_16x16@2x.png")
try render(size: 32, filename: "icon_32x32.png")
try render(size: 64, filename: "icon_32x32@2x.png")
try render(size: 128, filename: "icon_128x128.png")
try render(size: 256, filename: "icon_128x128@2x.png")
try render(size: 256, filename: "icon_256x256.png")
try render(size: 512, filename: "icon_256x256@2x.png")
try render(size: 512, filename: "icon_512x512.png")
try render(size: 1024, filename: "icon_512x512@2x.png")

let process = Process()
process.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
process.arguments = ["-c", "icns", "-o", outputURL.path, iconsetURL.path]
try process.run()
process.waitUntilExit()
guard process.terminationStatus == 0 else { exit(Int32(process.terminationStatus)) }
