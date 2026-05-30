import SwiftUI

@main
struct FashionSwipeApp: App {
    @StateObject private var viewModel = SwipeViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(viewModel)
        }
    }
}
