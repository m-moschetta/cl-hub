import SwiftUI
import ClaudeHubCore

/// Wizard for creating a new session with any command.
struct NewSessionSheet: View {
    @EnvironmentObject var sessionManager: SessionManager
    @Environment(\.dismiss) var dismiss

    @State private var name = ""
    @State private var projectPath = ""
    @State private var selectedCommand = "claude"
    @State private var customCommand = ""
    @State private var flags = ""
    @State private var useWorktree = false
    @State private var initialPrompt = ""
    @State private var selectedGroupID: UUID?
    @State private var groups: [SessionGroup] = []

    private let presetCommands = [
        ("claude", "Claude Code"),
        ("opencode", "OpenCode"),
        ("zsh", "Terminal (zsh)"),
        ("bash", "Terminal (bash)"),
        ("custom", "Custom..."),
    ]

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

                    Picker("Command", selection: $selectedCommand) {
                        ForEach(presetCommands, id: \.0) { cmd in
                            Text(cmd.1).tag(cmd.0)
                        }
                    }

                    if selectedCommand == "custom" {
                        TextField("Custom Command", text: $customCommand, prompt: Text("/usr/local/bin/mytool"))
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

                    TextField("Flags", text: $flags, prompt: Text("--model sonnet"))
                        .help("Additional flags appended to the command")
                }

                if selectedCommand != "zsh" && selectedCommand != "bash" {
                    Section("Initial Prompt (optional)") {
                        TextEditor(text: $initialPrompt)
                            .font(.system(size: 13, design: .monospaced))
                            .frame(minHeight: 80)
                            .scrollContentBackground(.hidden)
                            .padding(4)
                            .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 6))
                    }
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
                .disabled(name.isEmpty || projectPath.isEmpty || (selectedCommand == "custom" && customCommand.isEmpty))
            }
            .padding()
        }
        .frame(width: 520)
        .onAppear {
            self.groups = sessionManager.fetchGroups()
            // Auto-open directory picker so the user picks a folder right away
            DispatchQueue.main.async {
                browseDirectory()
            }
        }
    }

    private var effectiveCommand: String {
        selectedCommand == "custom" ? customCommand : selectedCommand
    }

    private func browseDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.message = "Select the project directory"

        // Start from the last used directory if available
        if let lastPath = UserDefaults.standard.string(forKey: "lastProjectPath"),
           FileManager.default.fileExists(atPath: lastPath) {
            panel.directoryURL = URL(fileURLWithPath: lastPath)
        } else {
            panel.directoryURL = FileManager.default.homeDirectoryForCurrentUser
        }

        if panel.runModal() == .OK {
            projectPath = panel.url?.path ?? ""
            if name.isEmpty {
                name = panel.url?.lastPathComponent ?? ""
            }
            // Remember the parent directory for next time
            if let parent = panel.url?.deletingLastPathComponent().path {
                UserDefaults.standard.set(parent, forKey: "lastProjectPath")
            }
        }
    }

    private func createSession() {
        let session = sessionManager.createSession(
            name: name,
            projectPath: projectPath,
            command: effectiveCommand,
            claudeFlags: flags,
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
