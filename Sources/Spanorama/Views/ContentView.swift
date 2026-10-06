import SwiftUI
import SpanoramaKit

struct ContentView: View {
    @EnvironmentObject var model: EditorModel

    private var applyErrorBinding: Binding<Bool> {
        Binding(
            get: { model.applyErrorMessage != nil },
            set: { if !$0 { model.applyErrorMessage = nil } }
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider()
            HSplitView {
                EditorCanvasView()
                    .frame(minWidth: 480, maxWidth: .infinity, maxHeight: .infinity)
                if model.selectedLayer != nil {
                    LayerInspector()
                        .environmentObject(model)
                        .frame(minWidth: 250, idealWidth: 270, maxWidth: 320, maxHeight: .infinity)
                }
            }
            Divider()
            statusBar
        }
        .frame(minWidth: 980, minHeight: 620)
        .alert("Couldn't apply wallpaper", isPresented: applyErrorBinding, presenting: model.applyErrorMessage) { _ in
            Button("OK", role: .cancel) {}
        } message: { message in
            Text(message)
        }
    }

    private var toolbar: some View {
        HStack(spacing: 10) {
            Button {
                if let urls = FileDialogs.chooseImages() { model.addImages(at: urls) }
            } label: {
                Label("Add Images", systemImage: "photo.on.rectangle.angled")
            }
            .keyboardShortcut("o", modifiers: .command)

            Button {
                if let url = FileDialogs.choosePanorama() { model.addPanorama(at: url) }
            } label: {
                Label("Add Panorama", systemImage: "arrow.left.and.right.square")
            }
            .keyboardShortcut("O", modifiers: [.command, .shift])
            .help("Adds one image stretched across every display")

            Divider()
                .frame(height: 18)

            ColorPicker("Background", selection: backgroundBinding)

            Spacer()

            Button(role: .destructive) {
                model.resetToDefault()
            } label: {
                Label("Reset", systemImage: "arrow.uturn.backward")
            }
            .help("Restore the wallpapers that were active before Spanorama")

            Menu {
                Button("Export Layout…") { model.exportLayout() }
                Button("Import Layout…") { model.importLayout() }
            } label: {
                Label("Layout", systemImage: "square.and.arrow.down.on.square")
            }

            Button {
                model.apply()
            } label: {
                Label("Apply to Desktop", systemImage: "paintbrush.fill")
            }
            .keyboardShortcut("r", modifiers: .command)
            .buttonStyle(.borderedProminent)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private var backgroundBinding: Binding<Color> {
        Binding(
            get: { Color(nsColor: model.document.background.nsColor) },
            set: { newValue in
                model.setBackground(CodableColor(nsColor: NSColor(newValue)))
            }
        )
    }

    private var statusBar: some View {
        HStack(spacing: 12) {
            if let status = model.lastStatus {
                Text(status)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            let screens = model.screenService.screens
            Text("\(screens.count) display\(screens.count == 1 ? "" : "s")")
            if let union = model.screenService.unionBounds {
                Text("Canvas \(Int(union.width)) × \(Int(union.height)) pt")
            }
        }
        .font(.caption)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .foregroundStyle(.secondary)
    }
}
