import SwiftUI

struct MobileRootView: View {
    @EnvironmentObject private var appStore: MobileAppStore
    @Environment(\.scenePhase) private var scenePhase
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
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                appStore.reconnectIfNeeded()
            }
        }
    }
}
