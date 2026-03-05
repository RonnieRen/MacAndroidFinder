import SwiftUI

@main
struct DroidFinderApp: App {
    @StateObject private var viewModel = DroidFinderViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(viewModel)
                .frame(minWidth: 900, minHeight: 560)
        }
    }
}
