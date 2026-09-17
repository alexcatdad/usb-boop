import SwiftUI
import USBBoopKit

struct MenuBarContentView: View {
    @Environment(\.openSettings) private var openSettings
    @Bindable var model: AppModel
    @State private var historyExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            monitoringStatus
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    if model.keepLatestResultPinned { latestResultCard }
                    currentDevicesSection
                    historySection
                }
            }
            // MenuBarExtra can propose a minimal window size. A maximum
            // alone lets ScrollView collapse to almost zero height in that window.
            .frame(height: 520)
            controlsSection
        }
        .padding(16)
        .frame(width: 390)
        .onAppear { model.becameActive() }
    }

    @ViewBuilder private var monitoringStatus: some View {
        if let message = model.monitoringMessage {
            VStack(alignment: .leading, spacing: 6) {
                Text(message).font(.callout).foregroundStyle(.secondary)
                if model.monitoringStatus.canRetry {
                    Button("Retry") { model.refreshDevices() }
                }
            }
        }
    }

    private var latestResultCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Latest connection").font(.subheadline.weight(.medium)).foregroundStyle(.secondary)
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
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(.quaternary.opacity(0.5), in: .rect(cornerRadius: 10))
    }

    private var currentDevicesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Connected devices").font(.subheadline.weight(.medium)).foregroundStyle(.secondary)
                Spacer()
                Button { model.refreshDevices() } label: {
                    Label("Refresh device list", systemImage: "arrow.clockwise").labelStyle(.iconOnly)
                }
                .buttonStyle(.borderless)
                .keyboardShortcut("r", modifiers: .command)
                .help("Refresh USB metadata")
            }
            if model.visibleDevices.isEmpty {
                Text(model.emptyDevicesMessage).font(.callout).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center).padding(.vertical, 8)
            } else {
                ScrollView {
                    LazyVStack(spacing: 4) {
                        ForEach(model.visibleDevices) { DeviceRow(device: $0) }
                    }
                }
                .frame(height: min(320, CGFloat(model.visibleDevices.count) * 82))
            }
            Text("Link speed is the negotiated connection rate, not measured file-transfer speed.")
                .font(.caption).foregroundStyle(.secondary)
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
    }

    private var controlsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Divider()
            Toggle("Notifications", isOn: Binding(
                get: { model.notificationsEnabled },
                set: { value in Task { await model.setNotificationsEnabled(value) } }
            ))
            .toggleStyle(.switch).controlSize(.small)
            if model.notificationAuthorization != .authorized {
                Text(model.notificationAuthorizationSummary).font(.caption).foregroundStyle(.secondary)
                if model.notificationsEnabled, model.canRequestNotifications {
                    Button("Enable notifications") { Task { await model.setNotificationsEnabled(true) } }
                }
            }
            HStack {
                Button("Settings…") {
                    NSApplication.shared.activate()
                    openSettings()
                }
                .buttonStyle(.borderless)
                .keyboardShortcut(",", modifiers: .command)
                Spacer()
                Button("Quit") { NSApplication.shared.terminate(nil) }
                    .buttonStyle(.borderless).keyboardShortcut("q", modifiers: .command)
            }.font(.callout)
        }
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
                Text(device.connectedAt == nil ? "Seen since" : "Connected")
                Text(device.connectedAt ?? device.firstSeenAt, style: .relative)
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
