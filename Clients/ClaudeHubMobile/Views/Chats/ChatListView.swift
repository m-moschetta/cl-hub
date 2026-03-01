import SwiftUI

struct ChatListView: View {
    @EnvironmentObject private var appStore: MobileAppStore
    @Binding var showingPairing: Bool
    @State private var showingNewSession = false

    var body: some View {
        VStack(spacing: 0) {
            header

            if appStore.connectionState != .authenticated {
                connectionBanner
            }

            if appStore.sessions.isEmpty {
                emptyState
            } else {
                sessionList
            }
        }
        .background(Color(.systemBackground))
        .sheet(isPresented: $showingNewSession) {
            NewSessionSheet()
                .environmentObject(appStore)
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            // Connection indicator
            HStack(spacing: 6) {
                Circle()
                    .fill(connectionColor)
                    .frame(width: 8, height: 8)

                if let name = appStore.pairedHostName {
                    Text(name)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .frame(minWidth: 60, alignment: .leading)

            Spacer()

            Text("ClaudeHub")
                .font(.headline.weight(.bold))

            Spacer()

            HStack(spacing: 14) {
                if appStore.connectionState == .authenticated {
                    Button {
                        showingNewSession = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 17, weight: .medium))
                    }

                    Button {
                        appStore.refreshSessions()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 15, weight: .medium))
                    }
                }

                Button {
                    showingPairing = true
                } label: {
                    Image(systemName: "qrcode.viewfinder")
                        .font(.system(size: 17, weight: .medium))
                }
            }
            .foregroundStyle(.green)
            .frame(minWidth: 60, alignment: .trailing)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial, ignoresSafeAreaEdges: .top)
    }

    // MARK: - Connection Banner

    private var connectionBanner: some View {
        HStack(spacing: 10) {
            Group {
                switch appStore.connectionState {
                case .disconnected:
                    Image(systemName: "wifi.slash")
                        .foregroundStyle(.red)
                case .connecting, .pairing:
                    ProgressView()
                        .scaleEffect(0.8)
                case .authenticated:
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                }
            }
            .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(connectionTitle)
                    .font(.subheadline.weight(.medium))
                Text(appStore.statusText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            if appStore.connectionState == .disconnected {
                Button("Reconnect") {
                    appStore.reconnect()
                }
                .font(.caption.weight(.semibold))
                .buttonStyle(.bordered)
                .controlSize(.small)
                .tint(.green)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            appStore.connectionState == .disconnected
                ? Color.red.opacity(0.08)
                : Color.orange.opacity(0.08)
        )
    }

    // MARK: - Session List

    private var sessionList: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                ForEach(appStore.sessions) { session in
                    ChatRowView(session: session)
                        .contentShape(.rect(cornerRadius: 14))
                        .onTapGesture {
                            withAnimation(.smooth(duration: 0.25)) {
                                appStore.prepareToOpenSession(session.id)
                            }
                        }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
        }
        .refreshable {
            appStore.refreshSessions()
            try? await Task.sleep(for: .milliseconds(500))
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "terminal.fill")
                .font(.system(size: 52))
                .foregroundStyle(.green.opacity(0.3))

            if appStore.connectionState == .authenticated {
                Text("No Active Sessions")
                    .font(.title3.weight(.semibold))

                Text("Create a new session or refresh\nto see active sessions.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                Button {
                    showingNewSession = true
                } label: {
                    Label("New Session", systemImage: "plus")
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                }
                .glassEffect(.regular.tint(.green).interactive(), in: .capsule)

                Button {
                    appStore.refreshSessions()
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                }
                .glassEffect(.regular.tint(.green).interactive(), in: .capsule)
            } else {
                Text("Not Connected")
                    .font(.title3.weight(.semibold))

                Text("Pair with your Mac to see active\nClaude sessions remotely.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                Button {
                    showingPairing = true
                } label: {
                    Label("Scan QR Code", systemImage: "qrcode.viewfinder")
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                }
                .glassEffect(.regular.tint(.green).interactive(), in: .capsule)
            }

            Spacer()
        }
        .padding(24)
        .frame(maxWidth: .infinity)
    }

    // MARK: - Helpers

    private var connectionTitle: String {
        switch appStore.connectionState {
        case .disconnected: return "Disconnected"
        case .pairing: return "Pairing…"
        case .connecting: return "Connecting…"
        case .authenticated: return "Connected"
        }
    }

    private var connectionColor: Color {
        switch appStore.connectionState {
        case .authenticated: return .green
        case .connecting, .pairing: return .orange
        case .disconnected: return .red
        }
    }
}
