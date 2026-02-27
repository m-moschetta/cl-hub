import SwiftUI
import SwiftData
import ClaudeHubCore

/// Overview grid showing all active agents with real-time status.
struct DashboardView: View {
    @Query(filter: #Predicate<Session> { !$0.isArchived },
           sort: \Session.sortOrder)
    private var sessions: [Session]

    @Binding var selectedSessionID: UUID?

    private let columns = [
        GridItem(.adaptive(minimum: 220, maximum: 300), spacing: 12)
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Summary stats
                HStack(spacing: 24) {
                    StatBadge(
                        label: "Total",
                        value: "\(sessions.count)",
                        color: .primary
                    )
                    StatBadge(
                        label: "Active",
                        value: "\(sessions.filter { $0.status != .disconnected }.count)",
                        color: .green
                    )
                    StatBadge(
                        label: "Thinking",
                        value: "\(sessions.filter { $0.status == .thinking }.count)",
                        color: .blue
                    )
                    StatBadge(
                        label: "Errors",
                        value: "\(sessions.filter { $0.status == .error }.count)",
                        color: .red
                    )
                }
                .padding(.horizontal)

                // Session grid
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(sessions, id: \.id) { session in
                        SessionCard(session: session)
                            .onTapGesture {
                                selectedSessionID = session.id
                            }
                    }
                }
                .padding(.horizontal)
            }
            .padding(.vertical)
        }
        .background(.background)
    }
}

private struct SessionCard: View {
    let session: Session

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Circle()
                    .fill(statusColor)
                    .frame(width: 8, height: 8)

                Text(session.name)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)

                Spacer()

                Text(session.status.displayName)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(statusColor.opacity(0.15), in: Capsule())
            }

            Text(session.projectPath)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.tertiary)
                .lineLimit(1)

            if !session.lastMessagePreview.isEmpty {
                Text(session.lastMessagePreview)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            if let branch = session.worktreeBranch {
                HStack(spacing: 3) {
                    Image(systemName: "arrow.triangle.branch")
                        .font(.system(size: 9))
                    Text(branch)
                        .font(.system(size: 10))
                }
                .foregroundStyle(.tertiary)
            }
        }
        .padding(12)
        .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(statusColor.opacity(0.3), lineWidth: 1)
        )
    }

    private var statusColor: Color {
        switch session.status {
        case .idle: return .green
        case .thinking: return .blue
        case .toolUse: return .orange
        case .error: return .red
        case .disconnected: return .gray
        }
    }
}

private struct StatBadge: View {
    let label: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(color)
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
    }
}
