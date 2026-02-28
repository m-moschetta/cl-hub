import ClaudeHubRemote
import CryptoKit
import Foundation
import UIKit

@MainActor
final class MobileRelayClient: NSObject, ObservableObject {
    var onSessionList: (([SessionSummary]) -> Void)?
    var onTerminalSnapshot: ((UUID, String) -> Void)?
    var onTerminalOutput: ((UUID, String) -> Void)?
    var onPairingSuccess: ((PairingSuccessPayload) -> Void)?
    var onClientAuthenticated: ((PairedHostRecord) -> Void)?
    var onStatusText: ((String) -> Void)?

    private var webSocketTask: URLSessionWebSocketTask?
    private let session: URLSession
    private let credentialStore: MobileCredentialStore
    private let clientID: String
    private let signingKey: P256.Signing.PrivateKey
    private var hostID: String?
    private var activeRelayURL: String?

    override init() {
        let credentialStore = MobileCredentialStore()
        let identity = credentialStore.loadOrCreateClientIdentity()
        self.credentialStore = credentialStore
        self.clientID = identity.clientID
        self.signingKey = identity.signingKey
        self.session = URLSession(configuration: .default)
        super.init()
    }

    func connect(using payload: PairingQRCodePayload) {
        disconnect()

        hostID = payload.hostID
        activeRelayURL = payload.relayURL
        connectSocket(to: payload.relayURL)

        send(
            type: RemoteMessageType.pairingRequest,
            target: RemotePeer(kind: .relay, id: "relay"),
            payload: PairingRequestPayload(
                hostID: payload.hostID,
                challengeID: payload.challengeID,
                nonce: payload.nonce,
                deviceName: UIDevice.current.name,
                publicKey: publicKeyBase64
            )
        )
    }

    func reconnectIfPossible() {
        guard let record = credentialStore.pairedHost() else { return }

        disconnect()
        hostID = record.hostID
        activeRelayURL = record.relayURL
        connectSocket(to: record.relayURL)
        authenticatePairedClient()
    }

    func requestSessions() {
        guard let hostID else { return }
        send(
            type: RemoteMessageType.listSessions,
            target: RemotePeer(kind: .host, id: hostID),
            payload: EmptyPayload()
        )
    }

    func sendInput(_ text: String, to sessionID: UUID) {
        guard let hostID else { return }
        send(
            type: RemoteMessageType.terminalInput,
            target: RemotePeer(kind: .host, id: hostID),
            payload: TerminalInputPayload(sessionID: sessionID, text: text)
        )
    }

    func sendResize(cols: Int, rows: Int, for sessionID: UUID) {
        guard let hostID else { return }
        send(
            type: RemoteMessageType.terminalResize,
            target: RemotePeer(kind: .host, id: hostID),
            payload: TerminalResizePayload(sessionID: sessionID, cols: cols, rows: rows)
        )
    }

    func openSession(_ sessionID: UUID, cols: Int = 100, rows: Int = 28) {
        guard let hostID else { return }
        send(
            type: RemoteMessageType.openSession,
            target: RemotePeer(kind: .host, id: hostID),
            payload: OpenSessionPayload(sessionID: sessionID, cols: cols, rows: rows)
        )
    }

    func disconnect() {
        webSocketTask?.cancel(with: .normalClosure, reason: nil)
        webSocketTask = nil
    }

    private func receiveLoop() {
        webSocketTask?.receive { [weak self] result in
            guard let self else { return }

            Task { @MainActor in
                switch result {
                case .success(let message):
                    switch message {
                    case .string(let text):
                        self.handleIncomingText(text)
                    case .data(let data):
                        if let text = String(data: data, encoding: .utf8) {
                            self.handleIncomingText(text)
                        }
                    @unknown default:
                        break
                    }
                    self.receiveLoop()
                case .failure(let error):
                    self.onStatusText?("Disconnected: \(error.localizedDescription)")
                }
            }
        }
    }

