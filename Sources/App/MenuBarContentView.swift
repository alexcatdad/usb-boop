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

    // MARK: - Latest Result

    private var latestResultCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Latest Result")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)

            if let device = model.latestConnectedDevice {
                HStack(alignment: .firstTextBaseline) {
                    Text(device.name)
                        .font(.body.weight(.semibold))
                        .lineLimit(1)

                    Spacer(minLength: 8)

                    Text(device.speed.displayLabel)
                        .font(.body.weight(.semibold).monospacedDigit())
                        .foregroundStyle(speedColor(for: device.speed))
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("\(device.name), \(device.speed.displayLabel)")

                Text(device.detailSummary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            } else {
                Text("Plug in a USB device to see its link speed.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(.quaternary.opacity(0.5), in: .rect(cornerRadius: 10))
    }

    // MARK: - Current Devices

    private var currentDevicesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Connected Devices")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)

                Spacer()

                Button {
                    model.refreshDevices()
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                        .labelStyle(.iconOnly)
                        .font(.caption)
                }
                .buttonStyle(.borderless)
                .keyboardShortcut("r", modifiers: .command)
                .help("Refresh device list")
            }

            if model.visibleDevices.isEmpty {
                Text("No USB devices visible.")
                    .font(.callout)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 8)
            } else {
                VStack(spacing: 2) {
                    ForEach(model.visibleDevices) { device in
                        DeviceRow(device: device)
                    }
                }
            }
        }
    }

    // MARK: - Controls

    private var controlsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Divider()

            Toggle("Notifications", isOn: $model.notificationsEnabled)
                .toggleStyle(.switch)
                .controlSize(.small)

            Toggle("Pin latest result", isOn: $model.keepLatestResultPinned)
                .toggleStyle(.switch)
                .controlSize(.small)

            HStack(spacing: 12) {
                SettingsLink {
                    Text("Settings...")
                        .font(.callout)
                }
                .buttonStyle(.borderless)

                Spacer()

                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }
                .buttonStyle(.borderless)
                .foregroundStyle(.secondary)
                .font(.callout)
                .keyboardShortcut("q", modifiers: .command)
            }
            .padding(.top, 4)
        }
    }
}

// MARK: - Device Row

private struct DeviceRow: View {
    let device: USBDevice

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(alignment: .firstTextBaseline) {
                if device.isHub {
                    Image(systemName: "point.3.connected.trianglepath.dotted")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }

                Text(device.name)
                    .font(.callout.weight(.medium))
                    .lineLimit(1)

                Spacer(minLength: 8)

                Text(device.speed.displayLabel)
                    .font(.callout.weight(.semibold).monospacedDigit())
                    .foregroundStyle(speedColor(for: device.speed))
            }

            HStack(spacing: 6) {
                if let technical = device.speed.technicalLabel {
                    Text(technical)
                }
                if let manufacturer = device.manufacturer, !manufacturer.isEmpty {
                    Text("·")
                    Text(manufacturer)
                }
                Text("·")
                Text(device.connectedAt, style: .relative)
                    .monospacedDigit()
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 5)
        .padding(.horizontal, 6)
        .background(.clear)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(device.name), \(device.speed.displayLabel)")
        .accessibilityValue(device.speed.technicalLabel ?? "")
        .accessibilityHint("Right-click to copy device info")
        .contextMenu {
            Button("Copy Device Info") {
                copyDeviceInfo()
            }
        }
    }

    private func copyDeviceInfo() {
        var lines = ["\(device.name) — \(device.speed.displayLabel)"]
        if let technical = device.speed.technicalLabel {
            lines.append(technical)
        }
        if let manufacturer = device.manufacturer, !manufacturer.isEmpty {
            lines.append("Manufacturer: \(manufacturer)")
        }
        if let vid = device.vendorID, let pid = device.productID {
            lines.append(String(format: "VID %04X / PID %04X", vid, pid))
        }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(lines.joined(separator: "\n"), forType: .string)
    }
}

// MARK: - Speed Color

private func speedColor(for speed: USBConnectionSpeed) -> Color {
    switch speed {
    case .usb3Gen2x2, .usb3Gen2:
        return .green
    case .usb3Gen1:
        return .blue
    case .usb2High:
        return .orange
    case .usb1Full, .usb1Low:
        return .secondary
    case .unknown, .other:
        return .secondary
    }
}
