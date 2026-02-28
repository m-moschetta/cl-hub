import SwiftUI

struct PairingSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appStore: MobileAppStore
    @State private var rawPayload = ""
    @State private var scannerError: String?

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 18) {
                Text("Scan the pairing QR shown by ClaudeHub on your Mac. If you are testing on Simulator, you can still paste the raw payload below.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                QRCodeScannerView(
                    onCodeScanned: { payload in
                        rawPayload = payload
                        pairAndDismiss()
                    },
                    onFailure: { message in
                        scannerError = message
                    }
                )
                .frame(height: 240)
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .overlay(alignment: .center) {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                }

                if let scannerError {
                    Text(scannerError)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }

                TextEditor(text: $rawPayload)
                    .font(.system(.body, design: .monospaced))
                    .padding(10)
                    .frame(minHeight: 120)
                    .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 18))

                Button("Pair with Host") {
                    pairAndDismiss()
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
                .disabled(rawPayload.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                Text(appStore.statusText)
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                Spacer()
            }
            .padding(20)
            .navigationTitle("Pair Device")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func pairAndDismiss() {
        appStore.pair(with: rawPayload)
        dismiss()
    }
}
