import Foundation
import SwiftData

/// Manages CRUD operations for sessions and session groups.
@MainActor
public final class SessionManager: ObservableObject {
    private let modelContext: ModelContext

    @Published public var selectedSessionID: UUID?

    public init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: - Sessions

    public func createSession(
        name: String,
        projectPath: String,
        claudeFlags: String = "",
        groupID: UUID? = nil,
        worktreePath: String? = nil,
        worktreeBranch: String? = nil
    ) -> Session {
        let session = Session(
            name: name,
            projectPath: projectPath,
            worktreePath: worktreePath,
            worktreeBranch: worktreeBranch,
            groupID: groupID,
            claudeFlags: claudeFlags
        )

        // Set sort order to end of list
        let descriptor = FetchDescriptor<Session>(
            sortBy: [SortDescriptor(\.sortOrder, order: .reverse)]
        )
        let maxOrder = (try? modelContext.fetch(descriptor).first?.sortOrder) ?? -1
        session.sortOrder = maxOrder + 1

        modelContext.insert(session)
        try? modelContext.save()
        return session
    }

    public func deleteSession(_ session: Session) {
        modelContext.delete(session)
        try? modelContext.save()
    }

    public func archiveSession(_ session: Session) {
        session.isArchived = true
        session.lastActivityDate = Date()
        try? modelContext.save()
    }

    public func renameSession(_ session: Session, to newName: String) {
        session.name = newName
        try? modelContext.save()
    }

    public func updateSessionStatus(_ session: Session, status: SessionStatus) {
        session.status = status
        session.lastActivityDate = Date()
        try? modelContext.save()
    }

    public func updateLastPreview(_ session: Session, preview: String) {
        session.lastMessagePreview = String(preview.prefix(200))
        session.lastActivityDate = Date()
        try? modelContext.save()
    }

    public func reorderSessions(_ sessions: [Session]) {
        for (index, session) in sessions.enumerated() {
            session.sortOrder = index
        }
        try? modelContext.save()
    }

    public func fetchSessions(includeArchived: Bool = false) -> [Session] {
        var descriptor = FetchDescriptor<Session>(
            sortBy: [SortDescriptor(\.sortOrder)]
        )
        if !includeArchived {
            descriptor.predicate = #Predicate { !$0.isArchived }
        }
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    public func fetchSession(by id: UUID) -> Session? {
        var descriptor = FetchDescriptor<Session>(
            predicate: #Predicate { $0.id == id }
        )
        descriptor.fetchLimit = 1
        return try? modelContext.fetch(descriptor).first
    }

    // MARK: - Groups

    public func createGroup(name: String) -> SessionGroup {
        let group = SessionGroup(name: name)
        let descriptor = FetchDescriptor<SessionGroup>(
            sortBy: [SortDescriptor(\.sortOrder, order: .reverse)]
        )
        let maxOrder = (try? modelContext.fetch(descriptor).first?.sortOrder) ?? -1
        group.sortOrder = maxOrder + 1

        modelContext.insert(group)
        try? modelContext.save()
        return group
    }

    public func deleteGroup(_ group: SessionGroup) {
        // Unassign sessions from this group
        let groupID = group.id
        var descriptor = FetchDescriptor<Session>(
            predicate: #Predicate { $0.groupID == groupID }
        )
        if let sessions = try? modelContext.fetch(descriptor) {
            for session in sessions {
                session.groupID = nil
            }
        }
        modelContext.delete(group)
        try? modelContext.save()
    }

    public func fetchGroups() -> [SessionGroup] {
        let descriptor = FetchDescriptor<SessionGroup>(
            sortBy: [SortDescriptor(\.sortOrder)]
        )
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    public func assignSession(_ session: Session, toGroup group: SessionGroup?) {
        session.groupID = group?.id
        try? modelContext.save()
    }
}
