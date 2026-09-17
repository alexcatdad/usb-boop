import Foundation

@MainActor
public final class IOKitUSBMonitor: USBMonitoring {
    public var onDevicesChanged: (@MainActor ([USBDevice]) -> Void)?
    public var onDeviceAttached: (@MainActor (USBDevice) -> Void)?
    public var onDeviceDetached: (@MainActor (USBDevice) -> Void)?
    public var onStatusChanged: (@MainActor (USBMonitoringStatus) -> Void)?
    public var onObservation: (@MainActor (USBObservation) -> Void)?
    public private(set) var status: USBMonitoringStatus = .stopped {
        didSet { if oldValue != status { onStatusChanged?(status) } }
    }

    private let registry: any USBRegistryAccess
    private let now: () -> Date
    private var knownDevices: [UInt64: USBDevice] = [:]
    private var started = false
    private var registrationIssue: USBMonitoringIssue?
    private var hasSnapshot = false

    public convenience init() { self.init(registry: IOKitUSBRegistry()) }

    public init(registry: any USBRegistryAccess, now: @escaping () -> Date = Date.init) {
        self.registry = registry
        self.now = now
    }

    public func start() {
        guard !started else { return }
        started = true
        status = .starting
        installRegistrations()
        if registrationIssue == .accessRestricted {
            markIssue(.accessRestricted)
        } else {
            reconcile(recordChanges: hasSnapshot)
        }
    }

    public func stop() {
        registry.stop()
        registry.onAttached = nil
        registry.onDetached = nil
        registry.onIssue = nil
        started = false
        registrationIssue = nil
        status = .stopped
    }

    /// Explicit user retry: the only operation allowed to retry an access denial.
    public func refresh() {
        if !started { start(); return }
        if registrationIssue != nil {
            registry.stop()
            installRegistrations()
        }
        if registrationIssue == .accessRestricted {
            markIssue(.accessRestricted)
            return
        }
        reconcile(recordChanges: hasSnapshot)
    }

    public func reconcileAfterWake() {
        guard started, status.issue != .accessRestricted else { return }
        // Recreate both registrations together. Initial iterator draining never emits attaches.
        registry.stop()
        installRegistrations()
        if registrationIssue == .accessRestricted {
            markIssue(.accessRestricted)
        } else {
            reconcile(recordChanges: hasSnapshot)
        }
    }

    private func installRegistrations() {
        registry.onAttached = { [weak self] snapshot in self?.receiveAttachments(snapshot) }
        registry.onDetached = { [weak self] identifiers in self?.receiveDetachments(identifiers) }
        registry.onIssue = { [weak self] issue in self?.markIssue(issue) }
        registrationIssue = registry.start()
        if registrationIssue != nil { registry.stop() }
    }

    private func reconcile(recordChanges: Bool) {
        let result = registry.snapshot()
        guard case let .success(snapshot) = result else {
            if case let .failure(issue) = result { markIssue(issue) }
            return
        }
        let observedAt = now()
        let previous = knownDevices
        // An incomplete enumeration cannot prove that an old device disappeared.
        var refreshed = snapshot.issue == nil ? [:] : knownDevices
        for device in snapshot.devices {
            let observed = USBDeviceMerger.observed(device, at: observedAt, attached: false)
            refreshed[device.id] = USBDeviceMerger.merge(observed, withKnownDevice: previous[device.id])
        }
        knownDevices = refreshed
        hasSnapshot = true
        if recordChanges {
            for device in refreshed.values where previous[device.id] == nil {
                observe(.firstSeen, device, at: observedAt)
            }
            for device in previous.values where refreshed[device.id] == nil {
                observe(.noLongerDetected, device, at: observedAt)
            }
        }
        if let issue = snapshot.issue ?? registrationIssue { markIssue(issue) } else { status = .monitoring }
        publishSnapshot()
    }

    private func receiveAttachments(_ snapshot: USBRegistrySnapshot) {
        guard started else { return }
        let observedAt = now()
        for device in snapshot.devices {
            let existing = knownDevices[device.id]
            let observed = USBDeviceMerger.observed(device, at: observedAt, attached: true)
            let merged = USBDeviceMerger.merge(observed, withKnownDevice: existing)
            knownDevices[device.id] = merged
            if existing == nil {
                observe(.attached, merged, at: observedAt)
                onDeviceAttached?(merged)
            }
        }
        if let issue = snapshot.issue { markIssue(issue) }
        publishSnapshot()
    }

    private func receiveDetachments(_ identifiers: [UInt64]) {
        guard started else { return }
        for identifier in identifiers {
            if let device = knownDevices.removeValue(forKey: identifier) {
                observe(.detached, device, at: now())
                onDeviceDetached?(device)
            }
        }
        publishSnapshot()
    }

    private func markIssue(_ issue: USBMonitoringIssue) {
        if issue == .accessRestricted {
            // Do not keep receiving/retrying denied operations in the background.
            registry.stop()
            registrationIssue = issue
        }
        status = hasSnapshot ? .degraded(issue) : .unavailable(issue)
    }

    private func observe(_ kind: USBObservation.Kind, _ device: USBDevice, at time: Date) {
        onObservation?(USBObservation(kind: kind, device: device, observedAt: time))
    }

    private func publishSnapshot() { onDevicesChanged?(USBDeviceMerger.sorted(knownDevices.values)) }
}

enum USBDeviceMerger {
    static func observed(_ device: USBDevice, at time: Date, attached: Bool) -> USBDevice {
        USBDevice(
            id: device.id, name: device.name, manufacturer: device.manufacturer,
            vendorID: device.vendorID, productID: device.productID, serialNumber: device.serialNumber,
            locationID: device.locationID, speed: device.speed, isHub: device.isHub,
            firstSeenAt: time, connectedAt: attached ? time : nil, rawRegistrySpeed: device.rawRegistrySpeed
        )
    }

    static func merge(_ device: USBDevice, withKnownDevice existing: USBDevice?) -> USBDevice {
        guard let existing else { return device }
        return USBDevice(
            id: device.id, name: device.name,
            manufacturer: device.manufacturer ?? existing.manufacturer,
            vendorID: device.vendorID ?? existing.vendorID, productID: device.productID ?? existing.productID,
            serialNumber: device.serialNumber ?? existing.serialNumber, locationID: device.locationID ?? existing.locationID,
            speed: device.speed, isHub: device.isHub, firstSeenAt: existing.firstSeenAt,
            connectedAt: existing.connectedAt, rawRegistrySpeed: device.rawRegistrySpeed
        )
    }

    static func sorted(_ devices: some Collection<USBDevice>) -> [USBDevice] {
        devices.sorted {
            if $0.firstSeenAt == $1.firstSeenAt {
                return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            }
            return $0.firstSeenAt > $1.firstSeenAt
        }
    }
}
