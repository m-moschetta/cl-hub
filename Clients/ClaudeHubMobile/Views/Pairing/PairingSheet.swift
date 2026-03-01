import SwiftUI

struct PairingSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appStore: MobileAppStore
    @State private var rawPayload = ""
    @State private var scannerError: String?
    @State private var showManualEntry = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Step indicator
                    HStack(spacing: 8) {
                        stepBubble(1, "Scan", isActive: appStore.connectionState != .authenticated)
                        stepLine
                        stepBubble(2, "Pair", isActive: appStore.connectionState == .pairing)
                        stepLine
                        stepBubble(3, "Done", isActive: appStore.connectionState == .authenticated)
                    }
                    .padding(.horizontal)

                    if appStore.connectionState == .authenticated {
                        successView
                    } else {
                        scannerSection
                        manualEntrySection
                    }

                    // Status
                    HStack(spacing: 8) {
                        if appStore.connectionState == .pairing || appStore.connectionState == .connecting {
                            ProgressView()
                                .scaleEffect(0.8)
                        }
                        Text(appStore.statusText)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                }
                .padding(20)
            }
            .navigationTitle("Pair Device")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private var scannerSection: some View {
        VStack(spacing: 12) {
            Text("Point camera at the QR code shown in ClaudeHub on your Mac.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            QRCodeScannerView(
                onCodeScanned: { payload in
                    rawPayload = payload
                    pairAndDismiss()
                },
                onFailure: { message in
                    scannerError = message
                }
            )
            .frame(height: 220)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(Color.green.opacity(0.3), lineWidth: 2)
            )
            .shadow(color: .green.opacity(0.1), radius: 8, y: 4)

            if let scannerError {
                Label(scannerError, systemImage: "camera.fill")
                    .font(.footnote)
                    .foregroundStyle(.red)
            }
        }
    }

    private var manualEntrySection: some View {
        VStack(spacing: 10) {
            Button {
                withAnimation { showManualEntry.toggle() }
            } label: {
                HStack {
                    Text("Paste payload manually")
                        .font(.subheadline)
                    Image(systemName: showManualEntry ? "chevron.up" : "chevron.down")
                        .font(.caption)
                }
                .foregroundStyle(.secondary)
            }

            if showManualEntry {
                TextEditor(text: $rawPayload)
                    .font(.system(.caption, design: .monospaced))
                    .padding(10)
                    .frame(minHeight: 100)
                    .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color(.separator), lineWidth: 0.5)
                    )

                Button {
                    pairAndDismiss()
                } label: {
                    Label("Pair with Host", systemImage: "link")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
                .controlSize(.large)
                .disabled(rawPayload.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
    }

    private var successView: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 56))
                .foregroundStyle(.green)

            Text("Connected!")
                .font(.title2.weight(.bold))

            if let name = appStore.pairedHostName {
                Text("Paired to \(name)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Button("View Sessions") {
                dismiss()
            }
            .buttonStyle(.borderedProminent)
            .tint(.green)
            .controlSize(.large)
        }
        .padding(.vertical, 24)
    }

    private func stepBubble(_ number: Int, _ label: String, isActive: Bool) -> some View {
        VStack(spacing: 4) {
            ZStack {
                Circle()
                    .fill(isActive ? Color.green : Color(.tertiarySystemFill))
                    .frame(width: 28, height: 28)
                Text("\(number)")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(isActive ? .white : .secondary)
            }
            Text(label)
                .font(.caption2)
                .foregroundStyle(isActive ? .primary : .secondary)
        }
    }

    private var stepLine: some View {
        Rectangle()
            .fill(Color(.separator))
            .frame(height: 1)
            .frame(maxWidth: .infinity)
            .padding(.bottom, 16)
    }

    private func pairAndDismiss() {
        appStore.pair(with: rawPayload)
    }
}
