import AppKit
import SwiftTerm
import ClaudeHubCore

/// A terminal view that runs a Claude Code session.
/// Subclasses LocalProcessTerminalView to intercept output for status detection and scrollback.
public class ClaudeTerminalView: LocalProcessTerminalView {

    public let sessionID: UUID
    public let outputParser: TerminalOutputParser
    private var theme: TerminalTheme

    /// The PID of the running process, if any.
    public var processPID: pid_t? {
        let pid = process.shellPid
        return pid != 0 ? pid : nil
    }

    /// Callback when the process terminates.
    public var onProcessTerminated: (() -> Void)?

    /// Callback for sending input (used by ProcessManager).
    public var sendInputHandler: ((String) -> Void)?

    /// Callback for raw terminal output, before any remote transport encoding.
    public var onRawOutput: ((Data) -> Void)?

    public init(
        sessionID: UUID,
        theme: TerminalTheme = .dark,
        frame: NSRect = .zero
    ) {
        self.sessionID = sessionID
        self.outputParser = TerminalOutputParser(sessionID: sessionID)
        self.theme = theme
        super.init(frame: frame)
        configureAppearance()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    // MARK: - Layout

    /// Prevent SwiftUI layout recursion by reporting no intrinsic size.
    /// SwiftUI will assign the available space instead of negotiating with the NSView.
    public override var intrinsicContentSize: NSSize {
        NSSize(width: NSView.noIntrinsicMetric, height: NSView.noIntrinsicMetric)
    }

    // MARK: - Configuration

    private func configureAppearance() {
        let terminal = getTerminal()

        // Apply theme colors
        terminal.backgroundColor = nativeForegroundColor(theme.background)
        terminal.foregroundColor = nativeForegroundColor(theme.foreground)

        // Font
        let font = theme.font
        self.font = font
    }

    private func nativeForegroundColor(_ color: NSColor) -> Color {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        let converted = color.usingColorSpace(.sRGB) ?? color
        converted.getRed(&r, green: &g, blue: &b, alpha: &a)
        return Color(
            red: UInt16(r * 65535),
            green: UInt16(g * 65535),
            blue: UInt16(b * 65535)
        )
    }

    // MARK: - Process Management

    /// Start a session in the specified directory with any command.
    /// - Parameters:
    ///   - command: The command to run ("claude", "opencode", "zsh", or any executable)
    ///   - workingDirectory: The directory to cd into before running
    ///   - flags: Additional flags appended to the command
    ///   - environmentVariables: Per-session env var overrides
    public func startSession(
        command: String = "claude",
        workingDirectory: String,
        flags: String = "",
        environmentVariables: [String: String] = [:]
    ) {
        // Resolve the command to an absolute path
        let resolvedCommand: String
        if command.hasPrefix("/") {
            // Already absolute
            resolvedCommand = command
        } else if command == "zsh" || command == "bash" {
            // Plain shell — no resolution needed, just launch interactively
            resolvedCommand = command
        } else {
            // Resolve via login shell (works for claude, opencode, etc.)
            resolvedCommand = Self.resolveCommandPath(command)
        }

        let fullCommand: String
        if flags.isEmpty {
            fullCommand = shellQuoted(resolvedCommand)
        } else {
            fullCommand = "\(shellQuoted(resolvedCommand)) \(flags)"
        }

        // Build env var exports for per-session overrides
        var envExports = "unset CLAUDECODE CLAUDE_CODE; export TERM=xterm-256color; export COLORTERM=truecolor"
        for (key, value) in environmentVariables {
            envExports += "; export \(key)=\(shellQuoted(value))"
        }

        let isPlainShell = (command == "zsh" || command == "bash")
        let execCommand: String
        if isPlainShell {
            // For plain shells, just cd and start interactive
            execCommand = "\(envExports); cd \(shellQuoted(workingDirectory)) && exec \(command)"
        } else {
            execCommand = "\(envExports); cd \(shellQuoted(workingDirectory)) && exec \(fullCommand)"
        }

        let shellArgs = ["-c", execCommand]

        startProcess(
            executable: "/bin/zsh",
            args: shellArgs,
            environment: nil,
            execName: nil
        )

        // Set up input handler for ProcessManager
        sendInputHandler = { [weak self] text in
            self?.send(txt: text)
        }
    }

    /// Restore scrollback from a previous session.
    public func restoreScrollback() {
        guard let data = ScrollbackStore.shared.readScrollback(for: sessionID) else { return }
        feed(byteArray: [UInt8](data)[...])
    }

    /// Apply a new theme to the terminal.
    public func applyTheme(_ newTheme: TerminalTheme) {
        self.theme = newTheme
        configureAppearance()
        setNeedsDisplay(bounds)
    }

    /// Update font size.
    public func setFontSize(_ size: CGFloat) {
        let newTheme = theme.withFontSize(size)
        applyTheme(newTheme)
    }

    // MARK: - Output Interception

    /// Override dataReceived to intercept terminal output for status detection and scrollback.
    public override func dataReceived(slice: ArraySlice<UInt8>) {
        super.dataReceived(slice: slice)
        let data = Data(slice)
        outputParser.processData(data)
        onRawOutput?(data)
    }

    // MARK: - Helpers

    /// Resolves any command name to its absolute path via a login shell.
    private static var _pathCache: [String: String] = [:]

    private static func resolveCommandPath(_ command: String) -> String {
        if let cached = _pathCache[command] { return cached }

        // 1. Ask a login interactive shell where the command is
        let proc = Process()
        let pipe = Pipe()
        proc.standardOutput = pipe
        proc.standardError = FileHandle.nullDevice
        proc.executableURL = URL(fileURLWithPath: "/bin/zsh")
        proc.arguments = ["-l", "-i", "-c", "which \(command)"]
        do {
            try proc.run()
            proc.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let resolved = (String(data: data, encoding: .utf8) ?? "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if !resolved.isEmpty && resolved.hasPrefix("/") {
                _pathCache[command] = resolved
                return resolved
            }
        } catch {}

        // 2. Check well-known locations manually
        let home = ProcessInfo.processInfo.environment["HOME"] ?? NSHomeDirectory()
        let candidates = [
            "\(home)/.local/bin/\(command)",
            "/opt/homebrew/bin/\(command)",
            "/usr/local/bin/\(command)",
        ]
        for candidate in candidates {
            if FileManager.default.fileExists(atPath: candidate) {
                _pathCache[command] = candidate
                return candidate
            }
        }

        return command
    }

    private func shellQuoted(_ path: String) -> String {
        "'\(path.replacingOccurrences(of: "'", with: "'\\''"))'"
    }

    /// Send text input to the terminal.
    public func sendText(_ text: String) {
        send(txt: text)
    }

    /// Send a newline-terminated command.
    public func sendCommand(_ command: String) {
        send(txt: command + "\n")
    }

    /// Resize the underlying pseudo-terminal using the requested character grid.
    public func resizeTerminal(cols: Int, rows: Int) {
        guard process.running, cols > 0, rows > 0 else { return }

        var size = winsize(
            ws_row: UInt16(clamping: rows),
            ws_col: UInt16(clamping: cols),
            ws_xpixel: UInt16(clamping: Int(frame.width)),
            ws_ypixel: UInt16(clamping: Int(frame.height))
        )

        let result = PseudoTerminalHelpers.setWinSize(
            masterPtyDescriptor: process.childfd,
            windowSize: &size
        )

        guard result == 0 else { return }
        getTerminal().resize(cols: cols, rows: rows)
    }
}
