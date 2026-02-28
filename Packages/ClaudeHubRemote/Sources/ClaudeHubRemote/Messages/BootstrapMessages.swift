import Foundation

public struct HostHelloPayload: Codable, Sendable {
    public init() {}
}

public struct HostRegisterPayload: Codable, Sendable {
    public let displayName: String
    public let publicKey: String
    public let appVersion: String
    public let platform: String

    public init(displayName: String, publicKey: String, appVersion: String, platform: String) {
        self.displayName = displayName
        self.publicKey = publicKey
        self.appVersion = appVersion
        self.platform = platform
    }

    enum CodingKeys: String, CodingKey {
        case displayName = "display_name"
        case publicKey = "public_key"
        case appVersion = "app_version"
        case platform
    }
}

public struct ChallengePayload: Codable, Sendable {
    public let nonce: String
    public let expiresAt: Date

    public init(nonce: String, expiresAt: Date) {
        self.nonce = nonce
        self.expiresAt = expiresAt
    }

    enum CodingKeys: String, CodingKey {
        case nonce
        case expiresAt = "expires_at"
    }
}

public struct SignedChallengePayload: Codable, Sendable {
    public let nonce: String
    public let signature: String

    public init(nonce: String, signature: String) {
        self.nonce = nonce
        self.signature = signature
    }
}

public struct HostAuthenticatedPayload: Codable, Sendable {
    public let authenticatedAt: Date

    public init(authenticatedAt: Date = Date()) {
        self.authenticatedAt = authenticatedAt
    }

    enum CodingKeys: String, CodingKey {
        case authenticatedAt = "authenticated_at"
    }
}

public struct ClientHelloPayload: Codable, Sendable {
    public let hostID: String

    public init(hostID: String) {
        self.hostID = hostID
    }

    enum CodingKeys: String, CodingKey {
        case hostID = "host_id"
    }
}

public struct ClientAuthenticatedPayload: Codable, Sendable {
    public let authenticatedAt: Date

    public init(authenticatedAt: Date = Date()) {
        self.authenticatedAt = authenticatedAt
    }

    enum CodingKeys: String, CodingKey {
        case authenticatedAt = "authenticated_at"
    }
}
