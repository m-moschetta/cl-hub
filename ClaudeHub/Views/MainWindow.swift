import SwiftUI
import SwiftData
import ClaudeHubCore

/// Root view with NavigationSplitView: sidebar + detail.
struct MainWindow: View {
    @EnvironmentObject var sessionManager: SessionManager
    @EnvironmentObject var processManager: ProcessManager
    @EnvironmentObject var orchestrationEngine: OrchestrationEngine

    @State private var selectedSessionID: UUID?
    @State private var showBroadcast = false
    @State private var showTaskWizard = false
    @State private var showDashboard = false
    @State private var columnVisibility: NavigationSplitViewVisibility = .all

    @Query(filter: #Predicate<Session> { !$0.isArchived },
           sort: \Session.sortOrder)
    private var sessions: [Session]

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            SidebarView(selectedSessionID: $selectedSessionID)
                .navigationSplitViewColumnWidth(min: 240, ideal: 280, max: 360)
        } detail: {
            if showDashboard {
                DashboardView(selectedSessionID: $selectedSessionID)
                    .onChange(of: selectedSessionID) { _, newValue in
                        if newValue != nil { showDashboard = false }
                    }
            } else if let sessionID = selectedSessionID,
                      let session = sessions.first(where: { $0.id == sessionID }) {
                TerminalContainerView(session: session)
            } else {
                emptyState
            }
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
        .sheet(isPresented: $showBroadcast) {
            BroadcastSheet()
        }
        .sheet(isPresented: $showTaskWizard) {
            TaskWizardView()
        }
        .onAppear {
            selectedSessionID = sessionManager.selectedSessionID
        }
        .onChange(of: selectedSessionID) { _, newValue in
            sessionManager.selectedSessionID = newValue
        }
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
                    // Trigger new session sheet via notification
                    NotificationCenter.default.post(
                        name: .init("showNewSession"), object: nil
                    )
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
