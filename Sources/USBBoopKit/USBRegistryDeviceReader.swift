import Foundation

private let usbProductStringKey = "USB Product Name"
private let usbVendorStringKey = "USB Vendor Name"
private let usbSerialNumberStringKey = "USB Serial Number"
private let usbVendorIDKey = "idVendor"
private let usbProductIDKey = "idProduct"
private let usbSpeedKey = "USBSpeed"
private let usbLocationIDKey = "locationID"
private let usbDeviceClassKey = "bDeviceClass"
private let usbHubClassValue = 9

struct USBRegistryDeviceReader {
    func sanitize(_ raw: String?) -> String? {
        guard let raw else { return nil }

        let cleaned = raw.unicodeScalars.filter { scalar in
            // Keep printable characters: letters, marks, numbers, punctuation, symbols, spaces
            // Reject control characters (Cc), format characters (Cf), surrogates, etc.
            switch scalar.properties.generalCategory {
            case .control, .format, .surrogate, .privateUse, .unassigned:
                return false
            default:
                return true
            }
        }

        let result = String(String.UnicodeScalarView(cleaned))
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !result.isEmpty else { return nil }

        if result.count > 128 {
            return String(result.prefix(128))
        }

        return result
    }

    func resolvedName(
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

    func makeDevice(id: UInt64, properties: [String: Any]) -> USBDevice {
        let productName = sanitize(properties[usbProductStringKey] as? String)
        let vendorName = sanitize(properties[usbVendorStringKey] as? String)
        let vendorID = (properties[usbVendorIDKey] as? NSNumber)?.intValue
        let productID = (properties[usbProductIDKey] as? NSNumber)?.intValue
        let rawSpeed = (properties[usbSpeedKey] as? NSNumber)?.intValue
        return USBDevice(
            id: id,
            name: resolvedName(productName: productName, vendorName: vendorName, vendorID: vendorID, productID: productID),
            manufacturer: vendorName, vendorID: vendorID, productID: productID,
            serialNumber: sanitize(properties[usbSerialNumberStringKey] as? String),
            locationID: (properties[usbLocationIDKey] as? NSNumber)?.uint32Value,
            speed: USBConnectionSpeed(registryValue: rawSpeed),
            isHub: (properties[usbDeviceClassKey] as? NSNumber)?.intValue == usbHubClassValue,
            rawRegistrySpeed: rawSpeed
        )
    }
}
