import SwiftUI
import ServiceManagement

struct LaunchAtLoginToggle: View {
    @State private var enabled = false
    private let isInstalledApp = Bundle.main.bundleURL.pathExtension == "app"

    var body: some View {
        Toggle("Launch at login", isOn: Binding(
            get: { enabled },
            set: { set($0) }
        ))
        .toggleStyle(.checkbox)
        .font(.caption)
        .disabled(!isInstalledApp)
        .help(isInstalledApp ? "Start AI Usage Bar when you log in"
                             : "Only available when running from the installed .app")
        .onAppear { refresh() }
    }

    private func refresh() {
        enabled = isInstalledApp && SMAppService.mainApp.status == .enabled
    }

    private func set(_ on: Bool) {
        do {
            if on { try SMAppService.mainApp.register() }
            else { try SMAppService.mainApp.unregister() }
        } catch {}
        refresh()
    }
}
