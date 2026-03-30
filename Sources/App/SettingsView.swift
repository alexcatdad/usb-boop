import Observation
import SwiftUI

struct SettingsView: View {
    @Bindable var model: AppModel

    var body: some View {
        Form {
            Section("Notifications") {
                Toggle("Enable connect notifications", isOn: $model.notificationsEnabled)
                Toggle("Keep latest result pinned in menu companion", isOn: $model.keepLatestResultPinned)

                Text("macOS controls whether notifications are banners or persistent alerts. usb-boop can send the notification, but Notification Center owns the final presentation style.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                Text(model.notificationAuthorizationSummary)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section("Current MVP Scope") {
                LabeledContent("Platform", value: "macOS 14+")
                LabeledContent("Architecture", value: "Apple Silicon")
                LabeledContent("Distribution", value: "Direct + Homebrew")
                LabeledContent("Launch at Login", value: "Planned later")
            }
        }
        .formStyle(.grouped)
        .frame(width: 460)
        .padding(20)
    }
}
