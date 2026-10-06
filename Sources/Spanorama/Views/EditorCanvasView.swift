import AppKit
import Combine
import SwiftUI
import SpanoramaKit

/// The interactive editing surface. Draws the real display arrangement and
/// the image layers in global screen coordinates, with drag-to-move,
/// scroll-to-zoom, arrow-key nudge and delete-key remove.
final class EditorCanvas: NSView {
    var model: EditorModel? {
        didSet {
            cancellable?.cancel()
            cancellable = model?.objectWillChange.sink { [weak self] _ in
                DispatchQueue.main.async { self?.needsDisplay = true }
            }
            needsDisplay = true
        }
    }

    private var cancellable: AnyCancellable?
    private var isDraggingLayer = false
    private var dragStartCanvasPoint: CGPoint?

    override var acceptsFirstResponder: Bool { true }

    // MARK: - Coordinate mapping (global screen points <-> view points)

    private struct Transform {
        let scale: CGFloat
        let tx: CGFloat
        let ty: CGFloat

        func toView(_ canvasPoint: CGPoint) -> CGPoint {
            CGPoint(
                x: canvasPoint.x * scale + tx,
                y: canvasPoint.y * scale + ty
            )
        }

        func toView(_ canvasRect: CGRect) -> CGRect {
            CGRect(origin: toView(canvasRect.origin), size: CGSize(width: canvasRect.width * scale, height: canvasRect.height * scale))
        }

        func toCanvas(_ viewPoint: CGPoint) -> CGPoint {
            CGPoint(
                x: (viewPoint.x - tx) / scale,
                y: (viewPoint.y - ty) / scale
            )
        }
    }

    /// Fits the union of all displays inside the view with a small margin.
    private var canvasTransform: Transform {
        let padding: CGFloat = 36
        guard let union = model?.screenService.unionBounds, union.width > 0, union.height > 0 else {
            return Transform(scale: 1, tx: 0, ty: 0)
        }
        let availableWidth = max(bounds.width - padding * 2, 10)
        let availableHeight = max(bounds.height - padding * 2, 10)
        let scale = min(availableWidth / union.width, availableHeight / union.height)
        let drawnWidth = union.width * scale
        let drawnHeight = union.height * scale
        return Transform(
            scale: scale,
            tx: (bounds.width - drawnWidth) / 2 - union.minX * scale,
            ty: (bounds.height - drawnHeight) / 2 - union.minY * scale
        )
    }

    private func canvasPoint(from event: NSEvent) -> CGPoint {
        let viewPoint = convert(event.locationInWindow, from: nil)
        return canvasTransform.toCanvas(viewPoint)
    }

    // MARK: - Drawing

    override func draw(_ dirtyRect: NSRect) {
        // The window background is a glass effect view (see VisualEffectBackground);
        // leave this view transparent so the glass shows around the canvas.

        guard let model else { return }
        let transform = canvasTransform

        guard let union = model.screenService.unionBounds, !model.screenService.screens.isEmpty else {
            drawCenteredText("No displays detected", in: bounds)
            return
        }

        // Canvas sheet — previews the background color that will be applied.
        let unionRect = transform.toView(union)
        model.document.background.nsColor.setFill()
        NSBezierPath(rect: unionRect).fill()

        // Screen rectangles — base fill previews the applied background color.
        for screen in model.screenService.screens {
            let rect = transform.toView(screen.frame)

            // Soft drop shadow, like an artboard in a design tool.
            NSGraphicsContext.current?.saveGraphicsState()
            let shadow = NSShadow()
            shadow.shadowColor = NSColor.black.withAlphaComponent(0.28)
            shadow.shadowBlurRadius = 6
            shadow.shadowOffset = NSSize(width: 0, height: -2)
            shadow.set()
            model.document.background.nsColor.setFill()
            NSBezierPath(rect: rect).fill()
            NSGraphicsContext.current?.restoreGraphicsState()

            NSColor.separatorColor.setStroke()
            let border = NSBezierPath(rect: rect)
            border.lineWidth = 1
            border.stroke()

            let label = "\(screen.name)  ·  \(screen.resolutionDescription)\(screen.isMain ? "  ·  main" : "")"
            drawText(label, at: NSPoint(x: rect.minX + 8, y: rect.maxY - 20))
        }

        // Layers
        for layer in model.sortedLayers {
            guard let cgImage = model.imageStore.image(for: layer.imageID) else { continue }
            let image = NSImage(cgImage: cgImage, size: CGSize(width: cgImage.width, height: cgImage.height))
            let aspect = CGFloat(cgImage.width) / CGFloat(cgImage.height)
            let drawRect = AspectMath.drawRect(imageAspect: aspect, in: layer.frame, mode: layer.mode)

            NSGraphicsContext.current?.saveGraphicsState()
            NSBezierPath(rect: transform.toView(layer.frame)).addClip()
            image.draw(in: transform.toView(drawRect))
            NSGraphicsContext.current?.restoreGraphicsState()
        }

        // Selection outline + corner handles
        if let selected = model.selectedLayer {
            let rect = transform.toView(selected.frame)
            let path = NSBezierPath(rect: rect)
            path.lineWidth = 1.5
            NSColor.controlAccentColor.setStroke()
            path.setLineDash([5, 3], count: 2, phase: 0)
            path.stroke()
            path.setLineDash([], count: 0, phase: 0)
            NSColor.controlAccentColor.setFill()
            for corner in cornerPoints(of: rect) {
                NSBezierPath(rect: CGRect(x: corner.x - 3, y: corner.y - 3, width: 6, height: 6)).fill()
            }
        }

        if model.document.layers.isEmpty {
            drawCenteredText(
                "Add images from the toolbar, then press ⌘R to apply them to your desktop",
                in: bounds
            )
        }
    }

