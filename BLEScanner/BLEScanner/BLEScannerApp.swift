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
