# MacBuddy Platform Design

Date: 2026-08-17
Status: approved

## 1. Product

MacBuddy is a Mac-native assistant that combines work help (ChatGPT / WorkBuddy style) and programming help (CodeBuddy / Qoder / Cursor style) in one app.

The first version is Mac-only. Windows is out of scope until P4 is stable.

Every phase ships a usable product. Later phases must not break earlier phase performance budgets.

## 2. Hard constraints

These numbers are release gates, not aspirations.

| Metric | Budget | How it is measured |
|---|---|---|
| Cold start to first keystroke in the composer | ≤ 1.2s | Time from process launch to composer `isFirstResponder`, on a warm disk, empty session list of ≤ 50 rows |
| Global hotkey to window visible | ≤ 100ms | Time from `CGEvent` / `NSEvent` hotkey callback to window `alpha ≥ 1` and on-screen |
| First-token feel | ≤ 300ms | Time from send tap to first visible streamed character or an explicit “thinking” placeholder. Placeholder must appear in ≤ 100ms if the model is slower |
| UI thread | never blocked by model, index, git, or plugin work | Main-thread hang detector: no ≥ 50ms stall on the AppKit/SwiftUI main queue during those operations |
| P2 skill load | ≤ 80ms added to cold start | Compare P1 vs P2 cold-start traces with all work skills installed but not yet used |
| P3 idle weight | no-project memory and cold start equal to P1 ± 10% | Sidecar not launched until a workspace is opened |

If a feature cannot meet these budgets, it stays behind a first-use load or a settings toggle. It does not ship on the default launch path.

## 3. Non-goals (until named later)

- Windows / Linux client
- Electron as the main process
- Full-repo always-on indexing at login
- Multi-agent parallel runners
- Enterprise SSO, team spaces, billing (P4 optional)
- Unrestricted RPA / GUI automation of arbitrary apps
- Shipping a fork of VS Code or a full IDE in P0–P3

## 4. Architecture choice

Chosen: **native thin shell + on-demand sidecar**.

Rejected:

- Electron / Tauri as the primary UI: faster to demo, worse cold start and memory on Mac.
- IDE-plugin-first: fastest for coding, fails the “work + coding in one Mac app” product.

### 4.1 Process layout

```
macbuddy.app (Swift / SwiftUI, always on)
  ├── UI: menu bar, hotkey window, chat, settings
  ├── Shell services: session store, settings, telemetry, permission broker
  └── XPC / local socket clients (idle until first use)

macbuddy-llm (sidecar, first chat send or model ping)
  └── streaming model router, cancel, retries

macbuddy-work (sidecar, first work skill)
  └── summarize / rewrite / meeting notes / Finder helpers

macbuddy-code (sidecar, first opened workspace only)
  └── workspace snapshot, patch preview, git explain, read-only terminal
```

The app process never imports vector DBs, language servers, or git libraries into its launch path.

Sidecars are separate processes. Crash or hang of a sidecar must not take down the shell. The UI shows a recoverable error and a retry.

### 4.2 Launch path (what may load before first keystroke)

Allowed:

- Menu bar extra
- Hotkey registration
- Empty chat window chrome
- Session list metadata only (id, title, updatedAt) for the last 50 sessions
- Local settings (UserDefaults / small JSON)

Forbidden on launch:

- Last session message bodies (hydrate after first frame)
- Model SDK / HTTP client stacks beyond a tiny stub
- Embedding / index
- Plugin host
- Workspace scan

### 4.3 Response path

- All LLM, index, git, and plugin work runs off the main thread in a sidecar.
- Generation is cancellable from the UI within 100ms of tap.
- Streamed tokens are coalesced to ~30ms frames so SwiftUI does not relayout per token.
- Long content (diffs, files) uses lazy / virtualized lists.
- Slow retrieval never blocks an answer: answer with the current context first; attach retrieved snippets if they arrive before the first token. If retrieval exceeds 400ms, skip it for that turn and mention that context was not expanded.

## 5. Components

Each unit has one job, a clear API, and no knowledge of sibling internals.

### 5.1 AppShell

Does: windowing, menu bar, global hotkey (default `⌘⇧Space`, user-changeable), focus, appearance.

Use: the only UI process.

Depends on: SessionStore (metadata), SettingsStore, Telemetry.

Does not: call models, touch the filesystem beyond its own container, spawn git.

### 5.2 SessionStore

Does: append-only chat sessions on disk (SQLite). Launch query returns metadata only. Message bodies load by `sessionId` after the window’s first frame.

Schema (minimum):

