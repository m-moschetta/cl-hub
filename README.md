# Cl.hub

> The WhatsApp for your AI coding agents.

**Cl.hub** is a native macOS app for running, monitoring, and orchestrating multiple AI coding agent sessions simultaneously — Claude Code, OpenCode, OpenAI Codex, Cursor CLI, and any custom CLI tool.

Every session appears as a "chat" in a sidebar. Unread badges notify you when an agent finishes or hits an error. Click it, read the terminal, reply with your next prompt. Control everything from your Mac — or from your iPhone.

```
┌─────────────────────────────────────────────────────────────────┐
│  ● ● ●                    Cl.hub                    ⊞ 📡 ＋ 📱  │
├──────────────────┬──────────────────────────────────────────────┤
│ 🔍 Search...     │                                              │
│                  │  ❯ claude --model sonnet                     │
│ 🟢 auth-refactor │  ╭──────────────────────────────────────╮   │
│    ✓ ready       │  │   Claude Code  ·  claude-sonnet-4-6  │   │
│                  │  ╰──────────────────────────────────────╯   │
│ 🔴 db-migration  │                                              │
│    ⚠ error       │  ◆ Reading: src/api/endpoints/users.ts      │
│                  │  I'll generate an OpenAPI spec...           │
│ 🔵 api-docs  ←   │                                              │
│    Thinking...   │  ◆ Writing: docs/openapi.yaml               │
│                  │  ◆ Bash: npx swagger-cli validate            │
│ 🟠 test-suite    │                                              │
│    Using tools   │  ✓ OpenAPI spec valid · 47 paths            │
│                  │                                              │
│ 📁 Backend · 2   │                                              │
│ 🟢 relay-server  │                                              │
│ [＋ New]      ⋯  │                                              │
└──────────────────┴──────────────────────────────────────────────┘
```

---

## Features

| Feature | Description |
|---|---|
| **Chat-style sidebar** | Every session is a "chat row" with live status dot, last output preview, unread badge, and git branch |
| **Unread notifications** | Green badge = agent ready for input · Red badge = action required · Just like message notifications |
| **Full PTY terminal** | Each session has a real PTY-backed terminal (SwiftTerm) with ANSI colors, scrollback, and keyboard input |
| **Broadcast prompts** | Send one instruction to any number of active agents simultaneously |
| **Git worktree isolation** | Each session can run in its own git worktree on a dedicated branch — zero conflicts between agents |
| **Orchestration engine** | Create agent tasks from templates: project path, initial prompt, worktree, flags, group |
| **Session groups** | Organize sessions into collapsible folders (e.g. "Backend", "Frontend", "Tests") |
| **MCP monitor** | Track MCP server status per session |
| **iPhone companion** | Pair your iPhone via QR code and monitor/control all sessions remotely |
| **Relay server** | Self-hostable WebSocket relay (Vapor · Docker) for encrypted remote access |

---

## Supported AI CLIs

