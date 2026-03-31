import Foundation

@MainActor
public enum USBMonitorFactory {
    public static func makeMonitor() -> any USBMonitoring {
        #if DEBUG
        if ProcessInfo.processInfo.environment["USB_BOOP_USE_FIXTURES"] == "1" {
            return FixtureUSBMonitor()
        }
        #endif
        return IOKitUSBMonitor()
    }
}
