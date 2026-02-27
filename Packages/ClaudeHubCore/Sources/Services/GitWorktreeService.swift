import Foundation

/// Manages git worktrees for session isolation.
/// Each session can optionally run in its own worktree with a dedicated branch.
public final class GitWorktreeService: @unchecked Sendable {

    public static let shared = GitWorktreeService()

    public struct WorktreeInfo {
        public let path: String
        public let branch: String
        public let head: String
    }

    public init() {}

    /// Check if a directory is a git repository.
    public func isGitRepo(at path: String) -> Bool {
        let result = shell("git -C \(quoted(path)) rev-parse --is-inside-work-tree 2>/dev/null")
        return result.trimmingCharacters(in: .whitespacesAndNewlines) == "true"
    }

    /// Create a new worktree for a session.
    /// Returns the worktree path and branch name.
    public func createWorktree(
        projectPath: String,
        sessionID: UUID
    ) -> (path: String, branch: String)? {
        let shortID = String(sessionID.uuidString.prefix(8)).lowercased()
        let branch = "claudehub/\(shortID)"
        let worktreeDir = (projectPath as NSString)
            .appendingPathComponent(".claudehub-worktrees")
        let worktreePath = (worktreeDir as NSString)
            .appendingPathComponent(shortID)

        // Create worktree directory
        try? FileManager.default.createDirectory(
            atPath: worktreeDir,
            withIntermediateDirectories: true
        )

        // Create worktree with new branch
        let result = shell(
            "git -C \(quoted(projectPath)) worktree add -b \(quoted(branch)) \(quoted(worktreePath)) 2>&1"
        )

        // Verify it was created
        if FileManager.default.fileExists(atPath: worktreePath) {
            return (worktreePath, branch)
        }

        // If branch already exists, try without -b
        let retryResult = shell(
            "git -C \(quoted(projectPath)) worktree add \(quoted(worktreePath)) \(quoted(branch)) 2>&1"
        )

        if FileManager.default.fileExists(atPath: worktreePath) {
            return (worktreePath, branch)
        }

        return nil
    }

    /// List all worktrees for a project.
    public func listWorktrees(projectPath: String) -> [WorktreeInfo] {
        let output = shell("git -C \(quoted(projectPath)) worktree list --porcelain 2>/dev/null")
        var worktrees: [WorktreeInfo] = []
        var currentPath: String?
        var currentHead: String?
        var currentBranch: String?

        for line in output.components(separatedBy: .newlines) {
            if line.hasPrefix("worktree ") {
                if let path = currentPath {
                    worktrees.append(WorktreeInfo(
                        path: path,
                        branch: currentBranch ?? "detached",
                        head: currentHead ?? ""
                    ))
                }
                currentPath = String(line.dropFirst("worktree ".count))
                currentHead = nil
                currentBranch = nil
            } else if line.hasPrefix("HEAD ") {
                currentHead = String(line.dropFirst("HEAD ".count))
            } else if line.hasPrefix("branch ") {
                let fullBranch = String(line.dropFirst("branch ".count))
                currentBranch = fullBranch.replacingOccurrences(of: "refs/heads/", with: "")
            }
        }

        if let path = currentPath {
            worktrees.append(WorktreeInfo(
                path: path,
                branch: currentBranch ?? "detached",
                head: currentHead ?? ""
            ))
        }

        return worktrees
    }

    /// Remove a worktree and optionally its branch.
    public func removeWorktree(
        projectPath: String,
        worktreePath: String,
        branch: String?,
        deleteBranch: Bool = true
    ) {
        // Remove worktree
        _ = shell("git -C \(quoted(projectPath)) worktree remove \(quoted(worktreePath)) --force 2>&1")

        // Clean up directory if still exists
        try? FileManager.default.removeItem(atPath: worktreePath)

        // Delete branch
        if deleteBranch, let branch = branch {
            _ = shell("git -C \(quoted(projectPath)) branch -D \(quoted(branch)) 2>&1")
        }

        // Prune worktree references
        _ = shell("git -C \(quoted(projectPath)) worktree prune 2>&1")
    }

    // MARK: - Helpers

    private func shell(_ command: String) -> String {
        let process = Process()
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        process.launchPath = "/bin/zsh"
        process.arguments = ["-c", command]

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return ""
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8) ?? ""
    }

    private func quoted(_ path: String) -> String {
        "'\(path.replacingOccurrences(of: "'", with: "'\\''"))'"
    }
}
