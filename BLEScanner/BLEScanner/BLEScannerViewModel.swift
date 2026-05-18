//
//  BLEScannerViewModel.swift
//  BLEScanner
//
//  Created by Shikha Sharma on 20/04/26.
//

import CoreBluetooth
import Foundation
import SwiftUI

@MainActor
final class BLEScannerViewModel: NSObject, ObservableObject {
    @Published private(set) var devices: [ScannedDevice] = []
    @Published var enabledDeviceTypes: Set<DeviceType> = Set(DeviceType.allCases)
    @Published var minimumRSSI: Double = -80
    @Published private(set) var isScanning = false
    @Published private(set) var bluetoothState: CBManagerState = .unknown
    @Published private(set) var connectedDeviceID: UUID?
    @Published private(set) var discoveredServices: [GATTServiceInfo] = []
    @Published var showRawDebugMode = true
    @Published private(set) var bodySensorLocation: String?
    @Published private(set) var healthMetrics = HealthMetricsState()

    private var centralManager: CBCentralManager!
    private var peripheralsByID: [UUID: CBPeripheral] = [:]

    override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: .main)
    }

    var canScan: Bool {
        bluetoothState == .poweredOn
    }

    var bluetoothStateText: String {
        switch bluetoothState {
        case .poweredOn:
            return isScanning ? "Scanning Active" : "Bluetooth Ready"
        case .poweredOff:
            return "Bluetooth Off"
        case .unsupported:
            return "BLE Unsupported"
        case .unauthorized:
            return "Bluetooth Not Authorized"
        case .resetting:
            return "Bluetooth Resetting"
        case .unknown:
            return "Checking Bluetooth"
        @unknown default:
            return "Bluetooth Unavailable"
        }
    }

    var bluetoothStateIcon: String {
        canScan ? "bolt.horizontal.circle.fill" : "bolt.horizontal.circle"
    }

    var bluetoothStateColor: Color {
        canScan ? .green : .orange
    }

    var currentRangeLabel: String {
        let threshold = Int(minimumRSSI)
        switch threshold {
        case -55 ... 0:
            return "Very Near • RSSI > \(threshold) dBm"
        case -65 ..< -55:
            return "Near • RSSI > \(threshold) dBm"
        case -75 ..< -65:
            return "Medium • RSSI > \(threshold) dBm"
        default:
            return "Far • RSSI > \(threshold) dBm"
        }
    }

    var filteredDevices: [ScannedDevice] {
        devices
            .filter {
                let matchesType = showRawDebugMode ? true : enabledDeviceTypes.contains($0.type)
                return matchesType && Double($0.rssi) >= minimumRSSI
            }
            .sorted { lhs, rhs in
                if lhs.rssi == rhs.rssi {
                    return lhs.displayName < rhs.displayName
                }
                return lhs.rssi > rhs.rssi
            }
    }

    func startScanningIfPossible() {
        guard canScan, !isScanning else { return }
        startScan()
    }

    func toggleScan() {
        isScanning ? stopScan() : startScan()
    }

    func toggleDeviceType(_ type: DeviceType) {
        if enabledDeviceTypes.contains(type) {
            enabledDeviceTypes.remove(type)
        } else {
            enabledDeviceTypes.insert(type)
        }
    }

    func toggleRawDebugMode() {
        showRawDebugMode.toggle()
    }

    func actionTitle(for device: ScannedDevice) -> String {
        switch device.connectionState {
        case .connected:
            return "View Details"
        case .connecting:
            return "Connecting..."
        case .failed:
            return "Retry Connect"
        case .disconnected:
            return "Connect"
        }
    }

    var connectedDeviceName: String? {
        guard let connectedDeviceID,
              let device = devices.first(where: { $0.id == connectedDeviceID }) else {
            return nil
        }

        return device.displayName
    }

    func device(for id: UUID) -> ScannedDevice? {
        devices.first(where: { $0.id == id })
    }

    var batteryLevel: Int? { healthMetrics.batteryLevel }
    var heartRateReading: HeartRateReading? { healthMetrics.heartRateReading }
    var bloodPressureReading: BloodPressureReading? { healthMetrics.bloodPressureReading }
    var vendorBloodPressureReading: VendorBloodPressureReading? { healthMetrics.vendorBloodPressureReading }
    var oxygenSaturationReading: OxygenSaturationReading? { healthMetrics.oxygenSaturationReading }
    var vendorOxygenSaturationReading: VendorOxygenSaturationReading? { healthMetrics.vendorOxygenSaturationReading }
    var stressReading: StressReading? { healthMetrics.stressReading }
    var vendorStressReading: VendorStressReading? { healthMetrics.vendorStressReading }
    var vendorHealthCandidates: [VendorHealthMetricCandidate] { healthMetrics.vendorHealthCandidates }

    func handleTap(on device: ScannedDevice) {
        guard let peripheral = peripheralsByID[device.id] else { return }

        switch device.connectionState {
        case .connected:
            break
        case .connecting:
            break
        case .disconnected, .failed:
            connect(to: peripheral)
        }
    }

    private func startScan() {
        guard canScan else { return }
        centralManager.scanForPeripherals(withServices: nil, options: [CBCentralManagerScanOptionAllowDuplicatesKey: true])
        isScanning = true
    }

    private func stopScan() {
        centralManager.stopScan()
        isScanning = false
    }

    private func connect(to peripheral: CBPeripheral) {
        if isScanning {
            stopScan()
        }

        resetConnectionData()
        updateConnectionState(.connecting, for: peripheral.identifier)
        peripheral.delegate = self
        centralManager.connect(peripheral, options: nil)
    }

    private func updateDiscoveredDevice(
        peripheral: CBPeripheral,
        advertisementData: [String: Any],
        rssi RSSI: NSNumber
    ) {
        let deviceType = DeviceTypeClassifier.classify(
            name: peripheral.name ?? (advertisementData[CBAdvertisementDataLocalNameKey] as? String),
            advertisementData: advertisementData
        )

        let index = devices.firstIndex(where: { $0.id == peripheral.identifier })
        let currentState = index.map { devices[$0].connectionState } ?? .disconnected
        let connectable = (advertisementData[CBAdvertisementDataIsConnectable] as? Bool) ?? true
        let serviceUUIDs = (advertisementData[CBAdvertisementDataServiceUUIDsKey] as? [CBUUID] ?? []).map(\.uuidString)
        let solicitationUUIDs = (advertisementData[CBAdvertisementDataSolicitedServiceUUIDsKey] as? [CBUUID] ?? []).map(\.uuidString)
        let overflowServiceUUIDs = (advertisementData[CBAdvertisementDataOverflowServiceUUIDsKey] as? [CBUUID] ?? []).map(\.uuidString)
        let manufacturerData = advertisementData[CBAdvertisementDataManufacturerDataKey] as? Data
        let manufacturerDataHex = manufacturerData?.shortHexString
        let companyName = BluetoothCompanyIdentifier.companyName(from: manufacturerData)
        let localName = advertisementData[CBAdvertisementDataLocalNameKey] as? String
        let txPowerLevel = advertisementData[CBAdvertisementDataTxPowerLevelKey] as? Int
        let device = ScannedDevice(
            id: peripheral.identifier,
            name: peripheral.name ?? localName,
            rssi: RSSI.intValue,
            type: deviceType,
            isConnectable: connectable,
            serviceUUIDs: serviceUUIDs,
            localName: localName,
            companyName: companyName,
            manufacturerDataHex: manufacturerDataHex,
            txPowerLevel: txPowerLevel,
            solicitationUUIDs: solicitationUUIDs,
            overflowServiceUUIDs: overflowServiceUUIDs,
            connectionState: currentState
        )

        peripheralsByID[peripheral.identifier] = peripheral

        if let index {
            devices[index] = device
        } else {
            devices.append(device)
        }
    }

    private func updateConnectionState(_ state: DeviceConnectionState, for deviceID: UUID) {
        guard let index = devices.firstIndex(where: { $0.id == deviceID }) else { return }
        devices[index].connectionState = state
        connectedDeviceID = state == .connected ? deviceID : (connectedDeviceID == deviceID ? nil : connectedDeviceID)
        if state != .connected {
            resetConnectionData()
        }
    }

    private func resetConnectionData() {
        discoveredServices = []
        bodySensorLocation = nil
        healthMetrics.reset()
    }

    private func refreshDiscoveredServices(from peripheral: CBPeripheral) {
        guard let services = peripheral.services else { return }

        discoveredServices = services.map { service in
            let characteristics = (service.characteristics ?? []).map { characteristic in
                GATTCharacteristicInfo(
                    uuid: characteristic.uuid.uuidString,
                    properties: characteristic.properties.displayText,
                    valueDescription: BLEMetricDecoder.decodedValueDescription(
                        for: characteristic,
                        metrics: healthMetrics,
                        bodySensorLocation: bodySensorLocation
                    )
                )
            }

            return GATTServiceInfo(
                uuid: service.uuid.uuidString,
                characteristics: characteristics
            )
        }
    }

    private func logCharacteristicEvent(_ event: String, characteristic: CBCharacteristic) {
        let uuid = characteristic.uuid.uuidString.uppercased()
        let serviceUUID = characteristic.service?.uuid.uuidString.uppercased() ?? "UnknownService"
        let hexValue = characteristic.value?.shortHexString ?? "nil"
        let decodedValue = BLEMetricDecoder.decodedValueDescription(
            for: characteristic,
            metrics: healthMetrics,
            bodySensorLocation: bodySensorLocation
        ) ?? "n/a"

        print("[BLE] \(event) service=\(serviceUUID) characteristic=\(uuid) hex=\(hexValue) decoded=\(decodedValue)")
    }
}

