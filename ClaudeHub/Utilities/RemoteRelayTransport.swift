import Combine
import Foundation
import ClaudeHubRemote

@MainActor
final class RemoteRelayTransport: ObservableObject {
    @Published private(set) var connectionState: RelayConnectionState = .disconnected

    var onTextMessage: ((String) -> Void)?

    private let session: URLSession
    private var webSocketTask: URLSessionWebSocketTask?

    init(session: URLSession = .shared) {
        self.session = session
    }

    func connect(to relayURL: String) {
        guard !relayURL.isEmpty,
              let url = URL(string: relayURL) else {
            connectionState = .disconnected
            return
        }

        disconnect()

        connectionState = .connecting
        let task = session.webSocketTask(with: url)
        webSocketTask = task
        task.resume()
        connectionState = .connected
        receiveNextMessage()
    }

    func disconnect() {
        webSocketTask?.cancel(with: .normalClosure, reason: nil)
        webSocketTask = nil
        connectionState = .disconnected
    }

    func send<Payload: Codable & Sendable>(_ envelope: RemoteEnvelope<Payload>) {
        guard let webSocketTask else { return }

        do {
            let text = try encode(envelope)
            sendRaw(text)
        } catch {
            connectionState = .disconnected
        }
    }

    func sendRaw(_ text: String) {
        guard let webSocketTask else { return }

        webSocketTask.send(.string(text)) { [weak self] error in
            if error != nil {
                Task { @MainActor in
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

    private func receiveNextMessage() {
        guard let webSocketTask else { return }

        webSocketTask.receive { [weak self] result in
            Task { @MainActor in
                guard let self else { return }

                switch result {
                case .success(let message):
                    switch message {
                    case .string(let text):
                        self.onTextMessage?(text)
                    case .data(let data):
                        if let text = String(data: data, encoding: .utf8) {
                            self.onTextMessage?(text)
                        }
                    @unknown default:
                        break
                    }
                    self.receiveNextMessage()
                case .failure:
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
