import ClaudeHubRemote
import SwiftUI

struct NewSessionSheet: View {
    @EnvironmentObject private var appStore: MobileAppStore
    @Environment(\.dismiss) private var dismiss

    // Form fields
    @State private var sessionName = ""
    @State private var selectedPathID: UUID?
    @State private var useCustomPath = false
    @State private var customPath = ""
    @State private var command = "claude"
    @State private var customCommand = ""
    @State private var selectedGroupID: UUID?
    @State private var useWorktree = false
    @State private var flags = ""
    @State private var initialPrompt = ""

    private let knownCommands = ["claude", "opencode", "codex", "zsh", "bash"]

    private var isShellCommand: Bool {
        let active = command == "custom" ? customCommand : command
        return active == "zsh" || active == "bash"
    }

    private var effectivePath: String {
        if useCustomPath { return customPath }
        guard let id = selectedPathID,
              let path = appStore.recentProjectPaths.first(where: { $0.id == id })
        else { return "" }
        return path.path
    }

    private var canCreate: Bool {
        !sessionName.trimmingCharacters(in: .whitespaces).isEmpty
            && !effectivePath.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                projectSection
                sessionSection
                optionsSection

                if !isShellCommand {
                    promptSection
                }
            }
            .navigationTitle("New Session")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") { create() }
                        .fontWeight(.semibold)
                        .disabled(!canCreate)
                }
            }
            .overlay {
                if appStore.isCreatingSession {
                    loadingOverlay
                }
            }
            .onAppear {
                appStore.requestProjectPaths()
            }
        }
    }

    // MARK: - Sections

    private var projectSection: some View {
        Section {
            Toggle("Custom path", isOn: $useCustomPath.animation())

            if useCustomPath {
                TextField("/path/to/project", text: $customPath)
                    .font(.system(.body, design: .monospaced))
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .onChange(of: customPath) { _, newValue in
                        autoFillName(from: newValue)
                    }
            } else {
                if appStore.recentProjectPaths.isEmpty {
                    HStack(spacing: 8) {
                        ProgressView().scaleEffect(0.8)
                        Text("Loading paths from Mac…")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Picker("Project", selection: $selectedPathID) {
                        Text("Select a project").tag(UUID?.none)
                        ForEach(appStore.recentProjectPaths) { p in
                            HStack {
                                Text(p.name)
                                if p.isGitRepo {
                                    Image(systemName: "arrow.triangle.branch")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .tag(Optional(p.id))
                        }
                    }
                    .onChange(of: selectedPathID) { _, newValue in
                        if let id = newValue,
                           let path = appStore.recentProjectPaths.first(where: { $0.id == id }) {
                            autoFillName(from: path.path)
                        }
                    }
                }
            }
        } header: {
            Text("Project")
        }
    }

    private var sessionSection: some View {
        Section {
            TextField("Session name", text: $sessionName)
                .textInputAutocapitalization(.words)

            Picker("Command", selection: $command) {
                ForEach(knownCommands, id: \.self) { cmd in
                    Text(cmd).tag(cmd)
                }
                Text("Custom…").tag("custom")
            }

            if command == "custom" {
                TextField("Command", text: $customCommand)
                    .font(.system(.body, design: .monospaced))
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }

            if !appStore.hostGroups.isEmpty {
                Picker("Group", selection: $selectedGroupID) {
                    Text("None").tag(UUID?.none)
                    ForEach(appStore.hostGroups) { group in
                        Text(group.name).tag(Optional(group.id))
                    }
                }
            }
        } header: {
            Text("Session")
        }
    }

    private var optionsSection: some View {
        Section {
            if !isShellCommand {
                Toggle("Use worktree", isOn: $useWorktree)
            }

            TextField("Flags (e.g. --dangerously-skip-permissions)", text: $flags)
                .font(.system(.body, design: .monospaced))
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
        } header: {
            Text("Options")
        }
    }

    private var promptSection: some View {
        Section {
            TextEditor(text: $initialPrompt)
                .font(.system(.body, design: .monospaced))
                .frame(minHeight: 80)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
        } header: {
            Text("Initial Prompt")
        } footer: {
            Text("Sent to the session after launch.")
        }
    }

    private var loadingOverlay: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()

            VStack(spacing: 14) {
                ProgressView()
                    .scaleEffect(1.2)
                Text("Creating session…")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
            }
            .padding(28)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        }
    }

    // MARK: - Actions

    private func autoFillName(from path: String) {
        guard sessionName.isEmpty else { return }
        let last = URL(fileURLWithPath: path).lastPathComponent
        if !last.isEmpty, last != "/" {
            sessionName = last
        }
    }

    private func create() {
        let activeCommand = command == "custom" ? customCommand : command
        appStore.createSession(
            name: sessionName.trimmingCharacters(in: .whitespaces),
            projectPath: effectivePath.trimmingCharacters(in: .whitespaces),
            command: activeCommand,
            flags: flags.trimmingCharacters(in: .whitespaces),
            groupID: selectedGroupID,
            useWorktree: useWorktree,
            initialPrompt: initialPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? nil
                : initialPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        dismiss()
    }
}
