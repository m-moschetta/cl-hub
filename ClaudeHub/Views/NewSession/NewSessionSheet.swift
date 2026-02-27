import SwiftUI
import ClaudeHubCore

/// Wizard for creating a new Claude Code session.
struct NewSessionSheet: View {
    @EnvironmentObject var sessionManager: SessionManager
    @Environment(\.dismiss) var dismiss

    @State private var name = ""
    @State private var projectPath = ""
    @State private var claudeFlags = ""
    @State private var useWorktree = false
    @State private var initialPrompt = ""
    @State private var selectedGroupID: UUID?

    @Query(sort: \SessionGroup.sortOrder)
    private var groups: [SessionGroup]

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("New Session")
                    .font(.title2.bold())
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
            }
            .padding()

            Divider()

            // Form
            Form {
                Section("Session") {
                    TextField("Name", text: $name, prompt: Text("My Feature"))

                    HStack {
                        TextField("Project Path", text: $projectPath, prompt: Text("/path/to/project"))
                        Button("Browse...") {
                            browseDirectory()
                        }
                    }

                    Picker("Group", selection: $selectedGroupID) {
                        Text("No Group").tag(nil as UUID?)
                        ForEach(groups, id: \.id) { group in
                            Text(group.name).tag(group.id as UUID?)
                        }
                    }
                }

                Section("Options") {
                    Toggle("Create Git Worktree", isOn: $useWorktree)
                        .help("Isolate this session in its own git worktree branch")

                    TextField("Claude Flags", text: $claudeFlags, prompt: Text("--model sonnet"))
                        .help("Additional flags passed to the claude command")
                }

                Section("Initial Prompt (optional)") {
                    TextEditor(text: $initialPrompt)
                        .font(.system(size: 13, design: .monospaced))
                        .frame(minHeight: 80)
                        .scrollContentBackground(.hidden)
                        .padding(4)
                        .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 6))
                }
            }
            .formStyle(.grouped)
            .frame(minHeight: 350)

            Divider()

            // Footer
            HStack {
                Spacer()
                Button("Create Session") {
                    createSession()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(name.isEmpty || projectPath.isEmpty)
            }
            .padding()
        }
        .frame(width: 500)
    }

    private func browseDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.message = "Select the project directory"

        if panel.runModal() == .OK {
            projectPath = panel.url?.path ?? ""
            if name.isEmpty {
                name = panel.url?.lastPathComponent ?? ""
            }
        }
    }

    private func createSession() {
        var worktreePath: String?
        var worktreeBranch: String?

        let session = sessionManager.createSession(
            name: name,
            projectPath: projectPath,
            claudeFlags: claudeFlags,
            groupID: selectedGroupID
        )

        if useWorktree {
            let worktreeService = GitWorktreeService.shared
            if worktreeService.isGitRepo(at: projectPath),
               let result = worktreeService.createWorktree(
                   projectPath: projectPath,
                   sessionID: session.id
               ) {
                session.worktreePath = result.path
                session.worktreeBranch = result.branch
                session.workingDirectory = result.path
            }
        }

        if !initialPrompt.isEmpty {
            session.lastMessagePreview = "⏳ \(initialPrompt)"
        }

        sessionManager.selectedSessionID = session.id
        dismiss()
    }
}