- [Claude Code](https://claude.ai/code) by Anthropic
- [OpenCode](https://opencode.ai)
- [OpenAI Codex CLI](https://github.com/openai/codex)
- [Cursor CLI](https://cursor.sh)
- Any custom command (zsh, bash, your own tool)

---

## Architecture

Cl.hub is made of three independent components:

```
┌─────────────────────┐     WebSocket      ┌──────────────────┐
│   Cl.hub macOS App  │ ◄────────────────► │  ClaudeHubRelay  │
│   (Swift · SwiftUI) │                    │  (Vapor · Docker) │
└────────┬────────────┘                    └────────┬─────────┘
         │ PTY process                              │ WebSocket
         ▼                                          ▼
  ┌─────────────┐                         ┌─────────────────────┐
  │  AI Agent   │                         │  ClaudeHubMobile    │
  │ (claude,    │                         │  iOS Companion App  │
  │  codex, ...) │                         │  (Swift · SwiftUI)  │
  └─────────────┘                         └─────────────────────┘
```

### `ClaudeHub/` — macOS app
Native SwiftUI app (macOS 14+). Manages PTY processes via `ProcessManager`, persists session state with SwiftData, renders terminals with [SwiftTerm](https://github.com/migueldeicaza/SwiftTerm).

Key packages:
- **`ClaudeHubCore`** — Session model, ProcessManager, SessionManager, OrchestrationEngine, GitWorktreeService, StatusDetector
- **`ClaudeHubTerminal`** — SwiftTerm wrapper with ANSI parsing and custom theme
- **`ClaudeHubRemote`** — Shared message types for Mac ↔ Relay ↔ iOS communication

### `Backend/ClaudeHubRelay/` — Relay server
Lightweight [Vapor](https://vapor.codes) WebSocket server. Routes encrypted messages between the Mac app and iOS clients. Deployable on Railway, Fly.io, or any Docker host.

### `Clients/ClaudeHubMobile/` — iOS companion
SwiftUI iOS app. Pairs with the Mac via QR code. Shows all sessions with live status, lets you read terminal output and send prompts remotely.

---

## Getting Started

### Requirements

- macOS 14 Sonoma or later
- Xcode 16+
- [xcodegen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`)

### 1. Clone & generate the Xcode project

```bash
git clone https://github.com/m-moschetta/cl-hub.git
cd cl-hub
./setup.sh
```

`setup.sh` installs xcodegen (if missing) and generates `ClaudeHub.xcodeproj`. Xcode opens automatically.

### 2. Build & run

Open `ClaudeHub.xcodeproj` in Xcode, select the `ClaudeHub` scheme, and press `⌘R`.

### 3. Create your first session

1. Click **＋ New Session** in the sidebar (or `⌘N`)
2. Enter a name, pick the project path, select your CLI (e.g. Claude Code)
3. Optionally enable **Create Git Worktree** to isolate the agent on its own branch
4. Hit **Start**

### 4. Broadcast a prompt

Click the **📡 broadcast** icon in the toolbar, write your prompt, select the sessions, hit **Broadcast**.

---

## Running the Relay (optional)

The relay server enables iPhone remote access. You can self-host it with Docker:

```bash
cd Backend/ClaudeHubRelay
docker build -t clihub-relay .
docker run -p 8080:8080 clihub-relay
```

Or deploy to Railway with one click using the included `railway.toml`.

Once running, open Cl.hub → toolbar → **📱 Pair iOS Device** and scan the QR code with the iOS app.

---

## Project Structure

```
cl-hub/
├── ClaudeHub/                  # macOS app source
│   ├── Views/
│   │   ├── Sidebar/            # Chat-style session list
│   │   ├── Terminal/           # SwiftTerm integration
│   │   ├── Dashboard/          # Overview grid
│   │   ├── Orchestration/      # Broadcast + Task wizard
│   │   └── Settings/
│   └── Utilities/
├── Packages/
│   ├── ClaudeHubCore/          # Business logic, models, services
│   ├── ClaudeHubTerminal/      # Terminal rendering
│   └── ClaudeHubRemote/        # Mac ↔ Relay ↔ iOS message protocol
├── Backend/
│   └── ClaudeHubRelay/         # Vapor WebSocket relay server
├── Clients/
│   └── ClaudeHubMobile/        # iOS companion app
├── landing/                    # Marketing landing page (static HTML)
├── project.yml                 # XcodeGen config
├── railway.toml                # Railway deploy config
└── setup.sh                    # One-command project setup
```

---

## Contributing

Contributions are welcome. Here's how to get started:

1. **Fork** the repo and clone your fork
2. **Create a branch**: `git checkout -b feat/your-feature`
3. **Generate the project**: `./setup.sh`
4. Make your changes in Xcode
5. **Commit** with a descriptive message
6. **Open a PR** against `master`

### Areas where help is welcome

- [ ] `StatusDetector` improvements — more reliable detection of agent states
- [ ] MCP server monitoring UI
- [ ] Scrollback search within terminals
- [ ] Session templates / saved configurations
- [ ] Linux / Windows CLI companion (relay client)
- [ ] Test coverage for `ClaudeHubCore`

Please open an issue before starting large changes so we can discuss approach first.

---

## License

MIT — see [LICENSE](./LICENSE).

---

<p align="center">
  Built with Swift · macOS native · Free &amp; open source
  <br><br>
  <a href="https://landing-bt4zwievz-m-moschettas-projects.vercel.app">Landing page</a>
</p>
