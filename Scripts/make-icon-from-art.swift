// Composes app icon artwork into the native macOS icon shape:
// Apple squircle (824×824 body in a 1024×1024 canvas, ~185px corner radius),
// transparent corners, and a soft baked-in drop shadow.
//
// Usage: swift Scripts/make-icon-from-art.swift <source-art.png> <output.png>
// The source should be square; its central area is scaled into the squircle.
import Foundation
import CoreGraphics
import ImageIO

guard CommandLine.arguments.count >= 3 else {
    FileHandle.standardError.write("usage: make-icon-from-art.swift <source.png> <output.png>\n".data(using: .utf8)!)
    exit(2)
}
let sourceURL = URL(fileURLWithPath: CommandLine.arguments[1])
let outputURL = URL(fileURLWithPath: CommandLine.arguments[2])

guard let source = CGImageSourceCreateWithURL(sourceURL as CFURL, nil),
      let art = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
    FileHandle.standardError.write("Cannot read source image\n".data(using: .utf8)!)
    exit(1)
}

let canvas: CGFloat = 1024
let margin: CGFloat = 100
let body = CGRect(x: margin, y: margin, width: canvas - margin * 2, height: canvas - margin * 2)
let cornerRadius: CGFloat = 185
let squircle = CGPath(
    roundedRect: body,
    cornerWidth: cornerRadius,
    cornerHeight: cornerRadius,
    transform: nil
)

let context = CGContext(
    data: nil, width: Int(canvas), height: Int(canvas),
    bitsPerComponent: 8, bytesPerRow: 0,
    space: CGColorSpace(name: CGColorSpace.sRGB)!,
    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
)!

// Shadow pass: an opaque squircle casts the baked-in drop shadow.
context.saveGState()
context.setShadow(
    offset: CGSize(width: 0, height: -14),
    blur: 44,
    color: CGColor(srgbRed: 0, green: 0, blue: 0, alpha: 0.45)
)
context.addPath(squircle)
context.setFillColor(CGColor(srgbRed: 0, green: 0, blue: 0, alpha: 1))
context.fillPath()
context.restoreGState()

// Artwork pass: scale the source art into the squircle and clip to it,
// so the corners become transparent.
context.saveGState()
context.addPath(squircle)
context.clip()
context.interpolationQuality = .high
context.draw(art, in: body)
context.restoreGState()

// Subtle inner edge highlight, like Apple's dark icons have.
context.saveGState()
context.addPath(squircle)
context.setStrokeColor(CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 0.08))
context.setLineWidth(2)
context.strokePath()
context.restoreGState()

let result = context.makeImage()!
let destination = CGImageDestinationCreateWithURL(outputURL as CFURL, "public.png" as CFString, 1, nil)!
CGImageDestinationAddImage(destination, result, nil)
guard CGImageDestinationFinalize(destination) else {
    FileHandle.standardError.write("Failed to write output\n".data(using: .utf8)!)
    exit(1)
}
print("Icon written to \(outputURL.path)")
