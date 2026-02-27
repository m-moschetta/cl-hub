import SwiftUI
import ClaudeHubCore

/// A single session row in the sidebar, styled like Telegram Desktop.
struct SessionRowView: View {
    let session: Session
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 10) {
            // Status dot
            Circle()
                .fill(statusColor)
                .frame(width: 10, height: 10)
                .overlay {
                    if session.status == .thinking {
                        Circle()
                            .stroke(statusColor.opacity(0.5), lineWidth: 2)
                            .scaleEffect(1.5)
                            .opacity(0)
                            .animation(
                                .easeInOut(duration: 1.0).repeatForever(autoreverses: false),
                                value: session.status
                            )
                    }
                }

            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text(session.name)
                        .font(.system(size: 13, weight: .semibold))
                        .lineLimit(1)

                    Spacer()

                    Text(timeAgo(session.lastActivityDate))
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                }

                HStack(spacing: 4) {
                    if session.status == .toolUse {
                        Image(systemName: "hammer.fill")
                            .font(.system(size: 9))
                            .foregroundStyle(.orange)
                    } else if session.status == .thinking {
                        Image(systemName: "brain")
                            .font(.system(size: 9))
                            .foregroundStyle(.blue)
                    }

                    Text(session.lastMessagePreview.isEmpty ? "No activity" : session.lastMessagePreview)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
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
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isSelected ? Color.accentColor.opacity(0.15) : Color.clear)
        )
        .contentShape(Rectangle())
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

    private func timeAgo(_ date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        if interval < 60 { return "now" }
        if interval < 3600 { return "\(Int(interval / 60))m" }
        if interval < 86400 { return "\(Int(interval / 3600))h" }
        return "\(Int(interval / 86400))d"
    }
}
