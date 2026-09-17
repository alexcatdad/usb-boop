import Foundation

public enum USBMonitoringIssue: String, Equatable, Sendable {
    case accessRestricted
    case registrationFailed
    case enumerationFailed
    case incompleteResults

    public var message: String {
        switch self {
        case .accessRestricted: "Access restricted. Available USB information may be incomplete."
        case .registrationFailed: "USB monitoring could not start. Results may be out of date."
        case .enumerationFailed: "USB information could not be refreshed. Previous results may be out of date."
        case .incompleteResults: "Some USB information is unavailable. Results may be incomplete."
        }
    }
}

public enum USBMonitoringStatus: Equatable, Sendable {
    case stopped
    case starting
    case monitoring
    case degraded(USBMonitoringIssue)
    case unavailable(USBMonitoringIssue)

    public var isSnapshotReliable: Bool { self == .monitoring }
    public var issue: USBMonitoringIssue? {
        switch self {
        case .degraded(let issue), .unavailable(let issue): issue
        default: nil
        }
    }
    public var canRetry: Bool { issue != nil || self == .stopped }
    public var message: String {
        if let issue { return issue.message }
        switch self {
        case .stopped: return "USB monitoring is stopped."
        case .starting: return "Starting USB monitoring…"
        default: return "Monitoring USB connections"
        }
    }
}

public struct USBObservation: Identifiable, Equatable, Sendable {
    public enum Kind: String, Sendable {
        case attached, detached, firstSeen, noLongerDetected
    }
    public let id: UUID
    public let kind: Kind
    public let observedAt: Date
    /// A metadata-only copy with the serial number removed, suitable for session history.
    public let device: USBDevice

    public init(kind: Kind, device: USBDevice, observedAt: Date = .now) {
        self.id = UUID()
        self.kind = kind
        self.observedAt = observedAt
        self.device = USBDevice(
            id: device.id, name: device.name, manufacturer: device.manufacturer,
            vendorID: device.vendorID, productID: device.productID, locationID: device.locationID,
            speed: device.speed, isHub: device.isHub, firstSeenAt: device.firstSeenAt,
            connectedAt: device.connectedAt, rawRegistrySpeed: device.rawRegistrySpeed
        )
    }
}

/// Callbacks execute synchronously on the main actor. Owners must clear callbacks or use
/// weak captures to avoid retaining their monitor through its subscriber.
@MainActor
public protocol USBMonitoring: AnyObject {
    var status: USBMonitoringStatus { get }
    var onDevicesChanged: (@MainActor ([USBDevice]) -> Void)? { get set }
    var onDeviceAttached: (@MainActor (USBDevice) -> Void)? { get set }
    var onDeviceDetached: (@MainActor (USBDevice) -> Void)? { get set }
    var onStatusChanged: (@MainActor (USBMonitoringStatus) -> Void)? { get set }
    var onObservation: (@MainActor (USBObservation) -> Void)? { get set }

    func start()
    func stop()
    func refresh()
    func reconcileAfterWake()
}
