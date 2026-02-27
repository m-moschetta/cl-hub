import SwiftUI
import ClaudeHubCore

/// Collapsible group header in the sidebar.
struct SessionGroupView: View {
    let group: SessionGroup
    let sessions: [Session]
    let selectedSessionID: UUID?
    let onSelect: (Session) -> Void

    @State private var isExpanded = true

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            ForEach(sessions, id: \.id) { session in
                SessionRowView(
                    session: session,
                    isSelected: session.id == selectedSessionID
                )
                .onTapGesture { onSelect(session) }
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
