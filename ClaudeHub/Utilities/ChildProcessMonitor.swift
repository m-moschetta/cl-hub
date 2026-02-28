import Foundation
import Combine

/// Monitors child processes of a given PID, polling periodically.
final class ChildProcessMonitor: ObservableObject {

    struct ChildProcess: Identifiable, Equatable {
        let pid: Int32
        let name: String
        var id: Int32 { pid }
    }

    @Published private(set) var children: [ChildProcess] = []

    private var parentPID: Int32?
    private var timer: AnyCancellable?

    /// Start monitoring children of the given PID.
    func start(parentPID: Int32) {
        self.parentPID = parentPID
        // Poll every 2 seconds
        timer = Timer.publish(every: 2, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.refresh()
            }
        // Initial scan
        refresh()
    }

    /// Stop monitoring.
    func stop() {
        timer?.cancel()
        timer = nil
        children = []
    }

    /// Force a refresh now.
    func refresh() {
        guard let ppid = parentPID else { return }
        DispatchQueue.global(qos: .utility).async { [weak self] in
            let result = Self.findDescendants(of: ppid)
            DispatchQueue.main.async {
                self?.children = result
            }
        }
    }

    /// Recursively find all descendant processes of a PID.
    private static func findDescendants(of pid: Int32) -> [ChildProcess] {
        // Get direct children
        let directChildren = getChildPIDs(of: pid)
        var all: [ChildProcess] = []

        for childPID in directChildren {
            let name = getProcessName(pid: childPID)
            // Skip shell wrappers and trivial processes
            let shortName = (name as NSString).lastPathComponent
            if ["zsh", "bash", "sh", "login"].contains(shortName) {
                // Descend into shell wrappers but don't show them
                all.append(contentsOf: findDescendants(of: childPID))
            } else if !shortName.isEmpty {
                all.append(ChildProcess(pid: childPID, name: shortName))
                // Also check for grandchildren
                all.append(contentsOf: findDescendants(of: childPID))
            }
        }

        return all
    }

    /// Get direct child PIDs of a process.
    private static func getChildPIDs(of pid: Int32) -> [Int32] {
        let proc = Process()
        let pipe = Pipe()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/pgrep")
        proc.arguments = ["-P", "\(pid)"]
        proc.standardOutput = pipe
        proc.standardError = FileHandle.nullDevice

        do {
            try proc.run()
            proc.waitUntilExit()
        } catch {
            return []
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let output = String(data: data, encoding: .utf8) else { return [] }

        return output.split(separator: "\n").compactMap { Int32($0.trimmingCharacters(in: .whitespaces)) }
    }

    /// Get the command name for a PID.
    private static func getProcessName(pid: Int32) -> String {
        let proc = Process()
        let pipe = Pipe()
        proc.executableURL = URL(fileURLWithPath: "/bin/ps")
        proc.arguments = ["-p", "\(pid)", "-o", "comm="]
        proc.standardOutput = pipe
        proc.standardError = FileHandle.nullDevice

        do {
            try proc.run()
            proc.waitUntilExit()
        } catch {
            return ""
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return (String(data: data, encoding: .utf8) ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
