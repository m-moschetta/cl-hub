import Foundation

// MARK: - Client → Host

public struct CreateSessionPayload: Codable, Sendable {
    public let name: String
    public let projectPath: String
    public let command: String
    public let flags: String
    public let groupID: UUID?
    public let useWorktree: Bool
    public let initialPrompt: String?

    public init(
        name: String,
        projectPath: String,
        command: String = "claude",
        flags: String = "",
        groupID: UUID? = nil,
        useWorktree: Bool = false,
        initialPrompt: String? = nil
    ) {
        self.name = name
        self.projectPath = projectPath
        self.command = command
        self.flags = flags
        self.groupID = groupID
        self.useWorktree = useWorktree
        self.initialPrompt = initialPrompt
    }

    enum CodingKeys: String, CodingKey {
        case name
        case projectPath = "project_path"
        case command
        case flags
        case groupID = "group_id"
        case useWorktree = "use_worktree"
        case initialPrompt = "initial_prompt"
    }
}

// MARK: - Host → Client

public struct ProjectPathsListPayload: Codable, Sendable {
    public let recentPaths: [RecentProjectPath]
    public let groups: [SessionGroupSummary]

    public init(recentPaths: [RecentProjectPath], groups: [SessionGroupSummary]) {
        self.recentPaths = recentPaths
        self.groups = groups
    }

    enum CodingKeys: String, CodingKey {
        case recentPaths = "recent_paths"
        case groups
    }
}

public struct RecentProjectPath: Codable, Sendable, Identifiable {
    public let id: UUID
    public let path: String
    public let name: String
    public let isGitRepo: Bool

    public init(id: UUID = UUID(), path: String, name: String, isGitRepo: Bool) {
        self.id = id
        self.path = path
        self.name = name
        self.isGitRepo = isGitRepo
    }

    enum CodingKeys: String, CodingKey {
        case id
        case path
        case name
        case isGitRepo = "is_git_repo"
    }
}

public struct SessionGroupSummary: Codable, Sendable, Identifiable {
    public let id: UUID
    public let name: String

    public init(id: UUID, name: String) {
        self.id = id
        self.name = name
    }
}

public struct SessionCreatedPayload: Codable, Sendable {
    public let session: SessionSummary

    public init(session: SessionSummary) {
        self.session = session
    }
}
