# BLE Nearby Device Scanner Project

## 1. Project Title

**BLE Nearby Device Scanner with Device-Type Filters, Range Slider, and Connect Functionality**

## 2. Project Summary

This project is a BLE-enabled application that scans and lists nearby Bluetooth Low Energy devices, allows the user to filter devices using toggle buttons by device type, provides a progress-bar style slider to control scanning range or proximity threshold, and enables connection to a selected BLE device.

The project is a strong fit for a team talk because it demonstrates:

- Real-time BLE scanning
- Interactive filtering
- Proximity-aware discovery
- Device connection workflow
- Clean user interface concepts
- Practical BLE use in mobile or desktop applications

## 3. Problem Statement

In many BLE applications, users see a long unfiltered list of nearby devices. This creates a poor experience because:

- Too many devices may appear at the same time
- Users may only care about specific device categories
- Nearby and far devices are mixed together
- Connection flow can become confusing

We need a smart BLE scanner that makes device discovery easier by allowing users to:

- View nearby BLE devices
- Filter by device type
- Narrow results using a distance or signal-strength range slider
- Select and connect to a device directly

## 4. Project Objective

Build an application that:

1. Scans for nearby BLE devices
2. Lists discovered BLE devices in real time
3. Provides toggles for device categories
4. Filters listed devices based on selected toggles
5. Uses a slider/progress bar to control the visible range
6. Allows the user to connect to a selected BLE device

## 5. Core Features

### A. Nearby BLE Device Discovery

The app continuously scans for BLE devices around the user and displays them in a dynamic list.

Each listed device may show:

- Device name
- MAC address or identifier
- Signal strength (RSSI)
- Estimated distance or range bucket
- Device type
- Connection status

### B. Device Type Toggles

The app includes toggle controls to filter visible devices by category.

Possible device-type toggles:

- Wearables
- Audio devices
- Sensors
- Beacons
- Medical devices
- Smart home devices
- Unknown devices

Behavior:

- When a toggle is on, devices of that type are shown
- When a toggle is off, devices of that type are hidden
- Multiple toggles can be selected at the same time

### C. Range Selection with Progress-Bar Slider

The app includes a slider that lets the user glide across a progress bar to choose the preferred device range.

Important note:
BLE does not directly provide exact distance. In practice, the app will use RSSI values to estimate proximity.

Example slider levels:

- Very Near
- Near
- Medium
- Far

Or numeric RSSI thresholds such as:

- `>-55 dBm`
- `>-65 dBm`
- `>-75 dBm`
- `>-85 dBm`

Behavior:

- Moving the slider adjusts which devices remain visible
- Stronger signals are treated as nearer devices
- Weaker signals are filtered out based on the selected threshold

### D. Connect to Selected BLE Device

Once a user selects a device from the filtered nearby list, the app starts a BLE connection flow.

Connection steps:

1. User taps a device from the list
2. App attempts BLE connection
3. Device status changes to connecting
4. On success, status changes to connected
5. App can optionally discover services and characteristics

## 6. User Flow

### End-to-End Flow

1. User opens the app
2. App starts scanning for nearby BLE devices
3. Devices appear in the list in real time
4. User turns on or off device-type toggles
5. User adjusts the range slider
6. Device list updates based on selected filters
7. User selects one device from the visible list
8. App connects to the chosen BLE device
9. Optional next step: show BLE services, read/write characteristics, or display device details

## 7. Functional Requirements

### Scanning

- The system should start BLE scan on user command or app launch
- The system should refresh the device list dynamically during scan
- The system should avoid duplicate entries for the same device

### Filtering

- The system should support filtering devices by type using toggles
- The system should support multiple selected toggles at once
- The system should update the device list immediately when toggles change

### Range Selection

- The system should provide a slider to set the visible proximity threshold
- The system should filter devices based on RSSI or estimated range
- The system should update the visible list as the slider changes

### Connection

- The system should allow the user to tap a listed device to connect
- The system should show connection states such as disconnected, connecting, connected, and failed
- The system should handle connection timeout or failure gracefully

## 8. Non-Functional Requirements

- Responsive UI during continuous scanning
- Smooth slider interaction
- Clear connection feedback
- Efficient battery usage
- Scalable to many discovered devices
- Stable reconnection handling

## 9. Device Type Classification Options

BLE devices do not always clearly announce a friendly type. We can classify devices using one or more of these methods:

- Advertised service UUIDs
- Device name patterns
- Manufacturer data
- Appearance field if available
- Custom mapping rules in the application

Example:

- Heart rate service -> wearable or medical
- Environmental sensing service -> sensor
- iBeacon or Eddystone pattern -> beacon
- Audio-related identifiers -> audio device

