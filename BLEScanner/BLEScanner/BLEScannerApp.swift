//
//  BLEScannerApp.swift
//  BLEScanner
//
//  Created by Shikha Sharma on 20/04/26.
//

import SwiftUI

@main
struct BLEScannerApp: App {
    // A single shared view model is created here and injected into the app.
    // This lets every screen observe the same BLE scan/connection state.
    @StateObject private var viewModel = BLEScannerViewModel()

    var body: some Scene {
        WindowGroup {
            // ContentView is the root screen of the app.
            ContentView()
                .environmentObject(viewModel)
        }
    }
}
