import Foundation
import CoreGraphics
import AppKit

/// A Codable wrapper around an RGBA color, safe to embed in JSON documents.
public struct CodableColor: Codable, Equatable {
    public var red: Double
    public var green: Double
    public var blue: Double
    public var alpha: Double

    public init(red: Double, green: Double, blue: Double, alpha: Double = 1) {
        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = alpha
    }

    public var nsColor: NSColor {
        NSColor(calibratedRed: red, green: green, blue: blue, alpha: alpha)
    }

    public var cgColor: CGColor {
        CGColor(srgbRed: red, green: green, blue: blue, alpha: alpha)
    }

    public init(nsColor: NSColor) {
        let c = nsColor.usingColorSpace(.sRGB) ?? .black
        self.init(red: Double(c.redComponent), green: Double(c.greenComponent), blue: Double(c.blueComponent), alpha: Double(c.alphaComponent))
    }
}
