import Foundation
import CoreGraphics

/// How an image's content maps into the rect the user placed it in.
public enum FillMode: String, Codable, CaseIterable, Identifiable {
    /// Image is letterboxed inside the rect, preserving aspect ratio.
    case fit
    /// Image covers the whole rect (overflow is clipped), preserving aspect ratio.
    case fill
    /// Image is distorted to exactly match the rect.
    case stretch

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .fit: return "Fit"
        case .fill: return "Fill"
        case .stretch: return "Stretch"
        }
    }
}

/// Aspect-ratio math shared by the editor canvas and the wallpaper renderer,
/// so what you see while editing is exactly what gets applied.
public enum AspectMath {
    /// The rect the image content should actually be drawn into for a given mode.
    /// The caller is responsible for clipping to `rect` when the mode is `.fill`.
    public static func drawRect(imageAspect: CGFloat, in rect: CGRect, mode: FillMode) -> CGRect {
        guard rect.width > 0, rect.height > 0, imageAspect > 0, imageAspect.isFinite else {
            return rect
        }
        let rectAspect = rect.width / rect.height
        let drawSize: CGSize
        switch mode {
        case .stretch:
            drawSize = rect.size
        case .fit:
            drawSize = imageAspect > rectAspect
                ? CGSize(width: rect.width, height: rect.width / imageAspect)
                : CGSize(width: rect.height * imageAspect, height: rect.height)
        case .fill:
            drawSize = imageAspect > rectAspect
                ? CGSize(width: rect.height * imageAspect, height: rect.height)
                : CGSize(width: rect.width, height: rect.width / imageAspect)
        }
        return CGRect(
            x: rect.midX - drawSize.width / 2,
            y: rect.midY - drawSize.height / 2,
            width: drawSize.width,
            height: drawSize.height
        )
    }
}
