import Foundation

public struct RemoteEnvelopeHeader: Codable, Sendable {
    public let v: Int
    public let type: String
    public let messageID: UUID
    public let timestamp: Date
    public let source: RemotePeer
    public let target: RemotePeer

    public init(
        v: Int,
        type: String,
        messageID: UUID,
        timestamp: Date,
        source: RemotePeer,
        target: RemotePeer
    ) {
        self.v = v
        self.type = type
        self.messageID = messageID
        self.timestamp = timestamp
        self.source = source
        self.target = target
    }

    enum CodingKeys: String, CodingKey {
        case v
        case type
        case messageID = "message_id"
        case timestamp
        case source
        case target
    }
}
