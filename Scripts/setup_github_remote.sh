#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

if ! command -v gh >/dev/null; then
  echo "Install GitHub CLI: brew install gh"
  exit 1
fi

if ! gh auth status >/dev/null 2>&1; then
  echo "Sign in first: gh auth login -h github.com -p ssh -w"
  exit 1
fi

if git remote get-url origin >/dev/null 2>&1; then
  echo "Remote origin already set:"
  git remote -v
  git push -u origin main --tags
  exit 0
fi

gh repo create macbuddy --private --source=. --remote=origin --description "Mac-native work + coding assistant"
git push -u origin main --tags
echo "Pushed to $(gh repo view --json url -q .url)"
