//
//  BLEDevice.swift
//  BLEScanner
//
//  Created by Shikha Sharma on 20/04/26.
//

import CoreBluetooth
import Foundation
import SwiftUI

// MARK: - App vocabulary
//
// This file defines the core data structures and decoding helpers used by the app.
// A useful way to think about it is:
// - `BLEScannerViewModel.swift` controls the BLE workflow
// - `ContentView.swift` controls how information is shown
// - this file explains what the information means
//
// In other words, this file answers questions like:
// - What is a scanned device?
// - What kinds of device types do we show in the filter?
// - What does a heart-rate packet look like after decoding?
// - How do we interpret GOBOULT vendor bytes as BP, SpO2, or stress?

// High-level categories shown in the scanner UI.
// These are not guaranteed by BLE itself. They are educated guesses
// made by the app from names, services, and manufacturer data.
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

// Tracks where we are in the connection lifecycle for a device.
// This is what powers the "Connect", "Connecting", "Connected", and "Failed" UI states.
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

// Represents one BLE device after we have converted raw CoreBluetooth information
// into a form that the UI can render easily.
//
// It includes:
// - user-facing data such as display name and RSSI
// - technical advertisement details for diagnostics
// - a connection state used by the list and detail navigation
struct ScannedDevice: Identifiable {
    let id: UUID
    let name: String?
    let rssi: Int
    let type: DeviceType
    let isConnectable: Bool
    let serviceUUIDs: [String]
    let localName: String?
    let companyName: String?
    let manufacturerDataHex: String?
    let txPowerLevel: Int?
    let solicitationUUIDs: [String]
    let overflowServiceUUIDs: [String]
    var connectionState: DeviceConnectionState

    var displayName: String {
        // Many BLE devices do not advertise a readable name.
        // Instead of showing a blank row, we fall back to a generic label.
        guard let name, !name.isEmpty else { return "Unnamed BLE Device" }
        return name
    }

    var identifierText: String {
        // The peripheral UUID is useful when device names are missing or duplicated.
        id.uuidString
    }

    var debugDetails: [String] {
        // These strings are shown in raw/debug-style UI to help identify
        // otherwise opaque BLE devices.
        var details: [String] = []
        details.append(isConnectable ? "Connectable" : "Not Connectable")

        if let localName, !localName.isEmpty, localName != name {
            details.append("Local Name: \(localName)")
        }

        if !serviceUUIDs.isEmpty {
            details.append("Services: \(serviceUUIDs.joined(separator: ", "))")
        }

        if !solicitationUUIDs.isEmpty {
            details.append("Solicits: \(solicitationUUIDs.joined(separator: ", "))")
        }

        if !overflowServiceUUIDs.isEmpty {
            details.append("Overflow: \(overflowServiceUUIDs.joined(separator: ", "))")
        }

        if let companyName, !companyName.isEmpty {
            details.append("Company: \(companyName)")
        }

        if let txPowerLevel {
            details.append("TX Power: \(txPowerLevel)")
        }

        if let manufacturerDataHex, !manufacturerDataHex.isEmpty {
            details.append("Mfr: \(manufacturerDataHex)")
        }

        return details
    }

    var proximityLabel: String {
        // RSSI is not true distance, but it is still useful as an approximate
        // "near vs far" signal for the user.
        switch rssi {
        case -55 ... 0:
            return "Very Near"
        case -65 ..< -55:
            return "Nearest"
        case -75 ..< -65:
            return "Medium"
        default:
            return "Far"
        }
    }
}

extension Data {
    var shortHexString: String {
        // Converts binary bytes into a short hex preview such as FEEA2008B911003B.
        // This is handy for logs and debugging proprietary characteristics.
        map { String(format: "%02X", $0) }
            .prefix(16)
            .joined()
    }
}

extension Array {
    func chunked(into size: Int) -> [[Element]] {
        // Breaks an array into equally sized groups.
        // We use this mostly to display vendor packets in cleaner byte pairs.
        guard size > 0 else { return [] }

        var chunks: [[Element]] = []
        chunks.reserveCapacity((count + size - 1) / size)

        var index = startIndex
        while index < endIndex {
            let nextIndex = self.index(index, offsetBy: size, limitedBy: endIndex) ?? endIndex
            chunks.append(Array(self[index ..< nextIndex]))
            index = nextIndex
        }

        return chunks
    }
}

