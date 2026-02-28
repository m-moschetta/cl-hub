import Combine
import Foundation
import ClaudeHubRemote
import os.log

private let logger = Logger(subsystem: "com.claudehub.app", category: "RelayTransport")

@MainActor
final class RemoteRelayTransport: ObservableObject {
    @Published private(set) var connectionState: RelayConnectionState = .disconnected

    var onTextMessage: ((String) -> Void)?

    private let session: URLSession
    private var webSocketTask: URLSessionWebSocketTask?
    /// Guard against stale callbacks from previous connection attempts.
    private var connectionGeneration: UInt64 = 0

    init(session: URLSession = .shared) {
        self.session = session
    }

    /// Connect to relay. `relayURL` is either a full ws:// URL (used as-is)
    /// or a base URL that gets `/ws/host/{hostID}` appended.
    func connect(to relayURL: String, hostID: String? = nil) {
        let relayURL = relayURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !relayURL.isEmpty else {
            logger.warning("connect() called with empty relayURL")
            connectionState = .disconnected
            return
        }

        // Build the WebSocket URL: append /ws/host/{hostID} to the base if needed
        let wsURL: URL
        if let hostID, !relayURL.contains("/ws/host/") {
            guard var components = URLComponents(string: relayURL) else {
                logger.error("Failed to parse relayURL: \(relayURL, privacy: .public)")
                connectionState = .disconnected
                return
            }
            let basePath = components.path.hasSuffix("/") ? components.path : components.path + "/"
            components.path = basePath + "ws/host/" + hostID
            // Upgrade http(s) to ws(s)
            if components.scheme == "http" { components.scheme = "ws" }
            if components.scheme == "https" { components.scheme = "wss" }
            guard let url = components.url else {
                logger.error("Failed to build URL from components")
                connectionState = .disconnected
                return
            }
            wsURL = url
        } else {
            guard let url = URL(string: relayURL) else {
                logger.error("Failed to parse relayURL as URL: \(relayURL, privacy: .public)")
                connectionState = .disconnected
                return
            }
            wsURL = url
        }

        disconnect()

        connectionGeneration &+= 1
        let gen = connectionGeneration

        logger.info("Connecting to WebSocket: \(wsURL.absoluteString, privacy: .public)")
        connectionState = .connecting
        let task = session.webSocketTask(with: wsURL)
        webSocketTask = task
        task.resume()

        // Use ping to confirm the connection is actually established before receiving
        task.sendPing { [weak self] error in
            Task { @MainActor in
                guard let self, self.connectionGeneration == gen else { return }
                if let error {
                    logger.error("WebSocket ping failed: \(error.localizedDescription, privacy: .public)")
                    self.connectionState = .disconnected
                    self.webSocketTask?.cancel(with: .abnormalClosure, reason: nil)
                    self.webSocketTask = nil
                } else {
                    logger.info("WebSocket connected (ping OK) — starting receive loop")
                    self.connectionState = .connected
                    self.receiveNextMessage(generation: gen)
                }
            }
        }
    }

    func disconnect() {
        webSocketTask?.cancel(with: .normalClosure, reason: nil)
        webSocketTask = nil
        connectionState = .disconnected
    }

    func send<Payload: Codable & Sendable>(_ envelope: RemoteEnvelope<Payload>) {
        guard let webSocketTask else {
            logger.warning("send() called but no webSocketTask")
            return
        }

        do {
            let text = try encode(envelope)
            sendRaw(text)
        } catch {
            logger.error("Failed to encode envelope: \(error.localizedDescription, privacy: .public)")
            connectionState = .disconnected
        }
    }

    func sendRaw(_ text: String) {
        guard let webSocketTask else {
            logger.warning("sendRaw() called but no webSocketTask")
            return
        }

        let preview = String(text.prefix(120))
        logger.debug("Sending: \(preview, privacy: .public)…")

        webSocketTask.send(.string(text)) { [weak self] error in
            if let error {
                Task { @MainActor in
                    logger.error("WebSocket send error: \(error.localizedDescription, privacy: .public)")
                    self?.connectionState = .disconnected
                }
            }
        }
    }

    func encode<Payload: Codable & Sendable>(_ envelope: RemoteEnvelope<Payload>) throws -> String {
        let data = try Self.encoder.encode(envelope)
        guard let text = String(data: data, encoding: .utf8) else {
            throw EncodingError.invalidValue(
                envelope,
                EncodingError.Context(codingPath: [], debugDescription: "Unable to encode envelope as UTF-8 string")
            )
        }
        return text
    }

    private func receiveNextMessage(generation gen: UInt64) {
        guard let webSocketTask, connectionGeneration == gen else { return }

        webSocketTask.receive { [weak self] result in
            Task { @MainActor in
                guard let self, self.connectionGeneration == gen else { return }

                switch result {
                case .success(let message):
                    switch message {
                    case .string(let text):
                        let preview = String(text.prefix(200))
                        logger.debug("Received: \(preview, privacy: .public)")
                        self.onTextMessage?(text)
                    case .data(let data):
                        if let text = String(data: data, encoding: .utf8) {
                            logger.debug("Received data: \(text.prefix(200), privacy: .public)")
                            self.onTextMessage?(text)
                        }
                    @unknown default:
                        break
                    }
                    self.receiveNextMessage(generation: gen)
                case .failure(let error):
                    logger.error("WebSocket receive failed: \(error.localizedDescription, privacy: .public)")
                    self.connectionState = .disconnected
                    self.webSocketTask = nil
                }
            }
        }
    }

    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()
}
