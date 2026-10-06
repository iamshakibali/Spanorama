import AppKit
import Combine
import CoreGraphics

/// Tracks the connected displays and keeps screen snapshots in sync
/// with hardware changes (connect / disconnect / resolution change).
@MainActor
public final class ScreenService: ObservableObject {
    @Published public private(set) var screens: [ScreenInfo] = []
    /// Global-coordinate bounds covering every connected display.
    @Published public private(set) var unionBounds: CGRect?

    private var observer: NSObjectProtocol?

    public init() {
        refresh()
        observer = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.refresh()
            }
        }
    }

    deinit {
        if let observer {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    public func refresh() {
        var infos: [ScreenInfo] = []
        for (index, screen) in NSScreen.screens.enumerated() {
            let displayID = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? Int ?? index
            infos.append(ScreenInfo(
                id: String(displayID),
                frame: screen.frame,
                name: screen.localizedName,
                scaleFactor: screen.backingScaleFactor,
                isMain: index == 0
            ))
        }
        screens = infos
        unionBounds = CanvasGeometry.unionBounds(of: infos.map(\.frame))
    }

    public func nsScreen(for info: ScreenInfo) -> NSScreen? {
        guard let displayID = Int(info.id) else { return nil }
        return NSScreen.screens.first {
            ($0.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? Int) == displayID
        }
    }
}
