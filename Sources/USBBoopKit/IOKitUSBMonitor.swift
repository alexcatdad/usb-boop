import Foundation
import IOKit

private let usbHostDeviceClassName = "IOUSBHostDevice"
private let usbProductStringKey = "USB Product Name"
private let usbVendorStringKey = "USB Vendor Name"
private let usbSerialNumberStringKey = "USB Serial Number"
private let usbVendorIDKey = "idVendor"
private let usbProductIDKey = "idProduct"
private let usbSpeedKey = "USBSpeed"
private let usbLocationIDKey = "locationID"
private let usbDeviceClassKey = "bDeviceClass"
private let usbHubClassValue = 9

@MainActor
public final class IOKitUSBMonitor: USBMonitoring, @unchecked Sendable {
    public var onDevicesChanged: (@MainActor ([USBDevice]) -> Void)?
    public var onDeviceAttached: (@MainActor (USBDevice) -> Void)?

    private let reader = USBRegistryDeviceReader()
    private var knownDevices: [UInt64: USBDevice] = [:]
    private var notificationPort: IONotificationPortRef?
    private var matchedIterator: io_iterator_t = 0
    private var terminatedIterator: io_iterator_t = 0
    private var didPrimeAttachedIterator = false
    private var started = false

    public init() {}

    public func start() {
        guard !started else {
            USBBoopLog.usbMonitor.debug("Ignoring duplicate start request")
            return
        }

        started = true
        USBBoopLog.usbMonitor.notice("Starting IOKit USB monitor")

        guard let notificationPort = IONotificationPortCreate(kIOMainPortDefault) else {
            USBBoopLog.usbMonitor.error("Failed to create IOKit notification port; falling back to one-time refresh")
            refresh()
            return
        }

        self.notificationPort = notificationPort

        if let runLoopSource = IONotificationPortGetRunLoopSource(notificationPort)?.takeUnretainedValue() {
            CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .defaultMode)
        }

        registerAttachNotifications()
        registerDetachNotifications()
    }

    public func stop() {
        USBBoopLog.usbMonitor.notice("Stopping IOKit USB monitor")

        if matchedIterator != 0 {
            IOObjectRelease(matchedIterator)
            matchedIterator = 0
        }

        if terminatedIterator != 0 {
            IOObjectRelease(terminatedIterator)
            terminatedIterator = 0
        }

        if let notificationPort {
            IONotificationPortDestroy(notificationPort)
            self.notificationPort = nil
        }
    }

    public func refresh() {
        var iterator: io_iterator_t = 0
        let result = IOServiceGetMatchingServices(kIOMainPortDefault, IOServiceMatching(usbHostDeviceClassName), &iterator)

        guard result == KERN_SUCCESS else {
            USBBoopLog.usbMonitor.error("Failed to enumerate USB services: \(result)")
            return
        }

        defer {
            IOObjectRelease(iterator)
        }

        var refreshed: [UInt64: USBDevice] = [:]

        while case let service = IOIteratorNext(iterator), service != 0 {
            defer { IOObjectRelease(service) }

            guard let device = reader.makeDevice(from: service) else {
                continue
            }

            refreshed[device.id] = merge(device, withKnownDevice: knownDevices[device.id])
        }

        knownDevices = refreshed
        USBBoopLog.usbMonitor.notice("Refresh complete with \(refreshed.count) visible devices")
        publishSnapshot()
    }

    private func registerAttachNotifications() {
        guard let notificationPort else {
            return
        }

        let result = IOServiceAddMatchingNotification(
            notificationPort,
            kIOMatchedNotification,
            IOServiceMatching(usbHostDeviceClassName),
            usbMatchedCallback,
            Unmanaged.passUnretained(self).toOpaque(),
            &matchedIterator
        )

        guard result == KERN_SUCCESS else {
            USBBoopLog.usbMonitor.error("Failed to register attach notification: \(result)")
            refresh()
            return
        }

        USBBoopLog.usbMonitor.debug("Registered attach notification")
        handleMatchedDevices(from: matchedIterator, shouldNotify: false)
        didPrimeAttachedIterator = true
    }

    private func registerDetachNotifications() {
        guard let notificationPort else {
            return
        }

        let result = IOServiceAddMatchingNotification(
            notificationPort,
            kIOTerminatedNotification,
            IOServiceMatching(usbHostDeviceClassName),
            usbTerminatedCallback,
            Unmanaged.passUnretained(self).toOpaque(),
            &terminatedIterator
        )

        guard result == KERN_SUCCESS else {
            USBBoopLog.usbMonitor.error("Failed to register detach notification: \(result)")
            return
        }

        USBBoopLog.usbMonitor.debug("Registered detach notification")
        handleTerminatedDevices(from: terminatedIterator)
    }

    fileprivate func handleMatchedDevices(from iterator: io_iterator_t, shouldNotify: Bool? = nil) {
        let notify = shouldNotify ?? didPrimeAttachedIterator

        while case let service = IOIteratorNext(iterator), service != 0 {
            defer { IOObjectRelease(service) }

            guard let device = reader.makeDevice(from: service) else {
                continue
            }

            let mergedDevice = merge(device, withKnownDevice: knownDevices[device.id])
            let wasKnown = knownDevices[device.id] != nil
            knownDevices[mergedDevice.id] = mergedDevice
            USBBoopLog.usbMonitor.notice(
                "Observed USB device: \(mergedDevice.name, privacy: .public) speed=\(mergedDevice.speed.displayLabel, privacy: .public) notify=\(notify && !wasKnown)"
            )

            if notify && !wasKnown {
                onDeviceAttached?(mergedDevice)
            }
        }

        publishSnapshot()
    }

    fileprivate func handleTerminatedDevices(from iterator: io_iterator_t) {
        var changed = false

        while case let service = IOIteratorNext(iterator), service != 0 {
            defer { IOObjectRelease(service) }

            guard let entryID = reader.registryEntryID(for: service) else {
                continue
            }

            if knownDevices.removeValue(forKey: entryID) != nil {
                changed = true
                USBBoopLog.usbMonitor.notice("USB device removed: entryID=\(entryID)")
            }
        }

        if changed {
            publishSnapshot()
        }
    }

    private func merge(_ device: USBDevice, withKnownDevice existing: USBDevice?) -> USBDevice {
        guard let existing else {
            return device
        }

        return USBDevice(
            id: device.id,
            name: device.name,
            manufacturer: device.manufacturer ?? existing.manufacturer,
            vendorID: device.vendorID ?? existing.vendorID,
            productID: device.productID ?? existing.productID,
            serialNumber: device.serialNumber ?? existing.serialNumber,
            locationID: device.locationID ?? existing.locationID,
            speed: device.speed == .unknown ? existing.speed : device.speed,
            isHub: device.isHub,
            connectedAt: existing.connectedAt
        )
    }

    private func publishSnapshot() {
        let devices = knownDevices.values.sorted {
            if $0.connectedAt == $1.connectedAt {
                return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            }

            return $0.connectedAt > $1.connectedAt
        }

        USBBoopLog.usbMonitor.debug("Publishing \(devices.count) visible USB devices to the app model")
        onDevicesChanged?(devices)
    }
}

