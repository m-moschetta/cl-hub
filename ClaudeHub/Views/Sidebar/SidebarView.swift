import SwiftUI
import SwiftData
import ClaudeHubCore

/// Main sidebar with session list, search, and groups.
struct SidebarView: View {
    @EnvironmentObject var sessionManager: SessionManager
    @Query(filter: #Predicate<Session> { !$0.isArchived },
           sort: \Session.sortOrder)
    private var sessions: [Session]

    @Query(sort: \SessionGroup.sortOrder)
    private var groups: [SessionGroup]

    @Binding var selectedSessionID: UUID?
    @State private var searchText = ""
    @State private var showNewSession = false
    @State private var showNewGroup = false
    @State private var newGroupName = ""

    var body: some View {
        VStack(spacing: 0) {
            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.tertiary)
                TextField("Search sessions...", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
            }
            .padding(8)
            .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 8))
            .padding(.horizontal, 12)
            .padding(.top, 8)

            // Session list
            ScrollView {
                LazyVStack(spacing: 2) {
                    // Ungrouped sessions
                    let ungrouped = filteredSessions.filter { $0.groupID == nil }
                    ForEach(ungrouped, id: \.id) { session in
                        SessionRowView(
                            session: session,
                            isSelected: session.id == selectedSessionID
                        )
                        .onTapGesture {
                            selectedSessionID = session.id
                        }
                        .contextMenu {
                            sessionContextMenu(for: session)
                        }
                    }

                    // Grouped sessions
                    ForEach(groups, id: \.id) { group in
                        let groupSessions = filteredSessions.filter { $0.groupID == group.id }
                        if !groupSessions.isEmpty {
                            SessionGroupView(
                                group: group,
                                sessions: groupSessions,
                                selectedSessionID: selectedSessionID,
                                onSelect: { session in
                                    selectedSessionID = session.id
                                }
                            )
                            .padding(.horizontal, 4)
                        }
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
            }

            Divider()

            // Bottom bar
            HStack {
                Button(action: { showNewSession = true }) {
                    Label("New Session", systemImage: "plus")
                        .font(.system(size: 12))
                }
                .buttonStyle(.borderless)

                Spacer()

                Menu {
                    Button("New Group...") { showNewGroup = true }
                    Divider()
                    Button("Show Archived") {
                        // TODO: Toggle archived visibility
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.system(size: 14))
                }
                .menuStyle(.borderlessButton)
                .frame(width: 30)
            }
            .padding(8)
        }
        .sheet(isPresented: $showNewSession) {
            NewSessionSheet()
        }
        .alert("New Group", isPresented: $showNewGroup) {
            TextField("Group name", text: $newGroupName)
            Button("Create") {
                if !newGroupName.isEmpty {
                    _ = sessionManager.createGroup(name: newGroupName)
                    newGroupName = ""
                }
            }
            Button("Cancel", role: .cancel) { newGroupName = "" }
        }
    }

    private var filteredSessions: [Session] {
        if searchText.isEmpty { return Array(sessions) }
        let query = searchText.lowercased()
        return sessions.filter { session in
            session.name.lowercased().contains(query)
            || session.projectPath.lowercased().contains(query)
            || session.lastMessagePreview.lowercased().contains(query)
        }
    }

    @ViewBuilder
    private func sessionContextMenu(for session: Session) -> some View {
        Button("Rename...") {
            // Inline rename would be better, but for now this works
        }

        Menu("Move to Group") {
            Button("No Group") {
                sessionManager.assignSession(session, toGroup: nil)
            }
            Divider()
            ForEach(groups, id: \.id) { group in
                Button(group.name) {
                    sessionManager.assignSession(session, toGroup: group)
                }
            }
        }

        Divider()

        Button("Archive") {
            sessionManager.archiveSession(session)
        }

        Button("Delete", role: .destructive) {
            if session.id == selectedSessionID {
                selectedSessionID = nil
            }
            // Clean up worktree if present
            if let worktreePath = session.worktreePath {
                GitWorktreeService.shared.removeWorktree(
                    projectPath: session.projectPath,
                    worktreePath: worktreePath,
                    branch: session.worktreeBranch
                )
            }
            ScrollbackStore.shared.deleteScrollback(for: session.id)
            sessionManager.deleteSession(session)
        }
    }
}