@MainActor
extension BLEScannerViewModel: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        bluetoothState = central.state
        if central.state == .poweredOn {
            startScanningIfPossible()
        } else {
            stopScan()
        }
    }

    func centralManager(
        _ central: CBCentralManager,
        didDiscover peripheral: CBPeripheral,
        advertisementData: [String: Any],
        rssi RSSI: NSNumber
    ) {
        updateDiscoveredDevice(peripheral: peripheral, advertisementData: advertisementData, rssi: RSSI)
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        connectedDeviceID = peripheral.identifier
        updateConnectionState(.connected, for: peripheral.identifier)
        peripheral.discoverServices(nil)
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        updateConnectionState(.failed, for: peripheral.identifier)
        startScanningIfPossible()
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        updateConnectionState(.disconnected, for: peripheral.identifier)
        startScanningIfPossible()
    }
}

@MainActor
extension BLEScannerViewModel: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard error == nil else { return }
        peripheral.services?.forEach { peripheral.discoverCharacteristics(nil, for: $0) }
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard error == nil else { return }
        service.characteristics?.forEach { characteristic in
            if characteristic.properties.contains(.notify) || characteristic.properties.contains(.indicate) {
                print("[BLE] Subscribing to \(characteristic.uuid.uuidString.uppercased()) on service \(service.uuid.uuidString.uppercased())")
                peripheral.setNotifyValue(true, for: characteristic)
            }

            if characteristic.properties.contains(.read) {
                print("[BLE] Reading \(characteristic.uuid.uuidString.uppercased()) on service \(service.uuid.uuidString.uppercased())")
                peripheral.readValue(for: characteristic)
            }
        }

        refreshDiscoveredServices(from: peripheral)
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard error == nil else { return }

        switch characteristic.uuid.uuidString.uppercased() {
        case "2A37":
            if let value = characteristic.value {
                healthMetrics.heartRateReading = BLEMetricDecoder.parseHeartRateMeasurement(from: value)
            }
        case "2A38":
            if let value = characteristic.value {
                bodySensorLocation = BLEMetricDecoder.parseBodySensorLocation(from: value)
            }
        case "2A35":
            if let value = characteristic.value {
                healthMetrics.bloodPressureReading = BLEMetricDecoder.parseBloodPressureMeasurement(from: value)
            }
        case "2A5E":
            if let value = characteristic.value {
                healthMetrics.oxygenSaturationReading = BLEMetricDecoder.parsePulseOximeterMeasurement(from: value)
            }
        case "2A19":
            if let value = characteristic.value?.first {
                healthMetrics.batteryLevel = Int(value)
            }
        default:
            healthMetrics.stressReading = BLEMetricDecoder.parseExperimentalStress(from: characteristic)
        }

        if let vendorBloodPressureReading = BLEMetricDecoder.parseVendorBloodPressure(from: characteristic) {
            healthMetrics.vendorBloodPressureReading = vendorBloodPressureReading
        }

        if let vendorOxygenSaturationReading = BLEMetricDecoder.parseVendorOxygenSaturation(from: characteristic) {
            healthMetrics.vendorOxygenSaturationReading = vendorOxygenSaturationReading
        }

        if let vendorStressReading = BLEMetricDecoder.parseVendorStress(from: characteristic) {
            healthMetrics.vendorStressReading = vendorStressReading
        }

        healthMetrics.vendorHealthCandidates = BLEMetricDecoder.updateVendorHealthCandidate(
            existing: healthMetrics.vendorHealthCandidates,
            characteristic: characteristic
        )
        logCharacteristicEvent("Updated", characteristic: characteristic)
        refreshDiscoveredServices(from: peripheral)
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        if let error {
            print("[BLE] Notify state failed for \(characteristic.uuid.uuidString.uppercased()): \(error.localizedDescription)")
            return
        }

        let state = characteristic.isNotifying ? "enabled" : "disabled"
        print("[BLE] Notifications \(state) for \(characteristic.uuid.uuidString.uppercased())")
    }
}

