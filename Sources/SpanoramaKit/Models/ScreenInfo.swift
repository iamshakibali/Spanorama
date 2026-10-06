import Foundation
import CoreGraphics

/// A snapshot of one physical display in the current screen arrangement.
public struct ScreenInfo: Identifiable, Equatable, Hashable {
    /// Stable identifier derived from the CGDirectDisplayID.
    public let id: String
    /// Frame in global screen coordinates (points, origin at the bottom-left of the main screen).
    public let frame: CGRect
    public let name: String
    public let scaleFactor: CGFloat
    public let isMain: Bool

    public init(id: String, frame: CGRect, name: String, scaleFactor: CGFloat, isMain: Bool) {
        self.id = id
        self.frame = frame
        self.name = name
        self.scaleFactor = scaleFactor
        self.isMain = isMain
    }

    /// Pixel size of a wallpaper image that fills this screen 1:1.
    public var pixelSize: CGSize {
        CGSize(width: frame.width * scaleFactor, height: frame.height * scaleFactor)
    }

    public var resolutionDescription: String {
        "\(Int(pixelSize.width)) × \(Int(pixelSize.height))"
    }
}
