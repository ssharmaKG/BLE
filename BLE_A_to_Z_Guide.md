# BLE A-Z Guide

## 1. What is BLE?

BLE stands for **Bluetooth Low Energy**.

It is a wireless communication technology designed for:
- low power consumption
- short-range communication
- periodic data exchange
- battery-powered devices

BLE is part of the Bluetooth family, but it is different from classic Bluetooth.

Classic Bluetooth is commonly used for:
- continuous audio streaming
- keyboards
- mouse
- other wireless accessories

BLE is commonly used for:
- smartwatches
- fitness bands
- heart-rate monitors
- smart locks
- beacons
- health devices
- IoT sensors

The core idea of BLE is:

**send useful data while consuming as little battery as possible**

---

## 2. Why is BLE used?

BLE is used because many modern devices need to:
- stay connected for long periods
- run on small batteries
- send small packets of data
- wake up quickly
- communicate efficiently with phones, tablets, and embedded devices

Examples:
- a fitness band sending heart-rate values
- a smart lock receiving unlock commands
- a beacon broadcasting presence
- a temperature sensor sending readings every few seconds

If these devices used heavier communication methods all the time, battery life would drop quickly.

---

## 3. Main features of BLE

BLE provides:

### Low power usage
- best feature of BLE
- ideal for battery-operated devices
- devices can run for months or years depending on usage

### Fast discovery
- devices can advertise themselves quickly
- phones can scan and find nearby BLE peripherals

### Short-range communication
- works well for nearby devices
- exact range depends on environment, hardware, and signal conditions

### Standardized profiles
- many common use cases already have standard services and characteristics
- example: heart rate, battery, device information

### Small data packets
- optimized for compact data exchange instead of heavy streaming

### Broad ecosystem support
- supported on iPhone, Android, watches, tablets, laptops, and embedded boards

### Client-server style communication
- one device exposes data
- another device discovers, connects, reads, writes, or subscribes

---

## 4. Where BLE is used

BLE is used in many categories:

### Wearables
- smartwatches
- fitness bands
- smart rings

### Health and medical
- heart-rate monitors
- blood pressure monitors
- pulse oximeters
- glucose devices

### Smart home
- locks
- bulbs
- sensors
- tags

### Industrial and IoT
- temperature sensors
- humidity sensors
- tracking devices
- gateways

### Retail and location
- beacons
- proximity devices
- footfall tracking

### Consumer electronics
- remotes
- device onboarding tools

---

## 5. Core BLE concepts

To understand BLE properly, these are the most important concepts.

### 5.1 Central and Peripheral

BLE usually works between:

- **Central**
  - the device that scans and connects
  - example: iPhone app

- **Peripheral**
  - the device that advertises data and accepts connection
  - example: smartwatch, sensor, beacon

In our project:
- **iPhone app = Central**
- **watch / BLE device = Peripheral**

Code in our project:

```swift
@MainActor
final class BLEScannerViewModel: NSObject, ObservableObject {
    private var centralManager: CBCentralManager!
    private var peripheralsByID: [UUID: CBPeripheral] = [:]

    override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: .main)
    }
}
```

This shows the phone-side app acting as the BLE central, while discovered devices are represented as `CBPeripheral`.

---

### 5.2 Advertising

Advertising means a BLE peripheral is broadcasting small packets so nearby central devices can discover it.

Advertisement data may include:
- local name
- service UUIDs
- manufacturer data
- connectable flag
- TX power

Important:
- not every device advertises a readable name
- some devices appear as unnamed
- some devices advertise only limited information

Code in our project:

```swift
let connectable = (advertisementData[CBAdvertisementDataIsConnectable] as? Bool) ?? true
let serviceUUIDs = (advertisementData[CBAdvertisementDataServiceUUIDsKey] as? [CBUUID] ?? []).map(\.uuidString)
let manufacturerData = advertisementData[CBAdvertisementDataManufacturerDataKey] as? Data
let localName = advertisementData[CBAdvertisementDataLocalNameKey] as? String
let txPowerLevel = advertisementData[CBAdvertisementDataTxPowerLevelKey] as? Int
```

This is how we extract advertisement information while scanning.

---

### 5.3 Scanning

Scanning means the central device listens for nearby BLE advertisements.

