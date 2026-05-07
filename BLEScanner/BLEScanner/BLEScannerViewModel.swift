import CoreBluetooth
import Foundation
import SwiftUI

final class BLEScannerViewModel: NSObject, ObservableObject {
    @Published var devices: [ScannedDevice] = []
    @Published var enabledDeviceTypes: Set<DeviceType> = Set(DeviceType.allCases)
    @Published var minimumRSSI: Double = -80
    @Published var isScanning = false
    @Published var bluetoothState: CBManagerState = .unknown
    @Published var connectedDeviceID: UUID?

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
            .filter { enabledDeviceTypes.contains($0.type) && Double($0.rssi) >= minimumRSSI }
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

    func actionTitle(for device: ScannedDevice) -> String {
        switch device.connectionState {
        case .connected:
            return "Disconnect"
        case .connecting:
            return "Connecting..."
        case .failed:
            return "Retry Connect"
        case .disconnected:
            return "Connect"
        }
    }

    func handleTap(on device: ScannedDevice) {
        guard let peripheral = peripheralsByID[device.id] else { return }

        switch device.connectionState {
        case .connected:
            centralManager.cancelPeripheralConnection(peripheral)
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
        let manufacturerDataHex = (advertisementData[CBAdvertisementDataManufacturerDataKey] as? Data)?.shortHexString
        let device = ScannedDevice(
            id: peripheral.identifier,
            name: peripheral.name ?? (advertisementData[CBAdvertisementDataLocalNameKey] as? String),
            rssi: RSSI.intValue,
            type: deviceType,
            isConnectable: connectable,
            serviceUUIDs: serviceUUIDs,
            manufacturerDataHex: manufacturerDataHex,
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
    }
}

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

extension BLEScannerViewModel: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {}
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
                manufacturerDataHex: nil,
                connectionState: .connected
            ),
            ScannedDevice(
                id: UUID(),
                name: "Beacon Lobby",
                rssi: -68,
                type: .beacon,
                isConnectable: false,
                serviceUUIDs: ["FEAA"],
                manufacturerDataHex: "4C000215AABBCCDD",
                connectionState: .disconnected
            ),
            ScannedDevice(
                id: UUID(),
                name: "Temp Sensor",
                rssi: -71,
                type: .sensor,
                isConnectable: true,
                serviceUUIDs: ["181A"],
                manufacturerDataHex: nil,
                connectionState: .disconnected
            )
        ]
        return model
    }
}
