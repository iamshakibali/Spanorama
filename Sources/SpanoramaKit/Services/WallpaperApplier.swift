import AppKit
import CoreGraphics
import ImageIO
import Foundation

/// Renders the canvas into one image per display and applies each image
/// as that display's desktop picture. This is the core of the panorama trick:
/// every display gets its own pre-composited crop, applied with "no scaling"
/// so crops line up pixel-perfectly across screens.
@MainActor
public final class WallpaperApplier {
    public struct Outcome: Equatable {
        public let screenName: String
        public let errorMessage: String?
        public var succeeded: Bool { errorMessage == nil }

        public init(screenName: String, errorMessage: String?) {
            self.screenName = screenName
            self.errorMessage = errorMessage
        }
    }

    public init() {}

    public func apply(
        document: CanvasDocument,
        canvasBounds: CGRect,
        screens: [ScreenInfo],
        imageStore: ImageStore,
        nsScreenProvider: (ScreenInfo) -> NSScreen?
    ) -> [Outcome] {
        var outcomes: [Outcome] = []
        for screen in screens {
            do {
                guard let image = Self.renderWallpaper(for: screen, canvasBounds: canvasBounds, document: document, imageStore: imageStore) else {
                    throw ApplyError.renderFailed(screenName: screen.name)
                }
                let url = try Self.writeTempPNG(image, screenID: screen.id)
                guard let nsScreen = nsScreenProvider(screen) else {
                    throw ApplyError.screenNotFound(name: screen.name)
                }
                // "No scaling" places the crop 1:1 (one image pixel per point),
                // which is what makes per-display crops line up across screens.
                try NSWorkspace.shared.setDesktopImageURL(
                    url,
                    for: nsScreen,
                    options: [.imageScaling: NSNumber(value: NSImageScaling.scaleNone.rawValue)]
                )
                outcomes.append(Outcome(screenName: screen.name, errorMessage: nil))
            } catch {
                outcomes.append(Outcome(screenName: screen.name, errorMessage: error.localizedDescription))
            }
        }
        return outcomes
    }

    public enum ApplyError: LocalizedError {
        case renderFailed(screenName: String)
        case screenNotFound(name: String)
        case encodeFailed

        public var errorDescription: String? {
            switch self {
            case .renderFailed(let name): return "Failed to render wallpaper for \(name)."
            case .screenNotFound(let name): return "Display \(name) is no longer connected."
            case .encodeFailed: return "Failed to encode wallpaper image."
            }
        }
    }

    // MARK: - Rendering

    /// Renders one display's wallpaper: background color plus every layer,
    /// mapped from global screen coordinates into the display's pixel space.
    /// The same drawing routine backs the editor canvas, so preview == result.
    public nonisolated static func renderWallpaper(
        for screen: ScreenInfo,
        canvasBounds: CGRect,
        document: CanvasDocument,
        imageStore: ImageStore
    ) -> CGImage? {
        let pixelSize = screen.pixelSize
        let width = max(Int(pixelSize.width.rounded()), 1)
        let height = max(Int(pixelSize.height.rounded()), 1)
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }

        context.scaleBy(x: screen.scaleFactor, y: screen.scaleFactor)
        context.translateBy(x: -screen.frame.minX, y: -screen.frame.minY)

        drawContents(of: document, imageStore: imageStore, into: context, fillRect: canvasBounds)
        return context.makeImage()
    }

    /// Draws background and layers in global screen coordinates.
    /// Callers are expected to have transformed the context so that global
    /// coordinates map correctly onto their target surface.
    public nonisolated static func drawContents(
        of document: CanvasDocument,
        imageStore: ImageStore,
        into context: CGContext,
        fillRect: CGRect
    ) {
        context.saveGState()
        context.setFillColor(document.background.cgColor)
        context.fill(fillRect)
        context.restoreGState()

        for layer in document.layers.sorted(by: { $0.zOrder < $1.zOrder }) {
            guard let image = imageStore.image(for: layer.imageID) else { continue }
            let aspect = CGFloat(image.width) / CGFloat(image.height)
            let drawRect = AspectMath.drawRect(imageAspect: aspect, in: layer.frame, mode: layer.mode)
            context.saveGState()
            context.clip(to: layer.frame)
            context.draw(image, in: drawRect)
            context.restoreGState()
        }
    }

    // MARK: - Encoding

    public nonisolated static func writeTempPNG(_ image: CGImage, screenID: String) throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("Spanorama", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        // Unique name per apply: macOS keys its wallpaper cache by URL.
        let url = directory.appendingPathComponent("wallpaper-\(screenID)-\(UUID().uuidString).png")
        guard let destination = CGImageDestinationCreateWithURL(url as CFURL, "public.png" as CFString, 1, nil) else {
            throw ApplyError.encodeFailed
        }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else {
            throw ApplyError.encodeFailed
        }
        return url
    }
}
