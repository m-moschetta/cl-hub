import ClaudeHubRemote
import Foundation
import Vapor

var env = try Environment.detect()
try LoggingSystem.bootstrap(from: &env)
let app = Application(env)
defer { app.shutdown() }

// Railway / Render inject PORT env var — honour it if present
if let portStr = Environment.get("PORT"), let port = Int(portStr) {
    app.http.server.configuration.port = port
    app.http.server.configuration.hostname = "0.0.0.0"
}

/// The relay's own public base URL — clients need this to reconnect after pairing.
/// Set via RELAY_PUBLIC_URL env var, defaults to ws://localhost:8080
let relayPublicURL = Environment.get("RELAY_PUBLIC_URL") ?? "ws://localhost:8080"

let registry = RelayRegistry()
app.storage[RelayRegistryKey.self] = registry

configureRoutes(app, registry: registry, relayPublicURL: relayPublicURL)
try app.run()

private func configureRoutes(_ app: Application, registry: RelayRegistry, relayPublicURL: String) {
    app.get { _ in
        "ClaudeHubRelay OK"
    }

    app.webSocket("ws", "host", ":hostID") { req, ws in
        guard let hostID = req.parameters.get("hostID") else {
            ws.close(promise: nil)
            return
        }

        app.logger.notice("Host \(hostID) WebSocket connected")
        registry.setHostSocket(ws, for: hostID)

        ws.onText { ws, text in
            app.logger.notice("Host \(hostID) text received (\(text.count) chars)")
            handleHostMessage(registry: registry, hostID: hostID, ws: ws, text: text, relayPublicURL: relayPublicURL, logger: app.logger)
        }

        ws.onClose.whenComplete { _ in
            app.logger.notice("Host \(hostID) disconnected")
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
    text: String,
    relayPublicURL: String,
    logger: Logger
) {
    guard let data = text.data(using: .utf8),
          let header = try? makeDecoder().decode(RemoteEnvelopeHeader.self, from: data)
    else {
        logger.notice("Failed to decode header for host \(hostID)")
        return
    }

    logger.notice("Host message decoded: type=\(header.type)")

    switch header.type {
    case RemoteMessageType.hostRegister:
        guard let envelope = try? makeDecoder().decode(RemoteEnvelope<HostRegisterPayload>.self, from: data) else { return }
        registry.registerHost(envelope.payload, for: hostID)

    case RemoteMessageType.hostHello:
        logger.notice("Creating challenge for host \(hostID)")
        let challenge = registry.createChallenge(for: hostID)
        logger.notice("Challenge created, sending via sendJSON")
        sendJSON(
            type: RemoteMessageType.challenge,
            target: RemotePeer(kind: .host, id: hostID),
            payload: ["nonce": challenge.nonce, "expires_at": isoDate(challenge.expiresAt)],
            over: ws
        )

    case RemoteMessageType.hostAuth:
        guard let envelope = try? makeDecoder().decode(RemoteEnvelope<SignedChallengePayload>.self, from: data) else { return }
        let isValid = registry.verifyHostSignature(
            hostID: hostID,
            nonce: envelope.payload.nonce,
            signature: envelope.payload.signature
        )

        if isValid {
            sendJSON(
                type: RemoteMessageType.hostAuthenticated,
                target: RemotePeer(kind: .host, id: hostID),
                payload: [:],
                over: ws
            )
        } else {
            ws.close(promise: nil)
        }

    case RemoteMessageType.pairingCreate:
        guard let envelope = try? makeDecoder().decode(RemoteEnvelope<PairingCreatePayload>.self, from: data) else { return }
        let challenge = registry.createPairingChallenge(
            for: hostID,
            ttl: TimeInterval(envelope.payload.ttlSeconds)
        )
        sendJSON(
            type: RemoteMessageType.pairingCreated,
            target: RemotePeer(kind: .host, id: hostID),
            payload: [
                "challenge_id": challenge.challengeID,
                "nonce": challenge.nonce,
                "expires_at": isoDate(challenge.expiresAt),
                "relay_url": relayPublicURL,
            ],
            over: ws
        )

    case RemoteMessageType.pairingApprove:
        guard let envelope = try? makeDecoder().decode(RemoteEnvelope<PairingApprovePayload>.self, from: data),
              let request = registry.approvePairing(
                hostID: hostID,
                clientID: envelope.payload.clientID,
                challengeID: envelope.payload.challengeID
              ),
              let clientSocket = registry.clientSocket(for: request.clientID),
              let registration = registry.hostRegistration(for: hostID)
        else { return }

        sendJSON(
            type: RemoteMessageType.pairingSuccess,
            target: RemotePeer(kind: .client, id: request.clientID),
            payload: [
                "host_id": hostID,
                "host_name": registration.displayName,
                "host_public_key": registration.publicKey,
            ],
            over: clientSocket
        )

    case RemoteMessageType.sessionList,
         RemoteMessageType.terminalOutput,
         RemoteMessageType.terminalSnapshot,
         RemoteMessageType.sessionUpdated:
        // Pass-through: forward raw JSON to the target client
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
          let header = try? makeDecoder().decode(RemoteEnvelopeHeader.self, from: data)
    else { return }

    switch header.type {
    case RemoteMessageType.pairingRequest:
        guard let envelope = try? makeDecoder().decode(RemoteEnvelope<PairingRequestPayload>.self, from: data),
              let request = registry.beginPairingRequest(envelope.payload, clientID: clientID),
              let hostSocket = registry.hostSocket(for: request.hostID)
        else { return }

        sendJSON(
            type: RemoteMessageType.pairingPendingApproval,
            target: RemotePeer(kind: .host, id: request.hostID),
            payload: [
                "client_id": request.clientID,
                "device_name": request.deviceName,
                "public_key": request.publicKey,
                "challenge_id": request.challengeID,
            ],
            over: hostSocket
        )

    case RemoteMessageType.clientHello:
        guard let envelope = try? makeDecoder().decode(RemoteEnvelope<ClientHelloPayload>.self, from: data),
              let challenge = registry.createClientChallenge(clientID: clientID, hostID: envelope.payload.hostID)
        else {
            ws.close(promise: nil)
            return
        }

        sendJSON(
            type: RemoteMessageType.challenge,
            target: RemotePeer(kind: .client, id: clientID),
            payload: ["nonce": challenge.nonce, "expires_at": isoDate(challenge.expiresAt)],
            over: ws
        )

    case RemoteMessageType.clientAuth:
        guard let envelope = try? makeDecoder().decode(RemoteEnvelope<SignedChallengePayload>.self, from: data) else { return }
        let isValid = registry.verifyClientSignature(
            clientID: clientID,
            nonce: envelope.payload.nonce,
            signature: envelope.payload.signature
        )

        if isValid {
            sendJSON(
                type: RemoteMessageType.clientAuthenticated,
                target: RemotePeer(kind: .client, id: clientID),
                payload: [:],
                over: ws
            )
        } else {
            ws.close(promise: nil)
        }

    case RemoteMessageType.listSessions,
         RemoteMessageType.openSession,
         RemoteMessageType.terminalInput,
         RemoteMessageType.terminalInterrupt,
         RemoteMessageType.terminalResize:
        // Pass-through: forward raw JSON to the target host
        if let hostSocket = registry.hostSocket(for: header.target.id) {
            hostSocket.send(text)
        }

    default:
        break
    }
}

// MARK: - Helpers

/// Build and send a JSON envelope using JSONSerialization (avoids JSONEncoder deadlock on NIO).
private func sendJSON(
    type: String,
    target: RemotePeer,
    payload: [String: Any],
    over ws: WebSocket
) {
    let dict: [String: Any] = [
        "v": 1,
        "type": type,
        "message_id": UUID().uuidString,
        "timestamp": isoDate(Date()),
        "source": ["kind": "relay", "id": "relay"],
        "target": ["kind": target.kind.rawValue, "id": target.id],
        "payload": payload,
    ]
    guard JSONSerialization.isValidJSONObject(dict) else {
        print("[sendJSON] Invalid JSON object for type=\(type)")
        return
    }
    guard let data = try? JSONSerialization.data(withJSONObject: dict),
          let text = String(data: data, encoding: .utf8)
    else {
        print("[sendJSON] Failed to serialize JSON for type=\(type)")
        return
    }
    print("[sendJSON] Sending \(text.count) chars, type=\(type)")
    ws.send(text)
}

private func isoDate(_ date: Date) -> String {
    let f = ISO8601DateFormatter()
    f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return f.string(from: date)
}

private func makeDecoder() -> JSONDecoder {
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    return decoder
}

private struct RelayRegistryKey: StorageKey {
    typealias Value = RelayRegistry
}
