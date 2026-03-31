import SwiftUI
import USBBoopKit

struct SettingsView: View {
    @Bindable var model: AppModel

    // swiftlint:disable:next force_unwrapping
    private static let gitHubURL = URL(string: "https://github.com/alexcatdad/usb-boop")!

    var body: some View {
        Form {
            Section("Notifications") {
                Toggle("Show notification when a device connects", isOn: $model.notificationsEnabled)

                Text(model.notificationAuthorizationSummary)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section("Display") {
                Toggle("Pin latest result in menu", isOn: $model.keepLatestResultPinned)

                Toggle("Show USB hubs in device list", isOn: $model.showHubs)

                Text("Internal hubs appear on most Macs. Hiding them keeps the list focused on the devices you plugged in.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section("About") {
                LabeledContent("Version", value: Self.appVersion)

                Link("View on GitHub", destination: Self.gitHubURL)

                Text("usb-boop is free and open source under the MIT License.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 460, height: 380)
    }

    private static var appVersion: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "dev"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "0"
        return "\(version) (\(build))"
    }
}
