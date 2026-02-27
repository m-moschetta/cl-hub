import AppKit
import ClaudeHubCore

/// NSApplicationDelegate for cleanup on termination.
final class AppDelegate: NSObject, NSApplicationDelegate {

    var processManager: ProcessManager?

    func applicationWillTerminate(_ notification: Notification) {
        // Kill all child processes
        processManager?.killAll()

        // Close all scrollback file handles
        ScrollbackStore.shared.closeAll()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false  // Keep running in menu bar
    }
}
