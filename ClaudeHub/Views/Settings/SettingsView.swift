import SwiftUI

/// App-wide settings: font, theme, default Claude flags.
struct SettingsView: View {
    @AppStorage("defaultFontSize") private var defaultFontSize: Double = 13.0
    @AppStorage("defaultClaudeFlags") private var defaultClaudeFlags: String = ""
    @AppStorage("preferDarkTheme") private var preferDarkTheme: Bool = true
    @AppStorage("notifyOnCompletion") private var notifyOnCompletion: Bool = true
    @AppStorage("notifyOnError") private var notifyOnError: Bool = true
    @AppStorage("maxScrollbackMB") private var maxScrollbackMB: Double = 50.0

    var body: some View {
        TabView {
            generalSettings
                .tabItem { Label("General", systemImage: "gear") }

            terminalSettings
                .tabItem { Label("Terminal", systemImage: "terminal") }

            notificationSettings
                .tabItem { Label("Notifications", systemImage: "bell") }
        }
        .frame(width: 450, height: 300)
    }

    private var generalSettings: some View {
        Form {
            Section("Claude Code") {
                TextField("Default Flags", text: $defaultClaudeFlags, prompt: Text("--model sonnet"))
                    .help("Flags applied to all new sessions unless overridden")
            }

            Section("Storage") {
                HStack {
                    Text("Max Scrollback per Session")
                    Spacer()
                    Slider(value: $maxScrollbackMB, in: 10...200, step: 10)
                        .frame(width: 150)
                    Text("\(Int(maxScrollbackMB)) MB")
                        .frame(width: 50, alignment: .trailing)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
    }

    private var terminalSettings: some View {
        Form {
            Section("Appearance") {
                Picker("Theme", selection: $preferDarkTheme) {
                    Text("Dark").tag(true)
                    Text("Light").tag(false)
                }
                .pickerStyle(.segmented)

                HStack {
                    Text("Font Size")
                    Spacer()
                    Slider(value: $defaultFontSize, in: 9...24, step: 1)
                        .frame(width: 150)
                    Text("\(Int(defaultFontSize)) pt")
                        .frame(width: 40, alignment: .trailing)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
    }

    private var notificationSettings: some View {
        Form {
            Section("Notify when...") {
                Toggle("Claude finishes thinking", isOn: $notifyOnCompletion)
                Toggle("An error occurs", isOn: $notifyOnError)
            }
        }
        .formStyle(.grouped)
    }
}
