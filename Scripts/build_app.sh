#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$ROOT/Apps/MacBuddy/build/Debug"
APP="$OUT/MacBuddy.app"

swift build --package-path "$ROOT/Apps/MacBuddy" -c debug

mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$ROOT/Apps/MacBuddy/MacBuddy/Info.plist" "$APP/Contents/Info.plist"
cp "$ROOT/Apps/MacBuddy/.build/debug/MacBuddy" "$APP/Contents/MacOS/MacBuddy"
chmod +x "$APP/Contents/MacOS/MacBuddy"

echo "Built $APP"
