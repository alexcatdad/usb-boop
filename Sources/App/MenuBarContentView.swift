import MenubarKit
import SwiftUI
import USBBoopKit

/// The menu bar panel. MenubarKit's standard 340pt width fits a device row:
/// name and copy button on one line, the link speed on its own line below.
struct MenuBarContentView: View {
    @Bindable var model: AppModel
    @State private var historyExpanded = false

    var body: some View {
        MenubarPanel {
            StatusHeader(model.status) {
                RefreshButton(isRefreshing: false, title: "Refresh device list") { model.refreshDevices() }
                    .keyboardShortcut("r", modifiers: .command)
            }
            if model.monitoringStatus.canRetry {
                PrimaryActionButton("Try Again") { model.refreshDevices() }
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    if model.keepLatestResultPinned { latestResultCard }
                    currentDevicesSection
                    historySection
                }
            }
            // MenuBarExtra can propose a minimal window size. A maximum
            // alone lets ScrollView collapse to almost zero height in that window.
            .frame(height: 500)
            notificationControls
            MenuSection(quitTitle: "Quit usb-boop") {
                OpenSettingsButton()
                    .keyboardShortcut(",", modifiers: .command)
            }
            VersionFooter()
        }
        .onAppear { model.becameActive() }
    }

    private var latestResultCard: some View {
        VStack(alignment: .leading, spacing: 2) {
            TileHeader("Latest connection")
            Group {
                if let device = model.latestConnectedDevice {
                    DeviceRow(device: device)
                    if let status = model.latestConnectionStatus {
                        Text(status).font(.caption).foregroundStyle(.secondary)
                    }
                } else {
                    Text("Plug in a USB device to see its link speed.")
                        .font(.callout).foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 12)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .groupedTile()
    }

    private var currentDevicesSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            VStack(alignment: .leading, spacing: 2) {
                TileHeader("Connected devices")
                if model.visibleDevices.isEmpty {
                    Text(model.emptyDevicesMessage).font(.callout).foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center).padding(.vertical, 8)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 4) {
                            ForEach(model.visibleDevices) { DeviceRow(device: $0) }
                        }
                        .padding(.horizontal, 12)
                    }
                    .frame(height: min(320, CGFloat(model.visibleDevices.count) * 82))
                }
            }
            .groupedTile()
            Text("Link speed is the negotiated connection rate, not measured file-transfer speed.")
                .font(.caption).foregroundStyle(.secondary)
                .padding(.horizontal, 4)
        }
    }

    private var historySection: some View {
        DisclosureGroup("Recent activity", isExpanded: $historyExpanded) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("This session · last 50 observations").font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    Button("Clear") { model.clearHistory() }.disabled(model.history.isEmpty)
                }
                if model.visibleHistory.isEmpty {
                    Text("No recent activity.").font(.callout).foregroundStyle(.secondary)
                } else {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 10) {
                            ForEach(model.visibleHistory) { observation in
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(observation.device.name).font(.callout).lineLimit(1)
                                        .help(observation.device.name)
                                    Text("\(observation.kind.label) · \(observation.device.linkSpeedSummary)")
                                        .font(.caption).foregroundStyle(.secondary)
                                    Text(observation.observedAt, style: .time).font(.caption.monospacedDigit())
                                }
                                .accessibilityElement(children: .combine)
                            }
                        }
                    }.frame(height: min(140, CGFloat(model.visibleHistory.count) * 66))
                }
            }.padding(.top, 8)
        }
        .font(.subheadline)
        .padding(.horizontal, 4)
    }

    private var notificationControls: some View {
        VStack(alignment: .leading, spacing: 6) {
            Toggle("Notifications", isOn: Binding(
                get: { model.notificationsEnabled },
                set: { value in Task { await model.setNotificationsEnabled(value) } }
            ))
            .toggleStyle(.switch).controlSize(.small)
            if model.notificationAuthorization != .authorized {
                Text(model.notificationAuthorizationSummary).font(.caption).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                if model.notificationsEnabled, model.canRequestNotifications {
                    Button("Enable notifications") { Task { await model.setNotificationsEnabled(true) } }
                        .disabled(model.isRequestingNotificationAuthorization)
                }
            }
        }
        .padding(.horizontal, 4)
    }
}

private struct DeviceRow: View {
    let device: USBDevice

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text(device.name).font(.callout.weight(.medium)).lineLimit(1).help(device.name)
                Spacer(minLength: 4)
                Button(action: copyDeviceInfo) {
                    Label("Copy device info", systemImage: "doc.on.doc").labelStyle(.iconOnly)
                }
                .buttonStyle(.borderless)
                .help("Copy device info")
                .accessibilityLabel("Copy info for \(device.name)")
            }
            Text(device.linkSpeedSummary)
                .font(.callout.weight(.semibold).monospacedDigit())
                .foregroundStyle(speedColor)
            HStack(spacing: 4) {
                if device.isHub { Text("Hub ·") }
                Text(device.connectedAt == nil ? "Seen since" : "Connected at")
                Text((device.connectedAt ?? device.firstSeenAt).formatted(date: .abbreviated, time: .shortened))
            }.font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 5).padding(.horizontal, 4)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(device.name), \(device.linkSpeedSummary)")
        .accessibilityAction(named: Text("Copy device info"), copyDeviceInfo)
        .contextMenu { Button("Copy Device Info", action: copyDeviceInfo) }
    }

    private var speedColor: Color {
        switch device.speed {
        case .usb3Gen2x2, .usb3Gen2: .green
        case .usb3Gen1: .blue
        case .usb2High: .orange
        default: .secondary
        }
    }

    private func copyDeviceInfo() {
        var lines = [device.name, device.linkSpeedSummary]
        if let technical = device.speed.technicalLabel { lines.append(technical) }
        if let manufacturer = device.manufacturer { lines.append("Manufacturer: \(manufacturer)") }
        if let identifiers = device.vendorProductSummary { lines.append(identifiers) }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(lines.joined(separator: "\n"), forType: .string)
    }
}

private extension USBObservation.Kind {
    var label: String {
        switch self {
        case .attached: "Connected"
        case .detached: "Disconnected"
        case .firstSeen: "First seen"
        case .noLongerDetected: "No longer detected"
        }
    }
}
