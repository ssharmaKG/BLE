//
//  BLEScannerApp.swift
//  BLEScanner
//
//  Created by Shikha Sharma on 20/04/26.
//

import SwiftUI

@main
struct BLEScannerApp: App {
    @StateObject private var viewModel = BLEScannerViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(viewModel)
        }
    }
}
