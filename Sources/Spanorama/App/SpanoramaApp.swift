import SwiftUI
import AppKit
import SpanoramaKit

@main
struct SpanoramaApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var model = EditorModel()

    var body: some Scene {
        WindowGroup("Spanorama") {
            ContentView()
                .environmentObject(model)
        }
        .windowToolbarStyle(.unified)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Layout") { model.newLayout() }
                    .keyboardShortcut("n", modifiers: .command)

                Divider()

                Button("Add Images…") {
                    if let urls = FileDialogs.chooseImages() { model.addImages(at: urls) }
                }
                .keyboardShortcut("o", modifiers: .command)

                Button("Add Panorama…") {
                    if let url = FileDialogs.choosePanorama() { model.addPanorama(at: url) }
                }
                .keyboardShortcut("O", modifiers: [.command, .shift])

                Divider()

                Button("Export Layout…") { model.exportLayout() }
                    .keyboardShortcut("e", modifiers: [.command, .shift])
                Button("Import Layout…") { model.importLayout() }
                    .keyboardShortcut("i", modifiers: [.command, .shift])
            }

            CommandMenu("Desktop") {
                Button("Apply to Desktop") { model.apply() }
                    .keyboardShortcut("r", modifiers: .command)
                Button("Reset to macOS Default") { model.resetToDefault() }
            }

            CommandMenu("Arrange") {
                Button("Bring to Front") { model.arrangeSelected(.front) }
                    .keyboardShortcut("]", modifiers: [.command, .shift])
                Button("Send to Back") { model.arrangeSelected(.back) }
                    .keyboardShortcut("[", modifiers: [.command, .shift])
                Divider()
                Button("Duplicate") { model.duplicateSelected() }
                    .keyboardShortcut("d", modifiers: .command)
            }
        }

        Settings {
            SettingsView()
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}
