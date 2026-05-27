//
//  DeviceRow.swift
//  BLEScanner
//
//  Created by Shikha Sharma on 27/05/26.
//

import SwiftUI

// One row in the scanner list representing a discovered BLE peripheral.
struct DeviceRow: View {
    let device: ScannedDevice
    let isSelected: Bool
    let actionTitle: String
    let action: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
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
                ForEach(device.debugDetails, id: \.self) { detail in
                    Text(detail)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            Button(actionTitle, action: action)
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

private extension DeviceRow {
    var deviceIcon: some View {
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
