import Observation
import SwiftUI
import USBBoopKit

struct MenuBarContentView: View {
    @Bindable var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if model.keepLatestResultPinned {
                latestResultCard
            }

            currentDevicesSection
            controlsSection
        }
        .padding(16)
        .frame(width: 360)
    }

    private var latestResultCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Latest Result")
                .font(.headline)

            Text(model.latestResultTitle)
                .font(.body.weight(.semibold))

            Text(model.latestResultDetail)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(.quaternary.opacity(0.65), in: .rect(cornerRadius: 14))
    }

    private var currentDevicesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Current Devices")
                    .font(.headline)

                Spacer()

                Button("Refresh") {
                    model.refreshDevices()
                }
                .buttonStyle(.borderless)
            }

            if model.currentDevices.isEmpty {
                Text("No USB devices are currently visible.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(model.currentDevices) { device in
                        DeviceRow(device: device)
                    }
                }
            }
        }
    }

    private var controlsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Divider()

            Toggle("Enable connect notifications", isOn: $model.notificationsEnabled)
                .toggleStyle(.switch)

            Toggle("Keep latest result pinned in menu", isOn: $model.keepLatestResultPinned)
                .toggleStyle(.switch)

            Text(model.notificationAuthorizationSummary)
                .font(.footnote)
                .foregroundStyle(.secondary)

            HStack {
                SettingsLink {
                    Label("Settings", systemImage: "gearshape")
                }

                Spacer()

                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }
            }
        }
    }
}

private struct DeviceRow: View {
    let device: USBDevice

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                Text(device.name)
                    .font(.body.weight(.medium))
                    .lineLimit(1)

                Spacer(minLength: 12)

                Text(device.speed.displayLabel)
                    .font(.footnote.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            Text(device.detailSummary)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 2)
    }
}
