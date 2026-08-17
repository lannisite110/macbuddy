#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/common.sh"
require_app
kill_macbuddy
open -g "$MACBUDDY_APP"
sleep 1
echo "Press ⌘⇧Space once, then Enter"
read -r

python3 - <<'PY'
import json, os, sys
path = os.path.expanduser("~/Library/Application Support/MacBuddy/Telemetry/perf.jsonl")
rows = [json.loads(l) for l in open(path)] if os.path.exists(path) else []
hot = [r for r in rows if r.get("kind") == "hotkeyToVisible"]
if not hot:
    print("FAIL: no hotkeyToVisible event")
    sys.exit(1)
ms = hot[-1]["durationMs"]
if ms > 100:
    print(f"FAIL: hotkey {ms}ms > 100ms")
    sys.exit(1)
print(f"PASS: hotkey {ms}ms")
PY
kill_macbuddy
