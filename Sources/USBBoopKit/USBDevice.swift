import Foundation

public struct USBDevice: Identifiable, Equatable, Hashable, Sendable {
    public let id: UInt64
    public let name: String
    public let manufacturer: String?
    public let vendorID: Int?
    public let productID: Int?
    /// Serial number from USB descriptor. Treat as sensitive — never log with .public privacy.
    public let serialNumber: String?
    public let locationID: UInt32?
    public let speed: USBConnectionSpeed
    public let isHub: Bool
    public let firstSeenAt: Date
    public let connectedAt: Date?
    /// Original USBSpeed value; future values remain available without guessing their meaning.
    public let rawRegistrySpeed: Int?

    public init(
        id: UInt64,
        name: String,
        manufacturer: String? = nil,
        vendorID: Int? = nil,
        productID: Int? = nil,
        serialNumber: String? = nil,
        locationID: UInt32? = nil,
        speed: USBConnectionSpeed,
        isHub: Bool = false,
        firstSeenAt: Date? = nil,
        connectedAt: Date? = nil,
        rawRegistrySpeed: Int? = nil
    ) {
        self.id = id
        self.name = name
        self.manufacturer = manufacturer
        self.vendorID = vendorID
        self.productID = productID
        self.serialNumber = serialNumber
        self.locationID = locationID
        self.speed = speed
        self.isHub = isHub
        self.firstSeenAt = firstSeenAt ?? connectedAt ?? .now
        self.connectedAt = connectedAt
        self.rawRegistrySpeed = rawRegistrySpeed
    }

    public var subtitle: String {
        if let technicalLabel = speed.technicalLabel {
            return technicalLabel
        }

        return speed.displayLabel
    }

    public var linkSpeedSummary: String {
        speed == .unknown || speed == .other ? speed.displayLabel : "Link speed: \(speed.displayLabel)"
    }

    public var notificationBody: String { "Connected · \(linkSpeedSummary)" }

    public var detailSummary: String {
        var details: [String] = [speed.displayLabel]

        if let technicalLabel = speed.technicalLabel {
            details.append(technicalLabel)
        }

        if let manufacturer, !manufacturer.isEmpty {
            details.append(manufacturer)
        }

        if let locationID {
            details.append(String(format: "Location 0x%08X", locationID))
        }

        return details.joined(separator: " • ")
    }

    public var vendorProductSummary: String? {
        guard let vendorID, let productID else {
            return nil
        }

        return String(format: "VID %04X / PID %04X", vendorID, productID)
    }
}
