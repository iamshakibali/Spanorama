import SwiftUI
import ServiceManagement

struct SettingsView: View {
    @AppStorage(EditorModel.autoReapplyKey)
    private var autoReapply = false
    @AppStorage("launchAtLogin")
    private var launchAtLogin = false

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
            } footer: {
                Text("Auto re-apply keeps your panorama intact when displays come and go.")
            }
        }
        .formStyle(.grouped)
        .frame(width: 420)
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
