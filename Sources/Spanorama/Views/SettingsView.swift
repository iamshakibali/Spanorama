import SwiftUI
import ServiceManagement
import SpanoramaKit

struct SettingsView: View {
    @EnvironmentObject var updater: UpdateModel
    @AppStorage(EditorModel.autoReapplyKey)
    private var autoReapply = false
    @AppStorage("launchAtLogin")
    private var launchAtLogin = false
    @AppStorage(UpdateModel.autoCheckKey)
    private var autoCheckUpdates = true

    var body: some View {
        Form {
            Section {
                Toggle(isOn: $autoReapply) {
                    Text("Re-apply wallpaper when displays change")
                    Text("Reapplies the current layout after a display is connected, disconnected, or its resolution changes.")
                }
                Toggle(isOn: $launchAtLogin) {
                    Text("Launch Spanorama at login")
                }
                .onChange(of: launchAtLogin) { enabled in
                    setLaunchAtLogin(enabled)
                }
            } header: {
                Text("General")
            } footer: {
                Text("Auto re-apply keeps your panorama intact when displays come and go.")
            }

            Section("Updates") {
                Toggle(isOn: $autoCheckUpdates) {
                    Text("Automatically check for updates")
                    Text("Checks GitHub for a new release when Spanorama starts and every 6 hours.")
                }
                LabeledContent("Current Version") {
                    Text("v\(updater.currentVersion)")
                        .foregroundStyle(.secondary)
                        .font(.body.monospaced())
                }
                HStack {
                    Button("Check for Updates") {
                        updater.checkNow()
                    }
                    if updater.state == .checking || updater.state == .downloading {
                        ProgressView()
                            .controlSize(.small)
                    }
                }
                if let status = updater.statusMessage {
                    Text(status)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 460)
    }

    private func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            // Running from a bare executable (e.g. `swift run`) can't register;
            // the packaged .app can.
        }
    }
}
