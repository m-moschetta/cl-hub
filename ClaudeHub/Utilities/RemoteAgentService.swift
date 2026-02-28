import Combine
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

    let hostID: String
    let relayURL: String

    private let sessionManager: SessionManager
    private let processManager: ProcessManager
    private let transport: RemoteRelayTransport
    private var cancellables: Set<AnyCancellable> = []
    private let signingKey = P256.Signing.PrivateKey()
    private var activeClientIDs: Set<String> = []
    private var requestedTerminalSizes: [UUID: (cols: Int, rows: Int)] = [:]

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
        transport.connect(to: relayURL)
    }

    func disconnect() {
        transport.disconnect()
        isAuthenticated = false
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
        case RemoteMessageType.pairingPendingApproval:
            guard let envelope = try? Self.decoder.decode(RemoteEnvelope<PairingPendingApprovalPayload>.self, from: data) else { return }
            handlePairingPendingApproval(envelope.payload)
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

    private func handlePairingPendingApproval(_ payload: PairingPendingApprovalPayload) {
        activeClientIDs.insert(payload.clientID)
        send(
            type: RemoteMessageType.pairingApprove,
            target: relayPeer,
            payload: PairingApprovePayload(
                clientID: payload.clientID,
                challengeID: payload.challengeID,
                signature: signNonce(payload.challengeID)
            )
        )
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
