import SwiftUI

struct MobileRootView: View {
    @EnvironmentObject private var appStore: MobileAppStore
    @State private var showingPairing = false

    var body: some View {
        Group {
            if let session = appStore.selectedSession {
                TerminalScreenView(session: session)
            } else {
                ChatListView(showingPairing: $showingPairing)
            }
        }
        .animation(.smooth, value: appStore.selectedSessionID)
        .sheet(isPresented: $showingPairing) {
            PairingSheet()
                .environmentObject(appStore)
        }
        .tint(.green)
        .preferredColorScheme(.dark)
        .onChange(of: appStore.connectionState) { _, newState in
            if newState == .authenticated && showingPairing {
                showingPairing = false
            }
        }
    }
}
