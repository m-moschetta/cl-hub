import Foundation

/// Persists terminal scrollback data to disk for session restore.
/// Stores raw terminal output in ~/Library/Application Support/ClaudeHub/scrollback/<uuid>.raw
public final class ScrollbackStore: @unchecked Sendable {

    private let baseDirectory: URL
    private var fileHandles: [UUID: FileHandle] = [:]
    private let lock = NSLock()

    public static let shared = ScrollbackStore()

    public init() {
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first!
        self.baseDirectory = appSupport
            .appendingPathComponent("ClaudeHub", isDirectory: true)
            .appendingPathComponent("scrollback", isDirectory: true)

        try? FileManager.default.createDirectory(
            at: baseDirectory,
            withIntermediateDirectories: true
        )
    }

    /// Get the file path for a session's scrollback.
    public func filePath(for sessionID: UUID) -> URL {
        baseDirectory.appendingPathComponent("\(sessionID.uuidString).raw")
    }

    /// Append raw terminal data for a session.
    public func append(data: Data, for sessionID: UUID) {
        lock.lock()
        defer { lock.unlock() }

        let handle: FileHandle
        if let existing = fileHandles[sessionID] {
            handle = existing
        } else {
            let path = filePath(for: sessionID)
            if !FileManager.default.fileExists(atPath: path.path) {
                FileManager.default.createFile(atPath: path.path, contents: nil)
            }
            guard let newHandle = FileHandle(forWritingAtPath: path.path) else { return }
            newHandle.seekToEndOfFile()
            fileHandles[sessionID] = newHandle
            handle = newHandle
        }

        handle.write(data)
    }

    /// Read all scrollback data for a session.
    public func readScrollback(for sessionID: UUID) -> Data? {
        let path = filePath(for: sessionID)
        return try? Data(contentsOf: path)
    }

    /// Delete scrollback for a session.
    public func deleteScrollback(for sessionID: UUID) {
        lock.lock()
        fileHandles[sessionID]?.closeFile()
        fileHandles.removeValue(forKey: sessionID)
        lock.unlock()

        let path = filePath(for: sessionID)
        try? FileManager.default.removeItem(at: path)
    }

    /// Close file handle without deleting (for app termination).
    public func closeHandle(for sessionID: UUID) {
        lock.lock()
        fileHandles[sessionID]?.closeFile()
        fileHandles.removeValue(forKey: sessionID)
        lock.unlock()
    }

    /// Close all open handles.
    public func closeAll() {
        lock.lock()
        for (_, handle) in fileHandles {
            handle.closeFile()
        }
        fileHandles.removeAll()
        lock.unlock()
    }

    /// Get total scrollback size for a session (for memory management).
    public func scrollbackSize(for sessionID: UUID) -> UInt64 {
        let path = filePath(for: sessionID)
        let attrs = try? FileManager.default.attributesOfItem(atPath: path.path)
        return (attrs?[.size] as? UInt64) ?? 0
    }

    /// List all session IDs that have scrollback data.
    public func allSessionIDs() -> [UUID] {
        let files = (try? FileManager.default.contentsOfDirectory(
            at: baseDirectory,
            includingPropertiesForKeys: nil
        )) ?? []
        return files.compactMap { url -> UUID? in
            let name = url.deletingPathExtension().lastPathComponent
            return UUID(uuidString: name)
        }
    }
}
