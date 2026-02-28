import ClaudeHubRemote
import Foundation
import Vapor

var env = try Environment.detect()
try LoggingSystem.bootstrap(from: &env)
let app = Application(env)
defer { app.shutdown() }

let registry = RelayRegistry()
app.storage[RelayRegistryKey.self] = registry

configureRoutes(app, registry: registry)
try app.run()

private func configureRoutes(_ app: Application, registry: RelayRegistry) {
    app.get { _ in
        "ClaudeHubRelay OK"
    }

    app.webSocket("ws", "host", ":hostID") { req, ws in
        guard let hostID = req.parameters.get("hostID") else {
            ws.close(promise: nil)
            return
        }

        registry.setHostSocket(ws, for: hostID)

        ws.onText { ws, text in
            handleHostMessage(registry: registry, hostID: hostID, ws: ws, text: text)
        }

        ws.onClose.whenComplete { _ in
            registry.removeHostSocket(for: hostID)
        }
    }

    app.webSocket("ws", "client", ":clientID") { req, ws in
        guard let clientID = req.parameters.get("clientID") else {
            ws.close(promise: nil)
            return
        }

        registry.setClientSocket(ws, for: clientID)

        let payload = [
            "status": "connected",
            "client_id": clientID,
        ]
        if let data = try? JSONSerialization.data(withJSONObject: payload),
           let text = String(data: data, encoding: .utf8) {
            ws.send(text)
        }

        ws.onText { ws, text in
            handleClientMessage(registry: registry, clientID: clientID, ws: ws, text: text)
        }

        ws.onClose.whenComplete { _ in
            registry.removeClientSocket(for: clientID)
        }
    }
}

private func handleHostMessage(
    registry: RelayRegistry,
    hostID: String,
    ws: WebSocket,
    text: String
) {
    guard let data = text.data(using: .utf8),
          let header = try? decoder.decode(RemoteEnvelopeHeader.self, from: data)
    else {
        return
    }

    switch header.type {
    case RemoteMessageType.hostRegister:
        guard let envelope = try? decoder.decode(RemoteEnvelope<HostRegisterPayload>.self, from: data) else { return }
        registry.registerHost(envelope.payload, for: hostID)

    case RemoteMessageType.hostHello:
        let challenge = registry.createChallenge(for: hostID)
        let envelope = RemoteEnvelope(
            type: RemoteMessageType.challenge,
            source: relayPeer,
            target: RemotePeer(kind: .host, id: hostID),
            payload: ChallengePayload(nonce: challenge.nonce, expiresAt: challenge.expiresAt)
        )
        sendEnvelope(envelope, over: ws)

    case RemoteMessageType.hostAuth:
        guard let envelope = try? decoder.decode(RemoteEnvelope<SignedChallengePayload>.self, from: data) else { return }
        let isValid = registry.verifyHostSignature(
            hostID: hostID,
            nonce: envelope.payload.nonce,
            signature: envelope.payload.signature
        )

        if isValid {
            let ack = RemoteEnvelope(
                type: RemoteMessageType.hostAuthenticated,
                source: relayPeer,
                target: RemotePeer(kind: .host, id: hostID),
                payload: HostAuthenticatedPayload()
            )
            sendEnvelope(ack, over: ws)
        } else {
            ws.close(promise: nil)
        }

    case RemoteMessageType.pairingCreate:
        guard let envelope = try? decoder.decode(RemoteEnvelope<PairingCreatePayload>.self, from: data) else { return }
        let challenge = registry.createPairingChallenge(
            for: hostID,
            ttl: TimeInterval(envelope.payload.ttlSeconds)
        )
        let response = RemoteEnvelope(
            type: RemoteMessageType.pairingCreated,
            source: relayPeer,
            target: RemotePeer(kind: .host, id: hostID),
            payload: PairingCreatedPayload(
                challengeID: challenge.challengeID,
                nonce: challenge.nonce,
                expiresAt: challenge.expiresAt,
                relayURL: ""
            )
        )
        sendEnvelope(response, over: ws)

    case RemoteMessageType.pairingApprove:
        guard let envelope = try? decoder.decode(RemoteEnvelope<PairingApprovePayload>.self, from: data),
              let request = registry.approvePairing(
                hostID: hostID,
                clientID: envelope.payload.clientID,
                challengeID: envelope.payload.challengeID
              ),
              let clientSocket = registry.clientSocket(for: request.clientID),
              let registration = registry.hostRegistration(for: hostID)
        else { return }

        let success = RemoteEnvelope(
            type: RemoteMessageType.pairingSuccess,
            source: relayPeer,
            target: RemotePeer(kind: .client, id: request.clientID),
            payload: PairingSuccessPayload(
                hostID: hostID,
                hostName: registration.displayName,
                hostPublicKey: registration.publicKey
            )
        )
        sendEnvelope(success, over: clientSocket)

    case RemoteMessageType.sessionList,
         RemoteMessageType.terminalOutput,
         RemoteMessageType.sessionUpdated:
        if let clientSocket = registry.clientSocket(for: header.target.id) {
            clientSocket.send(text)
        }

    default:
        break
    }
}

