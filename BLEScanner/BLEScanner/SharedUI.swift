//
//  SharedUI.swift
//  BLEScanner
//
//  Created by Shikha Sharma on 27/05/26.
//

import SwiftUI

// Reusable status badge used in the scanner header.
struct StatusPill: View {
    let title: String
    let systemImage: String
    let tint: Color
    let isAnimating: Bool

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
                .symbolEffect(.pulse.byLayer, isActive: isAnimating)
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
}

// Small stat card used in the scanner header for counts and mode labels.
struct CompactStatCard: View {
    let title: String
    let value: String

    var body: some View {
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
}

// Reusable chip used by the device-type filter row.
struct ToggleChip: View {
    let title: String
    let isOn: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
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

// Shared gradient background used on both the home and detail screens.
struct AppBackground: View {
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

// Shared card styling used for most content sections in the app.
extension View {
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
