import SwiftUI

struct TerminalScreenView: View {
    @EnvironmentObject private var appStore: MobileAppStore

    let session: MobileSession
    @State private var actionTrigger = 0

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

            actionBar
        }
        .background(Color(red: 0.04, green: 0.06, blue: 0.09))
    }

    private var currentTranscript: String {
        appStore.sessions.first(where: { $0.id == session.id })?.transcript ?? session.transcript
    }

    private var liveSession: MobileSession {
        appStore.sessions.first(where: { $0.id == session.id }) ?? session
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack {
            Button {
                withAnimation(.smooth(duration: 0.25)) {
                    appStore.selectedSessionID = nil
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .semibold))
                    Text("Back")
                        .font(.subheadline.weight(.medium))
                }
                .foregroundStyle(.green)
            }
            .frame(minWidth: 60, alignment: .leading)

            Spacer()

            VStack(spacing: 2) {
                Text(session.name)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)

                HStack(spacing: 4) {
                    Circle()
                        .fill(statusColor)
                        .frame(width: 6, height: 6)
                    Text(statusLabel)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Button {
                appStore.refreshSessions()
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            .frame(minWidth: 60, alignment: .trailing)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial, ignoresSafeAreaEdges: .top)
    }

    // MARK: - Action Bar

    private struct ActionKey: Identifiable {
        let id: String
        let label: String
        let input: String
        let isPrimary: Bool

        init(_ label: String, _ input: String, primary: Bool = false) {
            self.id = label
            self.label = label
            self.input = input
            self.isPrimary = primary
        }
    }

    private var quickActions: [ActionKey] {
        [
            ActionKey("y", "y\n", primary: true),
            ActionKey("n", "n\n", primary: true),
            ActionKey("⌃C", "\u{03}", primary: true),
            ActionKey("Tab", "\t"),
            ActionKey("↑", "\u{1B}[A"),
            ActionKey("↓", "\u{1B}[B"),
            ActionKey("⌃D", "\u{04}"),
            ActionKey("⌃Z", "\u{1A}"),
            ActionKey("Esc", "\u{1B}"),
        ]
    }

    private var actionBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(quickActions) { action in
                    Button {
                        actionTrigger += 1
                        appStore.sendInput(action.input, to: session.id)
                    } label: {
                        Text(action.label)
                            .font(.system(
                                action.isPrimary ? .callout : .caption,
                                design: .monospaced,
                                weight: action.isPrimary ? .bold : .medium
                            ))
                            .foregroundStyle(action.isPrimary ? .green : .secondary)
                            .padding(.horizontal, action.isPrimary ? 16 : 12)
                            .padding(.vertical, 8)
                    }
                    .glassEffect(
                        action.isPrimary
                            ? .regular.tint(.green).interactive()
                            : .regular.interactive(),
                        in: .capsule
                    )
                    .sensoryFeedback(.impact(flexibility: .soft), trigger: actionTrigger)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .background(.ultraThinMaterial, ignoresSafeAreaEdges: .bottom)
    }

    // MARK: - Status

    private var statusColor: Color {
        switch liveSession.status {
        case "idle": return .green
        case "thinking": return .blue
        case "toolUse": return .orange
        case "error": return .red
        default: return .gray
        }
    }

    private var statusLabel: String {
        switch liveSession.status {
        case "idle": return "Ready"
        case "thinking": return "Thinking…"
        case "toolUse": return "Working…"
        case "error": return "Error"
        default: return liveSession.status.capitalized
        }
    }
}
