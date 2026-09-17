import SwiftUI
import USBBoopKit

struct SettingsView: View {
    @Bindable var model: AppModel
    private static let gitHubURL = URL(string: "https://github.com/alexcatdad/usb-boop")

    var body: some View {
        Form {
            Section("Notifications") {
                Toggle("Show quiet connection banners", isOn: Binding(
                    get: { model.notificationsEnabled },
                    set: { value in Task { await model.setNotificationsEnabled(value) } }
                ))
                Text(model.notificationAuthorizationSummary).font(.footnote).foregroundStyle(.secondary)
                if model.notificationsEnabled, model.canRequestNotifications {
                    Button("Enable notifications") { Task { await model.setNotificationsEnabled(true) } }
                }
                Toggle("Play a sound", isOn: $model.notificationSoundEnabled)
                    .disabled(!model.notificationsEnabled)
                Text("Hub connections are silent. Devices connected together share one banner.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            Section("Startup") {
                Toggle("Launch at login", isOn: Binding(
                    get: { model.loginItem.isEnabled },
                    set: { value in Task { await model.loginItem.setEnabled(value) } }
                ))
                .disabled(model.loginItem.isUpdating || model.loginItem.status == .requiresApproval)
                Text(model.loginItem.status.summary).font(.footnote).foregroundStyle(.secondary)
                if let error = model.loginItem.errorMessage {
                    Text(error).font(.footnote).foregroundStyle(.secondary)
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
                Text("Applies to the device list and recent activity. History is cleared when usb-boop quits.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            Section("About") {
                LabeledContent("Version", value: Self.appVersion)
                Text("usb-boop reads USB metadata only. It never opens device files or reads or writes your media.")
                    .font(.footnote).foregroundStyle(.secondary)
                if let gitHubURL = Self.gitHubURL { Link("View on GitHub", destination: gitHubURL) }
            }
        }
        .formStyle(.grouped)
        .frame(width: 480, height: 560)
        .onAppear { model.becameActive() }
    }

    private static var appVersion: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "dev"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "0"
        return "\(version) (\(build))"
    }
}
