import Foundation

/// Tracks active terminal processes and provides broadcast capabilities.
@MainActor
public final class ProcessManager: ObservableObject {

    public struct TerminalProcess {
        public let sessionID: UUID
        public let pid: Int32
        public let sendInput: (String) -> Void
        public let resize: (Int, Int) -> Void

        public init(
            sessionID: UUID,
            pid: Int32,
            sendInput: @escaping (String) -> Void,
            resize: @escaping (Int, Int) -> Void = { _, _ in }
        ) {
            self.sessionID = sessionID
            self.pid = pid
            self.sendInput = sendInput
            self.resize = resize
        }
    }

    @Published public private(set) var activeProcesses: [UUID: TerminalProcess] = [:]

    public init() {}

    /// Register a terminal process for a session.
    public func register(process: TerminalProcess) {
        activeProcesses[process.sessionID] = process
    }

    /// Unregister a terminal process.
    public func unregister(sessionID: UUID) {
        activeProcesses.removeValue(forKey: sessionID)
    }

    /// Send input text to a specific session's terminal.
    public func sendInput(_ text: String, to sessionID: UUID) {
        activeProcesses[sessionID]?.sendInput(text)
    }

    /// Resize a specific session's pseudo-terminal.
    public func resizeTerminal(sessionID: UUID, cols: Int, rows: Int) {
        guard cols > 0, rows > 0 else { return }
        activeProcesses[sessionID]?.resize(cols, rows)
    }

    /// Broadcast a prompt to multiple sessions.
    public func broadcast(prompt: String, to sessionIDs: [UUID]) {
        let textWithNewline = prompt.hasSuffix("\n") ? prompt : prompt + "\n"
        for id in sessionIDs {
            activeProcesses[id]?.sendInput(textWithNewline)
        }
    }

    /// Broadcast to all active sessions.
    public func broadcastToAll(prompt: String) {
        broadcast(prompt: prompt, to: Array(activeProcesses.keys))
    }

    /// Kill a specific session's process.
    public func killProcess(sessionID: UUID) {
        guard let process = activeProcesses[sessionID] else { return }
        kill(process.pid, SIGTERM)
        // Give it a moment, then force kill if needed
        DispatchQueue.global().asyncAfter(deadline: .now() + 2) {
            kill(process.pid, SIGKILL)
        }
        unregister(sessionID: sessionID)
    }

    /// Kill all processes (for app termination).
    public func killAll() {
        for (_, process) in activeProcesses {
            kill(process.pid, SIGTERM)
        }
        DispatchQueue.global().asyncAfter(deadline: .now() + 2) { [activeProcesses] in
            for (_, process) in activeProcesses {
                kill(process.pid, SIGKILL)
            }
        }
        activeProcesses.removeAll()
    }

    /// Check if a session has an active process.
    public func isActive(sessionID: UUID) -> Bool {
        activeProcesses[sessionID] != nil
    }

    /// Get PID for a session.
    public func pid(for sessionID: UUID) -> Int32? {
        activeProcesses[sessionID]?.pid
    }

    /// Clean up zombie processes from previous runs.
    public func cleanupStaleProcesses(knownPIDs: [Int32]) {
        for pid in knownPIDs {
            // Check if process is still running
            if kill(pid, 0) == 0 {
                // Process exists, kill it
                kill(pid, SIGTERM)
                DispatchQueue.global().asyncAfter(deadline: .now() + 2) {
                    kill(pid, SIGKILL)
                }
            }
        }
    }
}
