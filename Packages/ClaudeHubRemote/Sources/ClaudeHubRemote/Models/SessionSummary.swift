import Foundation

public struct SessionSummary: Codable, Sendable, Identifiable {
    public let id: UUID
    public let name: String
    public let status: String
    public let groupID: UUID?
    public let lastPreview: String
    public let hasUnread: Bool

    public init(
        id: UUID,
        name: String,
        status: String,
        groupID: UUID?,
        lastPreview: String,
        hasUnread: Bool
    ) {
        self.id = id
        self.name = name
        self.status = status
        self.groupID = groupID
        self.lastPreview = lastPreview
        self.hasUnread = hasUnread
    }

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case status
        case groupID = "group_id"
        case lastPreview = "last_preview"
        case hasUnread = "has_unread"
    }
}
