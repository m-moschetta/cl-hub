import Foundation

/// Provides multi-agent orchestration: broadcast prompts, create tasks from templates.
@MainActor
public final class OrchestrationEngine: ObservableObject {

    private let processManager: ProcessManager
    private let sessionManager: SessionManager

    public init(processManager: ProcessManager, sessionManager: SessionManager) {
        self.processManager = processManager
        self.sessionManager = sessionManager
    }

    /// Broadcast a prompt to selected sessions.
    public func broadcast(prompt: String, toSessionIDs ids: [UUID]) {
        processManager.broadcast(prompt: prompt, to: ids)
    }

    /// Create a new task: session + optional worktree + initial prompt.
    public func createTask(
        name: String,
        projectPath: String,
        prompt: String,
        useWorktree: Bool = false,
        groupID: UUID? = nil,
        claudeFlags: String = ""
    ) -> Session {
        var worktreePath: String?
        var worktreeBranch: String?

        let session = sessionManager.createSession(
            name: name,
            projectPath: projectPath,
            claudeFlags: claudeFlags,
            groupID: groupID,
            worktreePath: worktreePath,
            worktreeBranch: worktreeBranch
        )

        if useWorktree {
            let worktreeService = GitWorktreeService.shared
            if worktreeService.isGitRepo(at: projectPath),
               let result = worktreeService.createWorktree(
                   projectPath: projectPath,
                   sessionID: session.id
               ) {
                session.worktreePath = result.path
                session.worktreeBranch = result.branch
                session.workingDirectory = result.path
            }
        }

        // The initial prompt will be sent after the terminal starts
        // Store it in the session's lastMessagePreview as a pending prompt marker
        if !prompt.isEmpty {
            session.lastMessagePreview = "⏳ \(prompt)"
        }

        return session
    }

    /// Get session IDs that are currently active (have running processes).
    public func activeSessionIDs() -> [UUID] {
        Array(processManager.activeProcesses.keys)
    }
}
