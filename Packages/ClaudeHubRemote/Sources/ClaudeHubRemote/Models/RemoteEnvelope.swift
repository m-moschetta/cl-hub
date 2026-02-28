import Foundation

public struct RemoteEnvelope<Payload: Codable & Sendable>: Codable, Sendable {
    public let v: Int
    public let type: String
    public let messageID: UUID
    public let timestamp: Date
    public let source: RemotePeer
    public let target: RemotePeer
    public let payload: Payload

    public init(
        v: Int = 1,
        type: String,
        messageID: UUID = UUID(),
        timestamp: Date = Date(),
        source: RemotePeer,
        target: RemotePeer,
        payload: Payload
    ) {
        self.v = v
        self.type = type
        self.messageID = messageID
        self.timestamp = timestamp
        self.source = source
        self.target = target
        self.payload = payload
    }

    enum CodingKeys: String, CodingKey {
        case v
        case type
        case messageID = "message_id"
        case timestamp
        case source
        case target
        case payload
    }
}
