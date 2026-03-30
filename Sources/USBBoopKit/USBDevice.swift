import Foundation

public struct USBDevice: Identifiable, Equatable, Sendable {
    public let id: UInt64
    public let name: String
    public let manufacturer: String?
    public let vendorID: Int?
    public let productID: Int?
    public let serialNumber: String?
    public let locationID: UInt32?
    public let speed: USBConnectionSpeed
    public let isHub: Bool
    public let connectedAt: Date

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
        connectedAt: Date = .now
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
        self.connectedAt = connectedAt
    }

    public var subtitle: String {
        if let technicalLabel = speed.technicalLabel {
            return technicalLabel
        }

        return speed.displayLabel
    }

    public var notificationBody: String {
        "\(name) connected at \(speed.displayLabel)"
    }

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
