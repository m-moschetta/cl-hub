import SwiftUI
import SwiftData
import ClaudeHubCore

/// Sheet for broadcasting a prompt to multiple sessions.
struct BroadcastSheet: View {
    @EnvironmentObject var processManager: ProcessManager
    @Environment(\.dismiss) var dismiss

    @Query(filter: #Predicate<Session> { !$0.isArchived },
           sort: \Session.sortOrder)
    private var sessions: [Session]

    @State private var prompt = ""
    @State private var selectedIDs: Set<UUID> = []
    @State private var selectAll = false

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Broadcast Prompt")
                    .font(.title2.bold())
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
            }
            .padding()

            Divider()

            VStack(alignment: .leading, spacing: 12) {
                // Prompt input
                Text("Prompt")
                    .font(.headline)

                TextEditor(text: $prompt)
                    .font(.system(size: 13, design: .monospaced))
                    .frame(minHeight: 100)
                    .scrollContentBackground(.hidden)
                    .padding(4)
                    .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 6))

                // Session selection
                HStack {
                    Text("Send to")
                        .font(.headline)

                    Spacer()

                    Toggle("Select All Active", isOn: $selectAll)
                        .toggleStyle(.checkbox)
                        .onChange(of: selectAll) { _, newValue in
                            if newValue {
                                selectedIDs = Set(
                                    sessions
                                        .filter { processManager.isActive(sessionID: $0.id) }
                                        .map(\.id)
                                )
                            } else {
                                selectedIDs.removeAll()
                            }
                        }
                }

                ScrollView {
                    LazyVStack(spacing: 4) {
                        ForEach(sessions, id: \.id) { session in
                            let isActive = processManager.isActive(sessionID: session.id)
                            HStack {
                                Toggle(isOn: Binding(
                                    get: { selectedIDs.contains(session.id) },
                                    set: { isOn in
                                        if isOn { selectedIDs.insert(session.id) }
                                        else { selectedIDs.remove(session.id) }
                                    }
                                )) {
                                    HStack {
                                        Circle()
                                            .fill(isActive ? Color.green : Color.gray)
                                            .frame(width: 6, height: 6)
                                        Text(session.name)
                                            .font(.system(size: 13))
                                    }
                                }
                                .toggleStyle(.checkbox)
                                .disabled(!isActive)

                                Spacer()

                                if !isActive {
                                    Text("offline")
                                        .font(.system(size: 10))
                                        .foregroundStyle(.tertiary)
                                }
                            }
                            .padding(.vertical, 2)
                        }
                    }
                }
                .frame(maxHeight: 200)
            }
            .padding()

            Divider()

            HStack {
                Text("\(selectedIDs.count) session(s) selected")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                Button("Broadcast") {
                    processManager.broadcast(
                        prompt: prompt,
                        to: Array(selectedIDs)
                    )
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(prompt.isEmpty || selectedIDs.isEmpty)
            }
            .padding()
        }
        .frame(minWidth: 500, minHeight: 450)
    }
}
