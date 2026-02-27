import Foundation
import SwiftData

@Model
public final class Session {
    public var id: UUID
    public var name: String
    public var projectPath: String
    public var worktreePath: String?
    public var worktreeBranch: String?
    public var groupID: UUID?

    // Store status as raw string for SwiftData compatibility
    public var statusRaw: String

    public var lastMessagePreview: String
    public var lastActivityDate: Date
    public var createdDate: Date
    public var isArchived: Bool
    public var sortOrder: Int
    public var scrollbackFilePath: String?

    // Per-session settings
    public var command: String          // "claude", "opencode", "zsh", or any command
    public var claudeFlags: String
    public var environmentVariablesData: Data?
    public var workingDirectory: String
    public var fontSizeOverride: Double?

    // Process tracking
    public var lastPID: Int?

    public var status: SessionStatus {
        get { SessionStatus(rawValue: statusRaw) ?? .disconnected }
        set { statusRaw = newValue.rawValue }
    }

    public var environmentVariables: [String: String] {
        get {
            guard let data = environmentVariablesData else { return [:] }
            return (try? JSONDecoder().decode([String: String].self, from: data)) ?? [:]
        }
        set {
            environmentVariablesData = try? JSONEncoder().encode(newValue)
        }
    }

    public init(
        name: String,
        projectPath: String,
        command: String = "claude",
        worktreePath: String? = nil,
        worktreeBranch: String? = nil,
        groupID: UUID? = nil,
        claudeFlags: String = "",
        workingDirectory: String? = nil
    ) {
        self.id = UUID()
        self.name = name
        self.projectPath = projectPath
        self.command = command
        self.worktreePath = worktreePath
        self.worktreeBranch = worktreeBranch
        self.groupID = groupID
        self.statusRaw = SessionStatus.disconnected.rawValue
        self.lastMessagePreview = ""
        self.lastActivityDate = Date()
        self.createdDate = Date()
        self.isArchived = false
        self.sortOrder = 0
        self.claudeFlags = claudeFlags
        self.workingDirectory = workingDirectory ?? projectPath
    }
}
