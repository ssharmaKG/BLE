import CoreBluetooth
import Foundation
import SwiftUI

enum DeviceType: String, CaseIterable, Identifiable {
    case wearable
    case audio
    case sensor
    case beacon
    case medical
    case smartHome
    case unknown

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .wearable:
            return "Wearables"
        case .audio:
            return "Audio"
        case .sensor:
            return "Sensors"
        case .beacon:
            return "Beacons"
        case .medical:
            return "Medical"
        case .smartHome:
            return "Smart Home"
        case .unknown:
            return "Unknown"
        }
    }
}

enum DeviceConnectionState {
    case disconnected
    case connecting
    case connected
    case failed

    var badgeTitle: String {
        switch self {
        case .disconnected:
            return "Disconnected"
        case .connecting:
            return "Connecting"
        case .connected:
            return "Connected"
        case .failed:
            return "Failed"
        }
    }

    var badgeColor: Color {
        switch self {
        case .disconnected:
            return .gray
        case .connecting:
            return .orange
        case .connected:
            return .green
        case .failed:
            return .red
        }
    }
}

struct ScannedDevice: Identifiable {
    let id: UUID
    let name: String?
    let rssi: Int
    let type: DeviceType
    let isConnectable: Bool
    let serviceUUIDs: [String]
    let manufacturerDataHex: String?
    var connectionState: DeviceConnectionState

    var displayName: String {
        guard let name, !name.isEmpty else { return "Unnamed BLE Device" }
        return name
    }

    var identifierText: String {
        id.uuidString
    }

    var debugDetails: [String] {
        var details: [String] = []
        details.append(isConnectable ? "Connectable" : "Not Connectable")

        if !serviceUUIDs.isEmpty {
            details.append("Services: \(serviceUUIDs.joined(separator: ", "))")
        }

        if let manufacturerDataHex, !manufacturerDataHex.isEmpty {
            details.append("Mfr: \(manufacturerDataHex)")
        }

        return details
    }

    var proximityLabel: String {
        switch rssi {
        case -55 ... 0:
            return "Very Near"
        case -65 ..< -55:
            return "Near"
        case -75 ..< -65:
            return "Medium"
        default:
            return "Far"
        }
    }
}

extension Data {
    var shortHexString: String {
        map { String(format: "%02X", $0) }
            .prefix(16)
            .joined()
    }
}

enum DeviceTypeClassifier {
    static func classify(name: String?, advertisementData: [String: Any]) -> DeviceType {
        let serviceUUIDs = advertisementData[CBAdvertisementDataServiceUUIDsKey] as? [CBUUID] ?? []
        let lowercasedName = name?.lowercased() ?? ""
        let manufacturerData = advertisementData[CBAdvertisementDataManufacturerDataKey] as? Data

        // Samsung watches do not expose one universal watch-specific CBUUID,
        // so the most practical first-pass detection is by advertisement name.
        if lowercasedName.contains("galaxy") || lowercasedName.contains("galaxy fit") || lowercasedName.contains("samsung") {
            return .wearable
        }

        if serviceUUIDs.contains(CBUUID(string: "180D")) || serviceUUIDs.contains(CBUUID(string: "180A")) || lowercasedName.contains("watch") || lowercasedName.contains("band") {
            return .wearable
        }


        if serviceUUIDs.contains(CBUUID(string: "181A")) || lowercasedName.contains("sensor") || lowercasedName.contains("temp") {
            return .sensor
        }

        if serviceUUIDs.contains(CBUUID(string: "1809")) || serviceUUIDs.contains(CBUUID(string: "1808")) {
            return .medical
        }

        if lowercasedName.contains("speaker") || lowercasedName.contains("buds") || lowercasedName.contains("audio") {
            return .audio
        }

        if lowercasedName.contains("light") || lowercasedName.contains("bulb") || lowercasedName.contains("lock") {
            return .smartHome
        }

        if isLikelyBeacon(serviceUUIDs: serviceUUIDs, manufacturerData: manufacturerData, name: lowercasedName) {
            return .beacon
        }

        return .unknown
    }

    private static func isLikelyBeacon(serviceUUIDs: [CBUUID], manufacturerData: Data?, name: String) -> Bool {
        if name.contains("beacon") || serviceUUIDs.contains(CBUUID(string: "FEAA")) {
            return true
        }

        guard let manufacturerData, manufacturerData.count >= 4 else {
            return false
        }

        let prefix = [UInt8](manufacturerData.prefix(4))
        return prefix[2] == 0x02 && prefix[3] == 0x15
    }
}
