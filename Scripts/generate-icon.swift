#!/usr/bin/env swift
import AppKit

let sizes: [(CGFloat, String)] = [
    (16, "icon_16x16"),
    (32, "icon_16x16@2x"),
    (32, "icon_32x32"),
    (64, "icon_32x32@2x"),
    (128, "icon_128x128"),
    (256, "icon_128x128@2x"),
    (256, "icon_256x256"),
    (512, "icon_256x256@2x"),
    (512, "icon_512x512"),
    (1024, "icon_512x512@2x"),
]

let iconsetPath = ".build/AutoForti.iconset"
try? FileManager.default.createDirectory(atPath: iconsetPath, withIntermediateDirectories: true)

for (size, name) in sizes {
    let image = NSImage(size: NSSize(width: size, height: size), flipped: false) { rect in
        // Background: rounded rect with gradient
        let inset = size * 0.05
        let bgRect = rect.insetBy(dx: inset, dy: inset)
        let bgPath = NSBezierPath(roundedRect: bgRect, xRadius: size * 0.2, yRadius: size * 0.2)

        let gradient = NSGradient(
            colors: [
                NSColor(red: 0.08, green: 0.16, blue: 0.45, alpha: 1.0),
                NSColor(red: 0.06, green: 0.35, blue: 0.55, alpha: 1.0),
                NSColor(red: 0.08, green: 0.50, blue: 0.58, alpha: 1.0),
            ],
            atLocations: [0.0, 0.5, 1.0],
            colorSpace: .deviceRGB
        )!
        gradient.draw(in: bgPath, angle: -60)

        // Draw SF Symbol as white
        let symbolSize = size * 0.5
        let config = NSImage.SymbolConfiguration(pointSize: symbolSize, weight: .medium)
        if let symbol = NSImage(systemSymbolName: "lock.shield.fill", accessibilityDescription: nil)?
            .withSymbolConfiguration(config) {

            // Create white-tinted version
            let tinted = NSImage(size: symbol.size, flipped: false) { tintRect in
                symbol.draw(in: tintRect)
                NSColor.white.set()
                tintRect.fill(using: .sourceAtop)
                return true
            }

            let w = tinted.size.width
            let h = tinted.size.height
            let x = (size - w) / 2
            let y = (size - h) / 2
            tinted.draw(in: NSRect(x: x, y: y, width: w, height: h),
                        from: .zero, operation: .sourceOver, fraction: 1.0)
        }
        return true
    }

    guard let tiff = image.tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: tiff),
          let png = bitmap.representation(using: .png, properties: [:])
    else {
        print("Failed to render \(name)")
        continue
    }

    try! png.write(to: URL(fileURLWithPath: "\(iconsetPath)/\(name).png"))
    print("Generated \(name).png (\(Int(size))x\(Int(size)))")
}

print("Converting to icns...")
let proc = Process()
proc.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
proc.arguments = ["-c", "icns", iconsetPath, "-o", ".build/AutoForti.icns"]
try proc.run()
proc.waitUntilExit()

if proc.terminationStatus == 0 {
    print("Icon created at .build/AutoForti.icns")
} else {
    print("iconutil failed with exit code \(proc.terminationStatus)")
}
