import AppKit
import Combine
import CoreImage
import CryptoKit
import Foundation
import ClaudeHubCore
import ClaudeHubRemote

/// Bridges local session/process state to the shared remote protocol models.
@MainActor
final class RemoteAgentService: ObservableObject {
    @Published private(set) var connectionState: RelayConnectionState = .disconnected
    @Published private(set) var lastReceivedMessage: String?
    @Published private(set) var lastTerminalOutput: TerminalOutputPayload?
    @Published private(set) var isAuthenticated = false
    @Published private(set) var pairingQRImage: NSImage?
    @Published private(set) var pairingQRPayloadJSON: String?
    @Published private(set) var isPairingActive = false
    @Published private(set) var pairingError: String?

    let hostID: String
    let relayURL: String

    private let sessionManager: SessionManager
    private let processManager: ProcessManager
    private let transport: RemoteRelayTransport
    private var cancellables: Set<AnyCancellable> = []
    private let signingKey = P256.Signing.PrivateKey()
    private(set) var activeClientIDs: Set<String> = []
    private var requestedTerminalSizes: [UUID: (cols: Int, rows: Int)] = [:]
    private var pendingPairingRequest = false
    private var pairingTimeoutTask: Task<Void, Never>?

    init(
        sessionManager: SessionManager,
        processManager: ProcessManager,
        hostID: String = UUID().uuidString,
        relayURL: String = "",
        transport: RemoteRelayTransport? = nil
    ) {
        self.sessionManager = sessionManager
        self.processManager = processManager
        self.hostID = hostID
        self.relayURL = relayURL
        self.transport = transport ?? RemoteRelayTransport()

        self.transport.$connectionState
            .receive(on: RunLoop.main)
            .sink { [weak self] state in
                self?.handleTransportStateChange(state)
            }
            .store(in: &cancellables)

        self.transport.onTextMessage = { [weak self] text in
            self?.handleInboundText(text)
        }
    }

    func connectIfConfigured() {
        guard !relayURL.isEmpty else { return }
        connect()
    }

    func connect() {
        isAuthenticated = false
        transport.connect(to: relayURL, hostID: hostID)
    }

    func disconnect() {
        transport.disconnect()
        isAuthenticated = false
        isPairingActive = false
        pairingQRImage = nil
        pairingQRPayloadJSON = nil
    }

    /// Ask the relay to create a pairing challenge, then generate a QR code from the response.
    func requestPairing() {
        pairingError = nil

        guard !relayURL.isEmpty else {
            pairingError = "No relay URL configured. Set it in Settings → Remote."
            return
        }

        guard isAuthenticated else {
            // If not connected yet, connect first
            connect()
            // Will retry after auth
            pendingPairingRequest = true
            startPairingTimeout()
            return
        }

        isPairingActive = true
        startPairingTimeout()
        send(
            type: RemoteMessageType.pairingCreate,
            target: relayPeer,
            payload: PairingCreatePayload(ttlSeconds: 120)
        )
    }

    func cancelPairing() {
        isPairingActive = false
        pairingQRImage = nil
        pairingQRPayloadJSON = nil
        pairingError = nil
        pairingTimeoutTask?.cancel()
        pairingTimeoutTask = nil
    }

