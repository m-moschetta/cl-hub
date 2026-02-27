import SwiftUI
import SwiftData
import ClaudeHubCore

/// Keyboard shortcut commands for the app.
struct KeyboardShortcutCommands: Commands {

    @Binding var selectedSessionID: UUID?
    @Binding var showNewSession: Bool
    @Binding var showBroadcast: Bool
    @Binding var showDashboard: Bool

    let sessions: [Session]

    var body: some Commands {
        // New Session: Cmd+N
        CommandGroup(after: .newItem) {
            Button("New Session") {
                showNewSession = true
            }
            .keyboardShortcut("n", modifiers: .command)
        }

        // Session switching: Cmd+1 through Cmd+9
        CommandMenu("Sessions") {
            ForEach(Array(sessions.prefix(9).enumerated()), id: \.element.id) { index, session in
                Button(session.name) {
                    selectedSessionID = session.id
                }
                .keyboardShortcut(
                    KeyEquivalent(Character("\(index + 1)")),
                    modifiers: .command
                )
            }

            Divider()

            Button("Dashboard") {
                showDashboard.toggle()
            }
            .keyboardShortcut("d", modifiers: [.command, .shift])

            Button("Broadcast Prompt") {
                showBroadcast = true
            }
            .keyboardShortcut("b", modifiers: [.command, .shift])
        }
    }
}
