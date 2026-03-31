import Foundation

public enum USBConnectionSpeed: Int, CaseIterable, Codable, Sendable {
    case unknown = 0
    case usb1Low
    case usb1Full
    case usb2High
    case usb3Gen1
    case usb3Gen2
    case usb3Gen2x2
    case other

    public init(registryValue: Int?) {
        switch registryValue {
        case 2:
            self = .usb1Low
        case 1:
            self = .usb1Full
        case 3:
            self = .usb2High
        case 4:
            self = .usb3Gen1
        case 5:
            self = .usb3Gen2
        case 6:
            self = .usb3Gen2x2
        case 7:
            self = .other
        default:
            self = .unknown
        }
    }

    public var displayLabel: String {
        switch self {
        case .unknown:
            return "Speed unavailable"
        case .usb1Low:
            return "1.5 Mbps"
        case .usb1Full:
            return "12 Mbps"
        case .usb2High:
            return "480 Mbps"
        case .usb3Gen1:
            return "5 Gbps"
        case .usb3Gen2:
            return "10 Gbps"
        case .usb3Gen2x2:
            return "20 Gbps"
        case .other:
            return "Unclassified high-speed path"
        }
    }

    public var technicalLabel: String? {
        switch self {
        case .unknown:
            return nil
        case .usb1Low:
            return "USB 1.x low speed"
        case .usb1Full:
            return "USB 1.1 full speed"
        case .usb2High:
            return "USB 2.0 high speed"
        case .usb3Gen1:
            return "USB 3.2 Gen 1"
        case .usb3Gen2:
            return "USB 3.2 Gen 2"
        case .usb3Gen2x2:
            return "USB 3.2 Gen 2x2"
        case .other:
            return "USB high-speed path"
        }
    }

}
