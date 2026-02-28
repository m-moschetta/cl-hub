import SwiftUI

@main
struct ClaudeHubMobileApp: App {
    @StateObject private var appStore = MobileAppStore()

    var body: some Scene {
        WindowGroup {
            MobileRootView()
                .environmentObject(appStore)
        }
    }
}
