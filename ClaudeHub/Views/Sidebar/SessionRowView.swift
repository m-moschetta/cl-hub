import SwiftUI
import ClaudeHubCore

/// A single session row in the sidebar, styled like Telegram Desktop.
struct SessionRowView: View {
    let session: Session
    let isSelected: Bool

    @State private var isPulsing = false

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
                        .font(.system(size: 13, weight: session.hasUnread ? .bold : .semibold))
                        .foregroundStyle(session.hasUnread ? .primary : .primary)
                        .lineLimit(1)

                    Spacer()

                    if session.hasUnread {
                        unreadBadge
                            .transition(.scale.combined(with: .opacity))
                    } else {
                        Text(timeAgo(session.lastActivityDate))
                            .font(.system(size: 11))
                            .foregroundStyle(.tertiary)
                    }
                }

                // Status line (unread alert or activity indicator)
                if session.hasUnread {
                    HStack(spacing: 4) {
                        Image(systemName: session.status == .error ? "exclamationmark.triangle.fill" : "bell.fill")
                            .font(.system(size: 9))
                            .foregroundStyle(session.status == .error ? .red : .green)

                        Text(session.status == .error ? "Action required" : "Ready for input")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(session.status == .error ? .red : .green)
                            .lineLimit(1)
                    }
                } else {
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

                        Text(previewText)
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }

                // Preview line — always show the last terminal output below status
                if !session.hasUnread && !session.lastMessagePreview.isEmpty {
                    Text(session.lastMessagePreview)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.tertiary)
                        .lineLimit(2)
                        .truncationMode(.tail)
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
                .fill(rowBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(unreadBorderColor, lineWidth: session.hasUnread && !isSelected ? 1.5 : 0)
        )
        .contentShape(Rectangle())
        .onChange(of: session.hasUnread) { _, isUnread in
            if isUnread {
                isPulsing = true
            } else {
                isPulsing = false
            }
        }
    }

    private var rowBackground: Color {
        if isSelected {
            return Color.accentColor.opacity(0.15)
        }
        if session.hasUnread {
            return session.status == .error
                ? Color.red.opacity(0.08)
                : Color.green.opacity(0.08)
        }
        return .clear
    }

    private var unreadBorderColor: Color {
        session.status == .error ? .red.opacity(0.4) : .green.opacity(0.4)
    }

    /// WhatsApp-style unread badge with pulse animation.
    private var unreadBadge: some View {
        let isError = session.status == .error
        let badgeColor: Color = isError ? .red : .green
        let badgeIcon = isError ? "exclamationmark" : "checkmark"

        return ZStack {
            // Pulse ring
            Circle()
                .stroke(badgeColor.opacity(0.4), lineWidth: 2)
                .frame(width: 24, height: 24)
                .scaleEffect(isPulsing ? 1.3 : 1.0)
                .opacity(isPulsing ? 0 : 0.6)
                .animation(
                    .easeOut(duration: 1.2).repeatForever(autoreverses: false),
                    value: isPulsing
                )

            // Badge circle
            Circle()
                .fill(badgeColor)
                .frame(width: 20, height: 20)
                .shadow(color: badgeColor.opacity(0.5), radius: 4, x: 0, y: 0)
                .overlay {
                    Image(systemName: badgeIcon)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white)
                }
        }
    }

    private var previewText: String {
        switch session.status {
        case .thinking: return "Thinking..."
        case .toolUse: return "Using tools..."
        case .idle: return "Idle"
        case .error: return "Error"
        case .disconnected: return "Disconnected"
        }
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
