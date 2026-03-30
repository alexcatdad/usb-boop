import OSLog

public enum USBBoopLog {
    public static let subsystem = "com.alexcatdad.usb-boop"

    public static let usbMonitor = Logger(subsystem: subsystem, category: "usb-monitor")
    public static let appModel = Logger(subsystem: subsystem, category: "app-model")
}
