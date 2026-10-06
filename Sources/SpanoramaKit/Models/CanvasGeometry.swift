import Foundation
import CoreGraphics

/// Pure geometry for mapping a virtual canvas spanning all displays
/// onto individual screens. All values are in screen points unless
/// a name explicitly says pixels.
public enum CanvasGeometry {
    /// The bounding rect covering every given screen frame (global coordinates).
    /// Screen origins can be negative for displays left of / above the main screen.
    public static func unionBounds(of frames: [CGRect]) -> CGRect? {
        guard let first = frames.first else { return nil }
        var bounds = first
        for frame in frames.dropFirst() {
            bounds = bounds.union(frame)
        }
        return bounds
    }

    /// A screen's position relative to the canvas origin (bottom-left of the union bounds).
    public static func localFrame(for screen: CGRect, in bounds: CGRect) -> CGRect {
        CGRect(
            x: screen.minX - bounds.minX,
            y: screen.minY - bounds.minY,
            width: screen.width,
            height: screen.height
        )
    }
}
