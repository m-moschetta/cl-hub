import Foundation

public struct PairingQRCodePayload: Codable, Sendable {
    public let v: Int
    public let relayURL: String
    public let hostID: String
    public let challengeID: String
    public let nonce: String
    public let expiresAt: Date

    public init(
        v: Int = 1,
        relayURL: String,
        hostID: String,
        challengeID: String,
        nonce: String,
        expiresAt: Date
    ) {
        self.v = v
        self.relayURL = relayURL
        self.hostID = hostID
        self.challengeID = challengeID
        self.nonce = nonce
        self.expiresAt = expiresAt
    }

    enum CodingKeys: String, CodingKey {
        case v
        case relayURL = "relay_url"
        case hostID = "host_id"
        case challengeID = "challenge_id"
        case nonce
        case expiresAt = "expires_at"
    }
}
