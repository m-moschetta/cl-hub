import SwiftUI
import ClaudeHubCore

/// Side-by-side terminal view for comparing two sessions.
struct TerminalSplitView: View {
    let leftSession: Session
    let rightSession: Session

    var body: some View {
        HSplitView {
            TerminalContainerView(session: leftSession)
                .frame(minWidth: 400)

            TerminalContainerView(session: rightSession)
                .frame(minWidth: 400)
        }
    }
}
