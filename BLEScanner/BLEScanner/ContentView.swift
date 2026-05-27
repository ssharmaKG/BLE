//
//  ContentView.swift
//  BLEScanner
//
//  Created by Shikha Sharma on 20/04/26.
//

import SwiftUI

// MARK: - Root navigation
//
// `ContentView` is intentionally small now.
// Its only job is to:
// - hold navigation state
// - show the scanner home screen
// - push the device detail screen after connection
struct ContentView: View {
    @EnvironmentObject private var viewModel: BLEScannerViewModel
    @State private var navigationPath: [UUID] = []

    var body: some View {
        NavigationStack(path: $navigationPath) {
            ScannerHomeView(onOpenDevice: handleOpenDevice)
                .environmentObject(viewModel)
                .navigationTitle("BLE Explorer")
                .navigationBarTitleDisplayMode(.inline)
                .onChange(of: viewModel.connectedDeviceID) { _, connectedID in
                    guard let connectedID else { return }
                    if navigationPath.last != connectedID {
                        navigationPath.append(connectedID)
                    }
                }
                .navigationDestination(for: UUID.self) { deviceID in
                    DeviceDetailView(deviceID: deviceID)
                        .environmentObject(viewModel)
                }
        }
    }

    private func handleOpenDevice(_ device: ScannedDevice) {
        if device.connectionState == .connected {
            if navigationPath.last != device.id {
                navigationPath.append(device.id)
            }
            return
        }

        viewModel.handleTap(on: device)
    }
}
