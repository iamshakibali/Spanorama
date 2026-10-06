import SwiftUI
import SpanoramaKit

struct ContentView: View {
    @EnvironmentObject var model: EditorModel
    @EnvironmentObject var updater: UpdateModel

    private var applyErrorBinding: Binding<Bool> {
        Binding(
            get: { model.applyErrorMessage != nil },
            set: { if !$0 { model.applyErrorMessage = nil } }
        )
    }

    private var inspectorBinding: Binding<Bool> {
        Binding(
            get: { model.selectedLayer != nil },
            set: { if !$0 { model.selectedLayerID = nil } }
        )
    }

    private var backgroundBinding: Binding<Color> {
        Binding(
            get: { Color(nsColor: model.document.background.nsColor) },
            set: { model.setBackground(CodableColor(nsColor: NSColor($0))) }
        )
    }

    var body: some View {
        ZStack {
            VisualEffectBackground()
                .ignoresSafeArea()
            EditorCanvasView()
        }
        .toolbar { toolbarContent }
        .inspector(isPresented: inspectorBinding) {
            LayerInspector()
                .environmentObject(model)
                .inspectorColumnWidth(min: 260, ideal: 300, max: 380)
        }
        .navigationTitle("Spanorama")
        .frame(minWidth: 980, minHeight: 620)
        .safeAreaInset(edge: .bottom) {
            statusBar
        }
            .alert("Couldn't apply wallpaper", isPresented: applyErrorBinding, presenting: model.applyErrorMessage) { _ in
                Button("OK", role: .cancel) {}
            } message: { message in
                Text(message)
            }
            .alert("Update Available", isPresented: $updater.showDialog, presenting: updater.availableRelease) { release in
                Button("Download Update") {
                    Task { await updater.downloadAndOpen() }
                }
                Button("Skip This Version") {
                    updater.skipCurrentRelease()
                }
                Button("Remind Me Later", role: .cancel) {
                    updater.dismissDialog()
                }
            } message: { release in
                Text("\(release.name ?? release.tagName) is available — you have v\(updater.currentVersion). The update opens as a disk image; drag Spanorama into Applications.")
            }
    }

    // MARK: - Toolbar (native, lives in the title bar)

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
            ToolbarItemGroup {
                Button {
                    if let urls = FileDialogs.chooseImages() { model.addImages(at: urls) }
                } label: {
                    Label("Add Images", systemImage: "photo.on.rectangle.angled")
                }
                .help("Add one or more images to the canvas (⌘O)")

                Button {
                    if let url = FileDialogs.choosePanorama() { model.addPanorama(at: url) }
                } label: {
                    Label("Add Panorama", systemImage: "square.split.2x1")
                }
                .help("Span one image across every display (⇧⌘O)")

                ColorPicker("Background", selection: backgroundBinding)
                    .labelsHidden()
                    .help("Canvas background color")
            }

            ToolbarItemGroup(placement: .primaryAction) {
                Button {
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
                .help("Export or import a layout file")

                Button {
                    model.apply()
                } label: {
                    Label("Apply to Desktop", systemImage: "paintbrush.fill")
                }
                .buttonStyle(.borderedProminent)
                .help("Apply the canvas to every display (⌘R)")
            }
    }

    // MARK: - Status bar

    private var statusBar: some View {
        HStack(spacing: 12) {
            if let status = model.lastStatus {
                Text(status)
                    .foregroundStyle(.secondary)
                    .transition(.opacity)
            }
            Spacer()
            let screens = model.screenService.screens
            Text("\(screens.count) display\(screens.count == 1 ? "" : "s")")
            if let union = model.screenService.unionBounds {
                Text("Canvas \(Int(union.width)) × \(Int(union.height)) pt")
            }
        }
        .font(.caption)
        .padding(.horizontal, 14)
        .padding(.vertical, 7)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
        .foregroundStyle(.secondary)
    }
}
