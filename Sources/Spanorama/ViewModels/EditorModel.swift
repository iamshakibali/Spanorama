import AppKit
import Combine
import CoreGraphics
import Foundation
import ImageIO
import ServiceManagement
import SpanoramaKit

/// Central editing state: layers on the canvas, selection, and the
/// apply / reset / persistence workflows.
@MainActor
final class EditorModel: ObservableObject {
    @Published var document: CanvasDocument {
        didSet { persistSoon() }
    }
    @Published var selectedLayerID: UUID?
    @Published private(set) var lastStatus: String?
    @Published var applyErrorMessage: String?

    let screenService = ScreenService()
    let imageStore: ImageStore
    private let applier = WallpaperApplier()
    private var cancellables = Set<AnyCancellable>()
    private var persistTask: Task<Void, Never>?

    static let autoReapplyKey = "autoReapply"

    init() {
        self.document = LayoutStore.load() ?? CanvasDocument()
        do {
            imageStore = try ImageStore()
        } catch {
            fatalError("Cannot create image store: \(error)")
        }
        screenService.$screens
            .dropFirst()
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.screensChanged() }
            .store(in: &cancellables)
    }

    // MARK: - Derived state

    var selectedLayer: ImageLayer? {
        document.layers.first { $0.id == selectedLayerID }
    }

    var sortedLayers: [ImageLayer] {
        document.layers.sorted { $0.zOrder < $1.zOrder }
    }

    var canvasBounds: CGRect? {
        screenService.unionBounds
    }

    private var nextZOrder: Int {
        (document.layers.map(\.zOrder).max() ?? 0) + 1
    }

    // MARK: - Adding images

    func addImages(at urls: [URL]) {
        let bounds = screenService.unionBounds ?? CGRect(x: 0, y: 0, width: 1920, height: 1080)
        var added: [UUID] = []
        for (index, url) in urls.enumerated() {
            guard let key = try? imageStore.store(from: url),
                  let image = imageStore.image(for: key) else {
                lastStatus = "Couldn't read \(url.lastPathComponent)"
                continue
            }
            let aspect = CGFloat(image.width) / CGFloat(image.height)
            let area = bounds.insetBy(dx: bounds.width * 0.1, dy: bounds.height * 0.1)
            let frame = AspectMath.drawRect(imageAspect: aspect, in: area, mode: .fit)
                .offsetBy(dx: CGFloat(index) * 24, dy: -CGFloat(index) * 24)
            let layer = ImageLayer(
                imageID: key,
                originalName: url.lastPathComponent,
                frame: frame,
                mode: .fill,
                zOrder: nextZOrder
            )
            document.layers.append(layer)
            added.append(layer.id)
        }
        selectedLayerID = added.last
        lastStatus = added.isEmpty ? nil : "Added \(added.count) image(s)"
    }

    /// Adds one image stretched across the entire canvas so it spans every display.
    func addPanorama(at url: URL) {
        let bounds = screenService.unionBounds ?? CGRect(x: 0, y: 0, width: 1920, height: 1080)
        guard let key = try? imageStore.store(from: url), imageStore.image(for: key) != nil else {
            applyErrorMessage = "Couldn't read \(url.lastPathComponent)"
            return
        }
        let layer = ImageLayer(
            imageID: key,
            originalName: url.lastPathComponent,
            frame: bounds,
            mode: .fill,
            zOrder: nextZOrder
        )
        document.layers.append(layer)
        selectedLayerID = layer.id
        lastStatus = "Panorama added — press ⌘R to apply across all displays"
    }

    // MARK: - Layer editing

    /// Starts a fresh layout.
    func newLayout() {
        document = CanvasDocument()
        selectedLayerID = nil
        lastStatus = "New layout"
    }

    func arrangeSelected(_ direction: ArrangeDirection) {
        guard let id = selectedLayerID else { return }
        switch direction {
        case .front: bringToFront(id)
        case .back: sendToBack(id)
        }
    }

    func removeSelected() {
        guard let id = selectedLayerID else { return }
        removeLayer(with: id)
    }

    func removeLayer(with id: UUID) {
        if let layer = document.layers.first(where: { $0.id == id }) {
            imageStore.remove(layer.imageID)
        }
        document.layers.removeAll { $0.id == id }
        if selectedLayerID == id { selectedLayerID = nil }
    }

    func moveLayer(with id: UUID, by delta: CGSize) {
        mutateLayer(with: id) { $0.frame.origin = ($0.frame.origin).applyingTranslation(delta) }
    }

    func scaleLayer(with id: UUID, by factor: CGFloat, around anchor: CGPoint) {
        guard factor > 0 else { return }
        mutateLayer(with: id) { layer in
            var frame = layer.frame
            let newWidth = max(frame.width * factor, 16)
            let newHeight = max(frame.height * factor, 16)
            frame.origin.x = anchor.x - (anchor.x - frame.minX) * (newWidth / frame.width)
            frame.origin.y = anchor.y - (anchor.y - frame.minY) * (newHeight / frame.height)
            frame.size = CGSize(width: newWidth, height: newHeight)
            layer.frame = frame
        }
    }

    func nudgeSelected(by dx: CGFloat, _ dy: CGFloat) {
        guard let id = selectedLayerID else { return }
        moveLayer(with: id, by: CGSize(width: dx, height: dy))
    }

    func setFrame(_ frame: CGRect, for id: UUID) {
        mutateLayer(with: id) { $0.frame = frame }
    }

    func setMode(_ mode: FillMode, for id: UUID) {
        mutateLayer(with: id) { $0.mode = mode }
    }

    func bringToFront(_ id: UUID) {
        mutateLayer(with: id) { $0.zOrder = nextZOrder }
    }

    func sendToBack(_ id: UUID) {
        mutateLayer(with: id) { $0.zOrder = (document.layers.map(\.zOrder).min() ?? 0) - 1 }
    }

    /// Expands a layer to cover the whole canvas (all displays).
    func coverCanvas(with id: UUID) {
        guard let bounds = screenService.unionBounds else { return }
        mutateLayer(with: id) {
            $0.frame = bounds
            $0.mode = .fill
        }
    }

    /// Expands a layer to cover one specific display.
    func coverScreen(_ screen: ScreenInfo, with id: UUID) {
        mutateLayer(with: id) {
            $0.frame = screen.frame
            $0.mode = .fill
        }
    }

    func setBackground(_ color: CodableColor) {
        document.background = color
    }

    func duplicateSelected() {
        guard let selected = selectedLayer else { return }
        var copy = selected
        copy.id = UUID()
        copy.originalName = selected.originalName
        copy.frame = selected.frame.offsetBy(dx: 24, dy: -24)
        copy.zOrder = nextZOrder
        // Duplicate the stored image so deleting one copy keeps the other alive.
        if let image = imageStore.image(for: selected.imageID) {
            let newKey = "\(UUID().uuidString).png"
            if let destination = CGImageDestinationCreateWithURL(
                imageStore.url(for: newKey) as CFURL,
                "public.png" as CFString, 1, nil
            ) {
                CGImageDestinationAddImage(destination, image, nil)
                CGImageDestinationFinalize(destination)
                copy.imageID = newKey
            }
        }
        document.layers.append(copy)
        selectedLayerID = copy.id
    }

    private func mutateLayer(with id: UUID, _ mutation: (inout ImageLayer) -> Void) {
        guard let index = document.layers.firstIndex(where: { $0.id == id }) else { return }
        mutation(&document.layers[index])
    }

    // MARK: - Apply / Reset

    func apply() {
        guard !screenService.screens.isEmpty, let bounds = screenService.unionBounds else {
            applyErrorMessage = "No displays detected."
            return
        }
        guard !document.layers.isEmpty else {
            applyErrorMessage = "Add at least one image before applying."
            return
        }
        captureOriginalWallpapersIfNeeded()
        let outcomes = applier.apply(
            document: document,
            canvasBounds: bounds,
            screens: screenService.screens,
            imageStore: imageStore,
            nsScreenProvider: { [screenService] in screenService.nsScreen(for: $0) }
        )
        let failures = outcomes.filter { !$0.succeeded }
        if let first = failures.first {
            applyErrorMessage = "\(first.screenName): \(first.errorMessage ?? "unknown error")"
        } else {
            lastStatus = "Applied to \(outcomes.count) display\(outcomes.count == 1 ? "" : "s") ✓"
        }
    }

    /// Restores the wallpapers that were active before Spanorama first applied one.
    func resetToDefault() {
        let defaults = UserDefaults.standard
        var restored = 0
        for screen in screenService.screens {
            guard let nsScreen = screenService.nsScreen(for: screen),
                  let urlString = defaults.string(forKey: Self.originalKey(for: screen.id)),
                  let url = URL(string: urlString) else { continue }
            do {
                try NSWorkspace.shared.setDesktopImageURL(
                    url,
                    for: nsScreen,
                    options: [.imageScaling: NSNumber(value: NSImageScaling.scaleProportionallyUpOrDown.rawValue)]
                )
                restored += 1
            } catch {
                applyErrorMessage = "Reset failed for \(screen.name): \(error.localizedDescription)"
            }
        }
        lastStatus = restored > 0 ? "Restored default wallpaper on \(restored) display(s)" : "No saved default wallpapers to restore"
    }

    private static func originalKey(for screenID: String) -> String {
        "originalWallpaper.\(screenID)"
    }

    private func captureOriginalWallpapersIfNeeded() {
        let defaults = UserDefaults.standard
        for screen in screenService.screens {
            let key = Self.originalKey(for: screen.id)
            guard defaults.string(forKey: key) == nil,
                  let nsScreen = screenService.nsScreen(for: screen),
                  let current = NSWorkspace.shared.desktopImageURL(for: nsScreen) else { continue }
            defaults.set(current.absoluteString, forKey: key)
        }
    }

    // MARK: - Export / Import

    func exportLayout() {
        guard let url = FileDialogs.chooseExportDestination(defaultName: "MyLayout.spanorama.json") else { return }
        do {
            try LayoutStore.save(document, to: url)
            lastStatus = "Layout exported"
        } catch {
            applyErrorMessage = "Export failed: \(error.localizedDescription)"
        }
    }

    func importLayout() {
        guard let url = FileDialogs.chooseJSONFile() else { return }
        guard let imported = LayoutStore.load(from: url) else {
            applyErrorMessage = "That file isn't a valid Spanorama layout."
            return
        }
        document = imported
        selectedLayerID = nil
        lastStatus = "Layout imported"
    }

    // MARK: - Screen changes & persistence

    private func screensChanged() {
        guard UserDefaults.standard.bool(forKey: Self.autoReapplyKey),
              !document.layers.isEmpty,
              screenService.unionBounds != nil else { return }
        // Displays take a moment to settle after a configuration change.
        Task { [weak self] in
            try? await Task.sleep(nanoseconds: 700_000_000)
            guard !Task.isCancelled else { return }
            await MainActor.run { self?.apply() }
        }
    }

    private func persistSoon() {
        persistTask?.cancel()
        let snapshot = document
        persistTask = Task {
            try? await Task.sleep(nanoseconds: 400_000_000)
            guard !Task.isCancelled else { return }
            try? LayoutStore.save(snapshot)
        }
    }
}

extension CGPoint {
    func applyingTranslation(_ delta: CGSize) -> CGPoint {
        CGPoint(x: x + delta.width, y: y + delta.height)
    }
}

enum ArrangeDirection {
    case front
    case back
}

enum FileDialogs {
    static func chooseImages() -> [URL]? {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = true
        panel.allowedContentTypes = [.image]
        panel.message = "Choose images for your desktop"
        return panel.runModal() == .OK ? panel.urls : nil
    }

    static func choosePanorama() -> URL? {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.image]
        panel.message = "Choose a panorama image to span across all displays"
        return panel.runModal() == .OK ? panel.urls.first : nil
    }

    static func chooseExportDestination(defaultName: String) -> URL? {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = defaultName
        return panel.runModal() == .OK ? panel.url : nil
    }

    static func chooseJSONFile() -> URL? {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.json]
        return panel.runModal() == .OK ? panel.urls.first : nil
    }
}
