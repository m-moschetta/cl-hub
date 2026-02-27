import Foundation

/// Represents the current state of a Claude Code session.
/// Detected heuristically by parsing terminal output patterns.
public enum SessionStatus: String, Codable, CaseIterable {
    case idle
    case thinking
    case toolUse
    case error
    case disconnected

    public var displayName: String {
        switch self {
        case .idle: return "Idle"
        case .thinking: return "Thinking"
        case .toolUse: return "Tool Use"
        case .error: return "Error"
        case .disconnected: return "Disconnected"
        }
    }

    public var systemImageName: String {
        switch self {
        case .idle: return "circle.fill"
        case .thinking: return "brain"
        case .toolUse: return "hammer.fill"
        case .error: return "exclamationmark.triangle.fill"
        case .disconnected: return "xmark.circle.fill"
        }
    }

    public var colorName: String {
        switch self {
        case .idle: return "green"
        case .thinking: return "blue"
        case .toolUse: return "orange"
        case .error: return "red"
        case .disconnected: return "gray"
        }
    }
}
