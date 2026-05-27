//
//  ContentView.swift
//  BLEScanner
//
//  Created by Shikha Sharma on 20/04/26.
//

import SwiftUI

// MARK: - Home screen
//
// `ContentView` is the scanner dashboard of the app.
// It shows:
// - the scan status
// - filter controls
// - the list of discovered BLE devices
//
// From here the user can connect to a device, after which the app
// automatically navigates to a deeper inspection screen.
struct ContentView: View {
    // The view model is shared across the app and contains all BLE state.
    @EnvironmentObject private var viewModel: BLEScannerViewModel
    // Navigation is driven by connected device IDs.
    @State private var navigationPath: [UUID] = []
    // Used only for UI animation on the home screen hero section.
    @State private var animateHeader = false

    var body: some View {
        NavigationStack(path: $navigationPath) {
            ZStack {
                // Shared background styling used throughout the app.
                AppBackground()

                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        headerSection
                        filterSection
                        sliderSection
                        deviceListSection
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                }
            }
            .navigationTitle("BLE Explorer")
            .navigationBarTitleDisplayMode(.inline)
            .task {
                // Start scanning when the screen appears if Bluetooth is already ready.
                viewModel.startScanningIfPossible()
                animateHeader = true
            }
            .onChange(of: viewModel.connectedDeviceID) { _, connectedID in
                guard let connectedID else { return }
                // When a device connects, automatically push its detail screen.
                if navigationPath.last != connectedID {
                    navigationPath.append(connectedID)
                }
            }
            .navigationDestination(for: UUID.self) { deviceID in
                // Each UUID in the navigation path opens one device detail screen.
                DeviceDetailView(deviceID: deviceID)
                    .environmentObject(viewModel)
            }
        }
    }

    private var headerSection: some View {
        // Top summary section with the app title, scan button, and live scanner status.
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    Text("BLE Device Explorer")
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.primary)

                    Text("Scan, filter, connect, and inspect nearby BLE peripherals with a clean live view of health metrics and services.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button(viewModel.isScanning ? "Stop Scan" : "Start Scan") {
                    // Manual scan control in case the user wants to pause discovery.
                    viewModel.toggleScan()
                }
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 18)
                .padding(.vertical, 12)
                .background(
                    Capsule(style: .continuous)
                        .fill(viewModel.canScan ? Color.black : Color.gray.opacity(0.4))
                )
                .foregroundStyle(.white)
                .disabled(!viewModel.canScan)
            }

            HStack(spacing: 12) {
                statusPill(
                    title: viewModel.bluetoothStateText,
                    systemImage: viewModel.bluetoothStateIcon,
                    tint: viewModel.bluetoothStateColor
                )

                Spacer()

                compactStatCard(
                    title: "Visible",
                    value: "\(viewModel.filteredDevices.count)"
                )

                compactStatCard(
                    title: "Mode",
                    value: viewModel.showRawDebugMode ? "Raw" : "Smart"
                )
            }

            scanningHero
        }
        .sectionCard()
    }

    private var filterSection: some View {
        // Lets the user narrow the list by BLE device type,
        // or switch to raw debug mode to see everything discovered.
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Device Types")
                    .font(.headline.weight(.semibold))
                Spacer()
                Button {
                    viewModel.toggleRawDebugMode()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: viewModel.showRawDebugMode ? "waveform.path.ecg.rectangle.fill" : "switch.2")
                        Text(viewModel.showRawDebugMode ? "Raw Debug" : "Classifier")
                            .font(.caption.weight(.semibold))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        Capsule(style: .continuous)
                            .fill(viewModel.showRawDebugMode ? Color.orange.opacity(0.16) : Color.blue.opacity(0.10))
                    )
                    .foregroundStyle(viewModel.showRawDebugMode ? Color.orange : Color.blue)
                }
                .buttonStyle(.plain)
            }

            Text(viewModel.showRawDebugMode ? "Raw debug mode is on. All discovered devices can appear regardless of classifier type." : "Classifier mode is on. Device-type toggles control which devices are shown.")
                .font(.caption)
                .foregroundStyle(.secondary)

            ScrollView(.horizontal, showsIndicators: false) {
                // Horizontal chip row keeps the filter UI compact and touch friendly.
                HStack(spacing: 10) {
                    ForEach(DeviceType.allCases) { type in
                        ToggleChip(
                            title: type.displayName,
                            isOn: viewModel.enabledDeviceTypes.contains(type)
                        ) {
                            viewModel.toggleDeviceType(type)
                        }
                    }
                }
            }
        }
        .sectionCard()
    }

    private var sliderSection: some View {
        // RSSI is used here as a rough proximity filter.
        // Less negative values usually mean a stronger/closer signal.
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Range Filter")
                    .font(.headline.weight(.semibold))
                Spacer()
                Text(viewModel.currentRangeLabel)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.blue)
                    .contentTransition(.numericText())
            }

            Slider(value: $viewModel.minimumRSSI, in: -100 ... -40, step: 5)
                // The slider gives a simple UX for signal-strength filtering.
                .tint(Color(red: 0.11, green: 0.43, blue: 0.95))

            HStack {
                Text("Far")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("Near")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .sectionCard()
    }

    private var deviceListSection: some View {
        // Main scanner results area showing every visible peripheral
        // after the current filters have been applied.
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Nearby Devices")
                    .font(.headline.weight(.semibold))
                Spacer()
                Text("\(viewModel.filteredDevices.count) visible")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
            }

            if viewModel.filteredDevices.isEmpty {
                ContentUnavailableView(
                    "No Matching Devices",
                    systemImage: "dot.radiowaves.left.and.right",
                    description: Text("Try widening the range slider, enabling more device types, or checking whether the smartwatch is advertising over BLE.")
                )
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
                .background(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(.white.opacity(0.76))
                )
            } else {
                LazyVStack(spacing: 12) {
                    // We use LazyVStack instead of List to keep the custom card UI stable.
                    ForEach(viewModel.filteredDevices) { device in
                        DeviceRow(
                            device: device,
                            isSelected: viewModel.connectedDeviceID == device.id,
                            actionTitle: viewModel.actionTitle(for: device),
                            action: {
                                handleDeviceAction(device)
                            }
                        )
                    }
                }
            }
        }
    }

    private func handleDeviceAction(_ device: ScannedDevice) {
        // If already connected, just reopen the detail screen.
        // Otherwise ask the view model to connect.
        if device.connectionState == .connected {
            if navigationPath.last != device.id {
                navigationPath.append(device.id)
            }
            return
        }

        viewModel.handleTap(on: device)
    }

    private func statusPill(title: String, systemImage: String, tint: Color) -> some View {
        // Reusable little status badge used in the header.
        HStack(spacing: 8) {
            Image(systemName: systemImage)
                .symbolEffect(.pulse.byLayer, isActive: viewModel.isScanning)
            Text(title)
                .font(.caption.weight(.semibold))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            Capsule(style: .continuous)
                .fill(tint.opacity(0.14))
        )
        .foregroundStyle(tint)
    }

    private func compactStatCard(title: String, value: String) -> some View {
        // Small metric card used for top-line scanner stats.
        VStack(alignment: .leading, spacing: 4) {
            Text(title.uppercased())
                .font(.caption2.weight(.bold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.headline.weight(.bold))
                .contentTransition(.numericText())
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.white.opacity(0.72))
        )
    }

    private var scanningHero: some View {
        // Decorative hero row that also communicates scan state visually.
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.10))
                    .frame(width: 52, height: 52)
                    .scaleEffect(viewModel.isScanning && animateHeader ? 1.16 : 0.96)
                    .opacity(viewModel.isScanning ? 1 : 0.7)
                    .animation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true), value: viewModel.isScanning)

                Image(systemName: "dot.radiowaves.left.and.right")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(Color.blue)
                    .symbolEffect(.variableColor.iterative, isActive: viewModel.isScanning)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(viewModel.isScanning ? "Scanning nearby peripherals" : "Scanner ready")
                    .font(.subheadline.weight(.semibold))
                Text(viewModel.isScanning ? "Live BLE advertisements are updating below." : "Start a scan to discover nearby BLE devices.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.blue.opacity(0.08))
        )
    }

}