    private func cornerPoints(of rect: NSRect) -> [NSPoint] {
        [
            NSPoint(x: rect.minX, y: rect.minY),
            NSPoint(x: rect.maxX, y: rect.minY),
            NSPoint(x: rect.minX, y: rect.maxY),
            NSPoint(x: rect.maxX, y: rect.maxY)
        ]
    }

    private func drawText(_ text: String, at point: NSPoint) {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 11, weight: .medium),
            .foregroundColor: NSColor.secondaryLabelColor
        ]
        (text as NSString).draw(at: point, withAttributes: attributes)
    }

    private func drawCenteredText(_ text: String, in rect: NSRect) {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 13),
            .foregroundColor: NSColor.secondaryLabelColor
        ]
        let size = (text as NSString).size(withAttributes: attributes)
        (text as NSString).draw(
            at: NSPoint(x: rect.midX - size.width / 2, y: rect.midY - size.height / 2),
            withAttributes: attributes
        )
    }

    // MARK: - Interaction

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        guard let model else { return }
        let point = canvasPoint(from: event)
        dragStartCanvasPoint = point
        let hit = topmostLayer(containing: point, in: model)
        model.selectedLayerID = hit?.id
        isDraggingLayer = hit != nil
    }

    override func mouseDragged(with event: NSEvent) {
        guard let model, isDraggingLayer,
              let selectedID = model.selectedLayerID,
              let previous = dragStartCanvasPoint else { return }
        let current = canvasPoint(from: event)
        let delta = CGSize(width: current.x - previous.x, height: current.y - previous.y)
        dragStartCanvasPoint = current
        model.moveLayer(with: selectedID, by: delta)
    }

    override func mouseUp(with event: NSEvent) {
        isDraggingLayer = false
    }

    /// Scroll to scale the layer under the cursor (or the selected one),
    /// anchored at the cursor position.
    override func scrollWheel(with event: NSEvent) {
        guard let model else { return }
        let deltaY = event.scrollingDeltaY
        guard deltaY != 0 else { return }
        let point = canvasPoint(from: event)
        let target = topmostLayer(containing: point, in: model) ?? model.selectedLayer
        guard let target else { return }
        let factor = pow(1.0025, -deltaY)
        model.scaleLayer(with: target.id, by: factor, around: point)
    }

    override func keyDown(with event: NSEvent) {
        guard let model else { super.keyDown(with: event); return }
        let step: CGFloat = event.modifierFlags.contains(.shift) ? 10 : 1
        switch event.specialKey {
        case .delete, .backspace:
            model.removeSelected()
        case .leftArrow:
            model.nudgeSelected(by: -step, 0)
        case .rightArrow:
            model.nudgeSelected(by: step, 0)
        case .upArrow:
            model.nudgeSelected(by: 0, step)
        case .downArrow:
            model.nudgeSelected(by: 0, -step)
        default:
            super.keyDown(with: event)
        }
    }

    private func topmostLayer(containing point: CGPoint, in model: EditorModel) -> ImageLayer? {
        model.document.layers
            .filter { $0.frame.contains(point) }
            .max { $0.zOrder < $1.zOrder }
    }
}

/// SwiftUI bridge for the editing canvas.
struct EditorCanvasView: NSViewRepresentable {
    @EnvironmentObject var model: EditorModel

    func makeNSView(context: Context) -> EditorCanvas {
        let view = EditorCanvas()
        view.model = model
        return view
    }

    func updateNSView(_ nsView: EditorCanvas, context: Context) {
        if nsView.model !== model {
            nsView.model = model
        }
    }
}
