import Foundation
import IOKit

extension USBMonitoringIssue: Error {}

public struct USBRegistrySnapshot: Sendable {
    public let devices: [USBDevice]
    public let issue: USBMonitoringIssue?

    public init(devices: [USBDevice], issue: USBMonitoringIssue? = nil) {
        self.devices = devices
        self.issue = issue
    }
}

/// Metadata-only registry boundary. Implementations never open devices or volumes.
/// All callbacks are synchronous on the main actor and initial registration is silent.
@MainActor
public protocol USBRegistryAccess: AnyObject {
    var onAttached: ((USBRegistrySnapshot) -> Void)? { get set }
    var onDetached: (([UInt64]) -> Void)? { get set }
    var onIssue: ((USBMonitoringIssue) -> Void)? { get set }
    func start() -> USBMonitoringIssue?
    func stop()
    func snapshot() -> Result<USBRegistrySnapshot, USBMonitoringIssue>
}

@MainActor
final class IOKitUSBRegistry: USBRegistryAccess {
    var onAttached: ((USBRegistrySnapshot) -> Void)?
    var onDetached: (([UInt64]) -> Void)?
    var onIssue: ((USBMonitoringIssue) -> Void)?
    private var port: IONotificationPortRef?
    private var source: CFRunLoopSource?
    private var matchedIterator: io_iterator_t = 0
    private var terminatedIterator: io_iterator_t = 0
    private let reader = USBRegistryDeviceReader()

    isolated deinit { stop() }

    func start() -> USBMonitoringIssue? {
        guard port == nil else { return nil }
        guard let port = IONotificationPortCreate(kIOMainPortDefault) else { return .registrationFailed }
        self.port = port
        guard let source = IONotificationPortGetRunLoopSource(port)?.takeUnretainedValue() else {
            stop()
            return .registrationFailed
        }
        self.source = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        let context = Unmanaged.passUnretained(self).toOpaque()
        let matched = IOServiceAddMatchingNotification(
            port, kIOMatchedNotification, IOServiceMatching("IOUSBHostDevice"),
            registryMatchedCallback, context, &matchedIterator
        )
        guard matched == KERN_SUCCESS else { return registrationFailure(matched) }
        drainSilently(matchedIterator)
        let terminated = IOServiceAddMatchingNotification(
            port, kIOTerminatedNotification, IOServiceMatching("IOUSBHostDevice"),
            registryTerminatedCallback, context, &terminatedIterator
        )
        guard terminated == KERN_SUCCESS else { return registrationFailure(terminated) }
        drainSilently(terminatedIterator)
        return nil
    }

    func stop() {
        if let source {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
            self.source = nil
        }
        if matchedIterator != 0 { IOObjectRelease(matchedIterator); matchedIterator = 0 }
        if terminatedIterator != 0 { IOObjectRelease(terminatedIterator); terminatedIterator = 0 }
        if let port { IONotificationPortDestroy(port); self.port = nil }
    }

    func snapshot() -> Result<USBRegistrySnapshot, USBMonitoringIssue> {
        var iterator: io_iterator_t = 0
        let result = IOServiceGetMatchingServices(kIOMainPortDefault, IOServiceMatching("IOUSBHostDevice"), &iterator)
        guard result == KERN_SUCCESS else { return .failure(issue(for: result, fallback: .enumerationFailed)) }
        defer { IOObjectRelease(iterator) }
        return .success(readDevices(iterator))
    }

    fileprivate func attached(_ iterator: io_iterator_t) { onAttached?(readDevices(iterator)) }

    fileprivate func detached(_ iterator: io_iterator_t) {
        var identifiers: [UInt64] = []
        var failure: USBMonitoringIssue?
        while case let service = IOIteratorNext(iterator), service != 0 {
            defer { IOObjectRelease(service) }
            var identifier: UInt64 = 0
            let result = IORegistryEntryGetRegistryEntryID(service, &identifier)
            if result == KERN_SUCCESS, identifier != 0 {
                identifiers.append(identifier)
            } else {
                failure = preferredIssue(failure, issue(for: result, fallback: .incompleteResults))
            }
        }
        onDetached?(identifiers)
        if let failure { onIssue?(failure) }
    }

    private func readDevices(_ iterator: io_iterator_t) -> USBRegistrySnapshot {
        var devices: [USBDevice] = []
        var failure: USBMonitoringIssue?
        while case let service = IOIteratorNext(iterator), service != 0 {
            defer { IOObjectRelease(service) }
            var identifier: UInt64 = 0
            let identityResult = IORegistryEntryGetRegistryEntryID(service, &identifier)
            guard identityResult == KERN_SUCCESS, identifier != 0 else {
                failure = preferredIssue(failure, issue(for: identityResult, fallback: .incompleteResults))
                continue
            }
            var properties: Unmanaged<CFMutableDictionary>?
            let result = IORegistryEntryCreateCFProperties(service, &properties, kCFAllocatorDefault, 0)
            let dictionary = properties?.takeRetainedValue() as? [String: Any] ?? [:]
            // Retain the identifiable device even when optional metadata is unavailable.
            devices.append(reader.makeDevice(id: identifier, properties: dictionary))
            if result != KERN_SUCCESS {
                failure = preferredIssue(failure, issue(for: result, fallback: .incompleteResults))
            }
        }
        return USBRegistrySnapshot(devices: devices, issue: failure)
    }

    private func drainSilently(_ iterator: io_iterator_t) {
        while case let service = IOIteratorNext(iterator), service != 0 { IOObjectRelease(service) }
    }

    private func registrationFailure(_ result: kern_return_t) -> USBMonitoringIssue {
        stop() // Both registrations are one unit; release a partially installed pair.
        return issue(for: result, fallback: .registrationFailed)
    }

    private func issue(for result: kern_return_t, fallback: USBMonitoringIssue) -> USBMonitoringIssue {
        if result == kIOReturnNotPermitted || result == kIOReturnNotPrivileged || result == KERN_NO_ACCESS {
            return .accessRestricted
        }
        return fallback
    }

    private func preferredIssue(_ previous: USBMonitoringIssue?, _ next: USBMonitoringIssue) -> USBMonitoringIssue {
        previous == .accessRestricted ? .accessRestricted : next
    }
}

// IOKit owns the registrations; the app owns the adapter until stop() removes their
// main-run-loop source and destroys the port. No unretained context crosses a Task.
private func registryMatchedCallback(refCon: UnsafeMutableRawPointer?, iterator: io_iterator_t) {
    guard let refCon else { return }
    let registry = Unmanaged<IOKitUSBRegistry>.fromOpaque(refCon).takeUnretainedValue()
    MainActor.assumeIsolated { registry.attached(iterator) }
}

private func registryTerminatedCallback(refCon: UnsafeMutableRawPointer?, iterator: io_iterator_t) {
    guard let refCon else { return }
    let registry = Unmanaged<IOKitUSBRegistry>.fromOpaque(refCon).takeUnretainedValue()
    MainActor.assumeIsolated { registry.detached(iterator) }
}
