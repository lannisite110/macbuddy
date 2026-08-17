# P2 Work Assistant Slice — Plan

**Goal:** Summarize / rewrite / meeting notes on selected text or files, with Services menu integration — lazy-loaded, no cold-start regression.

**Shipped:**
- `Packages/WorkSkills` — prompts, `WorkEngine`, `SelectionReader`, `PermissionBroker`, `FileTextReader`
- Menu bar **Work** submenu (3 selection actions + Summarize File)
- macOS **Services** entries (text + file URL)
- Result sheet with Copy / Replace Selection
- Work sessions persisted to `SessionStore` (`origin: work`)

**Gate:** WorkSkills not initialized until first work action (`WorkCoordinator` / `WorkEngine` lazy).

## Try it

```bash
bash Scripts/build_app.sh
open Apps/MacBuddy/build/Debug/MacBuddy.app
```

1. System Settings → Privacy & Security → **Accessibility** → enable MacBuddy
2. Select text in any app → menu bar **MB → Work → Summarize Selection**
3. Or right-click text → Services → **MacBuddy: Summarize**
4. **Summarize File…** for Finder text files
