import SwiftUI

struct ChatRowView: View {
    let session: MobileSession

    var body: some View {
        HStack(spacing: 12) {
            // Status bar indicator
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(statusColor)
                .frame(width: 4, height: 44)

            VStack(alignment: .leading, spacing: 5) {
                HStack(alignment: .firstTextBaseline) {
                    Text(session.name)
                        .font(.body.weight(.semibold))
                        .lineLimit(1)

                    Spacer(minLength: 8)

                    Text(statusLabel)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(statusColor)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(statusColor.opacity(0.12), in: Capsule())
                }

                Text(session.lastPreview.isEmpty ? "Tap to open" : session.lastPreview)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            if session.hasUnread {
                Circle()
                    .fill(.green)
                    .frame(width: 8, height: 8)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(.secondarySystemBackground).opacity(0.6))
        )
    }

    private var statusLabel: String {
        switch session.status {
        case "idle": return "Ready"
        case "thinking": return "Thinking"
        case "toolUse": return "Working"
        case "error": return "Error"
        case "disconnected": return "Off"
        default: return session.status.capitalized
        }
    }

    private var statusColor: Color {
        switch session.status {
        case "idle": return .green
        case "thinking": return .blue
        case "toolUse": return .orange
        case "error": return .red
        default: return .gray
        }
    }
}