    private func startPairingTimeout() {
        pairingTimeoutTask?.cancel()
        pairingTimeoutTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(15))
            guard !Task.isCancelled else { return }
            guard let self, self.pairingQRImage == nil, self.isPairingActive || self.pendingPairingRequest else { return }
            self.pairingError = "Timeout: could not reach relay at \(self.relayURL). Check Settings → Remote."
            self.isPairingActive = false
            self.pendingPairingRequest = false
        }
    }

    func makeHostRegisterPayload(publicKey: String, displayName: String? = nil) -> HostRegisterPayload {
        HostRegisterPayload(
            displayName: displayName ?? Host.current().localizedName ?? "ClaudeHub Host",
            publicKey: publicKey,
            appVersion: appVersion,
            platform: "macos"
        )
    }

    func makePairingQRCodePayload(
        challengeID: String,
        nonce: String,
        expiresAt: Date
    ) -> PairingQRCodePayload {
        PairingQRCodePayload(
            relayURL: relayURL,
            hostID: hostID,
            challengeID: challengeID,
            nonce: nonce,
            expiresAt: expiresAt
        )
    }

    func makeSessionListPayload() -> SessionListPayload {
        let sessions = sessionManager.fetchSessions().map { session in
            SessionSummary(
                id: session.id,
                name: session.name,
                status: session.status.rawValue,
                groupID: session.groupID,
                lastPreview: session.lastMessagePreview,
                hasUnread: session.hasUnread
            )
        }
        return SessionListPayload(sessions: sessions)
    }

    func handleTerminalInput(_ payload: TerminalInputPayload) {
        processManager.sendInput(payload.text, to: payload.sessionID)
    }

    func handleTerminalResize(_ payload: TerminalResizePayload) {
        processManager.resizeTerminal(
            sessionID: payload.sessionID,
            cols: payload.cols,
            rows: payload.rows
        )
    }

    func pendingTerminalSize(for sessionID: UUID) -> (cols: Int, rows: Int)? {
        requestedTerminalSizes[sessionID]
    }

    func captureTerminalOutput(_ data: Data, for sessionID: UUID) {
        let text = String(data: data, encoding: .utf8) ?? String(decoding: data, as: UTF8.self)
        let payload = TerminalOutputPayload(sessionID: sessionID, data: text)
        lastTerminalOutput = payload

        guard isAuthenticated else { return }

        for clientID in activeClientIDs {
            send(
                type: RemoteMessageType.terminalOutput,
                target: RemotePeer(kind: .client, id: clientID),
                payload: payload
            )
        }
    }

    func makeSessionUpdatedPayload(for session: Session) -> SessionUpdatedPayload {
        SessionUpdatedPayload(
            session: SessionSummary(
                id: session.id,
                name: session.name,
                status: session.status.rawValue,
                groupID: session.groupID,
                lastPreview: session.lastMessagePreview,
                hasUnread: session.hasUnread
            )
        )
    }

    func makeEnvelope<Payload: Codable & Sendable>(
        type: String,
        target: RemotePeer,
        payload: Payload
    ) -> RemoteEnvelope<Payload> {
        RemoteEnvelope(
            type: type,
            source: RemotePeer(kind: .host, id: hostID),
            target: target,
            payload: payload
        )
    }

    func send<Payload: Codable & Sendable>(
        type: String,
        target: RemotePeer,
        payload: Payload
    ) {
        let envelope = makeEnvelope(type: type, target: target, payload: payload)
        transport.send(envelope)
    }

    private func handleTransportStateChange(_ state: RelayConnectionState) {
        if state == .disconnected {
            isAuthenticated = false
        }

        connectionState = state

        if state == .connected {
            sendHostRegister()
            sendHostHello()
        }
    }

    private func handleInboundText(_ text: String) {
        lastReceivedMessage = text

        guard let data = text.data(using: .utf8),
              let header = try? Self.decoder.decode(RemoteEnvelopeHeader.self, from: data)
        else { return }

        switch header.type {
        case RemoteMessageType.challenge:
            guard let envelope = try? Self.decoder.decode(RemoteEnvelope<ChallengePayload>.self, from: data) else { return }
            handleChallenge(envelope.payload)
        case RemoteMessageType.hostAuthenticated:
            isAuthenticated = true
            connectionState = .connected
        case RemoteMessageType.listSessions:
            guard let envelope = try? Self.decoder.decode(RemoteEnvelope<EmptyPayload>.self, from: data) else { return }
            handleListSessionsRequest(from: envelope.source.id)
        case RemoteMessageType.openSession:
            guard let envelope = try? Self.decoder.decode(RemoteEnvelope<OpenSessionPayload>.self, from: data) else { return }
            handleOpenSessionRequest(envelope)
        case RemoteMessageType.terminalInput:
            guard let envelope = try? Self.decoder.decode(RemoteEnvelope<TerminalInputPayload>.self, from: data) else { return }
            handleTerminalInputRequest(envelope)
        case RemoteMessageType.terminalResize:
            guard let envelope = try? Self.decoder.decode(RemoteEnvelope<TerminalResizePayload>.self, from: data) else { return }
            handleTerminalResizeRequest(envelope)
        case RemoteMessageType.pairingCreated:
            guard let envelope = try? Self.decoder.decode(RemoteEnvelope<PairingCreatedPayload>.self, from: data) else { return }
            handlePairingCreated(envelope.payload)
        case RemoteMessageType.pairingPendingApproval:
            guard let envelope = try? Self.decoder.decode(RemoteEnvelope<PairingPendingApprovalPayload>.self, from: data) else { return }
            handlePairingPendingApproval(envelope.payload)
        case RemoteMessageType.listProjectPaths:
            guard let envelope = try? Self.decoder.decode(RemoteEnvelope<EmptyPayload>.self, from: data) else { return }
            handleListProjectPathsRequest(from: envelope.source.id)
        case RemoteMessageType.createSession:
            guard let envelope = try? Self.decoder.decode(RemoteEnvelope<CreateSessionPayload>.self, from: data) else { return }
            handleCreateSessionRequest(envelope)
        default:
            break
        }
    }

    private func handleChallenge(_ payload: ChallengePayload) {
        connectionState = .authenticating

        let signature = signNonce(payload.nonce)
        send(
            type: RemoteMessageType.hostAuth,
            target: relayPeer,
            payload: SignedChallengePayload(nonce: payload.nonce, signature: signature)
        )

        // Until the relay emits an explicit auth ack, keep the UI usable.
        isAuthenticated = true
        connectionState = .connected

        // If a pairing was requested before auth completed, do it now
        if pendingPairingRequest {
            pendingPairingRequest = false
            requestPairing()
        }
    }

    private func sendHostHello() {
        send(
            type: RemoteMessageType.hostHello,
            target: relayPeer,
            payload: HostHelloPayload()
        )
    }

    private func sendHostRegister() {
        send(
            type: RemoteMessageType.hostRegister,
            target: relayPeer,
            payload: makeHostRegisterPayload(publicKey: publicKeyBase64)
        )
    }

    private func handleListSessionsRequest(from clientID: String) {
        activeClientIDs.insert(clientID)
        send(
            type: RemoteMessageType.sessionList,
            target: RemotePeer(kind: .client, id: clientID),
            payload: makeSessionListPayload()
        )
    }

    private func handleOpenSessionRequest(_ envelope: RemoteEnvelope<OpenSessionPayload>) {
        activeClientIDs.insert(envelope.source.id)

        let size = (cols: envelope.payload.cols, rows: envelope.payload.rows)
        requestedTerminalSizes[envelope.payload.sessionID] = size
        processManager.resizeTerminal(
            sessionID: envelope.payload.sessionID,
            cols: size.cols,
            rows: size.rows
        )

        guard let data = ScrollbackStore.shared.readScrollback(for: envelope.payload.sessionID) else { return }
        let maxSnapshotBytes = 128_000
        let snapshotData = data.count > maxSnapshotBytes ? data.suffix(maxSnapshotBytes) : data[...]
        let snapshot = String(decoding: snapshotData, as: UTF8.self)

        send(
            type: RemoteMessageType.terminalSnapshot,
            target: RemotePeer(kind: .client, id: envelope.source.id),
            payload: TerminalSnapshotPayload(
                sessionID: envelope.payload.sessionID,
                data: snapshot
            )
        )
    }

    private func handleTerminalInputRequest(_ envelope: RemoteEnvelope<TerminalInputPayload>) {
        activeClientIDs.insert(envelope.source.id)
        handleTerminalInput(envelope.payload)
    }

    private func handleTerminalResizeRequest(_ envelope: RemoteEnvelope<TerminalResizePayload>) {
        activeClientIDs.insert(envelope.source.id)
        requestedTerminalSizes[envelope.payload.sessionID] = (
            cols: envelope.payload.cols,
            rows: envelope.payload.rows
        )
        handleTerminalResize(envelope.payload)
    }

    private func handleListProjectPathsRequest(from clientID: String) {
        activeClientIDs.insert(clientID)

        let sessions = sessionManager.fetchSessions(includeArchived: true)
        var seenPaths = Set<String>()
        var recentPaths: [RecentProjectPath] = []

        for session in sessions {
            let path = session.projectPath
            guard !path.isEmpty, !seenPaths.contains(path) else { continue }
            seenPaths.insert(path)

            let url = URL(fileURLWithPath: path)
            let name = url.lastPathComponent
            let isGitRepo = FileManager.default.fileExists(
                atPath: url.appendingPathComponent(".git").path
            )

            recentPaths.append(RecentProjectPath(
                path: path,
                name: name,
                isGitRepo: isGitRepo
            ))
        }

        let groups = sessionManager.fetchGroups().map {
            SessionGroupSummary(id: $0.id, name: $0.name)
        }

        send(
            type: RemoteMessageType.projectPathsList,
            target: RemotePeer(kind: .client, id: clientID),
            payload: ProjectPathsListPayload(recentPaths: recentPaths, groups: groups)
        )
    }

    private func handleCreateSessionRequest(_ envelope: RemoteEnvelope<CreateSessionPayload>) {
        activeClientIDs.insert(envelope.source.id)
        let p = envelope.payload

        let session = sessionManager.createSession(
            name: p.name,
            projectPath: p.projectPath,
            command: p.command,
            claudeFlags: p.flags,
            groupID: p.groupID,
            worktreePath: p.useWorktree ? p.projectPath : nil,
            worktreeBranch: p.useWorktree ? "worktree/\(p.name.lowercased().replacingOccurrences(of: " ", with: "-"))" : nil
        )

        // Select the session to trigger process launch on Mac host
        sessionManager.selectedSessionID = session.id

        // If there's an initial prompt, inject it after a short delay to let the process start
        if let prompt = p.initialPrompt, !prompt.isEmpty {
            Task {
                try? await Task.sleep(for: .seconds(1.5))
                processManager.sendInput(prompt + "\n", to: session.id)
            }
        }

        let summary = SessionSummary(
            id: session.id,
            name: session.name,
            status: session.status.rawValue,
            groupID: session.groupID,
            lastPreview: session.lastMessagePreview,
            hasUnread: session.hasUnread
        )

        // Send session_created to the requesting client
        send(
            type: RemoteMessageType.sessionCreated,
            target: RemotePeer(kind: .client, id: envelope.source.id),
            payload: SessionCreatedPayload(session: summary)
        )

        // Broadcast updated session list to all connected clients
        let sessionListPayload = makeSessionListPayload()
        for clientID in activeClientIDs {
            send(
                type: RemoteMessageType.sessionList,
                target: RemotePeer(kind: .client, id: clientID),
                payload: sessionListPayload
            )
        }
    }

    private func handlePairingCreated(_ payload: PairingCreatedPayload) {
        // Use the relay URL from the response (the relay knows its own public address)
        // but fall back to our configured relay URL if empty
        let effectiveRelayURL = payload.relayURL.isEmpty ? relayURL : payload.relayURL

        let qrPayload = PairingQRCodePayload(
            relayURL: effectiveRelayURL,
            hostID: hostID,
            challengeID: payload.challengeID,
            nonce: payload.nonce,
            expiresAt: payload.expiresAt
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let jsonData = try? encoder.encode(qrPayload),
              let json = String(data: jsonData, encoding: .utf8) else { return }

        pairingTimeoutTask?.cancel()
        pairingTimeoutTask = nil
        pairingError = nil
        pairingQRPayloadJSON = json
        pairingQRImage = generateQRCode(from: json)
    }

    private func generateQRCode(from string: String) -> NSImage? {
        guard let data = string.data(using: .utf8),
              let filter = CIFilter(name: "CIQRCodeGenerator") else { return nil }

        filter.setValue(data, forKey: "inputMessage")
        filter.setValue("H", forKey: "inputCorrectionLevel")

        guard let ciImage = filter.outputImage else { return nil }

        // Scale up the tiny CIImage for display
        let scale = CGAffineTransform(scaleX: 10, y: 10)
        let scaledImage = ciImage.transformed(by: scale)

        let rep = NSCIImageRep(ciImage: scaledImage)
        let nsImage = NSImage(size: rep.size)
        nsImage.addRepresentation(rep)
        return nsImage
    }

    private func handlePairingPendingApproval(_ payload: PairingPendingApprovalPayload) {
        activeClientIDs.insert(payload.clientID)

        // Auto-approve pairing request
        send(
            type: RemoteMessageType.pairingApprove,
            target: relayPeer,
            payload: PairingApprovePayload(
                clientID: payload.clientID,
                challengeID: payload.challengeID,
                signature: signNonce(payload.challengeID)
            )
        )

        // Dismiss QR code — pairing is complete
        isPairingActive = false
        pairingQRImage = nil
        pairingQRPayloadJSON = nil
    }

    private func signNonce(_ nonce: String) -> String {
        let data = Data(nonce.utf8)
        let signature = try? signingKey.signature(for: data)
        return signature?.derRepresentation.base64EncodedString() ?? ""
    }

    private var publicKeyBase64: String {
        signingKey.publicKey.rawRepresentation.base64EncodedString()
    }

    private var relayPeer: RemotePeer {
        RemotePeer(kind: .relay, id: "relay")
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0"
    }

    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
}
