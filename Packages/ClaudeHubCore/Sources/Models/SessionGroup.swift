import Foundation
import SwiftData

@Model
public final class SessionGroup {
    public var id: UUID
    public var name: String
    public var sortOrder: Int

    public init(name: String, sortOrder: Int = 0) {
        self.id = UUID()
        self.name = name
        self.sortOrder = sortOrder
    }
}