    private func handleIncomingText(_ text: String) {
        guard let data = text.data(using: .utf8) else {
            onStatusText?(text)
            return
        }

        guard let header = try? Self.decoder.decode(RemoteEnvelopeHeader.self, from: data) else {
            onStatusText?(text)
            return
        }

        switch header.type {
        case RemoteMessageType.pairingSuccess:
            guard let envelope = try? Self.decoder.decode(RemoteEnvelope<PairingSuccessPayload>.self, from: data) else { return }
            if let activeRelayURL {
                credentialStore.savePairedHost(relayURL: activeRelayURL, payload: envelope.payload)
            }
            onPairingSuccess?(envelope.payload)
            onStatusText?("Paired to \(envelope.payload.hostName)")
            authenticatePairedClient()

        case RemoteMessageType.challenge:
            guard let envelope = try? Self.decoder.decode(RemoteEnvelope<ChallengePayload>.self, from: data) else { return }
            handleChallenge(envelope.payload)

        case RemoteMessageType.clientAuthenticated:
            guard let envelope = try? Self.decoder.decode(RemoteEnvelope<ClientAuthenticatedPayload>.self, from: data) else { return }
            handleAuthenticated(envelope.payload)

        case RemoteMessageType.sessionList:
            guard let envelope = try? Self.decoder.decode(RemoteEnvelope<SessionListPayload>.self, from: data) else { return }
            onSessionList?(envelope.payload.sessions)

        case RemoteMessageType.terminalSnapshot:
            guard let envelope = try? Self.decoder.decode(RemoteEnvelope<TerminalSnapshotPayload>.self, from: data) else { return }
            onTerminalSnapshot?(envelope.payload.sessionID, envelope.payload.data)

        case RemoteMessageType.terminalOutput:
            guard let envelope = try? Self.decoder.decode(RemoteEnvelope<TerminalOutputPayload>.self, from: data) else { return }
            onTerminalOutput?(envelope.payload.sessionID, envelope.payload.data)

        default:
            onStatusText?(header.type)
        }
    }

    private func handleChallenge(_ payload: ChallengePayload) {
        send(
            type: RemoteMessageType.clientAuth,
            target: RemotePeer(kind: .relay, id: "relay"),
            payload: SignedChallengePayload(
                nonce: payload.nonce,
                signature: signNonce(payload.nonce)
            )
        )
        onStatusText?("Authenticating device…")
    }

    private func handleAuthenticated(_ payload: ClientAuthenticatedPayload) {
        _ = payload
        if let record = credentialStore.pairedHost() {
            onClientAuthenticated?(record)
            onStatusText?("Connected to \(record.hostName)")
        } else {
            onStatusText?("Connected")
        }
        requestSessions()
    }

    private func send<Payload: Codable & Sendable>(
        type: String,
        target: RemotePeer,
        payload: Payload
    ) {
        guard let webSocketTask else { return }

        let envelope = RemoteEnvelope(
            type: type,
            source: RemotePeer(kind: .client, id: clientID),
            target: target,
            payload: payload
        )

        guard let data = try? Self.encoder.encode(envelope),
              let text = String(data: data, encoding: .utf8)
        else { return }

        webSocketTask.send(.string(text)) { [weak self] error in
            if let error {
                Task { @MainActor in
                    self?.onStatusText?("Send failed: \(error.localizedDescription)")
                }
            }
        }
    }

    private func connectSocket(to relayURL: String) {
        guard let relayBase = URL(string: relayURL) else {
            onStatusText?("Invalid relay URL")
            return
        }

        let wsURL = relayBase
            .deletingLastPathComponent()
            .appending(path: "ws")
            .appending(path: "client")
            .appending(path: clientID)

        let task = session.webSocketTask(with: wsURL)
        webSocketTask = task
        task.resume()
        onStatusText?("Connecting…")
        receiveLoop()
    }

    private func authenticatePairedClient() {
        guard let hostID else { return }
        send(
            type: RemoteMessageType.clientHello,
            target: RemotePeer(kind: .relay, id: "relay"),
            payload: ClientHelloPayload(hostID: hostID)
        )
    }

    private func signNonce(_ nonce: String) -> String {
        let signature = try? signingKey.signature(for: Data(nonce.utf8))
        return signature?.derRepresentation.base64EncodedString() ?? ""
    }

    private var publicKeyBase64: String {
        signingKey.publicKey.rawRepresentation.base64EncodedString()
    }

    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()

    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
}
