#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$ROOT/Apps/MacBuddy/build/Debug"
APP="$OUT/MacBuddy.app"
HELPERS="$APP/Contents/Helpers"

swift build --package-path "$ROOT/Apps/MacBuddy" -c debug
swift build --package-path "$ROOT/Sidecars/LLMSidecar" -c debug

mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" "$HELPERS"
cp "$ROOT/Apps/MacBuddy/MacBuddy/Info.plist" "$APP/Contents/Info.plist"
cp "$ROOT/Apps/MacBuddy/.build/debug/MacBuddy" "$APP/Contents/MacOS/MacBuddy"
cp "$ROOT/Sidecars/LLMSidecar/.build/debug/MacBuddyLLM" "$HELPERS/MacBuddyLLM"
chmod +x "$APP/Contents/MacOS/MacBuddy" "$HELPERS/MacBuddyLLM"

echo "Built $APP (with MacBuddyLLM sidecar)"
