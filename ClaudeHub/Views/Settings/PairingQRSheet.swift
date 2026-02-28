import SwiftUI

/// Shows a QR code for iOS device pairing.
/// The QR encodes a JSON payload that the iOS app scans to initiate pairing.
struct PairingQRSheet: View {
    @EnvironmentObject var remoteAgentService: RemoteAgentService
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 20) {
            Text("Pair iOS Device")
                .font(.title2.bold())

            // Connection status indicator
            HStack(spacing: 6) {
                Circle()
                    .fill(connectionColor)
                    .frame(width: 8, height: 8)
                Text(connectionLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let qrImage = remoteAgentService.pairingQRImage {
                Image(nsImage: qrImage)
                    .interpolation(.none)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 220, height: 220)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
            } else if let error = remoteAgentService.pairingError {
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 36))
                        .foregroundStyle(.red)

                    Text(error)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)

                    Button("Retry") {
                        remoteAgentService.requestPairing()
                    }
                    .buttonStyle(.borderedProminent)
                }
            } else if remoteAgentService.relayURL.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 36))
                        .foregroundStyle(.orange)

                    Text("No relay URL configured")
                        .font(.headline)

                    Text("Set a relay URL in Settings → Remote before pairing.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
            } else {
                VStack(spacing: 12) {
                    ProgressView()
                        .controlSize(.large)
                    Text("Connecting to relay…")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .onAppear {
                    remoteAgentService.requestPairing()
                }
            }

            if let json = remoteAgentService.pairingQRPayloadJSON {
                GroupBox("Manual Payload") {
                    ScrollView {
                        Text(json)
                            .font(.system(size: 10, design: .monospaced))
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(height: 60)
                }

                Button("Copy Payload") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(json, forType: .string)
                }
                .buttonStyle(.bordered)
            }

            HStack(spacing: 12) {
                if remoteAgentService.pairingQRImage != nil {
                    Button("Regenerate") {
                        remoteAgentService.requestPairing()
                    }
                    .buttonStyle(.bordered)
                }

                Button("Close") {
                    remoteAgentService.cancelPairing()
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
            }

            Text("Scan this QR with ClaudeHub Mobile to connect.")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(24)
        .frame(width: 360)
    }

    private var connectionColor: Color {
        switch remoteAgentService.connectionState {
        case .connected: .green
        case .connecting, .authenticating: .orange
        case .disconnected: .red
        }
    }

    private var connectionLabel: String {
        switch remoteAgentService.connectionState {
        case .connected:
            remoteAgentService.isAuthenticated ? "Connected & authenticated" : "Connected"
        case .connecting:
            "Connecting…"
        case .authenticating:
            "Authenticating…"
        case .disconnected:
            "Disconnected"
        }
    }
}
