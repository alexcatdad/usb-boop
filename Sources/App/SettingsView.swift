import MenubarKit
import SwiftUI
import USBBoopKit

struct SettingsView: View {
    @Bindable var model: AppModel

    var body: some View {
        // The notification section stays app-specific: the model owns the
        // permission request and hub/batch rules, which the kit section would bypass.
        SettingsForm {
            Section("Notifications") {
                Toggle(
                    "Show quiet connection banners",
                    isOn: Binding(
                        get: { model.notificationsEnabled },
                        set: { value in Task { await model.setNotificationsEnabled(value) } }
                    ))
                SettingsNote(model.notificationAuthorizationSummary)
                if model.notificationsEnabled, model.canRequestNotifications {
                    Button("Enable notifications") { Task { await model.setNotificationsEnabled(true) } }
                        .disabled(model.isRequestingNotificationAuthorization)
                }
                Toggle("Play a sound", isOn: $model.notificationSoundEnabled)
                    .disabled(!model.notificationsEnabled)
                SettingsNote("Hub connections are silent. Devices connected together share one banner.")
            }
            Section("Startup") {
                Toggle(
                    "Launch at login",
                    isOn: Binding(
                        get: { model.loginItem.isEnabled },
                        set: { value in Task { await model.loginItem.setEnabled(value) } }
                    )
                )
                .disabled(model.loginItem.isUpdating || model.loginItem.status == .requiresApproval)
                SettingsNote(model.loginItem.status.summary)
                if let error = model.loginItem.errorMessage {
                    SettingsNote(error)
                }
                if model.loginItem.status == .requiresApproval {
                    Button("Open Login Items Settings") { model.loginItem.openSystemSettings() }
                    Button("Cancel login request") { Task { await model.loginItem.setEnabled(false) } }
                        .disabled(model.loginItem.isUpdating)
                }
            }
            Section("Display") {
                Toggle("Pin latest result in menu", isOn: $model.keepLatestResultPinned)
                Toggle("Show USB hubs", isOn: $model.showHubs)
                SettingsNote("Applies to the device list and recent activity. History is cleared when usb-boop quits.")
            }
            SettingsAboutSection(
                note: "usb-boop reads USB metadata only. It never opens device files or reads or writes your media.",
                repository: URL(string: "https://github.com/alexcatdad/usb-boop"))
        }
        .onAppear { model.becameActive() }
    }
}
