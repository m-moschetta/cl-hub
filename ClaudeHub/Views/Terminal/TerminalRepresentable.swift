import SwiftUI
import AppKit
import SwiftTerm
import ClaudeHubTerminal
import ClaudeHubCore

/// NSViewRepresentable wrapper for ClaudeTerminalView, bridging it into SwiftUI.
struct TerminalRepresentable: NSViewRepresentable {
    let sessionID: UUID
    let command: String
    let workingDirectory: String
    let flags: String
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

        // Set up output parser callbacks — defer to avoid mutating state during view update
        terminalView.outputParser.onStatusChange = { status in
            DispatchQueue.main.async { onStatusChange?(status) }
        }
        terminalView.outputParser.onPreviewUpdate = { preview in
            DispatchQueue.main.async { onPreviewUpdate?(preview) }
        }
        terminalView.onProcessTerminated = {
            DispatchQueue.main.async { onProcessTerminated?() }
        }

        // Set up the TerminalView delegate for output interception
        context.coordinator.terminalView = terminalView
        terminalView.processDelegate = context.coordinator

        // Restore scrollback if available, then start session
        terminalView.restoreScrollback()
        terminalView.startSession(
            command: command,
            workingDirectory: workingDirectory,
            flags: flags,
            environmentVariables: environmentVariables
        )

        // Defer onTerminalReady to next run loop — makeNSView runs during view update
        DispatchQueue.main.async { onTerminalReady?(terminalView) }

        return terminalView
    }

    func updateNSView(_ nsView: ClaudeTerminalView, context: Context) {
        // Font size updates
        // NOTE: Avoid calling internal API `setFontSize`. If `ClaudeTerminalView` exposes a public way
        // to update font size at runtime (e.g., via theme), prefer that here. For now, rely on the
        // initial theme sizing applied in makeNSView.
        _ = fontSizeOverride // intentionally unused at runtime update to avoid internal API usage
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
            guard let terminal = terminalView else { return }
            DispatchQueue.main.async {
                terminal.outputParser.onStatusChange?(.disconnected)
                terminal.onProcessTerminated?()
            }
        }
    }
}

