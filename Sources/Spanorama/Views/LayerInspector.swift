import SwiftUI
import SpanoramaKit

/// Inspector for the selected image layer: exact geometry, fill mode,
/// z-order shortcuts and per-screen quick actions.
struct LayerInspector: View {
    @EnvironmentObject var model: EditorModel

    var body: some View {
        Group {
            if let layer = model.selectedLayer {
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        nameSection(layer)
                        geometrySection(layer)
                        modeSection(layer)
                        quickActionsSection(layer)
                        zOrderSection(layer)
                        screensSection(layer)
                    }
                    .padding(12)
                }
            } else {
                Text("Select an image to edit it")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    private func nameSection(_ layer: ImageLayer) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(layer.originalName)
                .font(.headline)
                .lineLimit(1)
            Text("z: \(layer.zOrder)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func geometrySection(_ layer: ImageLayer) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Position & Size").font(.subheadline.weight(.semibold))
            HStack {
                numberField("X", value: layer.frame.minX) { model.moveLayer(with: layer.id, by: CGSize(width: $0 - layer.frame.minX, height: 0)) }
                numberField("Y", value: layer.frame.minY) { model.moveLayer(with: layer.id, by: CGSize(width: 0, height: $0 - layer.frame.minY)) }
            }
            HStack {
                numberField("W", value: layer.frame.width) { resize(layer, width: $0) }
                numberField("H", value: layer.frame.height) { resize(layer, height: $0) }
            }
        }
    }

    private func modeSection(_ layer: ImageLayer) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Image Fit").font(.subheadline.weight(.semibold))
            Picker("", selection: modeBinding(for: layer)) {
                ForEach(FillMode.allCases) { mode in
                    Text(mode.label).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
        }
    }

    private func quickActionsSection(_ layer: ImageLayer) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Quick Actions").font(.subheadline.weight(.semibold))
            Button("Cover entire canvas") { model.coverCanvas(with: layer.id) }
                .frame(maxWidth: .infinity)
            Button("Duplicate") { model.duplicateSelected() }
                .frame(maxWidth: .infinity)
            Button("Bring to Front") { model.bringToFront(layer.id) }
                .frame(maxWidth: .infinity)
            Button("Send to Back") { model.sendToBack(layer.id) }
                .frame(maxWidth: .infinity)
            Button("Delete", role: .destructive) { model.removeSelected() }
                .frame(maxWidth: .infinity)
        }
    }

    private func zOrderSection(_ layer: ImageLayer) -> some View {
        EmptyView()
    }

    private func screensSection(_ layer: ImageLayer) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Cover Display").font(.subheadline.weight(.semibold))
            ForEach(model.screenService.screens) { screen in
                Button {
                    model.coverScreen(screen, with: layer.id)
                } label: {
                    HStack {
                        Text(screen.name)
                        Spacer()
                        Text(screen.resolutionDescription)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    // MARK: - Helpers

    private func numberField(_ label: String, value: Double, onChange: @escaping (Double) -> Void) -> some View {
        HStack {
            Text(label).frame(width: 16)
            TextField("", value: Binding(get: { value }, set: onChange), format: .number.precision(.fractionLength(0...1)))
                .textFieldStyle(.roundedBorder)
        }
    }

    private func resize(_ layer: ImageLayer, width: CGFloat? = nil, height: CGFloat? = nil) -> Void {
        var frame = layer.frame
        frame.size.width = width ?? frame.width
        frame.size.height = height ?? frame.height
        model.setFrame(frame, for: layer.id)
    }

    private func modeBinding(for layer: ImageLayer) -> Binding<FillMode> {
        Binding(
            get: { layer.mode },
            set: { model.setMode($0, for: layer.id) }
        )
    }
}
