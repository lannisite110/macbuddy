# P3 Coding Agent — Plan

**Goal:** On-demand coding agent after opening a workspace — `@file` mentions, diff preview, confirm-to-apply, read-only git.

**Shipped:**
- `Packages/CodeEngine` — workspace scan, ignore rules, `@file` parser, patch preview/apply, git diff/log, allowlisted commands
- `CodeCoordinator` — lazy engine, 30s idle close, open/close workspace
- **Code** menu + chat panel project bar
- When workspace open, **Send** routes to code patch flow
- **DiffPreviewView** — Apply / Decline
- Git explain via menu (diff + log)

**Gate:** `CodeEngine` only created when opening a workspace; closed clears engine.

## Try it

```bash
bash Scripts/build_app.sh
open Apps/MacBuddy/build/Debug/MacBuddy.app
```

1. **MB → Code → Open Workspace…** (or chat panel **Open Project**)
2. Type: `add a comment to @Apps/MacBuddy/MacBuddy/AppState.swift`
3. Review diff → **Apply** or **Decline**
4. **Code → Explain Git Diff** for read-only git output
