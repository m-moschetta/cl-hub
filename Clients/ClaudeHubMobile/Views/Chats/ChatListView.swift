import SwiftUI

struct ChatListView: View {
    @EnvironmentObject private var appStore: MobileAppStore

    var body: some View {
        VStack(spacing: 0) {
            header

            if appStore.sessions.isEmpty {
                emptyState
            } else {
                List(appStore.sessions) { session in
                    ChatRowView(session: session)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            appStore.prepareToOpenSession(session.id)
                        }
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
                }
                .listStyle(.plain)
            }
        }
        .background(Color(.systemGroupedBackground))
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(appStore.pairedHostName ?? "Not Paired")
                .font(.headline)
            Text(appStore.statusText)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            LinearGradient(
                colors: [Color.green.opacity(0.18), Color.white],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "message.circle")
                .font(.system(size: 42))
                .foregroundStyle(.green)

            Text("No active sessions")
                .font(.headline)

            Text("Pair the app with a ClaudeHub host, then pull sessions from the Mac.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button("Refresh Sessions") {
                appStore.refreshSessions()
            }
            .buttonStyle(.borderedProminent)
            .tint(.green)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
