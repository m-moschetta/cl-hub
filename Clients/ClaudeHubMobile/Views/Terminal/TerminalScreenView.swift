import SwiftUI

struct TerminalScreenView: View {
    @EnvironmentObject private var appStore: MobileAppStore

    let session: MobileSession
    @State private var draft = ""

    var body: some View {
        VStack(spacing: 0) {
            topBar

            RemoteTerminalView(
                transcript: currentTranscript,
                onInitialSize: { cols, rows in
                    appStore.openSessionIfNeeded(session.id, cols: cols, rows: rows)
                },
                onInput: { input in
                    appStore.sendInput(input, to: session.id)
                },
                onResize: { cols, rows in
                    appStore.openSessionIfNeeded(session.id, cols: cols, rows: rows)
                }
            )
            .id(session.id)
            .background(
                LinearGradient(
                    colors: [Color.black, Color(red: 0.08, green: 0.11, blue: 0.14)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )

            composer
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    private var currentTranscript: String {
        appStore.sessions.first(where: { $0.id == session.id })?.transcript ?? session.transcript
    }

    private var topBar: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text(session.name)
                    .font(.headline)
                Text(session.status.capitalized)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button("Refresh") {
                appStore.refreshSessions()
            }
            .buttonStyle(.bordered)
        }
        .padding(14)
        .background(.thinMaterial)
    }

    private var composer: some View {
        HStack(alignment: .bottom, spacing: 10) {
            TextField("Send command…", text: $draft, axis: .vertical)
                .textFieldStyle(.plain)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 18))

            Button {
                sendDraft()
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 34))
                    .foregroundStyle(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? .gray : .green)
            }
            .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding(12)
        .background(.bar)
    }

    private func sendDraft() {
        let trimmed = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        appStore.sendInput(trimmed + "\n", to: session.id)
        draft = ""
    }
}
