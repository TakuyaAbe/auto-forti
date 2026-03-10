#!/usr/bin/env swift
import AppKit

// Generate app icon with original shield + lock design (no SF Symbols)

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

func drawShield(in rect: NSRect, size: CGFloat) {
    let cx = size / 2
    let cy = size / 2

    // Shield dimensions
    let shieldW = size * 0.42
    let shieldH = size * 0.50
    let shieldTop = cy + shieldH * 0.45
    let shieldBot = cy - shieldH * 0.55

    // Shield path: pointed bottom, curved top
    let shield = NSBezierPath()
    shield.move(to: NSPoint(x: cx, y: shieldBot))  // bottom point
    // Left side curve
    shield.curve(to: NSPoint(x: cx - shieldW, y: cy + shieldH * 0.1),
                 controlPoint1: NSPoint(x: cx - shieldW * 0.5, y: shieldBot + shieldH * 0.1),
                 controlPoint2: NSPoint(x: cx - shieldW, y: cy - shieldH * 0.15))
    // Left top
    shield.line(to: NSPoint(x: cx - shieldW, y: shieldTop - shieldH * 0.15))
    // Top curve
    shield.curve(to: NSPoint(x: cx, y: shieldTop),
                 controlPoint1: NSPoint(x: cx - shieldW, y: shieldTop),
                 controlPoint2: NSPoint(x: cx - shieldW * 0.4, y: shieldTop))
    shield.curve(to: NSPoint(x: cx + shieldW, y: shieldTop - shieldH * 0.15),
                 controlPoint1: NSPoint(x: cx + shieldW * 0.4, y: shieldTop),
                 controlPoint2: NSPoint(x: cx + shieldW, y: shieldTop))
    // Right side
    shield.line(to: NSPoint(x: cx + shieldW, y: cy + shieldH * 0.1))
    shield.curve(to: NSPoint(x: cx, y: shieldBot),
                 controlPoint1: NSPoint(x: cx + shieldW, y: cy - shieldH * 0.15),
                 controlPoint2: NSPoint(x: cx + shieldW * 0.5, y: shieldBot + shieldH * 0.1))
    shield.close()

    // Shield fill with subtle gradient
    NSGraphicsContext.current?.saveGraphicsState()
    shield.addClip()
    let shieldGrad = NSGradient(
        starting: NSColor(white: 1.0, alpha: 0.95),
        ending: NSColor(white: 0.85, alpha: 0.95)
    )!
    shieldGrad.draw(in: shield.bounds, angle: -90)
    NSGraphicsContext.current?.restoreGraphicsState()

    // Shield stroke
    NSColor(white: 0.7, alpha: 0.5).setStroke()
    shield.lineWidth = size * 0.008
    shield.stroke()

    // Lock body
    let lockW = size * 0.14
    let lockH = size * 0.12
    let lockX = cx - lockW / 2
    let lockY = cy - lockH * 0.7
    let lockRect = NSRect(x: lockX, y: lockY, width: lockW, height: lockH)
    let lockPath = NSBezierPath(roundedRect: lockRect, xRadius: size * 0.02, yRadius: size * 0.02)
    NSColor(red: 0.08, green: 0.25, blue: 0.50, alpha: 1.0).setFill()
    lockPath.fill()

    // Lock shackle (U-shape)
    let shackleW = size * 0.09
    let shackleH = size * 0.09
    let shackle = NSBezierPath()
    shackle.lineWidth = size * 0.025
    shackle.lineCapStyle = .round
    let shackleLeft = cx - shackleW / 2
    let shackleRight = cx + shackleW / 2
    let shackleBottom = lockY + lockH
    shackle.move(to: NSPoint(x: shackleLeft, y: shackleBottom))
    shackle.line(to: NSPoint(x: shackleLeft, y: shackleBottom + shackleH * 0.5))
    shackle.curve(to: NSPoint(x: shackleRight, y: shackleBottom + shackleH * 0.5),
                  controlPoint1: NSPoint(x: shackleLeft, y: shackleBottom + shackleH),
                  controlPoint2: NSPoint(x: shackleRight, y: shackleBottom + shackleH))
    shackle.line(to: NSPoint(x: shackleRight, y: shackleBottom))
    NSColor(red: 0.08, green: 0.25, blue: 0.50, alpha: 1.0).setStroke()
    shackle.stroke()

    // Keyhole
    let keyholeR = size * 0.02
    let keyholeCY = lockY + lockH * 0.55
    let keyholePath = NSBezierPath(ovalIn: NSRect(x: cx - keyholeR, y: keyholeCY - keyholeR,
                                                   width: keyholeR * 2, height: keyholeR * 2))
    // Keyhole slot
    let slotW = size * 0.012
    let slotH = size * 0.035
    keyholePath.append(NSBezierPath(rect: NSRect(x: cx - slotW / 2, y: keyholeCY - keyholeR - slotH,
                                                  width: slotW, height: slotH)))
    NSColor(white: 0.9, alpha: 1.0).setFill()
    keyholePath.fill()
}

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

        // Draw original shield + lock
        drawShield(in: rect, size: size)

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
