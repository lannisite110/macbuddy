# Changelog

## v0.1.1 — 2026-08-18

### Tooling
- Fix cold-start timing (measure from app init, not first `LaunchTiming` access)
- Automate hotkey bench via `MACBUDDY_BENCH` / `MACBUDDY_BENCH_HOTKEY`
- Add `read_telemetry.py`, include hotkey gate in regression suite
- GitHub Actions CI on `macos-14`

## v0.1.0 — 2026-08-18

First shippable MacBuddy release (P0 through P4).

### P0 — Performance foundation
- Menu-bar app (`LSUIElement`), global hotkey `⌘⇧Space`
- SessionStore metadata-only launch query
- Local telemetry (cold start, hotkey)
- Perf bench scripts

### P1 — Chat core
- OpenAI-compatible streaming LLM client
- Chat UI with send/cancel, session persistence
- Clipboard and file-drop context
- Model settings (UserDefaults + Keychain)

### P2 — Work assistant
- Summarize, rewrite, meeting notes on selection
- Summarize file, macOS Services integration
- Accessibility permission flow
- Copy / Replace result sheet

### P3 — Coding agent
- Open workspace, `@file` mentions
- Unified diff preview, confirm-to-apply
- Read-only git diff/log
- Allowlisted command runner (`git`, `ls`, `rg`)

### P4 — Dual-core polish
- Incremental workspace index (toggle off by default)
- Workflow templates (menu + Settings)
- PluginHost with SHA256 manifest validation
- Optional account email + monthly quota
- `Scripts/perf/regression.sh` full regression suite
