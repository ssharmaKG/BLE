//
//  ScannerHomeView.swift
//  BLEScanner
//
//  Created by Shikha Sharma on 27/05/26.
//

import SwiftUI

// MARK: - Home screen
//
// This is the main BLE dashboard shown when the app opens.
// It contains:
// - the scan header
// - device type filters
// - RSSI range filter
// - the live list of nearby BLE devices
struct ScannerHomeView: View {
    @EnvironmentObject private var viewModel: BLEScannerViewModel
    @State private var animateHeader = false

    let onOpenDevice: (ScannedDevice) -> Void

    var body: some View {
        ZStack {
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
        .task {
            viewModel.startScanningIfPossible()
            animateHeader = true
        }
    }

    private var headerSection: some View {
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
                StatusPill(
                    title: viewModel.bluetoothStateText,
                    systemImage: viewModel.bluetoothStateIcon,
                    tint: viewModel.bluetoothStateColor,
                    isAnimating: viewModel.isScanning
                )

                Spacer()

                CompactStatCard(title: "Visible", value: "\(viewModel.filteredDevices.count)")
                CompactStatCard(title: "Mode", value: viewModel.showRawDebugMode ? "Raw" : "Smart")
            }

            scanningHero
        }
        .sectionCard()
    }

    private var filterSection: some View {
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
                    ForEach(viewModel.filteredDevices) { device in
                        DeviceRow(
                            device: device,
                            isSelected: viewModel.connectedDeviceID == device.id,
                            actionTitle: viewModel.actionTitle(for: device),
                            action: { onOpenDevice(device) }
                        )
                    }
                }
            }
        }
    }

    private var scanningHero: some View {
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