// A UI-friendly version of a BLE characteristic.
// It stores only the strings the detail screen needs to display.
struct GATTCharacteristicInfo: Identifiable {
    let id = UUID()
    let uuid: String
    let properties: String
    let valueDescription: String?
}

// A UI-friendly version of a BLE service.
struct GATTServiceInfo: Identifiable {
    let id = UUID()
    let uuid: String
    let characteristics: [GATTCharacteristicInfo]
}

// Standard heart-rate reading decoded from BLE Heart Rate Measurement (2A37).
struct HeartRateReading {
    let bpm: Int
    let sensorContactDetected: Bool?
    let energyExpended: Int?
    let rrIntervals: [Double]
}

// Standard blood-pressure reading decoded from a public BLE blood-pressure characteristic.
struct BloodPressureReading {
    let systolic: Double
    let diastolic: Double
    let meanArterialPressure: Double
}

// Blood-pressure reading inferred from GOBOULT's proprietary FEE3 packets.
struct VendorBloodPressureReading {
    let systolic: Int
    let diastolic: Int
    let sourceUUID: String
    let isExperimental: Bool
}

// Standard oxygen-saturation reading decoded from a public BLE pulse-oximeter characteristic.
struct OxygenSaturationReading {
    let spo2: Double
    let pulseRate: Double?
}

// Oxygen-saturation reading inferred from GOBOULT's proprietary FEE3 packets.
struct VendorOxygenSaturationReading {
    let spo2: Int
    let sourceUUID: String
    let isExperimental: Bool
}

// Generic "stress-like" reading inferred from non-standard characteristics.
struct StressReading {
    let score: Int
    let sourceUUID: String
    let isExperimental: Bool
}

// Stress reading specifically decoded from GOBOULT FEE3 packets.
struct VendorStressReading {
    let score: Int
    let sourceUUID: String
    let isExperimental: Bool
}

// Temporary exploratory bucket for private/vendor characteristics.
// We used this while observing which raw values changed when a measurement
// was triggered on the watch.
struct VendorHealthMetricCandidate: Identifiable {
    let id = UUID()
    let sourceUUID: String
    let label: String
    let valueSummary: String
    let isExperimental: Bool
    let updateCount: Int
    let recentValueSummaries: [String]
}

// All currently decoded values for the connected device.
// Keeping them in one structure makes it easy to reset the screen when
// the connection changes and easy to pass the whole metric state around.
struct HealthMetricsState {
    var batteryLevel: Int?
    var heartRateReading: HeartRateReading?
    var bloodPressureReading: BloodPressureReading?
    var vendorBloodPressureReading: VendorBloodPressureReading?
    var oxygenSaturationReading: OxygenSaturationReading?
    var vendorOxygenSaturationReading: VendorOxygenSaturationReading?
    var stressReading: StressReading?
    var vendorStressReading: VendorStressReading?
    var vendorHealthCandidates: [VendorHealthMetricCandidate] = []

    mutating func reset() {
        // Called when connection state changes so old device data does not leak
        // into the next device's detail screen.
        batteryLevel = nil
        heartRateReading = nil
        bloodPressureReading = nil
        vendorBloodPressureReading = nil
        oxygenSaturationReading = nil
        vendorOxygenSaturationReading = nil
        stressReading = nil
        vendorStressReading = nil
        vendorHealthCandidates = []
    }
}

// Maps manufacturer IDs from advertisement data into readable company names.
// This is helpful when the peripheral does not advertise a friendly device name.
enum BluetoothCompanyIdentifier {
    static func companyName(from manufacturerData: Data?) -> String? {
        guard let manufacturerData, manufacturerData.count >= 2 else { return nil }

        let companyID = UInt16(manufacturerData[0]) | (UInt16(manufacturerData[1]) << 8)

        switch companyID {
        case 0x004C:
            return "Apple"
        case 0x0075:
            return "Samsung Electronics"
        case 0x0006:
            return "Microsoft"
        case 0x000F:
            return "Broadcom"
        case 0x0131:
            return "Google"
        case 0x00E0:
            return "Google / Fitbit"
        case 0x03DA:
            return "Xiaomi"
        default:
            return String(format: "Company ID 0x%04X", companyID)
        }
    }
}

