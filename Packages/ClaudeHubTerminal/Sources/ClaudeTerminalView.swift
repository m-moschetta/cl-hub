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
    public var processPID: Int32? {
        getTerminal().getPid?()
    }

    /// Callback when the process terminates.
    public var onProcessTerminated: (() -> Void)?

    /// Callback for sending input (used by ProcessManager).
    public var sendInputHandler: ((String) -> Void)?

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

    // MARK: - Configuration

    private func configureAppearance() {
        let terminal = getTerminal()

        // Apply theme colors
        terminal.backgroundColor = nativeForegroundColor(theme.background)
        terminal.foregroundColor = nativeForegroundColor(theme.foreground)

        // Set ANSI colors
        for (index, color) in theme.ansiColors.enumerated() where index < 16 {
            terminal.installColors(
                DefaultColorMap(
                    ansiColors: theme.ansiColors.map { nativeForegroundColor($0) }
                )
            )
            break  // installColors sets all at once
        }

        // Font
        let font = theme.font
        terminal.setFont(font: font, cellDimensions: nil)
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

    /// Start a Claude Code session in the specified directory.
    public func startClaudeSession(
        workingDirectory: String,
        claudeFlags: String = "",
        environmentVariables: [String: String] = [:]
    ) {
        var env = ProcessInfo.processInfo.environment
        // Merge custom env vars
        for (key, value) in environmentVariables {
            env[key] = value
        }
        // Ensure proper terminal type
        env["TERM"] = "xterm-256color"
        env["COLORTERM"] = "truecolor"

        let claudeCommand: String
        if claudeFlags.isEmpty {
            claudeCommand = "claude"
        } else {
            claudeCommand = "claude \(claudeFlags)"
        }

        // Use login shell to pick up PATH and other env
        let shellArgs = ["-l", "-c", "cd \(shellQuoted(workingDirectory)) && \(claudeCommand)"]

        startProcess(
            executable: "/bin/zsh",
            args: shellArgs,
            environment: env.map { "\($0.key)=\($0.value)" },
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
        feed(byteArray: [UInt8](data))
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

    public override func processTerminated(_ source: Terminal, exitCode: Int32?) {
        super.processTerminated(source, exitCode: exitCode)
        outputParser.onStatusChange?(.disconnected)
        onProcessTerminated?()
    }

    // Note: SwiftTerm's LocalProcessTerminalView calls hostCurrentDirectoryUpdate
    // and other delegate methods. For output interception, we rely on the
    // TerminalViewDelegate methods that the Coordinator in TerminalRepresentable implements.

    // MARK: - Helpers

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
}
