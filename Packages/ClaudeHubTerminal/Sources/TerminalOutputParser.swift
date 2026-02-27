import Foundation
import ClaudeHubCore

/// Ring buffer that captures terminal output and delegates to StatusDetector and MCPMonitor.
public final class TerminalOutputParser: @unchecked Sendable {

    private let statusDetector: StatusDetector
    private let mcpMonitor: MCPMonitor
    private let scrollbackStore: ScrollbackStore
    private let sessionID: UUID

    /// Callback invoked on main thread when status changes.
    public var onStatusChange: ((SessionStatus) -> Void)?

    /// Callback invoked on main thread when a new preview line is available.
    public var onPreviewUpdate: ((String) -> Void)?

    /// Callback invoked when an MCP tool call is detected.
    public var onToolCall: ((MCPMonitor.ToolCall) -> Void)?

    private var lastStatus: SessionStatus?

    public init(
        sessionID: UUID,
        statusDetector: StatusDetector = StatusDetector(),
        mcpMonitor: MCPMonitor = MCPMonitor(),
        scrollbackStore: ScrollbackStore = .shared
    ) {
        self.sessionID = sessionID
        self.statusDetector = statusDetector
        self.mcpMonitor = mcpMonitor
        self.scrollbackStore = scrollbackStore
    }

    /// Process raw terminal data (called from terminal's dataReceived).
    public func processData(_ data: Data) {
        // Persist scrollback
        scrollbackStore.append(data: data, for: sessionID)

        // Convert to string for parsing
        guard let text = String(data: data, encoding: .utf8) else { return }

        // Detect status
        if let newStatus = statusDetector.processOutput(text) {
            if newStatus != lastStatus {
                lastStatus = newStatus
                let status = newStatus
                DispatchQueue.main.async { [weak self] in
                    self?.onStatusChange?(status)
                }
            }
        }

        // Extract preview
        if let preview = statusDetector.extractPreview() {
            let previewText = preview
            DispatchQueue.main.async { [weak self] in
                self?.onPreviewUpdate?(previewText)
            }
        }

        // Check for MCP tool calls
        let lines = text.components(separatedBy: .newlines)
        for line in lines {
            if let toolCall = mcpMonitor.processLine(line) {
                let call = toolCall
                DispatchQueue.main.async { [weak self] in
                    self?.onToolCall?(call)
                }
            }
        }
    }

    /// Process string output directly.
    public func processString(_ text: String) {
        if let data = text.data(using: .utf8) {
            processData(data)
        }
    }

    /// Reset all state.
    public func reset() {
        statusDetector.reset()
        mcpMonitor.reset()
        lastStatus = nil
    }
}