In our app:
- the phone scans nearby BLE devices
- discovered devices are shown in the list
- we filter them by type and RSSI

Code in our project:

```swift
private func startScan() {
    guard canScan else { return }
    centralManager.scanForPeripherals(
        withServices: nil,
        options: [CBCentralManagerScanOptionAllowDuplicatesKey: true]
    )
    isScanning = true
}
```

And the discovery callback:

```swift
func centralManager(
    _ central: CBCentralManager,
    didDiscover peripheral: CBPeripheral,
    advertisementData: [String: Any],
    rssi RSSI: NSNumber
) {
    updateDiscoveredDevice(peripheral: peripheral, advertisementData: advertisementData, rssi: RSSI)
}
```

---

### 5.4 RSSI

RSSI means **Received Signal Strength Indicator**.

It is shown in **dBm**.

Examples:
- `-45 dBm` = very strong / very near
- `-65 dBm` = moderate / near
- `-85 dBm` = weak / farther

Important:
- RSSI is not exact distance
- it changes because of walls, body position, interference, and orientation

In our app:
- we use RSSI as a range filter

Code in our project:

```swift
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
```

---

### 5.5 GATT

GATT stands for **Generic Attribute Profile**.

It defines how BLE data is organized and exchanged after connection.

You can think of GATT as the structured data model of BLE.

GATT is built around:
- services
- characteristics
- descriptors

---

### 5.6 Services

A **service** is a group of related functionality.

Examples:
- `180D` = Heart Rate Service
- `180F` = Battery Service
- `180A` = Device Information Service

A service answers:

**what kind of capability does this device expose?**

---

### 5.7 Characteristics

A **characteristic** is an individual data point or operation inside a service.

Examples:
- `2A37` = Heart Rate Measurement
- `2A19` = Battery Level
- `2A29` = Manufacturer Name

A characteristic answers:

**what exact value can I read, write, or subscribe to?**

---

### 5.8 Descriptors

Descriptors add metadata or behavior around a characteristic.

Example:
- enabling notifications often uses descriptor-related configuration under the hood

For beginner BLE understanding, services and characteristics matter most.

---

### 5.9 UUIDs

BLE uses **UUIDs** to identify services and characteristics.

Examples:
- service `180D`
- characteristic `2A37`

There are two types:

### Standard UUIDs
- defined by Bluetooth SIG
- same meaning across many devices

Examples:
- `180D` = Heart Rate
- `180F` = Battery
- `180A` = Device Info

### Vendor / proprietary UUIDs
- defined by device manufacturers
- meaning is not public unless documented

Examples from our watch:
- `FEEA`
- `FEE3`
- `AE00`

These often require reverse engineering or vendor documentation.

Code in our project:

```swift
switch characteristic.uuid.uuidString.uppercased() {
case "2A37":
    guard let heartRateReading = metrics.heartRateReading else { return nil }
    return "BPM \(heartRateReading.bpm)"
case "FEE3":
    if let vendorBloodPressureReading = metrics.vendorBloodPressureReading {
        return "BP \(vendorBloodPressureReading.systolic)/\(vendorBloodPressureReading.diastolic) mmHg"
    }
    if let vendorOxygenSaturationReading = metrics.vendorOxygenSaturationReading {
        return "SpO2 \(vendorOxygenSaturationReading.spo2)%"
    }
    return humanReadableVendorPacketSummary(for: value)
default:
    return nil
}
```

This is the exact place where standard and vendor UUIDs are treated differently.

---

## 6. Read, Write, Notify, Indicate

Characteristics have properties.

The most important ones are:

### Read
- app can request the value
- example: battery level

### Write
- app can send a value/command
- example: command to configure a device

### Notify
- device pushes updates automatically
- example: live heart-rate updates

### Indicate
- similar to notify, but acknowledged more formally

In our app:
- we read readable characteristics
- we subscribe to notify/indicate characteristics

Code in our project:

```swift
service.characteristics?.forEach { characteristic in
    if characteristic.properties.contains(.notify) || characteristic.properties.contains(.indicate) {
        peripheral.setNotifyValue(true, for: characteristic)
    }

    if characteristic.properties.contains(.read) {
        peripheral.readValue(for: characteristic)
    }
}
```

---

## 7. Standard BLE services we used

