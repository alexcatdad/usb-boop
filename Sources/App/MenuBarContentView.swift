import MenubarKit
import SwiftUI
import USBBoopKit

/// The menu bar panel, laid out like the other MenubarKit apps: status header,
/// grouped tiles of standard list rows, the menu section and the version footer.
struct MenuBarContentView: View {
    @Bindable var model: AppModel

    /// Height of one device row; the list shows up to `maxVisibleDevices`
    /// rows before it scrolls.
    static let rowHeight: CGFloat = 28
    static let maxVisibleDevices = 9
    static let recentActivityCount = 3

    var body: some View {
        MenubarPanel {
            StatusHeader(model.status) {
                RefreshButton(isRefreshing: false, title: "Refresh device list") { model.refreshDevices() }
                    .keyboardShortcut("r", modifiers: .command)
            }
            if model.monitoringStatus.canRetry {
                PrimaryActionButton("Try Again") { model.refreshDevices() }
            }
            if model.keepLatestResultPinned, let device = model.latestConnectedDevice {
                latestConnectionTile(device)
            }
            devicesTile
            if !model.visibleHistory.isEmpty {
                recentActivityTile
            }
            MenuSection(quitTitle: "Quit usb-boop", quitHelp: "Stops monitoring until you open usb-boop again.") {
                OpenSettingsButton()
                    .keyboardShortcut(",", modifiers: .command)
            }
            VersionFooter()
        }
        .onAppear { model.becameActive() }
    }

    private func latestConnectionTile(_ device: USBDevice) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            TileHeader("Latest connection")
            DeviceRow(device: device, subtitle: model.latestConnectionStatus ?? device.connectionSummary)
        }
        .groupedTile()
    }

    private var devicesTile: some View {
        VStack(alignment: .leading, spacing: 0) {
            TileHeader("Connected devices")
            if model.visibleDevices.isEmpty {
                Text(model.emptyDevicesMessage)
                    .font(.callout).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 12).padding(.vertical, 4)
            } else {
                BoundedScrollView(maxHeight: Self.deviceListMaxHeight) {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(model.visibleDevices) { DeviceRow(device: $0) }
                    }
                }
            }
        }
        .groupedTile()
        .help("Link speed is the negotiated connection rate, not measured file-transfer speed.")
    }

    private var recentActivityTile: some View {
        VStack(alignment: .leading, spacing: 0) {
            TileHeader("Recent activity", linkTitle: "Clear") { model.clearHistory() }
            ForEach(model.visibleHistory.prefix(Self.recentActivityCount)) { observation in
                HStack(spacing: 8) {
                    Text(observation.device.name).lineLimit(1).truncationMode(.tail)
                    Spacer(minLength: 4)
                    Text(observation.kind.label).foregroundStyle(.secondary)
                    Text(observation.observedAt, style: .time)
                        .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                }
                .font(.callout)
                .padding(.horizontal, 12)
                .frame(minHeight: 24)
                .help(observation.device.name)
                .accessibilityElement(children: .combine)
            }
        }
        .groupedTile()
    }

    static let deviceListMaxHeight = CGFloat(maxVisibleDevices) * rowHeight
}

/// A device row shaped like MenubarKit's status rows: the name and the
/// negotiated link speed on one line, the speed tinted by tier so it stays the
/// prominent value (AGENTS.md). The connection time moves to the hover text,
/// except in the "Latest connection" tile, which shows it as a subtitle.
/// Clicking copies the device info.
private struct DeviceRow: View {
    let device: USBDevice
    var subtitle: String?

    var body: some View {
        Button(action: copyDeviceInfo) {
            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(device.name).lineLimit(1).truncationMode(.tail)
                    if let subtitle {
                        Text(subtitle).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                    }
                }
                Spacer(minLength: 8)
                Text(device.speed.displayLabel)
                    .fontWeight(.semibold).monospacedDigit()
                    .foregroundStyle(device.speed.tint)
                    .lineLimit(1)
            }
            .font(.callout)
        }
        .buttonStyle(CompactRowButtonStyle(minHeight: subtitle == nil ? MenuBarContentView.rowHeight : 36))
        .help("\(device.connectionSummary). Click to copy device info.")
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(device.name), \(device.linkSpeedSummary), \(subtitle ?? device.connectionSummary)")
        .accessibilityHint("Copies the device info")
        .contextMenu { Button("Copy Device Info", action: copyDeviceInfo) }
    }

    private func copyDeviceInfo() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(device.copyableInfo, forType: .string)
    }
}

/// `ListRowButtonStyle`'s hover highlight at status-row height, so a device
/// list reads like the status tiles in the other apps.
private struct CompactRowButtonStyle: ButtonStyle {
    let minHeight: CGFloat

    func makeBody(configuration: Configuration) -> some View {
        CompactRowBody(configuration: configuration, minHeight: minHeight)
    }
}

private struct CompactRowBody: View {
    let configuration: ButtonStyleConfiguration
    let minHeight: CGFloat
    @State private var hovering = false

    var body: some View {
        configuration.label
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 8)
            .frame(minHeight: minHeight)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(.primary.opacity(configuration.isPressed ? 0.12 : hovering ? 0.07 : 0))
            )
            .padding(.horizontal, 4)
            .contentShape(Rectangle())
            .onHover { hovering = $0 }
    }
}

extension USBConnectionSpeed {
    /// The speed tier's colour: the fastest links stand out, unknown speeds stay neutral.
    var tint: Color {
        switch self {
        case .usb3Gen2x2, .usb3Gen2: .green
        case .usb3Gen1: .blue
        case .usb2High: .orange
        default: .primary
        }
    }
}

extension USBDevice {
    /// The text "Copy Device Info" puts on the pasteboard.
    var copyableInfo: String {
        var lines = [name, linkSpeedSummary]
        if let technical = speed.technicalLabel { lines.append(technical) }
        if let manufacturer { lines.append("Manufacturer: \(manufacturer)") }
        if let identifiers = vendorProductSummary { lines.append(identifiers) }
        return lines.joined(separator: "\n")
    }

    /// "Connected 15:31", or "Hub · seen since 6 Nov, 15:30" for devices
    /// present before monitoring started.
    var connectionSummary: String {
        let prefix = isHub ? "Hub · " : ""
        if let connectedAt {
            return prefix + "Connected " + connectedAt.formatted(date: .omitted, time: .shortened)
        }
        return prefix + "Seen since " + firstSeenAt.formatted(date: .abbreviated, time: .shortened)
    }
}

extension USBObservation.Kind {
    fileprivate var label: String {
        switch self {
        case .attached: "Connected"
        case .detached: "Disconnected"
        case .firstSeen: "First seen"
        case .noLongerDetected: "No longer detected"
        }
    }
}
