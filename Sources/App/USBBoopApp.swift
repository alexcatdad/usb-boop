import SwiftUI

@main
struct USBBoopApp: App {
    @NSApplicationDelegateAdaptor(AppLifecycle.self) private var lifecycle
    @State private var model: AppModel

    init() {
        let model = AppModel()
        _model = State(initialValue: model)
        lifecycle.model = model
        model.start()
    }

    var body: some Scene {
        MenuBarExtra("usb-boop", systemImage: "cable.connector") {
            MenuBarContentView(model: model)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView(model: model)
        }
    }
}
