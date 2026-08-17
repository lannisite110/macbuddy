#!/usr/bin/env bash
set -euo pipefail

MACBUDDY_APP="${MACBUDDY_APP:-$(cd "$(dirname "$0")/../.." && pwd)/Apps/MacBuddy/build/Debug/MacBuddy.app}"

require_app() {
  if [[ ! -d "$MACBUDDY_APP" ]]; then
    echo "Building app bundle via Scripts/build_app.sh"
    bash "$(cd "$(dirname "$0")/../.." && pwd)/Scripts/build_app.sh"
  fi
  if [[ ! -d "$MACBUDDY_APP" ]]; then
    echo "Build the app first: bash Scripts/build_app.sh"
    exit 1
  fi
}

kill_macbuddy() {
  pkill -x MacBuddy 2>/dev/null || true
  sleep 0.2
}