Unknown or unmatched devices can be grouped under **Unknown Devices**.

## 10. UI Proposal

### Main Screen Layout

#### Header

- Title: BLE Scanner
- Scan status indicator
- Optional scan button

#### Filter Section

- Toggle chips or switches for device types
- Example:
  - Wearables
  - Sensors
  - Beacons
  - Audio
  - Unknown

#### Range Section

- Label: Select Range
- Progress-bar style slider
- Text showing current threshold such as:
  - Near only
  - Up to medium range
  - RSSI > -70 dBm

#### Device List

Each device card shows:

- Device name
- Type
- RSSI
- Estimated range
- Connect button

#### Connection Status

- Disconnected
- Connecting...
- Connected
- Failed to connect

## 11. Suggested Data Model

### BLE Device Object

```json
{
  "id": "device-001",
  "name": "Heart Rate Sensor",
  "address": "AA:BB:CC:DD:EE:FF",
  "rssi": -62,
  "estimatedRange": "Near",
  "type": "Wearable",
  "isConnectable": true,
  "connectionState": "disconnected"
}
```

## 12. Filtering Logic

The filtering logic can work like this:

### Step 1: Scan Results

Collect all discovered BLE devices in memory.

### Step 2: Apply Type Filters

Keep only devices whose type matches enabled toggles.

### Step 3: Apply Range Filter

Keep only devices whose RSSI is above the selected threshold.

### Step 4: Render Filtered List

Show the final filtered device list in the UI.

### Example Pseudocode

```js
const filteredDevices = allDevices.filter((device) => {
  const matchesType = enabledTypes.includes(device.type);
  const matchesRange = device.rssi >= selectedRssiThreshold;
  return matchesType && matchesRange;
});
```

## 13. BLE Connection Flow

After selecting a device:

1. Stop or pause scan if required by the BLE library
2. Attempt connection to selected device
3. Show loader or connecting indicator
4. On success, save connected device state
5. Discover available services and characteristics if needed
6. Allow future actions such as read, write, notify, or disconnect

## 14. Technical Stack Options

Depending on platform, the project can be built in different ways.

### Option A: Flutter

Useful packages:

- `flutter_blue_plus`
- `permission_handler`

Why choose it:

- Good cross-platform story
- Nice UI support for toggles and slider
- Suitable for quick demo apps

### Option B: React Native

Useful libraries:

- `react-native-ble-plx`
- `react-native-permissions`

Why choose it:

- Strong for mobile-first app
- Good team demo value
- Easy to build dynamic scanner interface

### Option C: Native Android

Useful APIs:

- Android BluetoothLeScanner
- GATT APIs

Why choose it:

- Full BLE control
- Best if Android is the target demo environment

## 15. Challenges You Should Mention in the Talk

This will make your presentation more realistic and credible.

- RSSI is not an exact distance measurement
- Walls, people, and noise affect BLE signal strength
- Some devices may hide their name or type
- OS permissions are required for Bluetooth scanning
- Some devices advertise but do not allow connection
- Background scanning rules vary by platform

## 16. Business and Demo Value

This project is useful for a team presentation because it demonstrates:

- Real-world BLE discovery
- Better user experience through smart filtering
- Practical device connection workflow
- A foundation for many future BLE products

This scanner can later evolve into:

- Smart home controller
- Medical device manager
- Industrial sensor dashboard
- Asset locator
- Wearable integration platform

## 17. Sample Talk Pitch

You can describe the project like this:

"This project is a BLE Nearby Device Scanner that discovers nearby Bluetooth Low Energy devices in real time, filters them using device-type toggles, narrows visible devices using a range slider based on signal strength, and allows the user to connect directly to a selected device. The goal is to make BLE discovery more usable, interactive, and practical for real applications."

## 18. Suggested Demo Scenario

For your team talk, you can present this demo flow:

1. Start BLE scan
2. Show multiple nearby devices being discovered
3. Enable only Sensor and Wearable toggles
4. Adjust range slider to show only near devices
5. Select a device from the filtered list
6. Connect to the device
7. Show connection success

This makes the app feel interactive and easy to understand.

## 19. Future Enhancements

- Save favorite devices
- Auto reconnect to known devices
- Show signal strength graph over time
- Add service and characteristic explorer
- Add read and write operations after connection
- Add disconnect and reconnect controls
- Add device detail screen
- Add scan history

## 20. Final Recommendation

This is a very good BLE project for a team talk because it is:

- Practical
- Easy to demo
- Visually interactive
- Technically meaningful
- Extendable into real products

If you want to present both technical depth and product thinking, this project is a strong choice.