private func usbMatchedCallback(refCon: UnsafeMutableRawPointer?, iterator: io_iterator_t) {
    guard let refCon else {
        return
    }

    let monitor = Unmanaged<IOKitUSBMonitor>.fromOpaque(refCon).takeUnretainedValue()
    MainActor.assumeIsolated {
        monitor.handleMatchedDevices(from: iterator)
    }
}

private func usbTerminatedCallback(refCon: UnsafeMutableRawPointer?, iterator: io_iterator_t) {
    guard let refCon else {
        return
    }

    let monitor = Unmanaged<IOKitUSBMonitor>.fromOpaque(refCon).takeUnretainedValue()
    MainActor.assumeIsolated {
        monitor.handleTerminatedDevices(from: iterator)
    }
}

private struct USBRegistryDeviceReader {
    func makeDevice(from service: io_registry_entry_t) -> USBDevice? {
        guard let id = registryEntryID(for: service) else {
            return nil
        }

        let productName = stringProperty(for: service, key: usbProductStringKey)
        let vendorName = stringProperty(for: service, key: usbVendorStringKey)
        let serialNumber = stringProperty(for: service, key: usbSerialNumberStringKey)
        let vendorID = intProperty(for: service, key: usbVendorIDKey)
        let productID = intProperty(for: service, key: usbProductIDKey)
        let speed = USBConnectionSpeed(registryValue: intProperty(for: service, key: usbSpeedKey))
        let locationID = uint32Property(for: service, key: usbLocationIDKey)
        let deviceClass = intProperty(for: service, key: usbDeviceClassKey)

        let name = resolvedName(
            productName: productName,
            vendorName: vendorName,
            vendorID: vendorID,
            productID: productID
        )

        return USBDevice(
            id: id,
            name: name,
            manufacturer: vendorName,
            vendorID: vendorID,
            productID: productID,
            serialNumber: serialNumber,
            locationID: locationID,
            speed: speed,
            isHub: deviceClass == usbHubClassValue
        )
    }

    func registryEntryID(for service: io_registry_entry_t) -> UInt64? {
        var entryID: UInt64 = 0
        let result = IORegistryEntryGetRegistryEntryID(service, &entryID)

        guard result == KERN_SUCCESS else {
            return nil
        }

        return entryID
    }

    private func resolvedName(
        productName: String?,
        vendorName: String?,
        vendorID: Int?,
        productID: Int?
    ) -> String {
        if let productName, !productName.isEmpty {
            return productName
        }

        if let vendorName, !vendorName.isEmpty {
            return "\(vendorName) USB Device"
        }

        if let vendorID, let productID {
            return String(format: "USB Device %04X:%04X", vendorID, productID)
        }

        return "USB Device"
    }

    private func stringProperty(for service: io_registry_entry_t, key: String) -> String? {
        property(for: service, key: key) as? String
    }

    private func intProperty(for service: io_registry_entry_t, key: String) -> Int? {
        if let value = property(for: service, key: key) as? NSNumber {
            return value.intValue
        }

        return nil
    }

    private func uint32Property(for service: io_registry_entry_t, key: String) -> UInt32? {
        if let value = property(for: service, key: key) as? NSNumber {
            return value.uint32Value
        }

        return nil
    }

    private func property(for service: io_registry_entry_t, key: String) -> Any? {
        IORegistryEntryCreateCFProperty(service, key as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue()
    }
}