- `sessions(id, title, updated_at, origin)` where `origin` is the action that created the session (`chat` | `work` | `code`). A session may later contain mixed message types.
- `messages(id, session_id, role, created_at, body_path_or_blob)`
- Bodies over 32KB live as files; smaller bodies may live in SQLite.

Depends on: nothing in the sidecar set.

### 5.3 SettingsStore

Does: model provider keys, hotkey, skill enable flags, last workspace path.

Keys stay in the macOS Keychain. Non-secret prefs stay in UserDefaults.

Depends on: Keychain.

### 5.4 PermissionBroker

Does: request and cache TCC-related capabilities the app actually uses: Accessibility (selection capture), Files and Folders / user-selected folders, Automation for a small allowlist (Finder only in P2).

Use: every skill that needs a permission asks the broker; the broker owns the system prompt UI.

Depends on: AppShell (to present prompts).

### 5.5 Telemetry (local)

Does: record launch, hotkey-to-visible, first-keystroke, first-token, cancel latency. Writes JSONL under Application Support. No network in P0–P3 unless the user later opts in.

Use: a hidden “Performance” pane shows last 20 cold starts so regressions are visible without a server.

Depends on: nothing.

### 5.6 LlmSidecar

Does: stream completion from a configured provider; map errors; cancel; pick a model.

P1 providers (explicit): OpenAI-compatible HTTP (`baseURL` + API key) and one local option via the same protocol (user supplies endpoint, e.g. Ollama). No vendor SDK in the app target.

API (XPC):

- `complete(requestId, messages, model, tools: []) -> AsyncStream<Event>`
- `cancel(requestId)`
- `ping() -> latencyMs`

Depends on: SettingsStore (via a copied, non-secret config blob plus a Keychain-backed token passed at spawn).

### 5.7 WorkSidecar

Does: prompt templates for summarize, rewrite, meeting notes; optional paste of selected text / dropped files as context. Finder “summarize this file” uses a user-granted security-scoped bookmark, then sends extracted text (cap 100k characters) to LlmSidecar.

Does not: drive arbitrary GUI apps.

Loaded: on first use of a work action, not at login.

Depends on: LlmSidecar, PermissionBroker.

### 5.8 CodeSidecar

Does: when a workspace folder is opened:

- enumerate files with ignore rules (`.gitignore` + default ignores: `node_modules`, `.git`, build artifacts)
- resolve `@file` mentions by path
- produce a unified diff **preview** for proposed edits; apply only after explicit user confirm
- `git diff` / `git log -n 20` explain (read-only git)
- run allowlisted read-only commands (`git`, `ls`, `rg` if present) in the workspace with a timeout and no network

Does not in P3: write files without confirm, run tests by default, start an LSP, keep an always-on index.

Index: P3 uses an in-memory path + mtime list plus on-demand file reads. Persistent incremental index is P4.

Loaded: only after the user opens a workspace. Closing the workspace stops the sidecar after 30s idle.

Depends on: LlmSidecar, PermissionBroker (folder access).

### 5.9 PluginHost (P4 only)

Does: load signed / hashed plugins from a directory; each plugin is a sidecar with a capability manifest (`network`, `fs`, `ui.command`). Default install has zero plugins.

P0–P3 do not include this process.

## 6. Data flow

### 6.1 Chat send (P1)

1. User taps send. UI appends a local user message and a placeholder assistant row (≤ 100ms).
2. AppShell sends `complete` to LlmSidecar (started on first send if needed).
3. Sidecar streams tokens; AppShell coalesces and updates the assistant row.
4. On end, SessionStore persists. On cancel, sidecar abort; UI keeps partial text marked cancelled.

### 6.2 Work action (P2)

1. User invokes “Rewrite selection” (hotkey or menu).
2. PermissionBroker ensures Accessibility if needed; otherwise show a one-screen grant.
3. WorkSidecar starts if needed, reads selection, calls LlmSidecar, returns replacement text.
4. UI offers Copy / Replace. Replace uses Accessibility only if granted; otherwise Copy.

### 6.3 Code edit preview (P3)

1. User opens a folder. CodeSidecar starts, builds file list (async; UI remains usable).
2. User asks to change code with optional `@path`.
3. Sidecar reads those files (size cap 256KB per file), calls LlmSidecar, returns a unified diff.
4. UI shows the diff. Apply writes files only on confirm. Failure rolls back that file via a copy kept for the turn.

## 7. Error handling

