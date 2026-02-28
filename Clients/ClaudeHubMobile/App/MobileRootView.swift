import SwiftUI

struct MobileRootView: View {
    @EnvironmentObject private var appStore: MobileAppStore
    @State private var showingPairing = false

    var body: some View {
        NavigationStack {
            Group {
                if let selectedSession = appStore.selectedSession {
                    TerminalScreenView(session: selectedSession)
                } else {
                    ChatListView()
                }
            }
            .navigationTitle(appStore.selectedSession == nil ? "ClaudeHub" : "")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if appStore.selectedSession != nil {
                        Button("Chats") {
                            appStore.selectedSessionID = nil
                        }
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingPairing = true
                    } label: {
                        Image(systemName: "qrcode.viewfinder")
                    }
                }
            }
        }
        .sheet(isPresented: $showingPairing) {
            PairingSheet()
                .environmentObject(appStore)
        }
        .tint(.green)
    }
}