enum DeviceTypeClassifier {
    static func classify(name: String?, advertisementData: [String: Any]) -> DeviceType {
        // This classifier is a best-effort guess based on advertisement name
        // and standard service UUIDs. BLE advertisements are often incomplete,
        // so "unknown" is still a valid and common result.
        let serviceUUIDs = advertisementData[CBAdvertisementDataServiceUUIDsKey] as? [CBUUID] ?? []
        let lowercasedName = name?.lowercased() ?? ""
        let manufacturerData = advertisementData[CBAdvertisementDataManufacturerDataKey] as? Data

        // Samsung watches do not expose one universal watch-specific CBUUID,
        // so the most practical first-pass detection is by advertisement name.
        if lowercasedName.contains("galaxy") || lowercasedName.contains("galaxy fit") || lowercasedName.contains("samsung") {
            return .wearable
        }

        if serviceUUIDs.contains(CBUUID(string: "180D")) || lowercasedName.contains("watch") || lowercasedName.contains("band") || lowercasedName.contains("fit") {
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
        // Beacons often advertise either a known beacon service UUID
        // or a recognizable manufacturer-data layout.
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

// MARK: - BLE decoding
//
// These helpers translate raw characteristic bytes into values that humans can understand.
// For standard UUIDs we follow Bluetooth-defined formats.
// For private GOBOULT UUIDs we use patterns observed during live testing.
enum BLEMetricDecoder {
    static func decodedValueDescription(
        for characteristic: CBCharacteristic,
        metrics: HealthMetricsState,
        bodySensorLocation: String?
    ) -> String? {
        // This helper turns raw BLE values into text that the UI can show directly.
        switch characteristic.uuid.uuidString.uppercased() {
        case "2A37":
            guard let heartRateReading = metrics.heartRateReading else { return nil }
            return "BPM \(heartRateReading.bpm)"
        case "2A38":
            return bodySensorLocation
        case "2A35":
            guard let bloodPressureReading = metrics.bloodPressureReading else { return nil }
            return String(format: "%.0f/%.0f mmHg", bloodPressureReading.systolic, bloodPressureReading.diastolic)
        case "FEE3":
            if let vendorBloodPressureReading = parseVendorBloodPressure(from: characteristic) {
                return "BP \(vendorBloodPressureReading.systolic)/\(vendorBloodPressureReading.diastolic) mmHg"
            }
            if let vendorOxygenSaturationReading = parseVendorOxygenSaturation(from: characteristic) {
                return "SpO2 \(vendorOxygenSaturationReading.spo2)%"
            }
            if let vendorStressReading = parseVendorStress(from: characteristic) {
                return "Stress \(vendorStressReading.score)"
            }
            guard let value = characteristic.value, !value.isEmpty else { return nil }
            return humanReadableVendorPacketSummary(for: value)
        case "2A5E":
            guard let oxygenSaturationReading = metrics.oxygenSaturationReading else { return nil }
            if let pulseRate = oxygenSaturationReading.pulseRate {
                return String(format: "SpO2 %.0f%% • Pulse %.0f", oxygenSaturationReading.spo2, pulseRate)
            }
            return String(format: "SpO2 %.0f%%", oxygenSaturationReading.spo2)
        case "2A19":
            guard let batteryLevel = metrics.batteryLevel else { return nil }
            return "\(batteryLevel)%"
        case "2A25", "2A26", "2A28", "2A29":
            guard let value = characteristic.value,
                  let string = String(data: value, encoding: .utf8)?
                    .trimmingCharacters(in: .controlCharacters),
                  !string.isEmpty else { return nil }
            return string
        default:
            guard let value = characteristic.value, !value.isEmpty else { return nil }
            return value.shortHexString
        }
    }

    static func parseHeartRateMeasurement(from data: Data) -> HeartRateReading? {
        guard !data.isEmpty else { return nil }

        let bytes = [UInt8](data)
        let flags = bytes[0]
        var index = 1

        // The first byte is a bit-mask of flags that tells us how the rest
        // of the payload should be interpreted.
        let isUInt16 = (flags & 0x01) != 0
        let contactSupported = (flags & 0x04) != 0
        let contactDetected = (flags & 0x02) != 0
        let energyPresent = (flags & 0x08) != 0
        let rrPresent = (flags & 0x10) != 0

        let bpm: Int
        if isUInt16 {
            guard bytes.count >= index + 2 else { return nil }
            bpm = Int(UInt16(bytes[index]) | (UInt16(bytes[index + 1]) << 8))
            index += 2
        } else {
            guard bytes.count > index else { return nil }
            bpm = Int(bytes[index])
            index += 1
        }

        var energyExpended: Int?
        if energyPresent {
            guard bytes.count >= index + 2 else { return nil }
            energyExpended = Int(UInt16(bytes[index]) | (UInt16(bytes[index + 1]) << 8))
            index += 2
        }

        var rrIntervals: [Double] = []
        if rrPresent {
            while bytes.count >= index + 2 {
                let raw = UInt16(bytes[index]) | (UInt16(bytes[index + 1]) << 8)
                rrIntervals.append(Double(raw) / 1024.0)
                index += 2
            }
        }

        return HeartRateReading(
            bpm: bpm,
            sensorContactDetected: contactSupported ? contactDetected : nil,
            energyExpended: energyExpended,
            rrIntervals: rrIntervals
        )
    }

    static func parseBodySensorLocation(from data: Data) -> String? {
        guard let value = data.first else { return nil }

        // Standard BLE body-sensor locations defined by the Bluetooth spec.
        switch value {
        case 0: return "Other"
        case 1: return "Chest"
        case 2: return "Wrist"
        case 3: return "Finger"
        case 4: return "Hand"
        case 5: return "Ear Lobe"
        case 6: return "Foot"
        default: return "Unknown (\(value))"
        }
    }

    static func parseBloodPressureMeasurement(from data: Data) -> BloodPressureReading? {
        let bytes = [UInt8](data)
        guard bytes.count >= 7 else { return nil }

        // Standard BLE blood-pressure values are encoded as SFLOAT numbers.
        let systolic = parseSFloat(bytes[1], bytes[2])
        let diastolic = parseSFloat(bytes[3], bytes[4])
        let map = parseSFloat(bytes[5], bytes[6])

        return BloodPressureReading(
            systolic: systolic,
            diastolic: diastolic,
            meanArterialPressure: map
        )
    }

    static func parsePulseOximeterMeasurement(from data: Data) -> OxygenSaturationReading? {
        let bytes = [UInt8](data)
        guard bytes.count >= 5 else { return nil }

        // In the standard format, the payload stores SpO2 first and pulse rate second.
        let spo2 = parseSFloat(bytes[1], bytes[2])
        let pulseRate = parseSFloat(bytes[3], bytes[4])

        return OxygenSaturationReading(
            spo2: spo2,
            pulseRate: pulseRate
        )
    }

    static func parseExperimentalStress(from characteristic: CBCharacteristic) -> StressReading? {
        let uuid = characteristic.uuid.uuidString.uppercased()
        guard ["FEE4", "AE01", "AE02"].contains(uuid),
              let value = characteristic.value,
              let first = value.first else {
            return nil
        }

        // This is a fallback heuristic for non-standard wellness values.
        // It is useful for exploration, but not guaranteed by a public spec.
        return StressReading(
            score: Int(first),
            sourceUUID: uuid,
            isExperimental: true
        )
    }

    static func parseVendorBloodPressure(from characteristic: CBCharacteristic) -> VendorBloodPressureReading? {
        let uuid = characteristic.uuid.uuidString.uppercased()
        guard uuid == "FEE3",
              let value = characteristic.value else {
            return nil
        }

        let bytes = [UInt8](value)
        // Based on observed GOBOULT packets:
        // FE EA 20 08 ... .. SYS DIA
        // where the final two bytes map to systolic / diastolic.
        guard bytes.count >= 8,
              bytes[0] == 0xFE,
              bytes[1] == 0xEA,
              bytes[2] == 0x20,
              bytes[3] == 0x08 else {
            return nil
        }

        let systolic = Int(bytes[6])
        let diastolic = Int(bytes[7])
        guard (70 ... 220).contains(systolic),
              (40 ... 140).contains(diastolic) else {
            return nil
        }

        return VendorBloodPressureReading(
            systolic: systolic,
            diastolic: diastolic,
            sourceUUID: uuid,
            isExperimental: true
        )
    }

    static func parseVendorStress(from characteristic: CBCharacteristic) -> VendorStressReading? {
        let uuid = characteristic.uuid.uuidString.uppercased()
        guard uuid == "FEE3",
              let value = characteristic.value else {
            return nil
        }

        let bytes = [UInt8](value)
        // Observed GOBOULT stress packets share the same vendor header as BP,
        // but use 0x00 in the penultimate byte and the final byte as the score.
        guard bytes.count >= 8,
              bytes[0] == 0xFE,
              bytes[1] == 0xEA,
              bytes[2] == 0x20,
              bytes[3] == 0x08 else {
            return nil
        }

        // Observed GOBOULT stress packets use the 0x08 measurement family,
        // but unlike BP packets the penultimate byte remains 0x00.
        guard bytes[6] == 0x00 else {
            return nil
        }

        let score = Int(bytes[7])
        guard (0 ... 100).contains(score) else {
            return nil
        }

        return VendorStressReading(
            score: score,
            sourceUUID: uuid,
            isExperimental: true
        )
    }

    static func parseVendorOxygenSaturation(from characteristic: CBCharacteristic) -> VendorOxygenSaturationReading? {
        let uuid = characteristic.uuid.uuidString.uppercased()
        guard uuid == "FEE3",
              let value = characteristic.value else {
            return nil
        }

        let bytes = [UInt8](value)
        // Observed GOBOULT SpO2 packets use the shorter:
        // FE EA 20 06 xx SpO2
        guard bytes.count >= 6,
              bytes[0] == 0xFE,
              bytes[1] == 0xEA,
              bytes[2] == 0x20,
              bytes[3] == 0x06 else {
            return nil
        }

        let spo2 = Int(bytes[5])
        guard (70 ... 100).contains(spo2) else {
            return nil
        }

        return VendorOxygenSaturationReading(
            spo2: spo2,
            sourceUUID: uuid,
            isExperimental: true
        )
    }

    static func updateVendorHealthCandidate(
        existing: [VendorHealthMetricCandidate],
        characteristic: CBCharacteristic
    ) -> [VendorHealthMetricCandidate] {
        // This does not attempt to fully understand a packet.
        // It simply keeps a useful rolling summary of private data streams
        // so we can compare packet changes during reverse engineering.
        let uuid = characteristic.uuid.uuidString.uppercased()
        guard let value = characteristic.value,
              !value.isEmpty,
              isLikelyVendorHealthCharacteristic(uuid) else {
            return existing
        }

        var candidates = existing
        let latestSummary = vendorMetricValueSummary(for: value)
        let label = vendorMetricLabel(for: uuid, value: value)

        if let index = candidates.firstIndex(where: { $0.sourceUUID == uuid }) {
            let current = candidates[index]
            var history = current.recentValueSummaries

            if history.first != latestSummary {
                history.insert(latestSummary, at: 0)
            }

            candidates[index] = VendorHealthMetricCandidate(
                sourceUUID: uuid,
                label: label,
                valueSummary: latestSummary,
                isExperimental: true,
                updateCount: current.updateCount + 1,
                recentValueSummaries: Array(history.prefix(5))
            )
        } else {
            candidates.append(
                VendorHealthMetricCandidate(
                    sourceUUID: uuid,
                    label: label,
                    valueSummary: latestSummary,
                    isExperimental: true,
                    updateCount: 1,
                    recentValueSummaries: [latestSummary]
                )
            )
            candidates.sort { $0.sourceUUID < $1.sourceUUID }
        }

        return candidates
    }

    static func humanReadableVendorPacketSummary(for value: Data) -> String {
        let bytes = [UInt8](value)
        guard bytes.count >= 4 else {
            return "Raw vendor payload • \(value.shortHexString)"
        }

        // This is a debugging helper that explains a vendor packet in a
        // more readable way before we fully understand its meaning.
        let header = String(format: "%02X%02X%02X", bytes[0], bytes[1], bytes[2])
        let packetType = bytes[3]
        let payload = Array(bytes.dropFirst(4))
        let payloadHex = payload.map { String(format: "%02X", $0) }.joined(separator: " ")
        let payloadDecimal = payload.map(String.init).joined(separator: ", ")
        let payloadPairs = payload.chunked(into: 2).map {
            $0.map { String(format: "%02X", $0) }.joined()
        }

        let typeDescription: String
        switch packetType {
        case 0x06:
            typeDescription = "short status packet"
        case 0x08:
            typeDescription = "measurement packet"
        default:
            typeDescription = "vendor packet"
        }

        var hints: [String] = []
        if payload.count >= 2 {
            let firstPairValue = Int(payload[0]) | (payload.count > 1 ? Int(payload[1]) << 8 : 0)
            if (85 ... 220).contains(firstPairValue) {
                hints.append("first pair may be a measured value")
            }
        }
        if packetType == 0x08 && payload.count >= 4 {
            hints.append("longer packet, likely full health measurement")
        }
        if packetType == 0x06 {
            hints.append("shorter packet, likely status or compact metric")
        }

        let hintsText = hints.isEmpty ? "Meaning still unknown" : hints.joined(separator: " • ")
        let pairsText = payloadPairs.isEmpty ? "none" : payloadPairs.joined(separator: ", ")
        let hexText = payloadHex.isEmpty ? "none" : payloadHex
        let decimalText = payloadDecimal.isEmpty ? "none" : payloadDecimal

        return "Header \(header) • Type 0x\(String(format: "%02X", packetType)) (\(typeDescription)) • Payload \(hexText) • Decimal \(decimalText) • Pairs \(pairsText) • \(hintsText)"
    }

    private static func parseSFloat(_ lowerByte: UInt8, _ upperByte: UInt8) -> Double {
        // SFLOAT is a compact BLE numeric format used by several health characteristics.
        // It stores a mantissa and exponent in 16 bits.
        let raw = UInt16(lowerByte) | (UInt16(upperByte) << 8)
        var mantissa = Int16(raw & 0x0FFF)
        let exponentNibble = Int8((raw & 0xF000) >> 12)

        if mantissa >= 0x0800 {
            mantissa = mantissa - 0x1000
        }

        var exponent = exponentNibble
        if exponent >= 0x08 {
            exponent = exponent - 0x10
        }

        return Double(mantissa) * pow(10.0, Double(exponent))
    }

    private static func isLikelyVendorHealthCharacteristic(_ uuid: String) -> Bool {
        // Private UUIDs observed on the watch that may carry health/wellness data.
        [
            "FEE1", "FEE2", "FEE3", "FEE4", "FEE5", "FEE6",
            "FEC9", "FEA1", "0003", "0004", "AE01", "AE02"
        ].contains(uuid)
    }

    private static func vendorMetricLabel(for uuid: String, value: Data) -> String {
        // Best-effort labeling for private characteristics so the raw debug view
        // is easier to interpret during demos and testing.
        if uuid == "FEE3" {
            if let packetType = vendorPacketType(for: value) {
                switch packetType {
                case 0x06:
                    return "Primary vendor health stream • short packet"
                case 0x08:
                    return "Primary vendor health stream • measurement packet"
                default:
                    return "Primary vendor health stream • packet 0x\(String(format: "%02X", packetType))"
                }
            }

            return "Primary vendor health stream"
        }

        if let first = value.first {
            if (85 ... 100).contains(Int(first)) {
                return "Possible SpO2 / wellness score"
            }

            if (40 ... 140).contains(Int(first)) {
                return "Possible pulse / score"
            }
        }

        if value.count >= 2 {
            let bytes = [UInt8](value)
            let low = Int(bytes[0])
            let high = Int(bytes[1])

            if (80 ... 180).contains(low), (50 ... 120).contains(high) {
                return "Possible blood pressure payload"
            }
        }

        switch uuid {
        case "AE01", "AE02":
            return "Vendor wellness metric"
        case "FEE4", "FEE5", "FEE6":
            return "Vendor live sensor data"
        default:
            return "Vendor health candidate"
        }
    }

    private static func vendorMetricValueSummary(for value: Data) -> String {
        // Produces a compact readable summary from raw private bytes.
        if looksLikeVendorHealthPacket(value) {
            return humanReadableVendorPacketSummary(for: value)
        }

        let bytes = [UInt8](value)
        let decimalPreview = bytes.prefix(6).map(String.init).joined(separator: ", ")

        if value.count >= 2 {
            let pairPreview = Array(bytes.prefix(6))
                .chunked(into: 2)
                .map { chunk in
                    chunk.map(String.init).joined(separator: "/")
                }
                .joined(separator: " • ")

            return "\(value.shortHexString) (\(decimalPreview)) • pairs \(pairPreview)"
        }

        return "\(value.shortHexString) (\(decimalPreview))"
    }

    private static func looksLikeVendorHealthPacket(_ value: Data) -> Bool {
        // The GOBOULT health packets we observed all started with FE EA 20.
        let bytes = [UInt8](value)
        return bytes.count >= 4 && bytes[0] == 0xFE && bytes[1] == 0xEA && bytes[2] == 0x20
    }

    private static func vendorPacketType(for value: Data) -> UInt8? {
        // The fourth byte has been useful for splitting packet families
        // such as "short status packet" and "measurement packet".
        let bytes = [UInt8](value)
        guard bytes.count >= 4 else { return nil }
        return bytes[3]
    }
}
