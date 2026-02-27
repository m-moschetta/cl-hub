import SwiftUI
import SwiftData
import ClaudeHubCore

/// Create a new task: session + optional worktree + initial prompt in one action.
struct TaskWizardView: View {
    @EnvironmentObject var sessionManager: SessionManager
    @EnvironmentObject var orchestrationEngine: OrchestrationEngine
    @Environment(\.dismiss) var dismiss

    @Query(sort: \SessionGroup.sortOrder)
    private var groups: [SessionGroup]

    @State private var name = ""
    @State private var projectPath = ""
    @State private var prompt = ""
    @State private var useWorktree = true
    @State private var claudeFlags = ""
    @State private var selectedGroupID: UUID?

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("New Task")
                    .font(.title2.bold())
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
            }
            .padding()

            Divider()

            Form {
                Section("Task") {
                    TextField("Name", text: $name, prompt: Text("Fix auth bug"))

                    HStack {
                        TextField("Project Path", text: $projectPath, prompt: Text("/path/to/project"))
                        Button("Browse...") { browseDirectory() }
                    }
                }

                Section("Prompt") {
                    TextEditor(text: $prompt)
                        .font(.system(size: 13, design: .monospaced))
                        .frame(minHeight: 120)
                        .scrollContentBackground(.hidden)
                        .padding(4)
                        .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 6))
                }

                Section("Options") {
                    Toggle("Isolate with Git Worktree", isOn: $useWorktree)
                    TextField("Claude Flags", text: $claudeFlags, prompt: Text("--model sonnet"))

                    Picker("Group", selection: $selectedGroupID) {
                        Text("No Group").tag(nil as UUID?)
                        ForEach(groups, id: \.id) { group in
                            Text(group.name).tag(group.id as UUID?)
                        }
                    }
                }
            }
            .formStyle(.grouped)

            Divider()

            HStack {
                Spacer()
                Button("Create & Start") {
                    let session = orchestrationEngine.createTask(
                        name: name,
                        projectPath: projectPath,
                        prompt: prompt,
                        useWorktree: useWorktree,
                        groupID: selectedGroupID,
                        claudeFlags: claudeFlags
                    )
                    sessionManager.selectedSessionID = session.id
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(name.isEmpty || projectPath.isEmpty || prompt.isEmpty)
            }
            .padding()
        }
        .frame(width: 520)
    }

    private func browseDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK {
            projectPath = panel.url?.path ?? ""
            if name.isEmpty {
                name = panel.url?.lastPathComponent ?? ""
            }
        }
    }
}
