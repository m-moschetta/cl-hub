import Foundation

/// Monitors terminal output for MCP tool call patterns.
/// Extracts tool names, arguments, and results from Claude Code's output.
public final class MCPMonitor: @unchecked Sendable {

    public struct ToolCall {
        public let timestamp: Date
        public let toolName: String
        public let preview: String

        public init(timestamp: Date, toolName: String, preview: String) {
            self.timestamp = timestamp
            self.toolName = toolName
            self.preview = preview
        }
    }

    private var recentToolCalls: [ToolCall] = []
    private let maxToolCalls = 100
    private let lock = NSLock()

    /// Known tool name patterns from Claude Code
    private static let toolPatterns: [(pattern: String, name: String)] = [
        ("Read(", "Read"),
        ("Edit(", "Edit"),
        ("Write(", "Write"),
        ("Bash(", "Bash"),
        ("Glob(", "Glob"),
        ("Grep(", "Grep"),
        ("Task(", "Task"),
        ("WebFetch(", "WebFetch"),
        ("WebSearch(", "WebSearch"),
        ("NotebookEdit(", "NotebookEdit"),
        ("mcp__", "MCP"),
    ]

    public init() {}

    /// Process a line of terminal output for tool calls.
    public func processLine(_ line: String) -> ToolCall? {
        let stripped = line.trimmingCharacters(in: .whitespacesAndNewlines)

        // Look for tool markers
        guard stripped.contains("⏺") || stripped.contains("●") else {
            return nil
        }

        for (pattern, name) in Self.toolPatterns {
            if stripped.contains(pattern) {
                let preview = extractPreview(from: stripped, toolPattern: pattern)
                let call = ToolCall(
                    timestamp: Date(),
                    toolName: name,
                    preview: preview
                )

                lock.lock()
                recentToolCalls.append(call)
                if recentToolCalls.count > maxToolCalls {
                    recentToolCalls.removeFirst()
                }
                lock.unlock()

                return call
            }
        }

        return nil
    }

    /// Get recent tool calls.
    public func getRecentCalls(limit: Int = 20) -> [ToolCall] {
        lock.lock()
        defer { lock.unlock() }
        return Array(recentToolCalls.suffix(limit))
    }

    /// Clear history.
    public func reset() {
        lock.lock()
        recentToolCalls.removeAll()
        lock.unlock()
    }

    private func extractPreview(from line: String, toolPattern: String) -> String {
        guard let range = line.range(of: toolPattern) else {
            return line
        }
        let afterPattern = String(line[range.upperBound...])
        let preview = afterPattern
            .replacingOccurrences(of: ")", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return String(preview.prefix(100))
    }
}
