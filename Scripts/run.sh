#!/usr/bin/env bash
# One command: build (if needed) and launch MacBuddy.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="$ROOT/Apps/MacBuddy/build/Debug/MacBuddy.app"
BIN="$APP/Contents/MacOS/MacBuddy"

if [[ ! -x "$BIN" ]]; then
  echo "MacBuddy.app not found — building…"
  bash "$ROOT/Scripts/build_app.sh"
fi

open "$APP"
