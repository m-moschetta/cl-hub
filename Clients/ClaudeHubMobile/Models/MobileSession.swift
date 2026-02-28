import Foundation

struct MobileSession: Identifiable, Hashable {
    let id: UUID
    var name: String
    var status: String
    var lastPreview: String
    var hasUnread: Bool
    var transcript: String

    init(
        id: UUID,
        name: String,
        status: String,
        lastPreview: String,
        hasUnread: Bool,
        transcript: String = ""
    ) {
        self.id = id
        self.name = name
        self.status = status
        self.lastPreview = lastPreview
        self.hasUnread = hasUnread
        self.transcript = transcript
    }
}