private struct ToggleChip: View {
    // Reusable chip button for device-type filtering.
    let title: String
    let isOn: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            // The filled state makes it obvious which categories are active.
            HStack(spacing: 8) {
                Image(systemName: isOn ? "checkmark.circle.fill" : "circle")
                    .font(.caption.weight(.bold))
                Text(title)
                    .font(.subheadline.weight(.medium))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                Capsule(style: .continuous)
                    .fill(
                        isOn ?
                        LinearGradient(
                            colors: [Color(red: 0.10, green: 0.49, blue: 0.97), Color(red: 0.11, green: 0.73, blue: 0.78)],
                            startPoint: .leading,
                            endPoint: .trailing
                        ) :
                        LinearGradient(
                            colors: [.white.opacity(0.85), Color(.systemGray6)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .foregroundStyle(isOn ? .white : .primary)
            .overlay(
                Capsule(style: .continuous)
                    .stroke(isOn ? .clear : Color.black.opacity(0.06), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

private struct DeviceRow: View {
    // One row in the scanner list representing a discovered BLE peripheral.
    let device: ScannedDevice
    let isSelected: Bool
    let actionTitle: String
    let action: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Top row shows icon, readable name, category, and connection status.
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 10) {
                        deviceIcon

                        VStack(alignment: .leading, spacing: 4) {
                            Text(device.displayName)
                                .font(.headline.weight(.semibold))
                            Text(device.type.displayName)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                Spacer()
                Text(device.connectionState.badgeTitle)
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(device.connectionState.badgeColor.opacity(0.16))
                    .foregroundStyle(device.connectionState.badgeColor)
                    .clipShape(Capsule())
            }

            HStack {
                // Signal strength is useful because many BLE devices have no friendly name,
                // so RSSI becomes another clue for identifying the device nearby.
                Label("RSSI \(device.rssi) dBm", systemImage: "antenna.radiowaves.left.and.right")
                Spacer()
                Text(device.proximityLabel)
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            if !device.identifierText.isEmpty {
                Text(device.identifierText)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            if device.name == nil || device.name?.isEmpty == true || !device.debugDetails.isEmpty {
                // For unclear or vendor-specific devices, show extra advertisement hints
                // such as services, company name, and manufacturer bytes.
                ForEach(device.debugDetails, id: \.self) { detail in
                    Text(detail)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            Button(actionTitle, action: action)
                // Main row action: connect, retry, or reopen details.
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(device.isConnectable ? Color.black : Color.gray.opacity(0.3))
                )
                .foregroundStyle(.white)
                .disabled(device.connectionState == .connecting || (device.connectionState != .connected && !device.isConnectable))
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: isSelected ?
                            [Color.blue.opacity(0.14), .white.opacity(0.96)] :
                            [.white.opacity(0.94), Color(.secondarySystemBackground)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(isSelected ? Color.blue.opacity(0.32) : Color.black.opacity(0.05), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.06), radius: 14, x: 0, y: 8)
    }
}

private struct DeviceDetailView: View {
    // Detail screen for one connected device.
    // It combines human-readable health metrics with lower-level GATT inspection.
    @EnvironmentObject private var viewModel: BLEScannerViewModel
    let deviceID: UUID

    private var device: ScannedDevice? {
        viewModel.device(for: deviceID)
    }

    var body: some View {
        ZStack {
            // Reuse the same visual background as the home screen for continuity.
            AppBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    detailHeader
                    exposedMetricsSection
                    servicesSection
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
        }
        .navigationTitle(device?.displayName ?? "BLE Device")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var detailHeader: some View {
        // Summary header for the selected BLE device.
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                Image(systemName: detailIconName)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(Color.blue)
                    .frame(width: 44, height: 44)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color.blue.opacity(0.12))
                    )
                    .symbolEffect(.pulse.byLayer, isActive: viewModel.connectedDeviceID == deviceID)

                VStack(alignment: .leading, spacing: 4) {
                    Text(device?.displayName ?? "BLE Device")
                        .font(.title3.weight(.bold))
                    Text(device?.type.displayName ?? "Unknown")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            if let device {
                // These details are especially useful because BLE devices often expose
                // a UUID and advertisement hints even when they do not expose a nice name.
                Text("RSSI \(device.rssi) dBm • \(device.proximityLabel)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Text(device.identifierText)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)

                ForEach(device.debugDetails, id: \.self) { detail in
                    Text(detail)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .sectionCard()
    }

    private func serviceTitle(for uuid: String) -> String {
        // Friendly names for common standard and observed vendor services.
        switch uuid.uppercased() {
        case "180D": return "Heart Rate"
        case "180F": return "Battery Service"
        case "180A": return "Device Information"
        case "FEEA": return "Vendor Service FEEA"
        case "FEE7": return "Vendor Service FEE7"
        case "190E": return "Vendor Service 190E"
        case "AE00": return "Vendor Service AE00"
        default: return "Unknown Service"
        }
    }

    private func characteristicTitle(for uuid: String) -> String {
        // Friendly names for common standard and observed vendor characteristics.
        switch uuid.uppercased() {
        case "2A37": return "Heart Rate Measurement"
        case "2A38": return "Body Sensor Location"
        case "2A19": return "Battery Level"
        case "2A25": return "Serial Number"
        case "2A26": return "Firmware Revision"
        case "2A28": return "Software Revision"
        case "2A29": return "Manufacturer Name"
        case "FEE1": return "Vendor Characteristic FEE1"
        case "FEE2": return "Vendor Characteristic FEE2"
        case "FEE3": return "Vendor Characteristic FEE3"
        case "FEE4": return "Vendor Characteristic FEE4"
        case "FEE5": return "Vendor Characteristic FEE5"
        case "FEE6": return "Vendor Characteristic FEE6"
        case "FEC9": return "Vendor Characteristic FEC9"
        case "FEA1": return "Vendor Characteristic FEA1"
        case "0003": return "Vendor Characteristic 0003"
        case "0004": return "Vendor Characteristic 0004"
        case "AE01": return "Vendor Characteristic AE01"
        case "AE02": return "Vendor Characteristic AE02"
        default: return "Unknown Characteristic"
        }
    }

    private var exposedMetricsSection: some View {
        // The user-friendly summary of values we could decode from the device.
        // Some are standard BLE metrics, while some come from vendor packets.
        VStack(alignment: .leading, spacing: 12) {
            Text("Exposed Health Metrics")
                .font(.headline.weight(.semibold))

            metricRow(
                title: "Battery",
                value: viewModel.batteryLevel.map { "\($0)%" } ?? "Waiting..."
            )

            Divider()

            metricRow(
                title: "Heart Rate",
                value: viewModel.heartRateReading.map { "\($0.bpm) BPM" } ?? "Tap watch to fetch"
            )

            Divider()

            metricRow(
                title: "Blood Pressure",
                value: bloodPressureValueText
            )

            Divider()

            metricRow(
                title: "SpO2",
                value: oxygenValueText
            )

            Divider()

            metricRow(
                title: "Stress",
                value: stressValueText
            )

            Text("Tap the measurement you want on the watch to fetch and update these metrics.")
                // Some devices only send fresh values when the measurement is triggered
                // from the watch itself, so this note sets the right expectation.
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .sectionCard()
    }

    private var bloodPressureValueText: String {
        // Prefer standard BLE BP if available, otherwise fall back to the vendor decode.
        if let bloodPressureReading = viewModel.bloodPressureReading {
            return String(format: "%.0f/%.0f mmHg", bloodPressureReading.systolic, bloodPressureReading.diastolic)
        }

        if let vendorBloodPressureReading = viewModel.vendorBloodPressureReading {
            return "\(vendorBloodPressureReading.systolic)/\(vendorBloodPressureReading.diastolic) mmHg"
        }

        return "Tap watch to fetch"
    }

    private var oxygenValueText: String {
        // Prefer standard pulse-ox data if available, otherwise use the vendor packet mapping.
        if let oxygenSaturationReading = viewModel.oxygenSaturationReading {
            if let pulseRate = oxygenSaturationReading.pulseRate {
                return String(format: "%.0f%% • Pulse %.0f", oxygenSaturationReading.spo2, pulseRate)
            }
            return String(format: "%.0f%%", oxygenSaturationReading.spo2)
        }

        if let vendorOxygenSaturationReading = viewModel.vendorOxygenSaturationReading {
            return "\(vendorOxygenSaturationReading.spo2)%"
        }

        return "Tap watch to fetch"
    }

    private var stressValueText: String {
        // Stress is usually vendor-defined rather than standardized in BLE.
        if let stressReading = viewModel.stressReading {
            return "\(stressReading.score)"
        }

        if let vendorStressReading = viewModel.vendorStressReading {
            return "\(vendorStressReading.score)"
        }

        return "Tap watch to fetch"
    }

    private func metricRow(title: String, value: String) -> some View {
        // Shared UI for each headline metric row.
        HStack {
            HStack(spacing: 10) {
                Image(systemName: metricIconName(for: title))
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(metricIconColor(for: title))
                    .frame(width: 28, height: 28)
                    .background(
                        Circle()
                            .fill(metricIconColor(for: title).opacity(0.12))
                    )

                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(value)
                // Numeric text transition makes live updates feel smoother.
                .font(.title3.weight(.bold))
                .foregroundStyle(metricIconColor(for: title))
                .contentTransition(.numericText())
        }
    }

    private var servicesSection: some View {
        // Lower-level GATT inspector showing every discovered service
        // and each characteristic under it.
        VStack(alignment: .leading, spacing: 12) {
            Text("Available Services")
                .font(.headline.weight(.semibold))

            if viewModel.discoveredServices.isEmpty {
                Text("Discovering services and readable characteristics...")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                LazyVStack(alignment: .leading, spacing: 10) {
                    ForEach(viewModel.discoveredServices) { service in
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Service \(service.uuid) • \(serviceTitle(for: service.uuid))")
                                .font(.subheadline.weight(.semibold))

                            if service.characteristics.isEmpty {
                                Text("No characteristics discovered yet")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            } else {
                                ForEach(service.characteristics) { characteristic in
                                    // Each characteristic is one readable, writable,
                                    // or subscribable data point inside the service.
                                    VStack(alignment: .leading, spacing: 2) {
                                        HStack(spacing: 8) {
                                            Image(systemName: "point.3.connected.trianglepath.dotted")
                                                .font(.caption.weight(.bold))
                                                .foregroundStyle(.blue)
                                            Text("Characteristic \(characteristic.uuid) • \(characteristicTitle(for: characteristic.uuid))")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }

                                        Text("Properties: \(characteristic.properties)")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)

                                        if let valueDescription = characteristic.valueDescription {
                                            // We show decoded values when we understand them,
                                            // otherwise the view model falls back to a raw hex summary.
                                            Text("Value: \(valueDescription)")
                                                .font(.caption2)
                                                .foregroundStyle(.tertiary)
                                        }
                                    }
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(.white.opacity(0.72))
                        )
                    }
                }
            }
        }
        .sectionCard()
    }

    private var detailIconName: String {
        // Match the icon to the device category for easier visual scanning.
        guard let device else { return "sensor.tag.radiowaves.forward" }
        switch device.type {
        case .wearable: return "applewatch.radiowaves.left.and.right"
        case .audio: return "headphones"
        case .sensor: return "sensor"
        case .beacon: return "dot.radiowaves.left.and.right"
        case .medical: return "cross.case"
        case .smartHome: return "house.and.flag"
        case .unknown: return "sensor.tag.radiowaves.forward"
        }
    }

    private func metricIconName(for title: String) -> String {
        // Picks a semantic SF Symbol for each metric card.
        switch title {
        case "Battery": return "bolt.fill"
        case "Heart Rate": return "heart.fill"
        case "Blood Pressure": return "waveform.path.ecg"
        case "SpO2": return "drop.fill"
        case "Stress": return "brain.head.profile"
        default: return "circle.fill"
        }
    }

    private func metricIconColor(for title: String) -> Color {
        // Keeps the text/icon color language consistent across the detail screen.
        switch title {
        case "Battery": return .green
        case "Heart Rate": return .red
        case "Blood Pressure": return .blue
        case "SpO2": return .cyan
        case "Stress": return .orange
        default: return .gray
        }
    }
}

private extension DeviceRow {
    var deviceIcon: some View {
        // Visual identity for the device row based on its classified type.
        Image(systemName: iconName)
            .font(.subheadline.weight(.bold))
            .foregroundStyle(iconTint)
            .frame(width: 36, height: 36)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(iconTint.opacity(0.12))
            )
    }

    var iconName: String {
        // Picks a type-specific SF Symbol for each scanner row.
        switch device.type {
        case .wearable: return "applewatch.side.right"
        case .audio: return "headphones"
        case .sensor: return "sensor"
        case .beacon: return "dot.radiowaves.left.and.right"
        case .medical: return "cross.case.fill"
        case .smartHome: return "lock.home"
        case .unknown: return "antenna.radiowaves.left.and.right"
        }
    }

    var iconTint: Color {
        // Type-based color coding for quick visual grouping.
        switch device.type {
        case .wearable: return .pink
        case .audio: return .purple
        case .sensor: return .teal
        case .beacon: return .blue
        case .medical: return .red
        case .smartHome: return .orange
        case .unknown: return .gray
        }
    }
}

private struct AppBackground: View {
    var body: some View {
        LinearGradient(
            colors: [
                Color(red: 0.94, green: 0.98, blue: 1.00),
                Color(red: 0.97, green: 0.95, blue: 1.00),
                Color(red: 0.99, green: 0.98, blue: 0.95)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
        .overlay(alignment: .topTrailing) {
            Circle()
                .fill(Color.blue.opacity(0.10))
                .frame(width: 220, height: 220)
                .blur(radius: 18)
                .offset(x: 80, y: -60)
        }
        .overlay(alignment: .bottomLeading) {
            Circle()
                .fill(Color.orange.opacity(0.08))
                .frame(width: 200, height: 200)
                .blur(radius: 20)
                .offset(x: -60, y: 80)
        }
    }
}

private extension View {
    func sectionCard() -> some View {
        self
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(.white.opacity(0.78))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(Color.black.opacity(0.05), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.05), radius: 18, x: 0, y: 10)
    }
}