private func handleClientMessage(
    registry: RelayRegistry,
    clientID: String,
    ws: WebSocket,
    text: String
) {
    guard let data = text.data(using: .utf8),
          let header = try? decoder.decode(RemoteEnvelopeHeader.self, from: data)
    else {
        return
    }

    switch header.type {
    case RemoteMessageType.pairingRequest:
        guard let envelope = try? decoder.decode(RemoteEnvelope<PairingRequestPayload>.self, from: data),
              let request = registry.beginPairingRequest(envelope.payload, clientID: clientID),
              let hostSocket = registry.hostSocket(for: request.hostID)
        else { return }

        let pending: RemoteEnvelope<PairingPendingApprovalPayload> = RemoteEnvelope(
            type: RemoteMessageType.pairingPendingApproval,
            source: relayPeer,
            target: RemotePeer(kind: .host, id: request.hostID),
            payload: PairingPendingApprovalPayload(
                clientID: request.clientID,
                deviceName: request.deviceName,
                publicKey: request.publicKey,
                challengeID: request.challengeID
            )
        )
        sendEnvelope(pending, over: hostSocket)

    case RemoteMessageType.clientHello:
        guard let envelope = try? decoder.decode(RemoteEnvelope<ClientHelloPayload>.self, from: data),
              let challenge = registry.createClientChallenge(clientID: clientID, hostID: envelope.payload.hostID)
        else {
            ws.close(promise: nil)
            return
        }

        let response = RemoteEnvelope(
            type: RemoteMessageType.challenge,
            source: relayPeer,
            target: RemotePeer(kind: .client, id: clientID),
            payload: ChallengePayload(nonce: challenge.nonce, expiresAt: challenge.expiresAt)
        )
        sendEnvelope(response, over: ws)

    case RemoteMessageType.clientAuth:
        guard let envelope = try? decoder.decode(RemoteEnvelope<SignedChallengePayload>.self, from: data) else { return }
        let isValid = registry.verifyClientSignature(
            clientID: clientID,
            nonce: envelope.payload.nonce,
            signature: envelope.payload.signature
        )

        if isValid {
            let ack = RemoteEnvelope(
                type: RemoteMessageType.clientAuthenticated,
                source: relayPeer,
                target: RemotePeer(kind: .client, id: clientID),
                payload: ClientAuthenticatedPayload()
            )
            sendEnvelope(ack, over: ws)
        } else {
            ws.close(promise: nil)
        }

    case RemoteMessageType.listSessions,
         RemoteMessageType.openSession,
         RemoteMessageType.terminalInput,
         RemoteMessageType.terminalInterrupt,
         RemoteMessageType.terminalResize:
        if let hostSocket = registry.hostSocket(for: header.target.id) {
            hostSocket.send(text)
        }

    default:
        break
    }
}

private func sendEnvelope<Payload: Codable & Sendable>(
    _ envelope: RemoteEnvelope<Payload>,
    over ws: WebSocket
) {
    guard let text = try? encode(envelope) else { return }
    ws.send(text)
}

private func encode<Payload: Codable & Sendable>(_ envelope: RemoteEnvelope<Payload>) throws -> String {
    let data = try encoder.encode(envelope)
    guard let text = String(data: data, encoding: .utf8) else {
        throw Abort(.internalServerError, reason: "Unable to encode envelope")
    }
    return text
}

private struct RelayRegistryKey: StorageKey {
    typealias Value = RelayRegistry
}

private let relayPeer = RemotePeer(kind: .relay, id: "relay")

private let encoder: JSONEncoder = {
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    return encoder
}()

private let decoder: JSONDecoder = {
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    return decoder
}()
