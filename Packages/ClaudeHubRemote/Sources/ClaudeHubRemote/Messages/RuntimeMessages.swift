import Foundation

public struct SessionListPayload: Codable, Sendable {
    public let sessions: [SessionSummary]

    public init(sessions: [SessionSummary]) {
        self.sessions = sessions
    }
}

public struct OpenSessionPayload: Codable, Sendable {
    public let sessionID: UUID
    public let cols: Int
    public let rows: Int

    public init(sessionID: UUID, cols: Int, rows: Int) {
        self.sessionID = sessionID
        self.cols = cols
        self.rows = rows
    }

    enum CodingKeys: String, CodingKey {
        case sessionID = "session_id"
        case cols
        case rows
    }
}

public struct TerminalSnapshotPayload: Codable, Sendable {
    public let sessionID: UUID
    public let data: String

    public init(sessionID: UUID, data: String) {
        self.sessionID = sessionID
        self.data = data
    }

    enum CodingKeys: String, CodingKey {
        case sessionID = "session_id"
        case data
    }
}

public struct TerminalOutputPayload: Codable, Sendable {
    public let sessionID: UUID
    public let data: String

    public init(sessionID: UUID, data: String) {
        self.sessionID = sessionID
        self.data = data
    }

    enum CodingKeys: String, CodingKey {
        case sessionID = "session_id"
        case data
    }
}

public struct TerminalInputPayload: Codable, Sendable {
    public let sessionID: UUID
    public let text: String

    public init(sessionID: UUID, text: String) {
        self.sessionID = sessionID
        self.text = text
    }

    enum CodingKeys: String, CodingKey {
        case sessionID = "session_id"
        case text
    }
}

public struct TerminalInterruptPayload: Codable, Sendable {
    public let sessionID: UUID

    public init(sessionID: UUID) {
        self.sessionID = sessionID
    }

    enum CodingKeys: String, CodingKey {
        case sessionID = "session_id"
    }
}

public struct TerminalResizePayload: Codable, Sendable {
    public let sessionID: UUID
    public let cols: Int
    public let rows: Int

    public init(sessionID: UUID, cols: Int, rows: Int) {
        self.sessionID = sessionID
        self.cols = cols
        self.rows = rows
    }

    enum CodingKeys: String, CodingKey {
        case sessionID = "session_id"
        case cols
        case rows
    }
}

public struct SessionUpdatedPayload: Codable, Sendable {
    public let session: SessionSummary

    public init(session: SessionSummary) {
        self.session = session
    }
}
