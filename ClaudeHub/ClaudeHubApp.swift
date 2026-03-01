import SwiftUI
import SwiftData
import ClaudeHubCore

@main
struct ClaudeHubApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    let modelContainer: ModelContainer

    @StateObject private var sessionManager: SessionManager
    @StateObject private var processManager = ProcessManager()
    @StateObject private var orchestrationEngine: OrchestrationEngine
    @StateObject private var remoteAgentService: RemoteAgentService

    // State for keyboard shortcuts
    @State private var selectedSessionID: UUID?
    @State private var showNewSession = false
    @State private var showBroadcast = false
    @State private var showDashboard = false

    init() {
        let schema = Schema([
            Session.self,
            SessionGroup.self,
        ])
        let config = ModelConfiguration(
            "ClaudeHub",
            schema: schema,
            isStoredInMemoryOnly: false
        )

        do {
            let container = try ModelContainer(for: schema, configurations: [config])
            self.modelContainer = container

            let context = container.mainContext
            let sm = SessionManager(modelContext: context)
            let pm = ProcessManager()

            _sessionManager = StateObject(wrappedValue: sm)
            _processManager = StateObject(wrappedValue: pm)
            _orchestrationEngine = StateObject(wrappedValue: OrchestrationEngine(
                processManager: pm,
                sessionManager: sm
            ))
            // Persist hostID across launches so paired devices stay valid
            let defaults = UserDefaults.standard
            if defaults.string(forKey: "hostID")?.isEmpty != false {
                defaults.set(UUID().uuidString, forKey: "hostID")
            }
            let storedHostID = defaults.string(forKey: "hostID") ?? UUID().uuidString
            let storedRelayURL = defaults.string(forKey: "relayURL") ?? ""

            _remoteAgentService = StateObject(wrappedValue: RemoteAgentService(
                sessionManager: sm,
                processManager: pm,
                hostID: storedHostID,
                relayURL: storedRelayURL
            ))
        } catch {
            fatalError("Failed to create model container: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            MainWindow()
                .environmentObject(sessionManager)
                .environmentObject(processManager)
                .environmentObject(orchestrationEngine)
                .environmentObject(remoteAgentService)
                .frame(minWidth: 800, minHeight: 500)
                .onAppear {
                    appDelegate.processManager = processManager
                    NotificationManager.shared.requestAuthorization()
                    cleanupStaleProcesses()
                    remoteAgentService.connectIfConfigured()
                }
        }
        .modelContainer(modelContainer)
        .commands {
            KeyboardShortcutCommands(
                selectedSessionID: $selectedSessionID,
                showNewSession: $showNewSession,
                showBroadcast: $showBroadcast,
                showDashboard: $showDashboard,
                sessions: sessionManager.fetchSessions()
            )
        }

        Settings {
            SettingsView()
        }

        // Menu bar extra for quick switching
        MenuBarExtra("Cl.hub", systemImage: "terminal.fill") {
            MenuBarView()
                .environmentObject(sessionManager)
                .environmentObject(processManager)
                .environmentObject(remoteAgentService)
        }
    }

    private func cleanupStaleProcesses() {
        let sessions = sessionManager.fetchSessions(includeArchived: true)
        let stalePIDs = sessions.compactMap { $0.lastPID }.map { Int32($0) }
        processManager.cleanupStaleProcesses(knownPIDs: stalePIDs)

        // Reset all non-archived sessions to disconnected
        for session in sessions where !session.isArchived {
            session.status = .disconnected
        }
    }
}

/// Simple menu bar view for quick session switching.
struct MenuBarView: View {
    @EnvironmentObject var sessionManager: SessionManager
    @EnvironmentObject var processManager: ProcessManager

    var body: some View {
        let sessions = sessionManager.fetchSessions()

        if sessions.isEmpty {
            Text("No sessions")
                .foregroundStyle(.secondary)
        } else {
            ForEach(sessions, id: \.id) { session in
                Button {
                    sessionManager.selectedSessionID = session.id
                    NSApplication.shared.activate(ignoringOtherApps: true)
                    // Focus the main window
                    if let window = NSApplication.shared.windows.first(where: { $0.isKeyWindow || $0.canBecomeKey }) {
                        window.makeKeyAndOrderFront(nil)
                    }
                } label: {
                    HStack {
                        Circle()
                            .fill(statusColor(for: session.status))
                            .frame(width: 6, height: 6)
                        Text(session.name)
                        Spacer()
                        Text(session.status.displayName)
                            .foregroundStyle(.secondary)
                            .font(.caption)
                    }
                }
            }
        }

        Divider()

        Button("Quit Cl.hub") {
            NSApplication.shared.terminate(nil)
        }
        .keyboardShortcut("q")
    }

    private func statusColor(for status: SessionStatus) -> Color {
        switch status {
        case .idle: return .green
        case .thinking: return .blue
        case .toolUse: return .orange
        case .error: return .red
        case .disconnected: return .gray
        }
    }
}