In our project, the watch exposed some standard services:

### `180D` Heart Rate Service
Used for heart-related measurement data.

Related characteristic:
- `2A37` = Heart Rate Measurement

### `180F` Battery Service
Used to expose battery level.

Related characteristic:
- `2A19` = Battery Level

### `180A` Device Information Service
Used to expose metadata about the device.

Common characteristics:
- `2A25` = Serial Number
- `2A26` = Firmware Revision
- `2A28` = Software Revision
- `2A29` = Manufacturer Name

Code in our project:

```swift
case "2A37":
    if let value = characteristic.value {
        healthMetrics.heartRateReading = BLEMetricDecoder.parseHeartRateMeasurement(from: value)
    }
case "2A19":
    if let value = characteristic.value {
        healthMetrics.batteryLevel = BLEMetricDecoder.parseBatteryLevel(from: value)
    }
```

---

## 8. Proprietary BLE data

Not everything in BLE is standard.

Manufacturers often create custom services and characteristics for:
- private health metrics
- device settings
- advanced syncing
- ecosystem-specific behaviors

In our GOBOULT watch case:
- standard heart rate was exposed through standard BLE
- blood pressure, stress, and SpO2 came through vendor packets on `FEE3`

That means:
- BLE transport is public
- but the meaning of the payload is vendor-defined

This is very common in wearables.

Code in our project:

```swift
static func parseVendorBloodPressure(from characteristic: CBCharacteristic) -> VendorBloodPressureReading? {
    let uuid = characteristic.uuid.uuidString.uppercased()
    guard uuid == "FEE3",
          let value = characteristic.value else {
        return nil
    }

    let bytes = [UInt8](value)
    guard bytes.count >= 8,
          bytes[0] == 0xFE,
          bytes[1] == 0xEA,
          bytes[2] == 0x20,
          bytes[3] == 0x08 else {
        return nil
    }

    return VendorBloodPressureReading(
        systolic: Int(bytes[6]),
        diastolic: Int(bytes[7]),
        sourceUUID: uuid,
        isExperimental: true
    )
}
```

This is a real example of decoding vendor-specific payloads after identifying a pattern in raw bytes.

---

## 9. BLE architecture used in our app

Our app follows this flow:

### Step 1: Scan nearby peripherals
- use CoreBluetooth central manager
- receive advertisements

### Step 2: Build a device list
- show name if available
- show RSSI
- show type
- show manufacturer/service hints

### Step 3: Filter devices
- by type
- by signal strength

### Step 4: Connect to selected device
- establish BLE connection

### Step 5: Discover services
- inspect all GATT services exposed by the peripheral

### Step 6: Discover characteristics
- inspect all characteristics under each service

### Step 7: Read and subscribe
- read readable values
- subscribe to notify/indicate values

### Step 8: Decode metrics
- standard metrics through standard UUIDs
- vendor metrics through vendor packet parsing

Code in our project:

```swift
func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
    connectedDeviceID = peripheral.identifier
    updateConnectionState(.connected, for: peripheral.identifier)
    peripheral.discoverServices(nil)
}

func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
    guard error == nil else { return }
    peripheral.services?.forEach { peripheral.discoverCharacteristics(nil, for: $0) }
}
```

---

## 10. Apple iOS BLE framework

On iOS, BLE is handled using **CoreBluetooth**.

Main classes:

### `CBCentralManager`
- manages scanning and connection from the phone side

### `CBPeripheral`
- represents a discovered BLE peripheral

### `CBService`
- represents a service

### `CBCharacteristic`
- represents a characteristic

In our app:
- `CBCentralManager` scans and connects
- `CBPeripheralDelegate` handles services/characteristics/value updates

Code in our project:

```swift
import CoreBluetooth

@MainActor
extension BLEScannerViewModel: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) { ... }
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) { ... }
}

@MainActor
extension BLEScannerViewModel: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) { ... }
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) { ... }
}
```

---

## 11. What we built in this project

Our app is a **BLE Device Explorer / BLE Health Inspector**.

It supports:
- scanning nearby BLE devices
- filtering by device type
- filtering by RSSI/range
- connecting to a selected device
- navigating to a details page
- listing available services and characteristics
- reading readable values
- subscribing to live updates
- decoding standard metrics
- decoding some vendor-specific smartwatch metrics

