// Generates the Spanorama app icon: two displays with one panorama spanning them.
// Usage: swift Scripts/make-icon.swift <output-png-path>
import Foundation
import CoreGraphics
import ImageIO

let size = 1024
let context = CGContext(
    data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
    space: CGColorSpace(name: CGColorSpace.sRGB)!,
    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
)!

let full = CGRect(x: 0, y: 0, width: size, height: size)

// Squircle background with a vertical gradient.
let background = CGPath(roundedRect: full.insetBy(dx: 32, dy: 32), cornerWidth: 190, cornerHeight: 190, transform: nil)
context.addPath(background)
context.clip()

let bgGradient = CGGradient(
    colorsSpace: CGColorSpace(name: CGColorSpace.sRGB)!,
    colors: [
        CGColor(srgbRed: 0.13, green: 0.14, blue: 0.22, alpha: 1),
        CGColor(srgbRed: 0.06, green: 0.07, blue: 0.11, alpha: 1)
    ] as CFArray, locations: [0, 1]
)!
context.drawLinearGradient(bgGradient, start: CGPoint(x: size / 2, y: size), end: CGPoint(x: size / 2, y: 0), options: [])

// Two displays side by side (canvas coordinates are top-left origin for CG contexts).
let displayFrame = CGRect(x: 132, y: 380, width: 350, height: 240)
let gap: CGFloat = 60
let displays = [
    displayFrame,
    CGRect(x: displayFrame.maxX + gap, y: displayFrame.minY, width: displayFrame.width, height: displayFrame.height)
]

// Bezel: dark rounded rect behind each screen.
for var frame in displays {
    frame = frame.insetBy(dx: -18, dy: -18)
    let bezel = CGPath(roundedRect: frame, cornerWidth: 26, cornerHeight: 26, transform: nil)
    context.addPath(bezel)
    context.setFillColor(CGColor(srgbRed: 0.02, green: 0.02, blue: 0.04, alpha: 1))
    context.fillPath()
}

// One panorama spanning both screens: clipped to the union of both screen rects.
let panoramaRect = CGRect(
    x: displays[0].minX,
    y: displays[0].minY,
    width: displays[1].maxX - displays[0].minX,
    height: displays[0].height
)
context.addPath(CGPath(rect: panoramaRect, transform: nil))
context.clip()
let panorama = CGGradient(
    colorsSpace: CGColorSpace(name: CGColorSpace.sRGB)!,
    colors: [
        CGColor(srgbRed: 1.00, green: 0.55, blue: 0.25, alpha: 1), // sunrise orange
        CGColor(srgbRed: 0.95, green: 0.30, blue: 0.45, alpha: 1), // pink
        CGColor(srgbRed: 0.35, green: 0.30, blue: 0.80, alpha: 1), // dusk purple
        CGColor(srgbRed: 0.20, green: 0.55, blue: 0.90, alpha: 1)  // blue
    ] as CFArray, locations: [0, 0.35, 0.7, 1]
)!
context.drawLinearGradient(
    panorama,
    start: CGPoint(x: panoramaRect.minX, y: panoramaRect.midY),
    end: CGPoint(x: panoramaRect.maxX, y: panoramaRect.midY),
    options: []
)
// Sun disc riding the seam between the two screens.
let seam = displays[0].maxX + gap / 2
context.setFillColor(CGColor(srgbRed: 1, green: 0.92, blue: 0.75, alpha: 1))
context.fillEllipse(in: CGRect(x: seam - 42, y: panoramaRect.minY + 60, width: 84, height: 84))
// Repaint the gap between the bezels so the two reads as two separate screens.
let gapStrip = CGRect(x: displays[0].maxX + 18, y: panoramaRect.minY, width: gap - 36, height: panoramaRect.height)
context.saveGState()
context.addPath(CGPath(rect: gapStrip, transform: nil))
context.clip()
context.drawLinearGradient(bgGradient, start: CGPoint(x: size / 2, y: size), end: CGPoint(x: size / 2, y: 0), options: [])
context.restoreGState()
context.resetClip()

// Screen glass highlight: subtle top sheen on each display.
for frame in displays {
    let sheen = CGGradient(
        colorsSpace: CGColorSpace(name: CGColorSpace.sRGB)!,
        colors: [CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 0.22), CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 0)] as CFArray,
        locations: [0, 1]
    )!
    context.saveGState()
    context.addPath(CGPath(rect: frame, transform: nil))
    context.clip()
    context.drawLinearGradient(sheen, start: CGPoint(x: frame.midX, y: frame.maxY), end: CGPoint(x: frame.midX, y: frame.minY), options: [])
    context.restoreGState()
    // Stands
    let stand = CGRect(x: frame.midX - 16, y: frame.minY - 60, width: 32, height: 62)
    context.setFillColor(CGColor(srgbRed: 0.10, green: 0.10, blue: 0.16, alpha: 1))
    context.fill(stand)
    context.fill(CGRect(x: frame.midX - 52, y: frame.minY - 76, width: 104, height: 18))
}

let image = context.makeImage()!
let outputURL = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "icon-1024.png")
let destination = CGImageDestinationCreateWithURL(outputURL as CFURL, "public.png" as CFString, 1, nil)!
CGImageDestinationAddImage(destination, image, nil)
guard CGImageDestinationFinalize(destination) else {
    FileHandle.standardError.write("Failed to write icon\n".data(using: .utf8)!)
    exit(1)
}
print("Icon written to \(outputURL.path)")