extension BLEScannerViewModel {
    static var preview: BLEScannerViewModel {
        let model = BLEScannerViewModel()
        model.bluetoothState = .poweredOn
        model.isScanning = true
        model.minimumRSSI = -75
        model.devices = [
            ScannedDevice(
                id: UUID(),
                name: "HRM Strap",
                rssi: -52,
                type: .wearable,
                isConnectable: true,
                serviceUUIDs: ["180D"],
                localName: "HRM Strap",
                companyName: "Samsung Electronics",
                manufacturerDataHex: nil,
                txPowerLevel: -4,
                solicitationUUIDs: [],
                overflowServiceUUIDs: [],
                connectionState: .connected
            ),
            ScannedDevice(
                id: UUID(),
                name: "Beacon Lobby",
                rssi: -68,
                type: .beacon,
                isConnectable: false,
                serviceUUIDs: ["FEAA"],
                localName: "Beacon Lobby",
                companyName: "Apple",
                manufacturerDataHex: "4C000215AABBCCDD",
                txPowerLevel: nil,
                solicitationUUIDs: [],
                overflowServiceUUIDs: [],
                connectionState: .disconnected
            ),
            ScannedDevice(
                id: UUID(),
                name: "Temp Sensor",
                rssi: -71,
                type: .sensor,
                isConnectable: true,
                serviceUUIDs: ["181A"],
                localName: nil,
                companyName: nil,
                manufacturerDataHex: nil,
                txPowerLevel: -8,
                solicitationUUIDs: [],
                overflowServiceUUIDs: [],
                connectionState: .disconnected
            )
        ]
        model.connectedDeviceID = model.devices.first?.id
        model.discoveredServices = [
            GATTServiceInfo(
                uuid: "180D",
                characteristics: [
                    GATTCharacteristicInfo(uuid: "2A37", properties: "notify", valueDescription: "BPM 76"),
                    GATTCharacteristicInfo(uuid: "2A38", properties: "read", valueDescription: "Wrist")
                ]
            ),
            GATTServiceInfo(
                uuid: "180F",
                characteristics: [
                    GATTCharacteristicInfo(uuid: "2A19", properties: "read, notify", valueDescription: "87%")
                ]
            )
        ]
        model.healthMetrics.batteryLevel = 87
        model.healthMetrics.heartRateReading = HeartRateReading(
            bpm: 76,
            sensorContactDetected: true,
            energyExpended: nil,
            rrIntervals: [0.82, 0.79]
        )
        model.bodySensorLocation = "Wrist"
        model.healthMetrics.bloodPressureReading = BloodPressureReading(
            systolic: 120,
            diastolic: 80,
            meanArterialPressure: 93
        )
        model.healthMetrics.vendorBloodPressureReading = VendorBloodPressureReading(
            systolic: 115,
            diastolic: 81,
            sourceUUID: "FEE3",
            isExperimental: true
        )
        model.healthMetrics.oxygenSaturationReading = OxygenSaturationReading(
            spo2: 98,
            pulseRate: 76
        )
        model.healthMetrics.vendorOxygenSaturationReading = VendorOxygenSaturationReading(
            spo2: 99,
            sourceUUID: "FEE3",
            isExperimental: true
        )
        model.healthMetrics.stressReading = StressReading(
            score: 42,
            sourceUUID: "AE01",
            isExperimental: true
        )
        model.healthMetrics.vendorStressReading = VendorStressReading(
            score: 59,
            sourceUUID: "FEE3",
            isExperimental: true
        )
        model.healthMetrics.vendorHealthCandidates = [
            VendorHealthMetricCandidate(
                sourceUUID: "AE01",
                label: "Vendor wellness metric",
                valueSummary: "2A000100 (42, 0, 1, 0)",
                isExperimental: true,
                updateCount: 3,
                recentValueSummaries: [
                    "2A000100 (42, 0, 1, 0)",
                    "28000100 (40, 0, 1, 0)"
                ]
            ),
            VendorHealthMetricCandidate(
                sourceUUID: "FEE3",
                label: "Primary vendor health stream",
                valueSummary: "62004B00 (98, 0, 75, 0)",
                isExperimental: true,
                updateCount: 7,
                recentValueSummaries: [
                    "62004B00 (98, 0, 75, 0)",
                    "78005000 (120, 0, 80, 0)",
                    "2A000000 (42, 0, 0, 0)"
                ]
            )
        ]
        return model
    }
}

private extension CBCharacteristicProperties {
    var displayText: String {
        var parts: [String] = []
        if contains(.read) { parts.append("read") }
        if contains(.write) { parts.append("write") }
        if contains(.writeWithoutResponse) { parts.append("writeNoRsp") }
        if contains(.notify) { parts.append("notify") }
        if contains(.indicate) { parts.append("indicate") }
        if contains(.broadcast) { parts.append("broadcast") }
        return parts.isEmpty ? "none" : parts.joined(separator: ", ")
    }
}