---

## 12. Metrics we read in this app

### Standard metrics
- Heart Rate from `2A37`
- Battery from `2A19`
- Device info from `180A` characteristics

### Vendor metrics
From GOBOULT vendor packets on `FEE3`, we mapped:
- Blood Pressure
- SpO2
- Stress

This is important because it shows two BLE realities:
- some data is standardized
- some data is proprietary and must be inferred

Code in our project:

```swift
static func parseVendorOxygenSaturation(from characteristic: CBCharacteristic) -> VendorOxygenSaturationReading? {
    let bytes = [UInt8](value)
    guard bytes.count >= 6,
          bytes[0] == 0xFE,
          bytes[1] == 0xEA,
          bytes[2] == 0x20,
          bytes[3] == 0x06 else {
        return nil
    }

    return VendorOxygenSaturationReading(
        spo2: Int(bytes[5]),
        sourceUUID: uuid,
        isExperimental: true
    )
}
```

And for stress:

```swift
static func parseVendorStress(from characteristic: CBCharacteristic) -> VendorStressReading? {
    let bytes = [UInt8](value)
    guard bytes.count >= 8,
          bytes[0] == 0xFE,
          bytes[1] == 0xEA,
          bytes[2] == 0x20,
          bytes[3] == 0x08 else {
        return nil
    }

    return VendorStressReading(
        score: Int(bytes[7]),
        sourceUUID: uuid,
        isExperimental: true
    )
}
```

---

## 13. Advantages of BLE

BLE is powerful because it offers:
- low battery consumption
- simple device discovery
- support across modern platforms
- standard services for many health and sensor use cases
- real-time updates using notifications
- strong fit for wearables and IoT

---

## 14. Limitations of BLE

BLE also has limitations:

### Not every device is open
- many devices expose only partial public data

### Vendor lock-in
- meaningful data may be inside proprietary characteristics

### Signal fluctuation
- RSSI changes frequently

### Limited payloads
- not ideal for large continuous streams like rich audio

### Discovery is not guaranteed
- some devices advertise only sometimes
- some devices hide names

---

## 15. Security in BLE

BLE can support:
- pairing
- bonding
- encryption
- authenticated communication

Depending on the device, some characteristics may require:
- pairing first
- trusted device relationship
- vendor app workflow

This is one reason a generic BLE scanner may discover a device but still not access all its useful data.

---

## 16. Common BLE use cases

Here are realistic BLE project use cases:

### Health and wearable monitoring
- read heart rate
- inspect smartwatch public interfaces

### Device explorer / diagnostics
- discover nearby BLE devices
- inspect services and characteristics

### Smart home onboarding
- connect and configure BLE locks, bulbs, tags

### Sensor dashboard
- show environmental or health sensor values

### Asset tracking / beacon scanning
- use BLE proximity and advertisements

---

## 17. Important BLE terms cheat sheet

### BLE
Bluetooth Low Energy

### Central
The device that scans and connects

### Peripheral
The device that advertises and exposes data

### Advertisement
Small broadcast packet sent by peripheral

### RSSI
Signal strength in dBm

### GATT
Data model for BLE communication

### Service
Category of capability

### Characteristic
Actual value or operation

### UUID
Identifier for service/characteristic

### Notify
Device pushes updates

### Read
App requests current value

### Write
App sends command/data

---

## 18. Why BLE matters for modern products

BLE is important because it enables:
- wearables
- low-power health tracking
- smart home accessories
- asset tracking
- phone-to-device onboarding
- portable diagnostics

Without BLE, many small connected products would either:
- consume too much power
- be harder to pair
- require more expensive communication options

---

## 19. Summary

BLE is a low-power wireless technology built for nearby connected devices that need efficient communication.

It is widely used in:
- wearables
- health devices
- sensors
- smart home products
- beacons
- IoT systems

The most important BLE concepts are:
- advertising
- scanning
- central and peripheral roles
- GATT
- services
- characteristics
- standard vs proprietary UUIDs

In our project, BLE allowed us to:
- discover devices
- connect to a smartwatch
- inspect its services
- read standard values like heart rate and battery
- decode proprietary vendor health metrics

That makes this project a strong real-world example of how BLE works in modern product development.

---
