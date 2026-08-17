#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

echo "== MacBuddy P4 regression suite =="

PACKAGES=(SessionStore Telemetry SettingsStore LLMClient SidecarIPC WorkSkills CodeEngine PluginHost WorkflowTemplates)
for pkg in "${PACKAGES[@]}"; do
  echo "-- swift test: $pkg"
  swift test --package-path "Packages/$pkg"
done

echo "-- swift build: MacBuddy app"
swift build --package-path Apps/MacBuddy

echo "-- build app bundle"
bash Scripts/build_app.sh

echo "-- launch bench (P0 gate)"
bash Scripts/perf/launch_bench.sh

echo "-- hotkey bench (P0 gate)"
bash Scripts/perf/hotkey_bench.sh

echo ""
echo "ALL PASS: P4 regression suite"
