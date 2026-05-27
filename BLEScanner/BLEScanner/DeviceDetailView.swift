//
//  DeviceDetailView.swift
//  BLEScanner
//
//  Created by Shikha Sharma on 27/05/26.
//

import SwiftUI

// Detail screen for one connected device.
// It combines user-friendly metrics with a lower-level GATT inspector.
struct DeviceDetailView: View {
    @EnvironmentObject private var viewModel: BLEScannerViewModel
    let deviceID: UUID

    private var device: ScannedDevice? {
        viewModel.device(for: deviceID)
    }

    var body: some View {
        ZStack {
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

    private var exposedMetricsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Exposed Health Metrics")
                .font(.headline.weight(.semibold))

            metricRow(title: "Battery", value: viewModel.batteryLevel.map { "\($0)%" } ?? "Waiting...")

            Divider()
            metricRow(title: "Heart Rate", value: viewModel.heartRateReading.map { "\($0.bpm) BPM" } ?? "Tap watch to fetch")

            Divider()
            metricRow(title: "Blood Pressure", value: bloodPressureValueText)

            Divider()
            metricRow(title: "SpO2", value: oxygenValueText)

            Divider()
            metricRow(title: "Stress", value: stressValueText)

            Text("Tap the measurement you want on the watch to fetch and update these metrics.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .sectionCard()
    }

    private var servicesSection: some View {
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

    private var bloodPressureValueText: String {
        if let bloodPressureReading = viewModel.bloodPressureReading {
            return String(format: "%.0f/%.0f mmHg", bloodPressureReading.systolic, bloodPressureReading.diastolic)
        }

        if let vendorBloodPressureReading = viewModel.vendorBloodPressureReading {
            return "\(vendorBloodPressureReading.systolic)/\(vendorBloodPressureReading.diastolic) mmHg"
        }

        return "Tap watch to fetch"
    }

    private var oxygenValueText: String {
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
        if let stressReading = viewModel.stressReading {
            return "\(stressReading.score)"
        }

        if let vendorStressReading = viewModel.vendorStressReading {
            return "\(vendorStressReading.score)"
        }

        return "Tap watch to fetch"
    }

    private func metricRow(title: String, value: String) -> some View {
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
                .font(.title3.weight(.bold))
                .foregroundStyle(metricIconColor(for: title))
                .contentTransition(.numericText())
        }
    }

    private func serviceTitle(for uuid: String) -> String {
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

    private var detailIconName: String {
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
