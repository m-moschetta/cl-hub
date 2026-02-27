import SwiftUI
import ClaudeHubCore
import ClaudeHubTerminal

/// Container for the terminal with a toolbar showing session info.
struct TerminalContainerView: View {
    let session: Session
    @EnvironmentObject var sessionManager: SessionManager
    @EnvironmentObject var processManager: ProcessManager

    @State private var terminalView: ClaudeTerminalView?

    var body: some View {
        VStack(spacing: 0) {
            // Toolbar — fixed height, never negotiates with terminal
            terminalToolbar
                .fixedSize(horizontal: false, vertical: true)

            // Terminal — fills all remaining space
            TerminalRepresentable(
                sessionID: session.id,
                command: session.command,
                workingDirectory: session.worktreePath ?? session.workingDirectory,
                flags: session.claudeFlags,
                environmentVariables: session.environmentVariables,
                fontSizeOverride: session.fontSizeOverride,
                onStatusChange: { status in
                    sessionManager.updateSessionStatus(session, status: status)
                },
                onPreviewUpdate: { preview in
                    sessionManager.updateLastPreview(session, preview: preview)
                },
                onProcessTerminated: {
                    sessionManager.updateSessionStatus(session, status: .disconnected)
                    processManager.unregister(sessionID: session.id)
                },
                onTerminalReady: { tv in
                    self.terminalView = tv
                    let process = ProcessManager.TerminalProcess(
                        sessionID: session.id,
                        pid: tv.processPID ?? 0,
                        sendInput: { text in tv.sendText(text) }
                    )
                    self.processManager.register(process: process)
                    self.sessionManager.updateSessionStatus(session, status: .idle)
                }
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Color(nsColor: TerminalTheme.dark.background))
    }

    private var terminalToolbar: some View {
        HStack(spacing: 12) {
            // Status indicator
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)

            Text(session.name)
                .font(.headline)
                .lineLimit(1)

            if let branch = session.worktreeBranch {
                Label(branch, systemImage: "arrow.triangle.branch")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.quaternary, in: Capsule())
            }

            Spacer()

            Text(session.status.displayName)
                .font(.caption)
                .foregroundStyle(.secondary)

            // Actions
            Menu {
                Button("Restart Session") {
                    restartSession()
                }
                Button("Send Interrupt (Ctrl+C)") {
                    terminalView?.sendText("\u{03}")
                }
                Divider()
                Button("Copy Scrollback") {
                    copyScrollback()
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .foregroundStyle(.secondary)
            }
            .menuStyle(.borderlessButton)
            .frame(width: 30)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.bar)
    }

    private var statusColor: Color {
        switch session.status {
        case .idle: return .green
        case .thinking: return .blue
        case .toolUse: return .orange
        case .error: return .red
        case .disconnected: return .gray
        }
    }

    private func restartSession() {
        processManager.killProcess(sessionID: session.id)
        // Terminal will be recreated by SwiftUI when status changes
        sessionManager.updateSessionStatus(session, status: .disconnected)
    }

    private func copyScrollback() {
        if let data = ScrollbackStore.shared.readScrollback(for: session.id),
           let text = String(data: data, encoding: .utf8) {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(text, forType: .string)
        }
    }
}
