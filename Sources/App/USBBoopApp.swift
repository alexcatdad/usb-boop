import SwiftUI

@main
struct USBBoopApp: App {
    @State private var model: AppModel

    init() {
        let model = AppModel()
        _model = State(initialValue: model)
    }

    var body: some Scene {
        MenuBarExtra("usb-boop", systemImage: "cable.connector") {
            MenuBarContentView(model: model)
                .task {
                    model.start()
                }
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView(model: model)
        }
    }
}
