#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/common.sh"

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
READ_PY="$ROOT/Scripts/perf/read_telemetry.py"
SUPPORT="$HOME/Library/Application Support/MacBuddy/Telemetry/perf.jsonl"

require_app
kill_macbuddy
rm -f "$SUPPORT"

# Bench mode: panel hidden at launch; MACBUDDY_BENCH_HOTKEY triggers toggle path.
MACBUDDY_BENCH=1 MACBUDDY_BENCH_HOTKEY=1 open -g "$MACBUDDY_APP"

DURATION=-1
deadline=$(( $(date +%s) + 10 ))
while (( $(date +%s) < deadline )); do
  if DURATION=$(python3 "$READ_PY" hotkeyToVisible 2>/dev/null); then
    break
  fi
  sleep 0.2
done

if [[ "$DURATION" == "-1" ]]; then
  echo "FAIL: no hotkeyToVisible event within 10s"
  kill_macbuddy
  exit 1
fi

if python3 - <<PY
import sys
v = float("$DURATION")
sys.exit(0 if v <= 100 else 1)
PY
then
  echo "PASS: hotkey ${DURATION}ms"
else
  echo "FAIL: hotkey ${DURATION}ms > 100ms budget"
  kill_macbuddy
  exit 1
fi

kill_macbuddy
