# MacBuddy

Mac-native assistant that combines **work help** (summarize, rewrite, meeting notes) and **coding help** (workspace patches, git explain) in one menu-bar app.

Built for macOS 14+ (Sonoma). SwiftUI shell + Swift packages. LLM via OpenAI-compatible HTTP (Ollama, OpenAI, etc.).

## Quick start

**Requirements:** macOS 14+, Swift 5.10+, Xcode 15+ (optional; SwiftPM build works)

```bash
# Build .app bundle
bash Scripts/build_app.sh

# Launch
open Apps/MacBuddy/build/Debug/MacBuddy.app
```

**First run**

1. Menu bar icon **MB** appears (no Dock icon).
2. `⌘⇧Space` toggles the chat panel.
3. **MB → Settings → General** — set Base URL and Model:
   - Local Ollama: `http://127.0.0.1:11434/v1`, model e.g. `llama3.2`
   - OpenAI: `https://api.openai.com/v1` + API key
4. For **Work → selection actions**: enable MacBuddy in **System Settings → Privacy & Security → Accessibility**.

## Features by phase

| Phase | What you get |
|-------|----------------|
| **P0** | Menu bar, global hotkey, empty composer, perf telemetry |
| **P1** | Streaming chat, cancel, session persistence, clipboard/file context |
| **P2** | Summarize / rewrite / meeting notes on selection or files; Services menu |
| **P3** | Open workspace, `@file` mentions, diff preview, Apply/Decline, git explain |
| **P4** | Incremental index (off by default), workflow templates, plugin host, quota |

## Menu overview

- **Toggle Panel** — show/hide chat window
- **Work** — selection-based summarize, rewrite, meeting notes; summarize file
- **Code** — open/close workspace, explain git diff/log
- **Workflows** — run built-in multi-step templates
- **Settings** — model, features, workflows, plugins, performance

## Development

### Project layout

```
macbuddy/
  Apps/MacBuddy/           SwiftUI app (menu-bar agent)
  Packages/
    SessionStore/          SQLite sessions (metadata-only at launch)
    Telemetry/             Local JSONL perf events
    SettingsStore/         UserDefaults + Keychain
    LLMClient/             OpenAI-compatible SSE streaming
    WorkSkills/            Work actions + Accessibility selection
    CodeEngine/            Workspace scan, patches, git, index
    PluginHost/            Signed plugin manifests (SHA256)
    WorkflowTemplates/     Built-in workflow definitions
  Scripts/
    build_app.sh           Build .app from SwiftPM
    perf/                  Launch bench + full regression suite
  docs/superpowers/        Design spec + phase plans
```

### Tests and regression

```bash
# Full regression (all package tests + build + cold-start gate)
bash Scripts/perf/regression.sh

# Individual package
swift test --package-path Packages/LLMClient

# Cold start only (≤ 1.2s budget)
bash Scripts/perf/launch_bench.sh
```

### Performance budgets

| Metric | Budget |
|--------|--------|
| Cold start → composer focus | ≤ 1.2s |
| Hotkey → window visible | ≤ 100ms |
| First token feel | ≤ 300ms |

Heavy engines (LLM, Work, Code) load **on first use**, not at login.

## Plugins

Default install ships **zero plugins**. Drop plugin folders into:

`~/Library/Application Support/MacBuddy/Plugins/<name>/`

Each plugin needs `manifest.json` + entry file with matching SHA256. See `Packages/PluginHost` tests for manifest format.

## Documentation

- Platform design: [docs/superpowers/specs/2026-08-17-macbuddy-platform-design.md](docs/superpowers/specs/2026-08-17-macbuddy-platform-design.md)
- Phase plans: [docs/superpowers/plans/](docs/superpowers/plans/)

## Roadmap (not shipped)

- XPC sidecar processes (LLM / Work / Code) instead of in-process lazy actors
- Windows client
- Persistent vector index (P4 index is path+mtime only)

## License

Private / unlicensed — add a license file if you open-source this project.
