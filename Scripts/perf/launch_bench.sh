#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/common.sh"
require_app
kill_macbuddy

SUPPORT="$HOME/Library/Application Support/MacBuddy/Telemetry/perf.jsonl"
rm -f "$SUPPORT"

open -g "$MACBUDDY_APP"
sleep 2

DURATION=$(python3 - <<'PY'
import json, os
path = os.path.expanduser("~/Library/Application Support/MacBuddy/Telemetry/perf.jsonl")
if not os.path.exists(path):
    print(-1)
    raise SystemExit
last = None
for line in open(path):
    ev = json.loads(line)
    if ev.get("kind") == "coldStart":
        last = ev["durationMs"]
print(last if last is not None else -1)
PY
)

if (( $(echo "$DURATION < 0" | bc -l) )); then
  echo "FAIL: no coldStart event recorded"
  exit 1
fi

if (( $(echo "$DURATION > 1200" | bc -l) )); then
  echo "FAIL: cold start ${DURATION}ms > 1200ms budget"
  exit 1
fi

echo "PASS: cold start ${DURATION}ms"
kill_macbuddy
