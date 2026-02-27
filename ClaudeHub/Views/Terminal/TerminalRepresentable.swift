import SwiftUI
import AppKit
import SwiftTerm
import ClaudeHubTerminal
import ClaudeHubCore

/// NSViewRepresentable wrapper for ClaudeTerminalView, bridging it into SwiftUI.
struct TerminalRepresentable: NSViewRepresentable {
    let sessionID: UUID
    let workingDirectory: String
    let claudeFlags: String
    let environmentVariables: [String: String]
    let fontSizeOverride: Double?

    var onStatusChange: ((SessionStatus) -> Void)?
    var onPreviewUpdate: ((String) -> Void)?
    var onProcessTerminated: (() -> Void)?
    var onTerminalReady: ((ClaudeTerminalView) -> Void)?

    func makeNSView(context: Context) -> ClaudeTerminalView {
        let theme: TerminalTheme = .dark
        let finalTheme: TerminalTheme
        if let fontSize = fontSizeOverride {
            finalTheme = theme.withFontSize(CGFloat(fontSize))
        } else {
            finalTheme = theme
        }

        let terminalView = ClaudeTerminalView(
            sessionID: sessionID,
            theme: finalTheme,
            frame: NSRect(x: 0, y: 0, width: 800, height: 600)
        )

        // Set up output parser callbacks
        terminalView.outputParser.onStatusChange = { status in
            onStatusChange?(status)
        }
        terminalView.outputParser.onPreviewUpdate = { preview in
            onPreviewUpdate?(preview)
        }
        terminalView.onProcessTerminated = {
            onProcessTerminated?()
        }

        // Set up the TerminalView delegate for output interception
        context.coordinator.terminalView = terminalView
        terminalView.terminalDelegate = context.coordinator

        // Restore scrollback if available, then start session
        terminalView.restoreScrollback()
        terminalView.startClaudeSession(
            workingDirectory: workingDirectory,
            claudeFlags: claudeFlags,
            environmentVariables: environmentVariables
        )

        onTerminalReady?(terminalView)

        return terminalView
    }

    func updateNSView(_ nsView: ClaudeTerminalView, context: Context) {
        // Font size updates
        if let fontSize = fontSizeOverride {
            nsView.setFontSize(CGFloat(fontSize))
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    class Coordinator: NSObject, LocalProcessTerminalViewDelegate {
        weak var terminalView: ClaudeTerminalView?

        func sizeChanged(source: LocalProcessTerminalView, newCols: Int, newRows: Int) {
            // Terminal size changed, nothing extra needed
        }

        func setTerminalTitle(source: LocalProcessTerminalView, title: String) {
            // Could update window title if needed
        }

        func hostCurrentDirectoryUpdate(source: TerminalView, directory: String?) {
            // Could track working directory changes
        }

        func processTerminated(source: TerminalView, exitCode: Int32?) {
            // Already handled by ClaudeTerminalView.onProcessTerminated
        }

        // Intercept data for parsing
        func dataReceived(slice: ArraySlice<UInt8>) {
            guard let terminal = terminalView else { return }
            let data = Data(slice)
            terminal.outputParser.processData(data)
        }
    }
}
