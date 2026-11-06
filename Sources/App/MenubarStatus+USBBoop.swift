import MenubarKit
import USBBoopKit

extension MenubarStatus {
    /// The tray and panel header status for a monitoring state. Anything but
    /// healthy (or starting) monitoring puts the attention badge on the tray glyph.
    static func usbBoop(_ monitoring: USBMonitoringStatus, deviceCount: Int) -> MenubarStatus {
        switch monitoring {
        case .monitoring:
            MenubarStatus(
                tone: .ok, word: "Monitoring", headline: "Monitoring USB",
                detail: deviceSummary(deviceCount))
        case .starting:
            MenubarStatus(tone: .ok, word: "Starting", headline: "Starting USB monitoring…")
        case .degraded(let issue):
            MenubarStatus(
                tone: .warning, word: "Results may be incomplete",
                headline: "Results may be incomplete", detail: issue.message)
        case .unavailable(let issue):
            MenubarStatus(
                tone: .error, word: "Monitoring unavailable",
                headline: "USB monitoring unavailable", detail: issue.message)
        case .stopped:
            MenubarStatus(
                tone: .off, word: "Stopped", headline: "USB monitoring stopped",
                detail: monitoring.message)
        }
    }

    private static func deviceSummary(_ count: Int) -> String {
        switch count {
        case 0: "No USB devices connected"
        case 1: "1 device connected"
        default: "\(count) devices connected"
        }
    }
}

extension AppModel {
    var status: MenubarStatus { .usbBoop(monitoringStatus, deviceCount: visibleDevices.count) }
}
