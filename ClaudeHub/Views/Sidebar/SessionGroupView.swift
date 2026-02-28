import SwiftUI
import UniformTypeIdentifiers
import ClaudeHubCore

/// Collapsible group header in the sidebar.
struct SessionGroupView: View {
    let group: SessionGroup
    let sessions: [Session]
    let selectedSessionID: UUID?
    let onSelect: (Session) -> Void
    @EnvironmentObject var sessionManager: SessionManager

    @State private var isExpanded = true
    @State private var draggedSessionID: UUID?

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            ForEach(sessions, id: \.id) { session in
                SessionRowView(
                    session: session,
                    isSelected: session.id == selectedSessionID
                )
                .onTapGesture { onSelect(session) }
                .onDrag {
                    draggedSessionID = session.id
                    return NSItemProvider(object: session.id.uuidString as NSString)
                }
                .onDrop(of: [.text], delegate: GroupSessionDropDelegate(
                    targetSession: session,
                    allSessions: sessions,
                    draggedSessionID: $draggedSessionID,
                    sessionManager: sessionManager
                ))
                .opacity(draggedSessionID == session.id ? 0.5 : 1)
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "folder.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)

                Text(group.name)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)

                Text("\(sessions.count)")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1)
                    .background(.quaternary, in: Capsule())
            }
        }
    }
}

// MARK: - Drag & Drop

private struct GroupSessionDropDelegate: DropDelegate {
    let targetSession: Session
    let allSessions: [Session]
    @Binding var draggedSessionID: UUID?
    let sessionManager: SessionManager

    func dropEntered(info: DropInfo) {
        guard let draggedID = draggedSessionID,
              draggedID != targetSession.id,
              let fromIndex = allSessions.firstIndex(where: { $0.id == draggedID }),
              let toIndex = allSessions.firstIndex(where: { $0.id == targetSession.id })
        else { return }

        var reordered = allSessions
        let item = reordered.remove(at: fromIndex)
        reordered.insert(item, at: toIndex)

        withAnimation(.easeInOut(duration: 0.2)) {
            sessionManager.reorderSessions(reordered)
        }
    }

    func performDrop(info: DropInfo) -> Bool {
        draggedSessionID = nil
        return true
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func validateDrop(info: DropInfo) -> Bool {
        draggedSessionID != nil
    }
}
