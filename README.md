# MacBuddy

Mac-native assistant that combines **work help** (summarize, rewrite, meeting notes) and **coding help** (workspace patches, git explain) in one menu-bar app.

Built for macOS 14+ (Sonoma). SwiftUI shell + Swift packages. LLM via OpenAI-compatible HTTP (Ollama, OpenAI, etc.).

## Quick start

**Requirements:** macOS 14+, Swift 5.10+, Xcode 15+ (optional; SwiftPM build works)

```bash
# Build + launch (one line from repo root)
./Scripts/run.sh

# Or build only, then open manually
bash Scripts/build_app.sh
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
  Sidecars/LLMSidecar/         LLM sidecar process (MacBuddyLLM)
  Sidecars/WorkSidecar/        Work sidecar process (MacBuddyWork)
  Sidecars/CodeSidecar/        Code sidecar process (MacBuddyCode)
  Packages/
    SidecarIPC/                Unix-socket JSON protocol
    LLMSidecarClient/          Spawn + talk to LLM sidecar
    WorkSidecarClient/         Spawn + talk to Work sidecar
    CodeSidecarClient/         Spawn + talk to Code sidecar
    LLMClient/                 OpenAI-compatible SSE (runs inside sidecars)
    WorkSkills/            Work prompts + Accessibility (selection stays in the app)
    CodeEngine/            Workspace scan, patches, git, index (runs inside Code sidecar)
    PluginHost/            Signed plugin manifests (SHA256)
    WorkflowTemplates/     Built-in workflow definitions
  Scripts/
    build_app.sh           Build .app from SwiftPM
    perf/                  Launch bench + full regression suite
  docs/superpowers/        Design spec + phase plans
```

### Tests and regression

```bash
# Full regression (all package tests + build + cold-start + hotkey gates)
bash Scripts/perf/regression.sh

# Individual benches
bash Scripts/perf/launch_bench.sh    # cold start ≤ 1.2s
bash Scripts/perf/hotkey_bench.sh    # hotkey show ≤ 100ms (automated via bench env)

# Individual package
swift test --package-path Packages/LLMClient
```

Cold start is measured from `MacBuddyApp.init()` to composer `onAppear`. Hotkey bench uses `MACBUDDY_BENCH=1` (panel hidden at launch) and `MACBUDDY_BENCH_HOTKEY=1` (programmatic toggle) so CI does not require manual keypress.

### Performance budgets

| Metric | Budget |
|--------|--------|
| Cold start → composer focus | ≤ 1.2s |
| Hotkey → window visible | ≤ 100ms |
| First token feel | ≤ 300ms |

Heavy engines (LLM, Work, Code) load **on first use**, not at login.

## CI

GitHub Actions runs on `macos-14` for every push/PR to `main`:

- All package `swift test`
- App build + `.app` bundle
- Launch bench + hotkey bench

Workflow: [`.github/workflows/ci.yml`](.github/workflows/ci.yml)

### Publishing (private GitHub)

```bash
brew install gh
gh auth login -h github.com -p ssh -w
bash Scripts/setup_github_remote.sh
```

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
