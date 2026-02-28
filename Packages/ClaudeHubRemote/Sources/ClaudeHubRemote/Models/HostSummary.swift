import Foundation

public struct HostSummary: Codable, Sendable, Identifiable {
    public let id: String
    public let displayName: String
    public let isOnline: Bool
    public let lastSeenAt: Date?

    public init(
        id: String,
        displayName: String,
        isOnline: Bool,
        lastSeenAt: Date?
    ) {
        self.id = id
        self.displayName = displayName
        self.isOnline = isOnline
        self.lastSeenAt = lastSeenAt
    }

    enum CodingKeys: String, CodingKey {
        case id
        case displayName = "display_name"
        case isOnline = "is_online"
        case lastSeenAt = "last_seen_at"
    }
}
