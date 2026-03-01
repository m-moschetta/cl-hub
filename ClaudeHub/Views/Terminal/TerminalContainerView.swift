import SwiftUI
import UniformTypeIdentifiers
import ClaudeHubCore
import ClaudeHubRemote
import ClaudeHubTerminal

/// Container for the terminal with a toolbar showing session info.
struct TerminalContainerView: View {
    let session: Session
    var selectedSessionID: UUID?
    @EnvironmentObject var sessionManager: SessionManager
    @EnvironmentObject var processManager: ProcessManager
    @EnvironmentObject var remoteAgentService: RemoteAgentService

    @State private var terminalView: ClaudeTerminalView?
    @State private var previousStatus: SessionStatus = .disconnected
    @State private var isDropTargeted = false
    @StateObject private var childMonitor = ChildProcessMonitor()
    @State private var showChildProcesses = false

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
                    let wasActive = previousStatus == .thinking || previousStatus == .toolUse
                    let isNowSettled = status == .idle || status == .error

                    sessionManager.updateSessionStatus(session, status: status)

                    // Mark as unread if session transitioned from active → settled
                    // and this is NOT the currently selected session
                    if wasActive && isNowSettled && session.id != selectedSessionID {
                        session.hasUnread = true
                    }

                    previousStatus = status

                    // Broadcast to remote clients
                    broadcastSessionUpdate()
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
                    tv.onRawOutput = { data in
                        Task { @MainActor in
                            remoteAgentService.captureTerminalOutput(data, for: session.id)
                        }
                    }
                    let process = ProcessManager.TerminalProcess(
                        sessionID: session.id,
                        pid: tv.processPID ?? 0,
                        sendInput: { text in tv.sendText(text) },
                        resize: { cols, rows in
                            tv.resizeTerminal(cols: cols, rows: rows)
                        }
                    )
                    self.processManager.register(process: process)
                    if let requestedSize = remoteAgentService.pendingTerminalSize(for: session.id) {
                        tv.resizeTerminal(cols: requestedSize.cols, rows: requestedSize.rows)
                    }
                    self.sessionManager.updateSessionStatus(session, status: .idle)
                    // Start monitoring child processes
                    if let pid = tv.processPID {
                        childMonitor.start(parentPID: pid)
                    }
                }
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .overlay {
                if isDropTargeted {
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(Color.accentColor, lineWidth: 2)
                        .background(Color.accentColor.opacity(0.08))
                        .allowsHitTesting(false)
                }
            }
            .onDrop(of: [.fileURL], isTargeted: $isDropTargeted) { providers in
                handleFileDrop(providers)
            }
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

            // Child process indicator
            if !childMonitor.children.isEmpty {
                Button(action: { showChildProcesses.toggle() }) {
                    HStack(spacing: 4) {
                        Image(systemName: "gearshape.2.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(.orange)
                            .symbolEffect(.pulse, isActive: true)

                        Text("\(childMonitor.children.count)")
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.orange.opacity(0.1), in: Capsule())
                }
                .buttonStyle(.borderless)
                .popover(isPresented: $showChildProcesses, arrowEdge: .bottom) {
                    childProcessPopover
                }
            }

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

    private var childProcessPopover: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "gearshape.2.fill")
                    .foregroundStyle(.orange)
                Text("Background Processes")
                    .font(.headline)
                Spacer()
                Text("\(childMonitor.children.count)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.quaternary, in: Capsule())
            }

            Divider()

            ForEach(childMonitor.children) { child in
                HStack(spacing: 8) {
                    Circle()
                        .fill(.green)
                        .frame(width: 6, height: 6)

                    Text(child.name)
                        .font(.system(size: 12, design: .monospaced))
                        .lineLimit(1)

                    Spacer()

                    Text("PID \(child.pid)")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.tertiary)
                }
            }

            if childMonitor.children.isEmpty {
                Text("No background processes")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(12)
        .frame(minWidth: 260)
    }

    private func restartSession() {
        childMonitor.stop()
        processManager.killProcess(sessionID: session.id)
        // Terminal will be recreated by SwiftUI when status changes
        sessionManager.updateSessionStatus(session, status: .disconnected)
    }

    private func handleFileDrop(_ providers: [NSItemProvider]) -> Bool {
        var handled = false
        for provider in providers {
            if provider.canLoadObject(ofClass: URL.self) {
                handled = true
                _ = provider.loadObject(ofClass: URL.self) { url, _ in
                    guard let url = url, url.isFileURL else { return }
                    let path = url.path
                    // Shell-quote paths with special characters
                    let quoted = "'\(path.replacingOccurrences(of: "'", with: "'\\''"))'"
                    DispatchQueue.main.async {
                        terminalView?.sendText(quoted + " ")
                    }
                }
            }
        }
        return handled
    }

    private func copyScrollback() {
        if let data = ScrollbackStore.shared.readScrollback(for: session.id),
           let text = String(data: data, encoding: .utf8) {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(text, forType: .string)
        }
    }

    private func broadcastSessionUpdate() {
        guard remoteAgentService.isAuthenticated else { return }
        let payload = remoteAgentService.makeSessionUpdatedPayload(for: session)
        for clientID in remoteAgentService.activeClientIDs {
            remoteAgentService.send(
                type: RemoteMessageType.sessionUpdated,
                target: RemotePeer(kind: .client, id: clientID),
                payload: payload
            )
        }
    }
}
