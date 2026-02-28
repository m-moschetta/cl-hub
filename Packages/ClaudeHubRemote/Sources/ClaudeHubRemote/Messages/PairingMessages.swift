import Foundation

public struct PairingCreatePayload: Codable, Sendable {
    public let ttlSeconds: Int

    public init(ttlSeconds: Int = 60) {
        self.ttlSeconds = ttlSeconds
    }

    enum CodingKeys: String, CodingKey {
        case ttlSeconds = "ttl_seconds"
    }
}

public struct PairingCreatedPayload: Codable, Sendable {
    public let challengeID: String
    public let nonce: String
    public let expiresAt: Date
    public let relayURL: String

    public init(challengeID: String, nonce: String, expiresAt: Date, relayURL: String) {
        self.challengeID = challengeID
        self.nonce = nonce
        self.expiresAt = expiresAt
        self.relayURL = relayURL
    }

    enum CodingKeys: String, CodingKey {
        case challengeID = "challenge_id"
        case nonce
        case expiresAt = "expires_at"
        case relayURL = "relay_url"
    }
}

public struct PairingRequestPayload: Codable, Sendable {
    public let hostID: String
    public let challengeID: String
    public let nonce: String
    public let deviceName: String
    public let publicKey: String

    public init(hostID: String, challengeID: String, nonce: String, deviceName: String, publicKey: String) {
        self.hostID = hostID
        self.challengeID = challengeID
        self.nonce = nonce
        self.deviceName = deviceName
        self.publicKey = publicKey
    }

    enum CodingKeys: String, CodingKey {
        case hostID = "host_id"
        case challengeID = "challenge_id"
        case nonce
        case deviceName = "device_name"
        case publicKey = "public_key"
    }
}

public struct PairingPendingApprovalPayload: Codable, Sendable {
    public let clientID: String
    public let deviceName: String
    public let publicKey: String
    public let challengeID: String

    public init(clientID: String, deviceName: String, publicKey: String, challengeID: String) {
        self.clientID = clientID
        self.deviceName = deviceName
        self.publicKey = publicKey
        self.challengeID = challengeID
    }

    enum CodingKeys: String, CodingKey {
        case clientID = "client_id"
        case deviceName = "device_name"
        case publicKey = "public_key"
        case challengeID = "challenge_id"
    }
}

public struct PairingApprovePayload: Codable, Sendable {
    public let clientID: String
    public let challengeID: String
    public let signature: String

    public init(clientID: String, challengeID: String, signature: String) {
        self.clientID = clientID
        self.challengeID = challengeID
        self.signature = signature
    }

    enum CodingKeys: String, CodingKey {
        case clientID = "client_id"
        case challengeID = "challenge_id"
        case signature
    }
}

public struct PairingSuccessPayload: Codable, Sendable {
    public let hostID: String
    public let hostName: String
    public let hostPublicKey: String

    public init(hostID: String, hostName: String, hostPublicKey: String) {
        self.hostID = hostID
        self.hostName = hostName
        self.hostPublicKey = hostPublicKey
    }

    enum CodingKeys: String, CodingKey {
        case hostID = "host_id"
        case hostName = "host_name"
        case hostPublicKey = "host_public_key"
    }
}
