import SwiftUI
import SpanoramaKit

/// Inspector for the selected image layer, styled like a native macOS
/// inspector (grouped form, System Settings look).
struct LayerInspector: View {
    @EnvironmentObject var model: EditorModel

    var body: some View {
        Group {
            if let layer = model.selectedLayer {
                Form {
                    Section("Image") {
                        LabeledContent("Name") {
                            Text(layer.originalName)
                                .lineLimit(1)
                                .truncationMode(.middle)
                                .help(layer.originalName)
                        }
                        LabeledContent("Fit") {
                            Picker("", selection: modeBinding(for: layer)) {
                                ForEach(FillMode.allCases) { mode in
                                    Text(mode.label).tag(mode)
                                }
                            }
                            .pickerStyle(.segmented)
                            .labelsHidden()
                        }
                    }

                    Section("Position & Size") {
                        LabeledContent("X") {
                            numberField(value: layer.frame.minX) {
                                model.moveLayer(with: layer.id, by: CGSize(width: $0 - layer.frame.minX, height: 0))
                            }
                        }
                        LabeledContent("Y") {
                            numberField(value: layer.frame.minY) {
                                model.moveLayer(with: layer.id, by: CGSize(width: 0, height: $0 - layer.frame.minY))
                            }
                        }
                        LabeledContent("Width") {
                            numberField(value: layer.frame.width) {
                                resize(layer, width: $0)
                            }
                        }
                        LabeledContent("Height") {
                            numberField(value: layer.frame.height) {
                                resize(layer, height: $0)
                            }
                        }
                    }

                    Section("Arrange") {
                        Button("Cover Entire Canvas") { model.coverCanvas(with: layer.id) }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Button("Bring to Front") { model.bringToFront(layer.id) }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Button("Send to Back") { model.sendToBack(layer.id) }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Button("Duplicate") { model.duplicateSelected() }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Button("Delete", role: .destructive) { model.removeSelected() }
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    Section("Cover Display") {
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
                .formStyle(.grouped)
            } else {
                Text("Select an image to edit it")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    // MARK: - Helpers

    private func numberField(value: Double, onChange: @escaping (Double) -> Void) -> some View {
        TextField("", value: Binding(get: { value }, set: onChange), format: .number.precision(.fractionLength(0...1)))
            .textFieldStyle(.roundedBorder)
            .multilineTextAlignment(.trailing)
            .frame(maxWidth: 110)
    }

    private func resize(_ layer: ImageLayer, width: CGFloat? = nil, height: CGFloat? = nil) {
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
