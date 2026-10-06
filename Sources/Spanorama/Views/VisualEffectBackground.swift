import SwiftUI
import AppKit

/// Full-window backdrop: the Liquid Glass surface the UI floats on.
/// Shows the blurred desktop behind the window, so the editor chrome
/// picks up whatever wallpaper is behind Spanorama.
struct VisualEffectBackground: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .underWindowBackground
        view.blendingMode = .behindWindow
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}