| Failure | User-visible behavior |
|---|---|
| Sidecar crash | Banner: “Engine restarted”. Auto-respawn once. Second failure in 60s: banner + disable that engine until relaunch |
| Network / 401 | Inline error on the assistant row; composer stays editable; key stays in Settings |
| Generation hang > 45s without tokens | Auto-cancel, error “No response”, retry button |
| Permission denied | Action-specific empty state with a button that opens System Settings to the right pane |
| File too large | Skip that file, list skipped paths in the reply preamble |
| Disk full / SQLite error | Block send, show “Could not save chat”, do not crash |
| Apply patch conflict | Do not write; show the failed hunk; keep preview |

No modal alerts on the hotkey window except permission sheets.

## 8. Testing

- **Launch bench (CI + local):** script launches the app, waits for composer focus, asserts ≤ 1.2s. Fail the build if exceeded on the reference Mac (Apple Silicon, 16GB). Until CI Macs exist, run as a required local script before tagging a release.
- **Hotkey bench:** inject the hotkey while the app is already running; assert ≤ 100ms to visible.
- **Stream unit tests:** LlmSidecar against a local fake HTTP server; cancel mid-stream; coalescing.
- **SessionStore:** metadata-only launch query does not read `messages` blobs (assert with query plan / SQL trace).
- **CodeSidecar:** apply is off by default in tests; patch preview golden files; ignore rules; command allowlist rejects `curl` and `rm`.
- **UI:** SwiftUI snapshot of empty window and streaming placeholder; no network.

## 9. Phased delivery

Each phase is a shippable tag. Do not start the next phase’s default-path work until the current phase’s gates pass.

### P0 — Performance foundation (1–2 weeks)

Ship: menu bar extra, global hotkey window, empty composer, settings shell, SessionStore metadata, local telemetry of launch/hotkey.

Do not ship: models, skills, sidecars, accounts.

Gate: cold start ≤ 1.2s, hotkey ≤ 100ms.

### P1 — Chat core (2–3 weeks)

Ship: LlmSidecar, streaming, cancel, OpenAI-compatible + local endpoint, clipboard / file drop into context (size caps), persist messages.

Do not ship: agents that write files, work templates, IDE features.

Gate: placeholder ≤ 100ms, first-token feel ≤ 300ms, no main-thread stalls.

### P2 — Work slice (3–4 weeks)

Ship: WorkSidecar; summarize / rewrite / meeting notes; selection and Finder file summarize; Shortcuts / Services entry points for those three actions.

Do not ship: generic RPA, company-wide knowledge sync.

Gate: unused work skills add ≤ 80ms to cold start.

### P3 — Coding agent, on demand (4–6 weeks)

Ship: CodeSidecar after workspace open; `@file`; diff preview + confirm apply; read-only git explain; allowlisted read-only terminal.

Do not ship: always-on index, LSP, multi-agent, unattended writes.

Gate: with no workspace, memory and cold start within 10% of P1.

### P4 — Dual-core polish (ongoing)

Ship: incremental index behind a toggle (off by default), workflow templates, PluginHost, optional account/quota. Performance regression suite is required on every merge to main.

Do not ship: Windows until Mac gates stay green for two consecutive minor releases.

## 10. Repository layout (from empty repo)

```
macbuddy/
  Apps/MacBuddy/          SwiftUI app target
  Sidecars/LLM/           Swift sidecar; OpenAI-compatible HTTP only
  Sidecars/Work/
  Sidecars/Code/
  Packages/SessionStore/
  Packages/Telemetry/
  docs/superpowers/
  Scripts/perf/           launch and hotkey benches
```

P0 implements `Apps/MacBuddy`, `Packages/SessionStore`, `Packages/Telemetry`, and `Scripts/perf` only.

## 11. Decisions already made

- Product name in-repo: MacBuddy.
- UI toolkit: SwiftUI, macOS 14+ (Sonoma).
- Default hotkey: Command-Shift-Space.
- Sidecar language: Swift + XPC through P3. Another language only if a phase gate fails and a rewrite is justified.
- First model integration: OpenAI-compatible HTTP, user-supplied base URL and key; optional local endpoint with the same API.
- Persistence: SQLite + files, not CloudKit, in P0–P3.
- Code writes: preview-then-confirm only.
- Plugins: not before P4.
- Implementation plans after this spec: one plan per phase, starting with P0. This document is the product design, not a single implementation ticket.

## 12. Success for the first public demo

A reviewer on a Mac can:

1. Launch and type in under 1.2s.
2. Summon with the hotkey in under 100ms.
3. Stream a chat reply and cancel it.
4. Rewrite selected text.
5. Open a folder, ask for a change, see a diff, decline or apply.

If (1) or (2) fail, the demo fails regardless of (3)–(5).
