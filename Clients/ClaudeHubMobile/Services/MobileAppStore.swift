import ClaudeHubRemote
import Foundation

@MainActor
final class MobileAppStore: ObservableObject {
    @Published var connectionState: MobileConnectionState = .disconnected
    @Published var statusText = "Scan or paste a QR pairing payload."
    @Published var sessions: [MobileSession] = []
    @Published var selectedSessionID: UUID?
    @Published var pairedHostName: String?
    @Published var recentProjectPaths: [RecentProjectPath] = []
    @Published var hostGroups: [SessionGroupSummary] = []
    @Published var isCreatingSession = false

    let relayClient = MobileRelayClient()
    private var pendingOpenSessionID: UUID?

    init() {
        relayClient.onStatusText = { [weak self] text in
            self?.statusText = text
        }

        relayClient.onPairingSuccess = { [weak self] payload in
            self?.pairedHostName = payload.hostName
            self?.connectionState = .authenticated
        }

        relayClient.onClientAuthenticated = { [weak self] record in
            self?.pairedHostName = record.hostName
            self?.connectionState = .authenticated
        }

        relayClient.onSessionList = { [weak self] list in
            self?.sessions = list.map {
                MobileSession(
                    id: $0.id,
                    name: $0.name,
                    status: $0.status,
                    lastPreview: $0.lastPreview,
                    hasUnread: $0.hasUnread
                )
            }
        }

        relayClient.onSessionUpdated = { [weak self] summary in
            guard let self,
                  let index = self.sessions.firstIndex(where: { $0.id == summary.id })
            else { return }

            self.sessions[index].status = summary.status
            self.sessions[index].name = summary.name
            self.sessions[index].hasUnread = summary.hasUnread
            if !summary.lastPreview.isEmpty {
                self.sessions[index].lastPreview = summary.lastPreview
            }
        }

        relayClient.onDisconnected = { [weak self] in
            self?.connectionState = .disconnected
        }

        relayClient.onProjectPathsList = { [weak self] payload in
            self?.recentProjectPaths = payload.recentPaths
            self?.hostGroups = payload.groups
        }

        relayClient.onSessionCreated = { [weak self] summary in
            self?.isCreatingSession = false
            self?.prepareToOpenSession(summary.id)
        }

        relayClient.onTerminalSnapshot = { [weak self] sessionID, snapshot in
            guard let self,
                  let index = self.sessions.firstIndex(where: { $0.id == sessionID })
            else { return }

            self.sessions[index].transcript = snapshot
            self.sessions[index].lastPreview = String(snapshot.trimmingCharacters(in: .whitespacesAndNewlines).prefix(80))
        }

        relayClient.onTerminalOutput = { [weak self] sessionID, chunk in
            guard let self,
                  let index = self.sessions.firstIndex(where: { $0.id == sessionID })
            else { return }

            self.sessions[index].transcript += chunk
            self.sessions[index].lastPreview = String(chunk.trimmingCharacters(in: .whitespacesAndNewlines).prefix(80))
        }

        if let pairedHost = MobileCredentialStore().pairedHost() {
            pairedHostName = pairedHost.hostName
            statusText = "Reconnecting to \(pairedHost.hostName)…"
            connectionState = .connecting
            relayClient.reconnectIfPossible()
        }
    }

    var selectedSession: MobileSession? {
        guard let selectedSessionID else { return nil }
        return sessions.first(where: { $0.id == selectedSessionID })
    }

    func pair(with rawQRCodePayload: String) {
        do {
            connectionState = .pairing
            let payload = try QRCodePairingParser.parse(rawQRCodePayload)
            relayClient.connect(using: payload)
            statusText = "Pairing in progress…"
        } catch {
            statusText = error.localizedDescription
            connectionState = .disconnected
        }
    }

    func reconnect() {
        connectionState = .connecting
        statusText = "Reconnecting…"
        relayClient.reconnectIfPossible()
    }

    /// Called when the app returns to foreground — reconnects if the socket died
    func reconnectIfNeeded() {
        guard connectionState != .authenticated else { return }
        connectionState = .connecting
        relayClient.reconnectIfNeeded()
    }

    func refreshSessions() {
        relayClient.requestSessions()
    }

    func sendInput(_ text: String, to sessionID: UUID) {
        relayClient.sendInput(text, to: sessionID)
    }

    func sendResize(cols: Int, rows: Int, for sessionID: UUID) {
        relayClient.sendResize(cols: cols, rows: rows, for: sessionID)
    }

    func prepareToOpenSession(_ sessionID: UUID) {
        selectedSessionID = sessionID
        pendingOpenSessionID = sessionID
    }

    func openSessionIfNeeded(_ sessionID: UUID, cols: Int, rows: Int) {
        if pendingOpenSessionID == sessionID {
            relayClient.openSession(sessionID, cols: cols, rows: rows)
            pendingOpenSessionID = nil
        } else {
            relayClient.sendResize(cols: cols, rows: rows, for: sessionID)
        }
    }

    func requestProjectPaths() {
        relayClient.requestProjectPaths()
    }

    func createSession(
        name: String,
        projectPath: String,
        command: String,
        flags: String,
        groupID: UUID?,
        useWorktree: Bool,
        initialPrompt: String?
    ) {
        isCreatingSession = true
        relayClient.createSession(CreateSessionPayload(
            name: name,
            projectPath: projectPath,
            command: command,
            flags: flags,
            groupID: groupID,
            useWorktree: useWorktree,
            initialPrompt: initialPrompt
        ))
    }
}
