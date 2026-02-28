import Foundation

/// Parses terminal output to detect the current state of a Claude Code session.
/// Uses heuristic pattern matching on ANSI-stripped text.
public final class StatusDetector: @unchecked Sendable {

    /// Patterns that indicate Claude is thinking/processing
    private static let thinkingPatterns: [String] = [
        "⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏",  // Braille spinner
        "Thinking",
        "Planning",
    ]

    /// Patterns that indicate tool use
    private static let toolUsePatterns: [String] = [
        "⏺",          // Tool marker
        "● Read(",
        "● Edit(",
        "● Write(",
        "● Bash(",
        "● Glob(",
        "● Grep(",
        "● Task(",
        "Reading",
        "Editing",
        "Writing",
        "Running",
    ]

    /// Patterns that indicate errors
    private static let errorPatterns: [String] = [
        "Error:",
        "error:",
        "fatal:",
        "FATAL:",
        "✗",
        "✘",
        "panic:",
        "Permission denied",
    ]

    /// Patterns that indicate idle state (prompt ready)
    private static let idlePatterns: [String] = [
        "> ",        // Claude prompt
        "❯ ",        // Alternative prompt
        "$ ",        // Shell prompt fallback
    ]

    // Ring buffer for recent lines
    private var recentLines: [String] = []
    private let maxRecentLines = 50
    private let lock = NSLock()

    public init() {}

    /// Feed a chunk of terminal output and get the detected status.
    public func processOutput(_ text: String) -> SessionStatus? {
        let stripped = stripANSI(text)
        guard !stripped.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }

        lock.lock()
        let lines = stripped.components(separatedBy: .newlines).filter { !$0.isEmpty }
        recentLines.append(contentsOf: lines)
        if recentLines.count > maxRecentLines {
            recentLines.removeFirst(recentLines.count - maxRecentLines)
        }
        let lastLines = Array(recentLines.suffix(5))
        lock.unlock()

        let combined = lastLines.joined(separator: "\n")

        // Check in priority order: error > toolUse > thinking > idle
        for pattern in Self.errorPatterns {
            if combined.contains(pattern) {
                return .error
            }
        }

        for pattern in Self.toolUsePatterns {
            if combined.contains(pattern) {
                return .toolUse
            }
        }

        for pattern in Self.thinkingPatterns {
            if combined.contains(pattern) {
                return .thinking
            }
        }

        // Check if the last line looks like a prompt
        if let lastLine = lastLines.last?.trimmingCharacters(in: .whitespaces) {
            for pattern in Self.idlePatterns {
                if lastLine.hasSuffix(pattern) || lastLine == pattern.trimmingCharacters(in: .whitespaces) {
                    return .idle
                }
            }
        }

        return nil
    }

    /// Strip ANSI escape sequences from text.
    private func stripANSI(_ text: String) -> String {
        // Matches ESC[ ... final_byte sequences (CSI) and ESC] ... ST sequences (OSC)
        let pattern = #"\x1b\[[0-9;]*[a-zA-Z]|\x1b\][^\x07]*\x07|\x1b\][^\x1b]*\x1b\\|\x1b[()][0-9A-B]"#
        return text.replacingOccurrences(
            of: pattern,
            with: "",
            options: .regularExpression
        )
    }

    /// Reset detector state (e.g., on session restart).
    public func reset() {
        lock.lock()
        recentLines.removeAll()
        lock.unlock()
    }

    /// Noise patterns to skip in preview extraction.
    private static let previewNoisePatterns: [String] = [
        "⏺", "─", "━", "╭", "╰", "│", "├", "└",
        "> ", "❯ ", "$ ",
    ]

    /// Extract a preview message from recent output (last meaningful lines).
    public func extractPreview() -> String? {
        lock.lock()
        let lines = recentLines
        lock.unlock()

        // Collect up to 2 meaningful lines from the end
        var meaningful: [String] = []
        for line in lines.reversed() {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty, trimmed.count > 2 else { continue }

            // Skip spinners
            if Self.thinkingPatterns.contains(where: { trimmed.contains($0) }) { continue }

            // Skip decorative/noise lines
            let isNoise = Self.previewNoisePatterns.contains { noise in
                trimmed.hasPrefix(noise) && trimmed.count < 6
            }
            if isNoise { continue }

            // Clean up common prefixes
            var cleaned = trimmed
            // Strip leading tool markers but keep the description
            if cleaned.hasPrefix("● ") {
                // e.g. "● Read(file.swift)" → "Read(file.swift)"
                cleaned = String(cleaned.dropFirst(2))
            }

            meaningful.insert(cleaned, at: 0)
            if meaningful.count >= 2 { break }
        }

        guard !meaningful.isEmpty else { return nil }
        return meaningful.joined(separator: " — ")
    }
}
