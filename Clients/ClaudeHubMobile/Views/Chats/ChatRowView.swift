import SwiftUI

struct ChatRowView: View {
    let session: MobileSession

    var body: some View {
        HStack(spacing: 14) {
            Circle()
                .fill(statusColor.opacity(0.16))
                .frame(width: 54, height: 54)
                .overlay {
                    Image(systemName: "terminal.fill")
                        .foregroundStyle(statusColor)
                }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(session.name)
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    Spacer()

                    Text(session.status.capitalized)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 8) {
                    Text(session.lastPreview.isEmpty ? "Tap to open terminal" : session.lastPreview)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)

                    Spacer()

                    if session.hasUnread {
                        Circle()
                            .fill(.green)
                            .frame(width: 10, height: 10)
                    }
                }
            }
        }
        .padding(.vertical, 12)
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
