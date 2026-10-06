import SwiftUI
import AppKit

@main
struct SpanoramaApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var model = EditorModel()

    var body: some Scene {
        WindowGroup("Spanorama") {
            ContentView()
                .environmentObject(model)
        }
        .commands {
            CommandGroup(after: .newItem) {
                Button("Add Images…") {
                    if let urls = FileDialogs.chooseImages() { model.addImages(at: urls) }
                }
                .keyboardShortcut("o", modifiers: .command)

                Button("Add Panorama…") {
                    if let url = FileDialogs.choosePanorama() { model.addPanorama(at: url) }
                }
                .keyboardShortcut("O", modifiers: [.command, .shift])

                Divider()

                Button("Apply to Desktop") { model.apply() }
                    .keyboardShortcut("r", modifiers: .command)

                Button("Reset to macOS Default") { model.resetToDefault() }

                Divider()

                Button("Export Layout…") { model.exportLayout() }
                    .keyboardShortcut("e", modifiers: [.command, .shift])
                Button("Import Layout…") { model.importLayout() }
                    .keyboardShortcut("i", modifiers: .command)
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
