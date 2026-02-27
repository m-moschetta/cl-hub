import SwiftUI
import SwiftData
import ClaudeHubCore

/// Root view using HSplitView to keep terminal processes alive across selection changes.
/// NavigationSplitView destroys detail content on selection change, which kills terminal processes.
/// HSplitView preserves both panes independently.
struct MainWindow: View {
    @EnvironmentObject var sessionManager: SessionManager
    @EnvironmentObject var processManager: ProcessManager
    @EnvironmentObject var orchestrationEngine: OrchestrationEngine

    @State private var selectedSessionID: UUID?
    @State private var activatedSessionIDs: Set<UUID> = []
    @State private var showNewSession = false
    @State private var showBroadcast = false
    @State private var showTaskWizard = false
    @State private var showDashboard = false

    @Query(filter: #Predicate<Session> { !$0.isArchived },
           sort: \Session.sortOrder)
    private var sessions: [Session]

    var body: some View {
        HSplitView {
            // Sidebar
            SidebarView(selectedSessionID: $selectedSessionID)
                .frame(minWidth: 240, idealWidth: 280, maxWidth: 360)

            // Detail: terminals live in a ZStack, show/hide by opacity
            ZStack {
                if showDashboard {
                    DashboardView(selectedSessionID: $selectedSessionID)
                        .onChange(of: selectedSessionID) { _, newValue in
                            if newValue != nil { showDashboard = false }
                        }
                }

                // Terminals for activated sessions — kept alive permanently
                ForEach(activatedSessions, id: \.id) { session in
                    let isVisible = session.id == selectedSessionID && !showDashboard
                    TerminalContainerView(session: session)
                        .opacity(isVisible ? 1 : 0)
                        .allowsHitTesting(isVisible)
                }

                if selectedSessionID == nil && !showDashboard {
                    emptyState
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button(action: { showDashboard.toggle() }) {
                    Image(systemName: showDashboard ? "square.grid.2x2.fill" : "square.grid.2x2")
                }
                .help("Dashboard")

                Button(action: { showBroadcast = true }) {
                    Image(systemName: "megaphone")
                }
                .help("Broadcast Prompt (Cmd+Shift+B)")

                Button(action: { showTaskWizard = true }) {
                    Image(systemName: "plus.rectangle.on.folder")
                }
                .help("New Task")
            }
        }
        .sheet(isPresented: $showNewSession) {
            NewSessionSheet()
        }
        .sheet(isPresented: $showBroadcast) {
            BroadcastSheet()
        }
        .sheet(isPresented: $showTaskWizard) {
            TaskWizardView()
        }
        .task {
            selectedSessionID = sessionManager.selectedSessionID
        }
        .onChange(of: selectedSessionID) { _, newValue in
            sessionManager.selectedSessionID = newValue
            if let id = newValue {
                activatedSessionIDs.insert(id)
            }
        }
    }

    /// Sessions that have been selected at least once — only these get a terminal.
    private var activatedSessions: [Session] {
        sessions.filter { activatedSessionIDs.contains($0.id) }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "terminal")
                .font(.system(size: 48))
                .foregroundStyle(.quaternary)

            Text("No Session Selected")
                .font(.title2)
                .foregroundStyle(.secondary)

            Text("Create a new session or select one from the sidebar")
                .font(.body)
                .foregroundStyle(.tertiary)

            HStack(spacing: 12) {
                Button("New Session") {
                    showNewSession = true
                }
                .buttonStyle(.borderedProminent)

                Button("Dashboard") {
                    showDashboard = true
                }
                .buttonStyle(.bordered)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
