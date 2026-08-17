#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/common.sh"

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
READ_PY="$ROOT/Scripts/perf/read_telemetry.py"
SUPPORT="$HOME/Library/Application Support/MacBuddy/Telemetry/perf.jsonl"

require_app
kill_macbuddy
rm -f "$SUPPORT"

open -g "$MACBUDDY_APP"

DURATION=-1
deadline=$(( $(date +%s) + 15 ))
while (( $(date +%s) < deadline )); do
  if DURATION=$(python3 "$READ_PY" coldStart 2>/dev/null); then
    break
  fi
  sleep 0.2
done

if [[ "$DURATION" == "-1" ]] || ! python3 - <<PY
import sys
try:
    v = float("$DURATION")
except ValueError:
    sys.exit(1)
sys.exit(0 if v >= 0 else 1)
PY
then
  echo "FAIL: no coldStart event recorded within 15s"
  kill_macbuddy
  exit 1
fi

if python3 - <<PY
import sys
v = float("$DURATION")
sys.exit(0 if v <= 1200 else 1)
PY
then
  echo "PASS: cold start ${DURATION}ms"
else
  echo "FAIL: cold start ${DURATION}ms > 1200ms budget"
  kill_macbuddy
  exit 1
fi

kill_macbuddy
