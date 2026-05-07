import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var viewModel: BLEScannerViewModel

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {
                headerSection
                filterSection
                sliderSection
                deviceListSection
                Spacer(minLength: 0)
            }
            .padding()
            .navigationTitle("BLE Scanner")
            .task {
                viewModel.startScanningIfPossible()
            }
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label(viewModel.bluetoothStateText, systemImage: viewModel.bluetoothStateIcon)
                    .foregroundStyle(viewModel.bluetoothStateColor)
                Spacer()
                Button(viewModel.isScanning ? "Stop Scan" : "Start Scan") {
                    viewModel.toggleScan()
                }
                .buttonStyle(.borderedProminent)
                .disabled(!viewModel.canScan)
            }

            Text("Discover nearby BLE devices, narrow the list by type and proximity, then connect to a selected device.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var filterSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Device Types")
                .font(.headline)

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
    }

    private var sliderSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Range Filter")
                    .font(.headline)
                Spacer()
                Text(viewModel.currentRangeLabel)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Slider(value: $viewModel.minimumRSSI, in: -100 ... -40, step: 5)
                .tint(.blue)

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
    }

    private var deviceListSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Nearby Devices")
                    .font(.headline)
                Spacer()
                Text("\(viewModel.filteredDevices.count) visible")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if viewModel.filteredDevices.isEmpty {
                ContentUnavailableView(
                    "No Matching Devices",
                    systemImage: "dot.radiowaves.left.and.right",
                    description: Text("Try widening the range slider or enabling more device types.")
                )
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
            } else {
                List(viewModel.filteredDevices) { device in
                    DeviceRow(
                        device: device,
                        isSelected: viewModel.connectedDeviceID == device.id,
                        actionTitle: viewModel.actionTitle(for: device),
                        action: {
                            viewModel.handleTap(on: device)
                        }
                    )
                    .listRowInsets(EdgeInsets(top: 10, leading: 0, bottom: 10, trailing: 0))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                }
                .listStyle(.plain)
                .frame(maxHeight: 420)
            }
        }
    }
}

private struct ToggleChip: View {
    let title: String
    let isOn: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.medium))
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .background(isOn ? Color.blue : Color(.systemGray6))
                .foregroundStyle(isOn ? .white : .primary)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

private struct DeviceRow: View {
    let device: ScannedDevice
    let isSelected: Bool
    let actionTitle: String
    let action: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(device.displayName)
                        .font(.headline)
                    Text(device.type.displayName)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
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

            if device.name == nil || device.name?.isEmpty == true {
                ForEach(device.debugDetails, id: \.self) { detail in
                    Text(detail)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            Button(actionTitle, action: action)
                .buttonStyle(.borderedProminent)
                .disabled(device.connectionState == .connecting || !device.isConnectable)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(isSelected ? Color.blue.opacity(0.08) : Color(.secondarySystemBackground))
        )
    }
}
