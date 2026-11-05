import MenubarKit
import SwiftUI

@main
struct USBBoopApp: App {
    @NSApplicationDelegateAdaptor(AppLifecycle.self) private var lifecycle
    @State private var model: AppModel
    private let trayIcon = TrayIconLoader.load(resourcesDirectory: Bundle.main.resourceURL, baseName: "USBBoopTrayIcon")
    private let isDevelopment = Bundle.main.bundleIdentifier?.hasSuffix(".dev") == true

    init() {
        let model = AppModel()
        _model = State(initialValue: model)
        lifecycle.model = model
        model.start()
    }

    var body: some Scene {
        MenuBarExtra {
            MenuBarContentView(model: model)
        } label: {
            TrayLabel(
                icon: trayIcon,
                fallbackSymbol: "cable.connector",
                status: model.status,
                appName: "usb-boop",
                isDevelopment: isDevelopment
            )
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView(model: model)
        }
    }
}
